param([int]$Port=8771,[switch]$Serve)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
foreach($relative in @('.runtime/AppData','.runtime/LocalAppData','.runtime/Temp','builds/web-river-preview','artifacts')) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot $relative) -Force | Out-Null
}
$env:APPDATA=Join-Path $PSScriptRoot '.runtime/AppData'
$env:LOCALAPPDATA=Join-Path $PSScriptRoot '.runtime/LocalAppData'
$env:TEMP=Join-Path $PSScriptRoot '.runtime/Temp'
$env:TMP=$env:TEMP
$riverEngine=Join-Path $PSScriptRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $riverEngine --headless --path $PSScriptRoot --export-debug Web builds/web-river-preview/index.html --log-file artifacts/v021-web-export.log *> artifacts/v021-web-export-console.log
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath artifacts/v021-web-export.log -Pattern 'SCRIPT ERROR:|Parse Error' -Quiet)) {throw 'River preview export failed'}
$riverHtml=Join-Path $PSScriptRoot 'builds/web-river-preview/index.html'
$riverPage=Get-Content -LiteralPath $riverHtml -Raw
if(-not $riverPage.Contains('"args":[]')) {throw 'Unexpected Godot HTML configuration'}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'builds/web-river-preview/island.html'),$riverPage,[Text.UTF8Encoding]::new($false))
$riverPage=$riverPage.Replace('"args":[]','"args":["--river-preview"]')
[IO.File]::WriteAllText($riverHtml,$riverPage,[Text.UTF8Encoding]::new($false))
$riverManifest=@{
    name='0.21 river development preview'
    revision='sandbox-12'
    formalRelease=$false
    builtAt=(Get-Date).ToString('o')
    pckSHA256=(Get-FileHash builds/web-river-preview/index.pck -Algorithm SHA256).Hash.ToLowerInvariant()
    entryArguments=@('--river-preview')
}
$riverManifest | ConvertTo-Json | Set-Content -LiteralPath builds/web-river-preview/preview.json -Encoding utf8
Write-Output 'River preview built in builds/web-river-preview. No APK or release tag was changed.'
if($Serve) {
    if($Port -lt 1024 -or $Port -gt 65535) {throw 'Choose a local port from 1024 to 65535'}
    & python tools/serve_web.py --directory builds/web-river-preview --port $Port
}
