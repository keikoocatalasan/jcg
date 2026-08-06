Set-Location "C:\Users\john\projects\jcg\flutter_app"
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
