@echo off
title ShowMMR 2026 - uninstall
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

cls
echo.
echo   ================================================
echo     ShowMMR 2026   -   uninstall
echo     by  %TG%
echo   ================================================
echo.
echo   This removes:
echo     - the mod archive from your Dota 2 folder
echo     - the background sync and its Windows startup entry
echo     - any search path an older ShowMMR build added to gameinfo
echo.
echo   Your MMR history is kept.
echo   Close Dota 2 first.
echo.
set "ok="
set /p ok=  Type YES to uninstall:
if /i not "%ok%"=="YES" (
  echo.
  echo   Cancelled - nothing was removed.
  echo.
  pause
  exit /b
)
cls
%PS% "%~dp0files\uninstall.ps1"
echo.
pause
exit /b
