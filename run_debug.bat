@echo off
rem Launches the game with the debug build (Godot editor binary + debug native extension).
rem The console window shows the log; it is also written to %APPDATA%\Godot\app_userdata\SDT Godot\logs\godot.log
rem Extra arguments are passed to Godot, e.g.  run_debug.bat --verbose
set GODOT=Godot_v4.7.2-stable_win64_console.exe
"%GODOT%" --path "%~dp0game" %*
if errorlevel 1 pause
