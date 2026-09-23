param([switch]$SkipImport)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
foreach($relative in @('.runtime/AppData','.runtime/LocalAppData','.runtime/Temp','builds/web','artifacts')) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot $relative) -Force | Out-Null
}
$env:APPDATA=Join-Path $PSScriptRoot '.runtime/AppData'
$env:LOCALAPPDATA=Join-Path $PSScriptRoot '.runtime/LocalAppData'
$env:TEMP=Join-Path $PSScriptRoot '.runtime/Temp'
$env:TMP=$env:TEMP
$engine=Join-Path $PSScriptRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if(-not $SkipImport) {
    & $engine --headless --path $PSScriptRoot --editor --import --quit --log-file artifacts/web-import.log
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath artifacts/web-import.log -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Web import failed.'}
}
& $engine --headless --path $PSScriptRoot --export-debug Web builds/web/index.html --log-file artifacts/web-export.log
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath artifacts/web-export.log -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Web export failed.'}
Get-Item builds/web/index.html,builds/web/index.pck | Select-Object Name,Length,LastWriteTime
