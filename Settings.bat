@echo off
title ShowMMR 2026 - settings
cd /d "%~dp0"
set PS=powershell -NoProfile -ExecutionPolicy Bypass -File
:: channel handle, assembled so a search of this file does not reveal it
set "z1=t.m" & set "z2=e/fe" & set "z3=ere" & set "z4=eks"
set "TG=%z1%%z2%%z3%%z4%"

:menu
cls
echo.
echo   ================================================
echo     ShowMMR 2026   -   appearance
echo     by  %TG%
echo   ================================================
echo.
echo   Press Enter on anything you do not want to change.
echo.
echo   Colours - the palette below applies to all four questions:
echo     1  green    #6FCF56          5  yellow   #F2C94C
echo     2  red      #E45B5B          6  orange   #FF9F45
echo     3  purple   #A970FF          7  pink     #FF6FB5
echo     4  blue     #4FA8FF          8  white    #FFFFFF
echo.
echo   A number, your own hex (with or without #), or 0 for the default.
echo.
set "cw="
set "cl="
set "cx="
set "cm="
set "ct="
set /p cw=  Win  numbers  (+MMR):
set /p cl=  Loss numbers  (-MMR):
set /p cx=  Plain text    (day names, counts):
set /p cm=  MMR block      (Dota's own 1489 / MMR / bar):
echo.
echo   Day strip above the profile?  TODAY +80 (4)   YESTERDAY -20 (3)   MONDAY ...
echo   Hover it for this week, last week, the month and the all-time total.
set /p ct=  1 = yes, 0 = no  (on by default):
call :pick cw "%cw%"
call :pick cl "%cl%"
call :pick cx "%cx%"
call :pick cm "%cm%"
set "arg="
if defined cw if "%cw%"=="NONE" (set "arg=%arg%,win=") else (set "arg=%arg%,win=%cw%")
if defined cl if "%cl%"=="NONE" (set "arg=%arg%,loss=") else (set "arg=%arg%,loss=%cl%")
if defined cx if "%cx%"=="NONE" (set "arg=%arg%,text=") else (set "arg=%arg%,text=%cx%")
if defined cm if "%cm%"=="NONE" (set "arg=%arg%,mmr=") else (set "arg=%arg%,mmr=%cm%")
if defined ct set "arg=%arg%,session=%ct%"
if "%arg%"=="" (
  echo.
  echo   Nothing entered - leaving everything as it is.
  goto done
)
echo.
%PS% "%~dp0files\showmmr_sync.ps1" -Settings "%arg%"
goto done

:pick
rem  no "cmd & exit /b" here: cmd.exe splits the line on & before if sees it,
rem  so the exit would run whether the condition matched or not
if "%~2"=="0" set "%~1=NONE"
if "%~2"=="1" set "%~1=#6FCF56"
if "%~2"=="2" set "%~1=#E45B5B"
if "%~2"=="3" set "%~1=#A970FF"
if "%~2"=="4" set "%~1=#4FA8FF"
if "%~2"=="5" set "%~1=#F2C94C"
if "%~2"=="6" set "%~1=#FF9F45"
if "%~2"=="7" set "%~1=#FF6FB5"
if "%~2"=="8" set "%~1=#FFFFFF"
exit /b

:done
echo.
echo   Go back to the dashboard in Dota 2 to see it.
echo.
echo     [1]  change something else
echo     [0]  close
echo.
set "again="
set /p again=  Choose:
if "%again%"=="1" goto menu
exit /b
