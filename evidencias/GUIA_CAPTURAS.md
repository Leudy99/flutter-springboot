# Guía de capturas (evidencias)

Todas las capturas deben ser de **tu pantalla**, tomadas en el momento. El script las ordena:

```powershell
powershell -ExecutionPolicy Bypass -File .\evidencias\capturas.ps1
```

El script deja el backend en **2 réplicas** para las primeras capturas, te pide abrir el navegador, escala a **5 réplicas** y muestra el resultado. Se detiene tras cada bloque: toma la captura con `Win + Shift + S` y presiona Enter.

| # | Captura | Qué debe verse | Descripción para el PDF |
|---|---|---|---|
| 1 | `docker images` | `springboot-backend` y `flutter-frontend` con su etiqueta `1.0` y tamaño | Imágenes Docker construidas para backend y frontend |
| 2 | `kubectl get pods` | 2 Pods `backend-deployment-…` y 1 `frontend-deployment-…`, todos `Running` | Pods con el backend en 2 réplicas |
| 3 | `kubectl get deployments` | `backend-deployment 2/2` y `frontend-deployment 1/1` | Deployments con sus réplicas disponibles |
| 4 | `kubectl get svc` | `backend-service` (30081) y `frontend-service` (30080) | Services que exponen backend y frontend |
| 5 | Navegador en `http://localhost:30080` | La app Flutter con la sesión iniciada y datos visibles | Frontend funcionando sobre Kubernetes |
| 6 | Navegador en `http://localhost:30081/api/users/me` | Respuesta 401 (o la pantalla de la app con datos) | Backend respondiendo desde Kubernetes |
| 7 | `kubectl get deployments` tras escalar | `backend-deployment 5/5` | Backend escalado a 5 réplicas |
| 8 | `kubectl get pods` tras escalar | 5 Pods `backend-deployment-…` en `Running` | Los 5 Pods del backend |

Las capturas 2 y 3 (2 réplicas) y las 7 y 8 (5 réplicas) deben mostrar claramente el cambio **2 → 5**.

Guarda las imágenes en esta carpeta (`evidencias/`) con nombres como `01-docker-images.png`, `02-pods-2-replicas.png`, etc. El PDF se arma al final con estas imágenes y la descripción de cada una.
