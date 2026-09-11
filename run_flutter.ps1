$host.ui.RawUI.WindowTitle = "JCG Flutter App"
$flutterDir = Join-Path $PSScriptRoot "flutter_app"
Set-Location $flutterDir
$androidSdk = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    Join-Path $env:LOCALAPPDATA "Android\sdk"
}
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:Path = "$(Join-Path $androidSdk 'platform-tools');$env:Path"
$deviceId = if ($env:JCG_DEVICE_ID) { $env:JCG_DEVICE_ID } else { "emulator-5554" }
Write-Host "Waiting for Android device $deviceId to complete system boot..." -ForegroundColor Yellow
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
    $deviceState = (& $adbPath -s $deviceId get-state 2>$null | Out-String).Trim()
    if ($deviceState -ne "device") {
        continue
    }
    $boot = & $adbPath -s $deviceId shell getprop sys.boot_completed 2>$null
} until ($boot -and $boot.Trim() -eq "1")
Write-Host "Android OS fully booted! Starting Flutter App..." -ForegroundColor Green
$appEnvironment = if ($env:JCG_APP_ENV) {
    $env:JCG_APP_ENV
} else {
    "production"
}
$backendPortForFlutter = if ($env:JCG_BACKEND_PORT) {
    $env:JCG_BACKEND_PORT
} else {
    "8000"
}
$fastApiBaseUrl = if ($env:JCG_FASTAPI_BASE_URL) {
    $env:JCG_FASTAPI_BASE_URL
} elseif ($appEnvironment -eq "development") {
    "http://10.0.2.2:$backendPortForFlutter"
} else {
    "https://nutrismart-ai-backend.onrender.com"
}
$devAuthBypass = if ($env:JCG_DEV_BYPASS_AUTH) {
    $env:JCG_DEV_BYPASS_AUTH
} else {
    "false"
}
$livePreview = if ($env:JCG_LIVE_PREVIEW) {
    $env:JCG_LIVE_PREVIEW
} else {
    "false"
}
flutter run -d $deviceId --dart-define-from-file=.env `
    --dart-define=FASTAPI_BASE_URL=$fastApiBaseUrl `
    --dart-define=APP_ENV=$appEnvironment `
    --dart-define=JCG_DEV_BYPASS_AUTH=$devAuthBypass `
    --dart-define=JCG_LIVE_PREVIEW=$livePreview
