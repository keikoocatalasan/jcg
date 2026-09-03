$host.ui.RawUI.WindowTitle = "JCG Flutter App"
$flutterDir = Join-Path $PSScriptRoot "flutter_app"
Set-Location $flutterDir
Write-Host "Waiting for Android Emulator to complete system boot..." -ForegroundColor Yellow
$androidSdk = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    Join-Path $env:LOCALAPPDATA "Android\sdk"
}
$adbPath = Join-Path $androidSdk "platform-tools\adb.exe"
if (-not (Test-Path $adbPath)) {
    throw "Android adb was not found at $adbPath. Set ANDROID_HOME or ANDROID_SDK_ROOT."
}
do {
    Start-Sleep -Seconds 3
    $boot = & $adbPath shell getprop sys.boot_completed 2>$null
} until ($boot -and $boot.Trim() -eq "1")
Write-Host "Android OS fully booted! Starting Flutter App..." -ForegroundColor Green
$deviceId = if ($env:JCG_DEVICE_ID) { $env:JCG_DEVICE_ID } else { "emulator-5554" }
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
flutter run -d $deviceId --dart-define-from-file=.env `
    --dart-define=FASTAPI_BASE_URL=$fastApiBaseUrl `
    --dart-define=APP_ENV=$appEnvironment
