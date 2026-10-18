# Informe de pruebas de carga y rendimiento

Endpoint probado: `POST /notifications/send`, en la arquitectura desplegada en AWS:

```text
K6 ─> API Gateway (HTTP API) ─> Lambda principal (Java 17, SnapStart) ─> SNS ─> SQS ─> notification-lambda (Python)
```

Todos los números de este informe salen de las ejecuciones guardadas en `load-tests/results/`. No hay valores estimados.

## 1. Herramienta y método

- **K6** (v2.3.0, en Docker) desde el PC del autor, hacia la URL pública de API Gateway.
- Cada usuario virtual (VU) envía una petición, espera 1 s y repite. Login una sola vez en `setup()` (no cuenta en los resultados).
- Destinatario `test@test.com`: **modo de carga** de `notification-lambda` (recibe, valida y registra el mensaje, pero no llama a SES, que en sandbox permite solo 200 correos/día). El flujo evaluado (API → Lambda → SNS → SQS → Lambda) es el mismo. El envío real queda en una prueba funcional aparte con `leudy0023@hotmail.com`, ya demostrada con correo recibido.
- Sin secretos en el repositorio: usuario y contraseña de pruebas llegan por variables de entorno.
- Costo: unas 129541 peticiones medidas en total, dentro de la capa gratuita o en centavos. SES no se usó en las pruebas de carga.

## 2. Resultados

Se probaron dos configuraciones de API Gateway. **Como estaba desplegado** el límite era 10 req/s (ráfaga 20): se midió primero para tener la línea base real. Después se subió temporalmente (10 000 req/s) para medir el resto de la arquitectura y se restauró a 10/20 al terminar.

| Escenario | VU | Peticiones | Req/s | Errores | Prom. (ms) | P95 (ms) | P99 (ms) | Respuestas |
|---|---|---|---|---|---|---|---|---|
| Línea base, límite 10/20 | 10 | 533 | 8,7 | 0 % | 131 | 156 | 1157 | 200: 533 |
| Línea base, límite alto | 10 | 531 | 8,4 | 0 % | 135 | 152 | 1485 | 200: 531 |
| Progresivo, límite 10/20 | 50 | 5579 | 45,8 | 81,9 % | 79 | 114 | 133 | 200: 1010 · 429: 4338 · 5xx: 231 |
| Progresivo | 50 | 5476 | 45,0 | 14,3 % | 99 | 120 | 143 | 200: 4694 · 5xx: 782 |
| Progresivo | 100 | 11031 | 90,6 | 48,0 % | 90 | 114 | 144 | 200: 5731 · 5xx: 5300 |
| Progresivo | 250 | 27590 | 226,2 | 70,4 % | 89 | 118 | 236 | 200: 8174 · 5xx: 19416 |
| Progresivo | 500 | 55370 | 455,5 | 80,1 % | 82 | 102 | 187 | 200: 11009 · 5xx: 44361 |

Estrés (20 s de rampa + fase sostenida; solo la fase sostenida cuenta):

| VU | Req/s | Errores | P95 (ms) | Resultado |
|---|---|---|---|---|
| 20 | 13,4 | 0 % | 132 | aceptable |
| 30 | 20,1 | 0 % | 132 | aceptable |
| 40 | 26,9 | 1,6 % | 132 | aceptable |
| 50 | 33,7 | 1,3 % | 123 | aceptable |
| 100 | 47,6 | 10,7 % | 113 | **detenido: > 5 % de errores** |

Capacidad aceptable medida: **hasta 50 usuarios concurrentes (~34 req/s)**. Con 100 se superó el 5 % de errores y la prueba se detuvo según el criterio de la actividad (no se llegó a 2000 VU).

Recuperación (250 VU, 1 min): 13 749 peticiones, 81,9 % de errores; la cola SQS llegó a **1917 mensajes visibles**, 0 en DLQ, y se **vació en 68 s** tras detener la carga.

Gráficas: `load-tests/results/charts/` (`progresivo-*.png`, `estres-*.png`, `*-cola.png`).

## 3. Qué muestran los logs

Consultas de CloudWatch Logs Insights sobre cada ventana (`results/logs-*.json`):

- **Cero errores dentro de las Lambdas**, en todas las pruebas.
- Cada respuesta 5xx de K6 **no tiene ejecución** de la Lambda principal: el rechazo ocurre antes de ejecutar el código (ejecuciones de la Lambda principal = peticiones 200). La Lambda dura ~20 ms de promedio.
- Ningún mensaje se pierde: los mensajes publicados en SNS coinciden con las ejecuciones de `notification-lambda`; DLQ siempre en 0.
- `notification-lambda` tarda ~3 ms por mensaje (modo de carga) y arranca en frío pocas veces (5).
- Con 250 VU la cola crece y se drena después: el consumidor va por detrás del productor, pero se recupera sin pérdida.

## 4. Cuello de botella

1. **Primero, API Gateway con límite 10 req/s / ráfaga 20** (config. original): con 50 VU devolvió **429** en 78 % de las peticiones. Medido y confirmado por el código de estado.
2. **Con el límite elevado**, los rechazos pasan a ser **503** que nunca llegan al código de la Lambda. Esto apunta al **límite de concurrencia de Lambda de la cuenta (10 ejecuciones simultáneas), compartido** entre la Lambda principal y `notification-lambda`, que además se dispara por SQS y compite por el mismo cupo. Es lo coherente con: errores solo de 40 VU en adelante, latencia de las respuestas buenas estable (~100 ms), rechazos instantáneos.
   - **Estado de la evidencia:** esta segunda parte es una **inferencia a partir de logs y códigos de estado**, no está confirmada con métricas. Falta la métrica `Throttles` / `ConcurrentExecutions` de CloudWatch: el usuario `terraform-deploy` no tiene `cloudwatch:GetMetricStatistics` (`python run.py metrics` lo documenta). Para cerrarla, el autor debe tomar capturas de CloudWatch (Lambda → Throttles y ConcurrentExecutions, API Gateway → 5xx) de las ventanas indicadas en `load-tests/README.md`, o dar el permiso `CloudWatchReadOnlyAccess`.

SNS, SQS y SES no son el cuello de botella: SNS/SQS no perdieron mensajes y SES no entró en las pruebas de carga.

## 5. Recomendaciones

1. Pedir aumento de la cuota de **concurrencia de Lambda** (Service Quotas) de 10 a un valor típico (1000). Es el cambio de mayor efecto.
2. Limitar la concurrencia del consumidor SQS (*maximum concurrency* del event source mapping) para que `notification-lambda` no consuma el cupo de la Lambda principal.
3. Mantener un límite de API Gateway acorde al tráfico real (el 10/20 inicial bloquea ya con 50 usuarios) y devolver `Retry-After` en 429/503.
4. Que el cliente reintente con espera exponencial ante 503.
5. Para correos reales, solicitar salida del sandbox de SES (hoy 200/día, 1/s).
6. Antes de optimizar nada más, repetir la línea base tras el cambio y comparar.

## 6. Preguntas de análisis

- **¿Cuántos usuarios soporta?** Hasta ~50 concurrentes (~34 req/s) con menos de 5 % de errores.
- **¿Dónde empieza a degradarse?** Entre 40 y 50 VU aparecen los primeros errores; con 100 supera el 5 %.
- **¿La latencia sube con la carga?** No: se mantiene ~80–140 ms (P95 < 240 ms) porque lo que sobra se rechaza al instante. El P99 de la línea base (1,1–1,5 s) corresponde a las primeras peticiones (arranque de la Lambda).
- **¿Qué falla primero?** La puerta de entrada: el límite de API Gateway (429) y luego la concurrencia de Lambda (503), no el código.
- **¿Se pierden mensajes?** No: DLQ en 0 y SNS = ejecuciones del consumidor.
- **¿Se recupera?** Sí: la cola de 1917 mensajes se vació en 68 s tras parar la carga.
- **¿SQS cumple su función?** Sí: absorbe el pico y lo drena después sin pérdida.
- **Limitaciones:** K6 corre desde un PC doméstico; no se confirmó con métricas de CloudWatch (ver sección 4); no se llegó a 2000 VU porque el criterio de parada se activó en 100.

## 7. Evidencias pendientes (a cargo del autor)

Capturas de consola AWS: API Gateway (4xx/5xx), Lambda (Throttles, ConcurrentExecutions), SNS, SQS (mensajes visibles) y CloudWatch Logs. Ventanas reales del 2026-10-18 (inicio–fin de K6):

- 15:15:58–15:16:59 UTC: baseline-como-desplegado
- 15:17:50–15:19:52 UTC: progressive-50vu-como-desplegado
- 15:22:55–15:23:58 UTC: baseline-limite-alto
- 15:24:21–15:26:23 UTC: progressive-50vu
- 15:27:34–15:29:35 UTC: progressive-100vu
- 15:31:35–15:33:37 UTC: progressive-250vu
- 15:36:17–15:38:18 UTC: progressive-500vu
- 15:54:55–15:56:16 UTC: stress-20vu
- 15:56:26–15:57:48 UTC: stress-30vu
- 15:58:04–15:59:26 UTC: stress-40vu
- 15:59:42–16:01:04 UTC: stress-50vu
- 16:01:20–16:02:02 UTC: stress-100vu
- 16:03:45–16:04:47 UTC: recovery-250vu
