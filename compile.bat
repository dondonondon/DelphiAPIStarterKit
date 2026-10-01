@echo off
setlocal

set "ROOT=%~dp0"
set "PROJECT=DelphiAPIStarterKit.dproj"
set "APP_EXE=DelphiAPIStarterKit.exe"

if not defined BUILD_CONFIG set "BUILD_CONFIG=Debug"
if not defined BUILD_PLATFORM set "BUILD_PLATFORM=Win32"

if defined DELPHI_RSVARS goto CheckRsvars
if defined BDS if exist "%BDS%\bin\rsvars.bat" set "DELPHI_RSVARS=%BDS%\bin\rsvars.bat"

:CheckRsvars

if not defined DELPHI_RSVARS (
    echo DELPHI_RSVARS is not configured.
    echo Set DELPHI_RSVARS to your rsvars.bat path, for example:
    echo set "DELPHI_RSVARS=C:\Program Files ^(x86^)\Embarcadero\Studio\37.0\bin\rsvars.bat"
    exit /b 1
)

if not exist "%DELPHI_RSVARS%" goto MissingRsvars

tasklist /FI "IMAGENAME eq %APP_EXE%" | findstr /I "%APP_EXE%" >nul
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM "%APP_EXE%"
)

call "%DELPHI_RSVARS%"

pushd "%ROOT%"
if errorlevel 1 exit /b %ERRORLEVEL%

echo Compiling %PROJECT%...
echo Config: %BUILD_CONFIG%
echo Platform: %BUILD_PLATFORM%
echo.

msbuild "%PROJECT%" /t:Make /p:Config=%BUILD_CONFIG% /p:Platform=%BUILD_PLATFORM% /nologo /v:minimal
set "BUILD_ERROR=%ERRORLEVEL%"

echo.
if %BUILD_ERROR% geq 1 (
    echo COMPILE FAILED
) else (
    echo COMPILE SUCCESS
)

popd
exit /b %BUILD_ERROR%

:MissingRsvars
echo rsvars.bat was not found. Check DELPHI_RSVARS.
exit /b 1
