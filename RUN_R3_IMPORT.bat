@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_R3_IMPORT.ps1"
exit /b %ERRORLEVEL%
