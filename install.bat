@echo off
setlocal enabledelayedexpansion
title 超级小爱 设备校验绕过工具

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在请求管理员权限...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

set "MIROOT="
for %%D in (C D E F G) do (
    if not defined MIROOT if exist "%%D:\Program Files\MI\XiaoaiAgent" set "MIROOT=%%D:\Program Files\MI\XiaoaiAgent"
)
if not defined MIROOT set "MIROOT=C:\Program Files\MI\XiaoaiAgent"

:MENU
cls
echo ==========================================================
echo         超级小爱  设备校验绕过工具
echo ==========================================================
echo   安装目录: %MIROOT%
echo.
echo   可用补丁版本:
set n=0
set "vers="
for /d %%d in ("patches\*") do (
    set /a n+=1
    set "vers[!n!]=%%~nxd"
    echo     [!n!]  %%~nxd
)
if %n%==0 ( echo     (patches 目录为空) & pause & exit /b )
echo.
echo     [D] 检测本机安装情况
echo     [Q] 退出
echo.
set /p "sel=请选择版本编号: "
if /i "%sel%"=="Q" exit /b
if /i "%sel%"=="D" goto DETECT
if not defined vers[%sel%] goto MENU

set "VER=!vers[%sel%]!"
set "TARGET=%MIROOT%\!VER!\XiaoaiAgent.dll"
set "PATCHFILE=%~dp0patches\!VER!\XiaoaiAgent.dll"
set "BACKUP=%MIROOT%\!VER!\XiaoaiAgent.dll.bak"

:ACTION
cls
echo ==========================================================
echo   版本: !VER!
if exist "!TARGET!" (echo   状态: 已安装) else (echo   状态: 未找到该版本)
echo   补丁: !PATCHFILE!
echo ==========================================================
echo.
echo     [1] 安装补丁（自动备份原文件）
echo     [2] 还原为官方原版
echo     [0] 返回
echo.
set /p "act=请选择操作: "
if "!act!"=="1" goto APPLY
if "!act!"=="2" goto RESTORE
if "!act!"=="0" goto MENU
goto ACTION

:APPLY
if not exist "!TARGET!"  ( echo [错误] 未找到 !TARGET! & pause & goto ACTION )
if not exist "!PATCHFILE!" ( echo [错误] 未找到补丁 !PATCHFILE! & pause & goto ACTION )
taskkill /f /im XiaoaiAgent.exe >nul 2>&1
timeout /t 2 /nobreak >nul
if not exist "!BACKUP!" ( copy /y "!TARGET!" "!BACKUP!" >nul & echo   已备份原文件 )
copy /y "!PATCHFILE!" "!TARGET!" >nul
if errorlevel 1 ( echo [错误] 复制失败，文件可能被占用 ) else (
    echo.
    echo   补丁安装成功！现在可以正常启动超级小爱。
)
echo.
pause
goto ACTION

:RESTORE
if not exist "!BACKUP!" ( echo 没有备份文件，无需还原。 & pause & goto ACTION )
taskkill /f /im XiaoaiAgent.exe >nul 2>&1
timeout /t 2 /nobreak >nul
copy /y "!BACKUP!" "!TARGET!" >nul
del /q "!BACKUP!" >nul 2>&1
echo 已还原为官方原版。
echo.
pause
goto ACTION

:DETECT
cls
echo ==========================================================
echo   本机安装检测
echo ==========================================================
echo.
if exist "%MIROOT%" (
    for /d %%d in ("%MIROOT%\*") do (
        if exist "%%~d\XiaoaiAgent.dll.bak" ( echo   版本 %%~nxd  [已打补丁] ) else ( echo   版本 %%~nxd  [官方原版] )
    )
) else ( echo   未检测到安装目录: %MIROOT% )
echo.
pause
goto MENU
