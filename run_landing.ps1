$host.ui.RawUI.WindowTitle = "JCG Landing Page Server (Port 8080)"
$landingDir = Join-Path $PSScriptRoot "landing_page"
Set-Location $landingDir
python -m http.server 8080
