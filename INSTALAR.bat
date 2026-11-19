@echo off
title Parche QTranslate - Reactivar traductor de Google
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  Se necesitan permisos de administrador.
    echo  Acepta la ventana de Windows que va a aparecer...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"

echo.
echo  Pulsa una tecla para cerrar esta ventana.
pause >nul
