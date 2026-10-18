# Pruebas de carga (K6)

Mide cómo responde la arquitectura serverless bajo carga concurrente:

```text
K6 ─HTTPS─> API Gateway ─> Lambda principal ─> SNS ─> SQS ─> notification-lambda
```

Endpoint bajo prueba: `POST /notifications/send` (requiere JWT).

## Archivos

| Archivo | Qué hace |
| --- | --- |
| `config.js` | URL, login, la petición medida, estadísticos y formato del resultado |
| `baseline.js` | Línea base: 10 usuarios virtuales, 1 minuto |
| `progressive.js` | Un nivel de carga por ejecución (50, 100, 250, 500 usuarios, 2 min) |
| `stress.js` | Un nivel de estrés por ejecución (20 s de rampa + 60 s sostenido); aborta con más de 5 % de errores o P95 > 5 s en la fase sostenida |
| `recovery.js` | Carga alta que luego se detiene para medir la recuperación |
| `run.py` | Driver: lanza K6, muestrea la cola SQS, mide el vaciado y aplica los criterios de parada |
| `plot.py` | Gráficas a partir de los resultados reales (`results/charts/`) |
| `results/` | Resultados de cada ejecución: `*.json` (K6), `*-queue.csv` (cola SQS), `logs-*.json` (Logs Insights), `aws-metrics-*.csv` (métricas de CloudWatch) y `charts/` |

## Configuración de las pruebas

- **Usuarios virtuales:** cada uno envía una petición, espera `THINK_TIME` (1 s por defecto) y repite.
- **Destinatario:** `test@test.com`. El dominio `test.com` activa el **modo de carga** de `notification-lambda`: el mensaje se recibe, valida y registra igual, pero **no se llama a SES** (en sandbox solo permite 200 correos al día). Con un correo real, el correo sí se envía; así se hace la prueba funcional independiente.
- **Autenticación:** K6 inicia sesión una vez en `setup()` y todos los usuarios virtuales reutilizan el JWT. La petición de login **no** entra en los resultados.
- **Credenciales:** nada sensible está en el repositorio. El usuario de pruebas llega por las variables de entorno `K6_EMAIL` y `K6_PASSWORD`. La URL de API Gateway se puede cambiar con `BASE_URL`.
- **Generador de carga:** K6 corre desde el PC del autor, en Docker (imagen `grafana/k6`). A cargas muy altas, la CPU y la red del PC también pueden limitar.

## Cómo ejecutarlas

Requisitos: Docker (o K6 instalado), AWS CLI configurado y Python 3 con `matplotlib`.

```bash
export K6_EMAIL=usuario-de-pruebas@test.com
export K6_PASSWORD=...        # contraseña del usuario de pruebas (no se guarda en el repo)

python run.py baseline --name baseline
python run.py progressive --levels 50 100 250 500
python run.py stress --levels 20 30 40 50 100 250 500 750 1000 1500 2000   # se detiene en el primer nivel fuera de parámetros
python run.py recovery --vus 250
python plot.py
```

También se puede lanzar un script directamente con K6:

```bash
k6 run -e K6_EMAIL=... -e K6_PASSWORD=... baseline.js
k6 run -e VUS=100 -e DURATION=2m -e K6_EMAIL=... -e K6_PASSWORD=... progressive.js
```

Cada ejecución guarda un JSON con peticiones, throughput, errores, latencia (promedio, mínimo, máximo, mediana, P90, P95 y P99), respuestas por código y, con `run.py`, el comportamiento de la cola.

### Criterios de parada del estrés

`run.py stress` sube de nivel y se detiene si ocurre algo de esto:

1. Más de 5 % de errores.
2. Latencia P95 superior a 5 segundos.
3. Throttling: más de 1 % de respuestas `429`.
4. Saturación de SQS: mensajes en la DLQ, o la cola no se vacía en 3 minutos.
5. Se alcanza el presupuesto de peticiones (`--max-requests`, 250000 por defecto), una protección de costes.

### Métricas de AWS

```bash
python run.py metrics --name estres --start 2026-10-18T15:00:00Z --end 2026-10-18T15:30:00Z
```

Descarga de CloudWatch (por minuto) las métricas de API Gateway, las dos Lambdas, SNS y SQS. Requiere permiso `cloudwatch:GetMetricStatistics`.

## Cuidado con los costes

Cada petición cuesta una fracción de centavo (API Gateway, Lambda, SNS, SQS y logs). Con las cargas de este informe el total queda dentro de la capa gratuita o en pocos centavos. El límite de peticiones de API Gateway se elevó solo durante las pruebas y se restauró después (ver el informe).
