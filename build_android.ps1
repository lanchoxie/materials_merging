param([switch]$SkipImport, [string]$Version = '0.15.0')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
foreach ($relative in @('.runtime/AppData','.runtime/LocalAppData','.runtime/Temp','.runtime/android','builds','artifacts')) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot $relative) -Force | Out-Null
}
$env:APPDATA = Join-Path $PSScriptRoot '.runtime/AppData'
$env:LOCALAPPDATA = Join-Path $PSScriptRoot '.runtime/LocalAppData'
$env:TEMP = Join-Path $PSScriptRoot '.runtime/Temp'
$env:TMP = $env:TEMP
$env:ANDROID_USER_HOME = Join-Path $PSScriptRoot '.runtime/android'
$env:ANDROID_SDK_HOME = Join-Path $PSScriptRoot '.runtime/android'
$env:ANDROID_HOME = Join-Path $PSScriptRoot 'tools/android/sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$jdk = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools/jdk') -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin/java.exe') } | Select-Object -First 1
if (-not $jdk) { throw 'Missing project-local OpenJDK 17.' }
$env:JAVA_HOME = $jdk.FullName
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH

$buildTools = Join-Path $env:ANDROID_HOME 'build-tools/35.0.1'
if (-not (Test-Path -LiteralPath (Join-Path $buildTools 'apksigner.bat'))) {
    New-Item -ItemType Directory -Path $buildTools -Force | Out-Null
    $unpacked = Join-Path $PSScriptRoot 'tools/android/build-tools-unpacked/android-15'
    Get-ChildItem -LiteralPath $unpacked | Copy-Item -Destination $buildTools -Recurse -Force
}

$settingsPath = Join-Path $PSScriptRoot 'tools/godot/editor_data/editor_settings-4.7.tres'
$settings = Get-Content -LiteralPath $settingsPath -Raw
$javaPath = $env:JAVA_HOME.Replace('\','/')
$sdkPath = $env:ANDROID_HOME.Replace('\','/')
$settings = $settings -replace '(?m)^export/android/java_sdk_path = .*$', ('export/android/java_sdk_path = "' + $javaPath + '"')
$settings = $settings -replace '(?m)^export/android/android_sdk_path = .*$', ('export/android/android_sdk_path = "' + $sdkPath + '"')
Set-Content -LiteralPath $settingsPath -Value $settings -Encoding utf8

$godot = Join-Path $PSScriptRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not $SkipImport) {
    & $godot --headless --path $PSScriptRoot --editor --import --quit --log-file (Join-Path $PSScriptRoot 'artifacts/android-import.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath artifacts/android-import.log -Pattern 'SCRIPT ERROR:' -Quiet)) { throw 'Godot import failed.' }
}
$apk = Join-Path $PSScriptRoot ('builds/AtomAtelier-' + $Version + '-android.apk')
& $godot --headless --path $PSScriptRoot --export-debug Android $apk --log-file (Join-Path $PSScriptRoot 'artifacts/android-export.log')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apk) -or (Select-String -LiteralPath artifacts/android-export.log -Pattern 'SCRIPT ERROR:' -Quiet)) { throw 'Android export failed.' }
& (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apk | Tee-Object -FilePath (Join-Path $PSScriptRoot 'artifacts/android-signature.txt')
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
& (Join-Path $buildTools 'aapt.exe') dump badging $apk | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'artifacts/android-package.txt')
if ($LASTEXITCODE -ne 0) { throw 'APK metadata verification failed.' }
Get-FileHash -LiteralPath $apk -Algorithm SHA256 | Format-List | Out-String | Set-Content -LiteralPath ($apk.Replace('.apk','.sha256.txt'))
Get-Item -LiteralPath $apk | Select-Object Name,Length,LastWriteTime
