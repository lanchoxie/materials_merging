param([switch]$Editor, [switch]$Check, [switch]$Capture)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

# Scope engine caches, logs and temporary files to this project.
foreach ($relative in @('.runtime/AppData', '.runtime/LocalAppData', '.runtime/Temp', 'artifacts', 'saves')) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot $relative) -Force | Out-Null
}
$env:APPDATA = Join-Path $PSScriptRoot '.runtime/AppData'
$env:LOCALAPPDATA = Join-Path $PSScriptRoot '.runtime/LocalAppData'
$env:TEMP = Join-Path $PSScriptRoot '.runtime/Temp'
$env:TMP = $env:TEMP

$engine = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools/godot') -Filter 'Godot*_win64.exe' | Select-Object -First 1
if (-not $engine) { throw 'Portable Godot is missing from tools/godot. See README.md.' }
$consoleEngine = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools/godot') -Filter 'Godot*_console.exe' | Select-Object -First 1
if ($Check) {
    & $consoleEngine.FullName --headless --path $PSScriptRoot --script res://tests/test_state.gd --log-file (Join-Path $PSScriptRoot 'artifacts/model-test.log')
    exit $LASTEXITCODE
}
if ($Capture) {
    & $consoleEngine.FullName --path $PSScriptRoot --rendering-driver opengl3 --log-file (Join-Path $PSScriptRoot 'artifacts/visual-test.log') -- --visual-test
    exit $LASTEXITCODE
}
$engineArguments = @('--path', ('"' + $PSScriptRoot + '"'), '--rendering-driver', 'opengl3', '--log-file', ('"' + (Join-Path $PSScriptRoot 'artifacts/play.log') + '"'))
if ($Editor) { $engineArguments += '--editor' }
$process = Start-Process -FilePath $engine.FullName -ArgumentList $engineArguments -WorkingDirectory $PSScriptRoot -PassThru
Write-Output ('Atom Atelier started. Process ID: ' + $process.Id)
