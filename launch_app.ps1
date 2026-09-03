$flutterDir = Join-Path $PSScriptRoot "flutter_app"
Set-Location $flutterDir
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
