param(
    [Parameter(Mandatory = $true)][string]$InputDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][int]$VersionCode
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $VersionCode -lt 1) {
    throw 'Release version must be major.minor.patch with a positive build number.'
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw 'Use a new staging directory to prevent stale release assets.'
}
$mapping = [ordered]@{
    'app-release.apk' = 'JCG-Fitness.apk'
    'app-arm64-v8a-release.apk' = 'JCG-Fitness-arm64-v8a.apk'
    'app-armeabi-v7a-release.apk' = 'JCG-Fitness-armeabi-v7a.apk'
    'app-x86_64-release.apk' = 'JCG-Fitness-x86_64.apk'
}
$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' } else { $null }
$aapt = Get-Command aapt -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $aapt -and $sdkRoot -and (Test-Path -LiteralPath (Join-Path $sdkRoot 'build-tools'))) {
    $aapt = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Recurse -File -Filter 'aapt*' |
        Where-Object { $_.Name -eq 'aapt' -or $_.Name -eq 'aapt.exe' } |
        Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName -First 1
}
if (-not $aapt) { throw 'Android aapt was not found; APK metadata cannot be validated.' }
foreach ($source in $mapping.Keys) {
    $file = Get-Item -LiteralPath (Join-Path $InputDirectory $source)
    if ($file.Length -eq 0) { throw "Empty APK: $source" }
    $badging = & $aapt dump badging $file.FullName
    $packageLine = $badging | Select-String '^package:' | Select-Object -First 1
    $sdkLine = $badging | Select-String "^sdkVersion:'" | Select-Object -First 1
    $labelLine = $badging | Select-String "^application-label:'JCG Fitness'" | Select-Object -First 1
    if (-not $packageLine -or $packageLine.Line -notmatch "name='com\.jcg\.fitness'" -or $packageLine.Line -notmatch "versionName='$Version'") {
        throw "APK metadata mismatch for $source. Expected com.jcg.fitness version $Version."
    }
    if (-not $sdkLine -or [int]([regex]::Match($sdkLine.Line, "sdkVersion:'(\d+)'" ).Groups[1].Value) -gt 26) {
        throw "APK $source has an unsupported minimum Android API."
    }
    if (-not $labelLine) { throw "APK $source is not labeled JCG Fitness." }
}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$assets = @()
foreach ($source in $mapping.Keys) {
    $name = $mapping[$source]
    $destination = Join-Path $OutputDirectory $name
    Copy-Item -LiteralPath (Join-Path $InputDirectory $source) -Destination $destination
    $assets += [ordered]@{
        name = $name
        bytes = (Get-Item -LiteralPath $destination).Length
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        url = "https://github.com/keikoocatalasan/jcg/releases/download/v$Version/$name"
    }
}
# Preserve the old public URL during the branded-name transition.
Copy-Item -LiteralPath (Join-Path $OutputDirectory 'JCG-Fitness.apk') -Destination (Join-Path $OutputDirectory 'app-release.apk')
$checksums = @($assets | ForEach-Object { "$($_.sha256)  $($_.name)" })
$checksums += "$($assets[0].sha256)  app-release.apk"
$checksums | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ascii
[ordered]@{
    schemaVersion = 1
    version = $Version
    versionCode = $VersionCode
    applicationId = 'com.jcg.fitness'
    minAndroidApi = 26
    generatedAt = [DateTime]::UtcNow.ToString('o')
    releaseNotesUrl = "https://github.com/keikoocatalasan/jcg/releases/tag/v$Version"
    assets = $assets
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'release.json') -Encoding utf8
Write-Host "Staged JCG Fitness $Version in $OutputDirectory. No release has been published."
