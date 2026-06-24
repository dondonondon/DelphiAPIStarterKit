@echo off
tasklist /FI "IMAGENAME eq DelphiAPIStarterKit.exe" | findstr /I "DelphiAPIStarterKit.exe" >nul
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM DelphiAPIStarterKit.exe
)
