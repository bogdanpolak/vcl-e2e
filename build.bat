@echo off
setlocal enabledelayedexpansion

echo ================================================================
echo  Building VCL-E2E Project Group (DemoApp, CLI, Unit Tests)
echo ================================================================

if "%BDS%"=="" (
    if exist "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" (
        call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
    ) else (
        echo [ERROR] RAD Studio / Delphi environment not detected!
        exit /b 1
    )
)

echo Building all projects with MSBuild...
msbuild VclE2E.groupproj /p:Config=Release /p:Platform=Win32 /verbosity:minimal
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    exit /b %ERRORLEVEL%
)

echo.
echo ================================================================
echo  Running Unit Tests...
echo ================================================================
bin\cli.exe --unit-tests
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Unit tests failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Build and Unit Tests completed successfully!
echo Executables are available in .\bin\
