@echo off
REM Optional helper: removes the startup entry created by install-autostart.cmd.
setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if exist "%STARTUP%\HandyButton.cmd" del "%STARTUP%\HandyButton.cmd" && echo Removed startup entry.
if not exist "%STARTUP%\HandyButton.cmd" echo No startup entry found.
pause
