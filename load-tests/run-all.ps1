# Ejecuta TODAS las pruebas de carga en orden, con topes para cuidar el costo.
# Uso:  powershell -ExecutionPolicy Bypass -File .\run-all.ps1
# Las credenciales NO estan en este archivo: se toman de K6_EMAIL / K6_PASSWORD o se piden.

# Los resultados del video llevan sufijo -video: NO pisan los resultados del informe.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $env:K6_EMAIL)    { $env:K6_EMAIL = Read-Host "K6_EMAIL" }
if (-not $env:K6_PASSWORD) {
    $sec = Read-Host "K6_PASSWORD" -AsSecureString
    $env:K6_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}

function Step($titulo, $comando) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  $titulo" -ForegroundColor Cyan
    Write-Host "  Inicio: $((Get-Date).ToUniversalTime().ToString('HH:mm:ss')) UTC" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Invoke-Expression $comando
    if ($LASTEXITCODE -ne 0) { throw "Fallo en: $titulo (codigo $LASTEXITCODE)" }
    Start-Sleep -Seconds 20   # pausa para que CloudWatch registre y para mostrar graficas
}

Step "ACTIVIDAD 1 - Linea base (10 usuarios, 1 min)"        "python run.py baseline --name video-baseline"
Step "ACTIVIDAD 2 - Incremento progresivo (50 y 100 usuarios, 2 min c/u)" "python run.py progressive --levels 50 100 --suffix=-video"
Step "ACTIVIDAD 4 - Prueba de estres (20, 40, 50, 100 usuarios)"          "python run.py stress --levels 20 40 50 100 --suffix=-video --continue-after-degradation --max-requests 40000"
Step "ACTIVIDAD 5 - Recuperacion (100 usuarios, luego se detiene)"        "python run.py recovery --vus 100"

Write-Host ""
Write-Host "TERMINADO. Resultados en load-tests\results\" -ForegroundColor Green
Write-Host "Espera 1-2 min y refresca las pestanas de CloudWatch (actividad 3)." -ForegroundColor Green
