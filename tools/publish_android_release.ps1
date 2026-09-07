$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterRoot = Join-Path $repoRoot 'flutter_app'
$outputDir = Join-Path $flutterRoot 'build\app\outputs\flutter-apk'
$envFile = Join-Path $flutterRoot '.env'

Set-Location $repoRoot

if (git status --short) {
    throw 'Commit and push the release source before publishing. The working tree is not clean.'
}

$versionLine = Get-Content (Join-Path $flutterRoot 'pubspec.yaml') |
    Select-String '^version:\s+([^+]+)\+([0-9]+)'
if (-not $versionLine) { throw 'Could not read the Flutter version from pubspec.yaml.' }
$versionMatch = [regex]::Match($versionLine.Line, '^version:\s+([^+]+)\+([0-9]+)')
$versionName = $versionMatch.Groups[1].Value
$tag = "v$versionName"

if (-not (Test-Path -LiteralPath (Join-Path $flutterRoot 'android\key.properties'))) {
    throw 'Missing flutter_app/android/key.properties. Configure the release keystore first.'
}
if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'Missing flutter_app/.env with production Supabase and API values.'
}
$envText = Get-Content -LiteralPath $envFile -Raw
if ($envText -notmatch '(?m)^APP_ENV=production\s*$') {
    throw 'flutter_app/.env must set APP_ENV=production.'
}
if ($envText -notmatch '(?m)^FASTAPI_BASE_URL=https://') {
    throw 'flutter_app/.env must use an HTTPS FASTAPI_BASE_URL.'
}

Set-Location $flutterRoot
flutter build apk --release --dart-define-from-file=.env
flutter build apk --release --split-per-abi --dart-define-from-file=.env
Set-Location $repoRoot

$apkNames = @(
    'app-release.apk',
    'app-arm64-v8a-release.apk',
    'app-armeabi-v7a-release.apk',
    'app-x86_64-release.apk'
)
foreach ($name in $apkNames) {
    if (-not (Test-Path -LiteralPath (Join-Path $outputDir $name))) {
        throw "Missing release artifact: $name"
    }
}

$checksumPath = Join-Path $outputDir 'SHA256SUMS.txt'
$checksums = foreach ($name in $apkNames) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $outputDir $name) -Algorithm SHA256).Hash.ToLower()
    "$hash  $name"
}
$checksums | Set-Content -LiteralPath $checksumPath -Encoding ascii

if (git tag --list $tag) {
    throw "Tag $tag already exists. Increase pubspec.yaml version before publishing."
}

git tag -a $tag -m "JCG Fitness $versionName"
git push origin $tag
gh release create $tag `
    (Join-Path $outputDir 'app-release.apk') `
    (Join-Path $outputDir 'app-arm64-v8a-release.apk') `
    (Join-Path $outputDir 'app-armeabi-v7a-release.apk') `
    (Join-Path $outputDir 'app-x86_64-release.apk') `
    $checksumPath `
    --repo keikoocatalasan/jcg `
    --title "JCG Fitness $versionName" `
    --generate-notes

Write-Host "Published $tag. The landing page will follow it through releases/latest."
