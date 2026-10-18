@echo off
setlocal EnableExtensions
title Build Video Preview Creator
cd /d "%~dp0"

set "SOURCE=%~dp0VideoPreviewCreatorLauncher.cs"
set "SCRIPT=%~dp0VideoPreviewCreator.ps1"
set "ICON=%~dp0VideoPreviewCreator-RazorBlade.ico"
set "OUTPUT=%~dp0VideoPreviewCreator.exe"
set "LOG=%~dp0Build-VideoPreviewCreator.log"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

echo.
echo ============================================
echo   Video Preview Creator - EXE Builder
echo ============================================
echo.
if not exist "%SOURCE%" (echo ERROR: C# launcher not found: "%SOURCE%" & goto :fail)
if not exist "%SCRIPT%" (echo ERROR: PowerShell source not found: "%SCRIPT%" & goto :fail)
if not exist "%ICON%" (echo ERROR: Razor icon not found: "%ICON%" & goto :fail)
if not exist "%CSC%" (echo ERROR: .NET Framework C# compiler not found. & goto :fail)

for %%F in ("%ICON%") do if %%~zF LEQ 0 (echo ERROR: Icon file is empty. & goto :fail)
echo Source: "%SOURCE%"
echo Script: "%SCRIPT%" (embedded into EXE)
echo Icon:   "%ICON%"
echo Output: "%OUTPUT%"
echo.
if exist "%OUTPUT%" del /q "%OUTPUT%"
if exist "%OUTPUT%" (echo ERROR: Could not remove previous EXE. Close it and retry. & goto :fail)
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll "/win32icon:%ICON%" "/out:%OUTPUT%" "%SOURCE%" > "%LOG%" 2>&1
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" (echo. & echo BUILD FAILED. Compiler output: & type "%LOG%" & goto :fail)
if not exist "%OUTPUT%" (echo ERROR: EXE was not created. & if exist "%LOG%" type "%LOG%" & goto :fail)
for %%F in ("%OUTPUT%") do if %%~zF LEQ 0 (echo ERROR: Generated EXE is empty. & goto :fail)
echo.
echo BUILD SUCCEEDED.
echo EXE: "%OUTPUT%"
echo Razor-blade icon embedded. PowerShell script embedded.
echo Build log: "%LOG%"
echo.
echo Requires FFmpeg and FFprobe available on PATH. Test the EXE on Windows.
pause
exit /b 0

:fail
echo.
echo Build did not complete successfully. No Windows security settings were changed.
pause
exit /b 1
