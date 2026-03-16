@echo off
echo Opening Git Bash to run setup-local.sh ...

:: Try common Git for Windows installation paths
set GIT_BASH=
if exist "C:\Program Files\Git\bin\bash.exe" set GIT_BASH=C:\Program Files\Git\bin\bash.exe
if exist "C:\Program Files (x86)\Git\bin\bash.exe" set GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe

if "%GIT_BASH%"=="" (
  echo ERROR: Git for Windows not found.
  echo Please install it from https://gitforwindows.org/ then re-run this script.
  pause
  exit /b 1
)

"%GIT_BASH%" -c "cd '%~dp0' && bash setup-local.sh"
pause
