# Evidencias (Docker y Kubernetes)

`Evidencias_Docker_Kubernetes.pdf` reúne las capturas de pantalla tomadas el 3 de noviembre de 2026 con los comandos ejecutados contra el cluster de Docker Desktop.

| # | Archivo | Contenido |
|---|---|---|
| 1 | `01-docker-images.png` | `docker images`: `springboot-backend:1.0` y `flutter-frontend:1.0` |
| 2 | `02-pods-2-replicas.png` | `kubectl get pods`: 2 Pods del backend y 1 del frontend, `Running` |
| 3 | `03-deployments-2-replicas.png` | `kubectl get deployments`: backend 2/2, frontend 1/1 |
| 4 | `04-services.png` | `kubectl get svc`: `backend-service` (30081) y `frontend-service` (30080) |
| 5 | `05-frontend-funcionando.png` | App Flutter Web en `http://localhost:30080` con datos del backend |
| 6 | `06-backend-usuarios.png` | Pantalla de usuarios, obtenidos de la API en Kubernetes |
| 7 | `07-escalado-comando.png` | `kubectl scale deployment backend-deployment --replicas=5` y Pods nuevos |
| 8 | `08-deployments-5-replicas.png` | `kubectl get deployments`: backend 5/5 |
| 9 | `09-pods-5-replicas.png` | `kubectl get pods`: 5 Pods del backend en `Running` |

Para repetir las capturas a mano, `capturas.ps1` ejecuta los comandos en orden y se detiene tras cada bloque:

```powershell
powershell -ExecutionPolicy Bypass -File .\evidencias\capturas.ps1
```
