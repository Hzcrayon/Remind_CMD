@echo off
setlocal EnableExtensions
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remind-main.ps1" %*
exit /b %ERRORLEVEL%
