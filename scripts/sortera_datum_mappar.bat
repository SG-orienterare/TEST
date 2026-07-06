@echo off
chcp 65001 >nul
setlocal

REM Sorterar Duplicate Cleaner-mappar till YYYY_MM_DD (t.ex. 2025_08_11)
REM Kör fran samma mapp som bat-filen ligger i.

set "MAPP=%~dp0"
set "MAPP=%MAPP:~0,-1%"

if /I "%~1"=="KOR" goto :run
if /I "%~1"=="RUN" goto :run

echo.
echo === TORRKORNING (inget flyttas) ===
echo Mapp: %MAPP%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reorganize-VideoFolders.ps1" -SourcePath "%MAPP%" -DryRun
echo.
echo Om allt ser bra ut, kor:
echo   %~nx0 KOR
echo.
pause
exit /b 0

:run
echo.
echo === KOR PA RIKTIGT ===
echo Mapp: %MAPP%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reorganize-VideoFolders.ps1" -SourcePath "%MAPP%"
echo.
pause
exit /b 0
