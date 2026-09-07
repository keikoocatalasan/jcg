$host.ui.RawUI.WindowTitle = "JCG FastAPI Backend"
$backendDir = Join-Path $PSScriptRoot "backend"
Set-Location $backendDir
$pythonPath = Join-Path $backendDir ".venv\Scripts\python.exe"
if (-not (Test-Path $pythonPath)) {
    throw "Backend virtual environment was not found at $pythonPath. Run the setup steps in README.md first."
}
$backendPort = if ($env:JCG_BACKEND_PORT) { $env:JCG_BACKEND_PORT } else { "8000" }
Write-Host "Starting JCG FastAPI on port $backendPort..." -ForegroundColor Green
& $pythonPath -m uvicorn app.main:app --reload --host 0.0.0.0 --port $backendPort
