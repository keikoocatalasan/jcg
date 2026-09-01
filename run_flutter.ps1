$host.ui.RawUI.WindowTitle = "JCG Flutter App"
Set-Location "C:\Users\john\projects\jcg\flutter_app"
Write-Host "Waiting for Android Emulator to complete system boot..." -ForegroundColor Yellow
do {
    Start-Sleep -Seconds 3
    $boot = & "C:\Users\john\AppData\Local\Android\sdk\platform-tools\adb.exe" shell getprop sys.boot_completed 2>$null
} until ($boot -and $boot.Trim() -eq "1")
Write-Host "Android OS fully booted! Starting Flutter App..." -ForegroundColor Green
$fastApiBaseUrl = if ($env:JCG_FASTAPI_BASE_URL) {
    $env:JCG_FASTAPI_BASE_URL
} else {
    "https://nutrismart-ai-backend.onrender.com"
}
$appEnvironment = if ($env:JCG_APP_ENV) {
    $env:JCG_APP_ENV
} else {
    "production"
}
flutter run -d emulator-5554 --dart-define-from-file=.env `
    --dart-define=FASTAPI_BASE_URL=$fastApiBaseUrl `
    --dart-define=APP_ENV=$appEnvironment
