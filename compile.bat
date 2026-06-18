@echo off
tasklist /FI "IMAGENAME eq DelphiAPIStarterKit.exe" | findstr /I "DelphiAPIStarterKit.exe" >nul
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM DelphiAPIStarterKit.exe
)

call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"

cd /d D:\Github\DelphiAPIStarterKit

echo Compiling DelphiAPIStarterKit.dproj...
echo.

msbuild DelphiAPIStarterKit.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /nologo /v:minimal

echo.
if errorlevel 1 (
    echo COMPILE FAILED
) else (
    echo COMPILE SUCCESS
)

pause