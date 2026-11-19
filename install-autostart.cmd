@echo off
REM Optional helper: adds the button to Windows startup (run once, then you can delete this file).
REM It creates a small .cmd in the Startup folder that launches "Start Handy button.vbs".
setlocal
set "HERE=%~dp0"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if not exist "%STARTUP%" mkdir "%STARTUP%"
> "%STARTUP%\HandyButton.cmd" echo @echo off
>>"%STARTUP%\HandyButton.cmd" echo start "" wscript.exe "%HERE%Start Handy button.vbs"
echo Added to startup: %STARTUP%\HandyButton.cmd
echo You can now delete this helper file.
pause
