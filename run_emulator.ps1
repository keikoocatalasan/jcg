$host.ui.RawUI.WindowTitle = "Android Emulator"
Set-Location $PSScriptRoot
$avdName = if ($env:JCG_AVD_NAME) { $env:JCG_AVD_NAME } else { "jcg_emu" }
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
$deviceId = if ($env:JCG_DEVICE_ID) { $env:JCG_DEVICE_ID } else { "emulator-5554" }
$deviceState = (& $adbPath -s $deviceId get-state 2>$null).Trim()
if ($deviceState -eq "device") {
    Write-Host "$deviceId is already running." -ForegroundColor Green
} else {
    flutter emulators --launch $avdName
}
