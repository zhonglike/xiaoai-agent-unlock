@echo off
cd /d "%~dp0"
echo ==========================================================
echo   Install Xiaomi Super XiaoAI on ANY brand PC
echo ==========================================================
echo.
set /p "INS=Installer path (source exe): "
set "INS=%INS:"=%"
if not exist "%INS%" ( echo File not found & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_installer.ps1" -Installer "%INS%"
echo.
pause
