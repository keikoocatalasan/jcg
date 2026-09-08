param(
    [Parameter(Mandatory = $true)]
    [string]$Arm64ApkPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Resolve-Path -LiteralPath $Arm64ApkPath -ErrorAction Stop
$destination = Join-Path $repoRoot 'landing_page\downloads\JCG-Fitness-arm64-v8a.apk'

if ((Get-Item -LiteralPath $source).Length -eq 0) {
    throw 'The ARM64 release artifact is empty.'
}

$aapt = Get-Command aapt -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' } else { $null }
if (-not $aapt -and $sdkRoot -and (Test-Path -LiteralPath (Join-Path $sdkRoot 'build-tools'))) {
    $aapt = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Recurse -File -Filter 'aapt*' |
        Where-Object { $_.Name -eq 'aapt' -or $_.Name -eq 'aapt.exe' } |
        Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName -First 1
}
if (-not $aapt) { throw 'Android aapt was not found; the fallback artifact cannot be validated.' }

$badging = & $aapt dump badging $source
$packageLine = $badging | Select-String '^package:' | Select-Object -First 1
$labelLine = $badging | Select-String "^application-label:'JCG Fitness'" | Select-Object -First 1
if (-not $packageLine -or $packageLine.Line -notmatch "name='com\.jcg\.fitness'" -or -not $labelLine) {
    throw 'The source artifact is not a JCG Fitness ARM64 APK.'
}

New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force
$hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Updated $destination with SHA-256 $hash. Commit this fallback before tagging the release."
