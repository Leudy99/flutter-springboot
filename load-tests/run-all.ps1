# Ejecuta TODAS las pruebas de carga en orden, con topes para cuidar el costo.
# Uso:  powershell -ExecutionPolicy Bypass -File .\run-all.ps1
# Las credenciales NO estan en este archivo: se toman de K6_EMAIL / K6_PASSWORD o se piden.

# Los resultados del video llevan sufijo -video: NO pisan los resultados del informe.
$ErrorActionPreference = "Stop"
$inicio = (Get-Date).ToUniversalTime()
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
Step "ACTIVIDAD 2 - Incremento progresivo (50, 100, 250 y 500 usuarios, 2 min c/u)" "python run.py progressive --levels 50 100 250 500 --suffix=-video"
Step "ACTIVIDAD 4 - Prueba de estres (20, 50, 100, 250 y 500 usuarios)"          "python run.py stress --levels 20 50 100 250 500 --suffix=-video --continue-after-degradation --max-requests 150000"
Step "ACTIVIDAD 5 - Recuperacion (250 usuarios, luego se detiene)"        "python run.py recovery --vus 250"

$fin = (Get-Date).ToUniversalTime()
Write-Host ""
Write-Host "VENTANA DE LAS PRUEBAS (para el selector de tiempo de CloudWatch):" -ForegroundColor Yellow
Write-Host "  Inicio: $($inicio.ToString('yyyy-MM-dd HH:mm:ss')) UTC   Fin: $($fin.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor Yellow
Write-Host "TERMINADO. Resultados en load-tests\results\" -ForegroundColor Green
Write-Host "Espera 1-2 min y refresca las pestanas de CloudWatch (actividad 3)." -ForegroundColor Green
