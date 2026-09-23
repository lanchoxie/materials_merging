@echo off
cd /d "%~dp0"
where pwsh.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_demo.ps1" -Editor
) else if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" (
    "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_demo.ps1" -Editor
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_demo.ps1" -Editor
)
if errorlevel 1 pause
