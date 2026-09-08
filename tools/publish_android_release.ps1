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
foreach ($requiredName in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'GOOGLE_WEB_CLIENT_ID')) {
    if ($envText -notmatch "(?m)^$requiredName=\S+\s*$") {
        throw "Missing production configuration: $requiredName"
    }
}

if (git tag --list $tag) {
    throw "Tag $tag already exists. Increase pubspec.yaml version before building."
}
if ($LASTEXITCODE -ne 0) { throw 'Failed to inspect release tags.' }

Set-Location $flutterRoot
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed; release stopped.' }
flutter test --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed; release stopped.' }
flutter build apk --release --dart-define-from-file=.env
if ($LASTEXITCODE -ne 0) { throw 'Universal APK build failed; release stopped.' }
flutter build apk --release --split-per-abi --dart-define-from-file=.env
if ($LASTEXITCODE -ne 0) { throw 'ABI APK build failed; release stopped.' }
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

$fallbackPath = Join-Path $repoRoot 'landing_page\downloads\JCG-Fitness-arm64-v8a.apk'
if (-not (Test-Path -LiteralPath $fallbackPath)) {
    throw 'Missing landing ARM64 fallback. Run tools/sync_android_fallback.ps1, commit the result, then publish.'
}
$builtArm64Hash = (Get-FileHash -LiteralPath (Join-Path $outputDir 'app-arm64-v8a-release.apk') -Algorithm SHA256).Hash
$fallbackHash = (Get-FileHash -LiteralPath $fallbackPath -Algorithm SHA256).Hash
if ($builtArm64Hash -ne $fallbackHash) {
    throw 'Landing ARM64 fallback does not match this release. Run tools/sync_android_fallback.ps1, commit the result, then publish.'
}

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ('jcg-release-' + [guid]::NewGuid().ToString('N'))
& (Join-Path $PSScriptRoot 'package_android_release.ps1') -InputDirectory $outputDir -OutputDirectory $stagingDir -Version $versionName -VersionCode ([int]$versionMatch.Groups[2].Value)

if (git tag --list $tag) {
    throw "Tag $tag already exists. Increase pubspec.yaml version before publishing."
}

git tag -a $tag -m "JCG Fitness $versionName"
if ($LASTEXITCODE -ne 0) { throw 'Release tag creation failed.' }
git push origin $tag
if ($LASTEXITCODE -ne 0) { throw 'Release tag push failed.' }
$releaseFiles = @(Get-ChildItem -LiteralPath $stagingDir -File | ForEach-Object { $_.FullName })
gh release create $tag @releaseFiles `
    --draft --verify-tag `
    --repo keikoocatalasan/jcg `
    --title "JCG Fitness $versionName" `
    --generate-notes
if ($LASTEXITCODE -ne 0) { throw 'GitHub release publishing failed.' }

Write-Host "Staged draft $tag. Verify the APKs before publishing; the public latest release is unchanged."
