# Muestra, en orden, cada comando de las evidencias de Docker y Kubernetes.
# Tras cada bloque se detiene: toma la captura de pantalla y presiona Enter.
# Uso:  powershell -ExecutionPolicy Bypass -File .\evidencias\capturas.ps1

function Paso($numero, $titulo, $comandos) {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  CAPTURA $numero - $titulo" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    foreach ($c in $comandos) {
        Write-Host ""
        Write-Host "> $c" -ForegroundColor Yellow
        Invoke-Expression $c
    }
    Write-Host ""
    Read-Host "Toma la captura y presiona Enter para continuar"
}

function Esperar($replicas) {
    Write-Host "Esperando a que el backend tenga $replicas replicas listas..." -ForegroundColor DarkGray
    for ($i = 0; $i -lt 40; $i++) {
        $listas = kubectl get deployment backend-deployment -o jsonpath='{.status.readyReplicas}'
        $total  = kubectl get pods -l app=backend --no-headers | Measure-Object | Select-Object -ExpandProperty Count
        if ($listas -eq "$replicas" -and $total -eq $replicas) { return }
        Start-Sleep -Seconds 3
    }
}

Paso 1 "Imagenes Docker (backend y frontend)" @('docker images | Select-String "REPOSITORY|springboot-backend|flutter-frontend"')

kubectl scale deployment backend-deployment --replicas=2 | Out-Null
Esperar 2
Paso 2 "Pods con el backend en 2 replicas" @('kubectl get pods')
Paso 3 "Deployments (backend 2/2)" @('kubectl get deployments')
Paso 4 "Services" @('kubectl get svc')

Clear-Host
Write-Host "CAPTURAS 5 y 6 - Aplicacion funcionando" -ForegroundColor Cyan
Write-Host "  1. Abre http://localhost:30080 en el navegador, inicia sesion y muestra los datos."
Write-Host "  2. Abre http://localhost:30081/api/users/me (responde 401: el backend esta activo y exige token)."
Write-Host "     O muestra la pantalla de la app con usuarios/archivos cargados desde el backend."
Read-Host "Toma las capturas y presiona Enter para escalar el backend a 5 replicas"

Clear-Host
Write-Host "> kubectl scale deployment backend-deployment --replicas=5" -ForegroundColor Yellow
kubectl scale deployment backend-deployment --replicas=5
Esperar 5
Paso 7 "Escalado: Deployment con 5 replicas" @('kubectl get deployments')
Paso 8 "Escalado: los 5 Pods del backend" @('kubectl get pods')

Write-Host "Listo. El backend queda en 5 replicas." -ForegroundColor Green
