@echo off
setlocal
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\art\run_demo.ps1" -AllTests
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\art\run_demo.ps1" -Test "%~1"
)
