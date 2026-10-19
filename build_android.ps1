param([switch]$SkipImport, [string]$Version = '0.20.0', [int]$VersionCode = 0, [switch]$Test, [switch]$Dev)
# v0.60: -Dev builds BOTH a player APK and a dev APK (infinite resources) in one run.
# The dev APK has its own package id (org.atomatelier.demo.dev) and name suffix [DEV],
# so it installs beside the player build. The dev build enables the `devbuild` feature,
# which activates the DevMode autoload that tops up coins/credits/XP/materials every second.
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

if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$' -or $VersionCode -lt 0) { throw 'Invalid Android version.' }

# --- Helper: build one APK with a given feature/package/name-suffix ---------------------------
function Build-OneApk {
    param(
        [string]$ApkLabel,       # file label, e.g. "" or "-dev"
        [string]$Features,       # export custom_features value, e.g. "" or "devbuild"
        [string]$PkgSuffix,      # package id suffix, e.g. "" or ".dev"
        [string]$NameSuffix      # display name suffix, e.g. "" or " [DEV]"
    )
    $apk = Join-Path $PSScriptRoot ('builds/AtomAtelier-' + $Version + $ApkLabel + '-android.apk')
    if (Test-Path -LiteralPath $apk) { throw ('An APK with this name already exists: ' + $apk) }
    $presetPath = Join-Path $PSScriptRoot 'export_presets.cfg'
    $projectPath = Join-Path $PSScriptRoot 'project.godot'
    $presetBytes = [IO.File]::ReadAllBytes($presetPath)
    $projectBytes = [IO.File]::ReadAllBytes($projectPath)
    try {
        $presetText = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($presetPath))
        # Apply custom_features
        if ($Features -ne '') {
            $presetText = ([regex]'(?m)^custom_features="[^"]*"').Replace($presetText, ('custom_features="' + $Features + '"'), 1)
        }
        # Apply package id suffix
        if ($PkgSuffix -ne '') {
            $presetText = $presetText -replace '(?m)^package/unique_name="org\.atomatelier\.demo"', ('package/unique_name="org.atomatelier.demo' + $PkgSuffix + '"')
        }
        # Apply display name suffix
        if ($NameSuffix -ne '') {
            $presetText = $presetText -replace '(?m)^package/name="([^"]+)"', ('package/name="$1' + $NameSuffix + '"')
        }
        # Always update version/name so the APK manifest reflects the real release version.
        if ($VersionCode -gt 0) {
            $presetText = $presetText -replace '(?m)^version/code=\d+', ('version/code=' + $VersionCode)
        }
        $presetText = $presetText -replace '(?m)^version/name="[^"]+"', ('version/name="' + $Version + '"')
        [IO.File]::WriteAllText($presetPath, $presetText, [Text.UTF8Encoding]::new($false))
        & $godot --headless --path $PSScriptRoot --export-debug Android $apk --log-file (Join-Path $PSScriptRoot ('artifacts/android-export' + $ApkLabel + '.log'))
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apk) -or (Select-String -LiteralPath ('artifacts/android-export' + $ApkLabel + '.log') -Pattern 'SCRIPT ERROR:|Parse Error' -Quiet)) { throw ('Android export failed for ' + $ApkLabel) }
    } finally {
        [IO.File]::WriteAllBytes($presetPath, $presetBytes)
        [IO.File]::WriteAllBytes($projectPath, $projectBytes)
    }
    & (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apk | Tee-Object -FilePath (Join-Path $PSScriptRoot ('artifacts/android-signature' + $ApkLabel + '.txt'))
    if ($LASTEXITCODE -ne 0) { throw ('APK signature verification failed for ' + $ApkLabel) }
    & (Join-Path $buildTools 'aapt.exe') dump badging $apk | Set-Content -LiteralPath (Join-Path $PSScriptRoot ('artifacts/android-package' + $ApkLabel + '.txt'))
    if ($LASTEXITCODE -ne 0) { throw ('APK metadata verification failed for ' + $ApkLabel) }
    Get-FileHash -LiteralPath $apk -Algorithm SHA256 | Format-List | Out-String | Set-Content -LiteralPath ($apk.Replace('.apk','.sha256.txt'))
    Get-Item -LiteralPath $apk | Select-Object Name,Length,LastWriteTime
}

# --- Build the requested APK(s) ---------------------------------------------------------------
# -Test builds the test edition (testbuild feature, own app id/name/save).
# -Dev builds BOTH the player APK (normal) and the dev APK (devbuild feature, own app id/name,
#   infinite resources via the DevMode autoload). -Dev overrides -Test.
# (no flags) builds just the player APK.
if ($Dev) {
    Write-Host '=== Player build ==='
    Build-OneApk -ApkLabel '' -Features '' -PkgSuffix '' -NameSuffix ''
    Write-Host '=== Dev (infinite resources) build ==='
    $devNameSuffix = ' [DEV]'
    Build-OneApk -ApkLabel '-dev' -Features 'devbuild' -PkgSuffix '.dev' -NameSuffix $devNameSuffix
} elseif ($Test) {
    Build-OneApk -ApkLabel '-test' -Features 'testbuild' -PkgSuffix '.test' -NameSuffix ([string][char]0x6D4B + [char]0x8BD5 + [char]0x7248)
} else {
    Build-OneApk -ApkLabel '' -Features '' -PkgSuffix '' -NameSuffix ''
}
