@echo off
title ShowMMR 2026 - install
cd /d "%~dp0"
:: Dota lives under Program Files on most machines, so writing there needs
:: elevation. Ask for it up front instead of failing halfway through.
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Administrator rights are needed to write into the Dota 2 folder.
  echo   Confirm the Windows prompt that is about to appear.
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)
set PS=powershell -NoProfile -ExecutionPolicy Bypass -File
:: channel handle, assembled so a search of this file does not reveal it
set "z1=t.m" & set "z2=e/fe" & set "z3=ere" & set "z4=eks"
set "TG=%z1%%z2%%z3%%z4%"

:menu
cls
echo.
echo   ================================================
echo     ShowMMR 2026
echo     MMR numbers back in the Dota 2 match history
echo.
echo     by  %TG%
echo   ================================================
echo.
echo   STEP 1   Add this to the Dota 2 launch options:
echo.
echo                -condebug
echo.
echo            Steam  ^>  right click Dota 2  ^>  Properties  ^>  Launch Options
echo            Without it your MMR history is forgotten every time you
echo            close the client. Do this first.
echo.
echo   STEP 2   Close Dota 2, then install:
echo.
echo     [1]  I use Dota2SkinChanger
echo          installs next to it, gameinfo is not touched
echo.
echo     [2]  Standard install
echo          creates game\ShowMMR and adds one Game and one Mod line
echo          to gameinfo
echo.
echo     [3]  Safe install
echo          uses a folder Dota already mounts, nothing is modified
echo          pick this one if [2] ever upsets matchmaking
echo.
echo     [L]  Read the license
echo     [U]  Uninstall
echo     [0]  Exit
echo.
set "pick="
set /p pick=  Choose:
if "%pick%"=="1" goto want1
if "%pick%"=="2" goto want2
if "%pick%"=="3" goto want3
if /i "%pick%"=="L" goto license
if /i "%pick%"=="U" goto uninstall
if "%pick%"=="0" exit /b
goto menu

:want1
set "mode=changer"
goto eula

:want2
set "mode=standard"
goto eula

:want3
set "mode=safe"
goto eula

:uninstall
cls
%PS% "%~dp0files\uninstall.ps1"
goto done

:license
cls
if not exist "%~dp0LICENSE.txt" (
  echo.
  echo   LICENSE.txt is missing from this folder.
  echo.
  pause
  goto menu
)
more "%~dp0LICENSE.txt"
echo.
pause
goto menu

:eula
cls
if not exist "%~dp0LICENSE.txt" (
  echo.
  echo   LICENSE.txt is missing from this folder. Nothing was installed.
  echo   Get a complete copy from %TG%
  echo.
  pause
  goto menu
)
echo.
echo   Before installing, read the license agreement.
echo   Space scrolls a page, Q leaves the text.
echo.
pause
more "%~dp0LICENSE.txt"
echo.
echo   ============================================================
echo     Type  AGREE  to accept the license and install.
echo     Anything else cancels.
echo   ============================================================
echo.
set "ok="
set /p ok=  Your answer:
if /i not "%ok%"=="AGREE" (
  echo.
  echo   Not accepted - nothing was installed.
  echo.
  pause
  goto menu
)
if "%mode%"=="changer" goto changer
if "%mode%"=="safe" goto safe
goto standard

:changer
cls
%PS% "%~dp0files\install.ps1" -ModDir "Dota2SkinChanger" -Launch
goto done

:standard
cls
%PS% "%~dp0files\install.ps1" -Launch
goto done

:safe
cls
%PS% "%~dp0files\install.ps1" -SafeMode -Launch
goto done

:done
echo.
pause
goto menu
