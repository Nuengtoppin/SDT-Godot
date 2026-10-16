@echo off
rem Launches the game with the debug build (Godot editor binary + debug native extension).
rem The console window shows the log; it is also written to %APPDATA%\Godot\app_userdata\SDT Godot\logs\godot.log
rem Extra arguments are passed to Godot, e.g.  run_debug.bat --verbose
rem Godot: the GODOT environment variable, else run_debug.local.bat next to this file (not in git; it can
rem contain e.g.  set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe), else godot.exe on PATH.
if not defined GODOT if exist "%~dp0run_debug.local.bat" call "%~dp0run_debug.local.bat"
if not defined GODOT set GODOT=godot.exe
"%GODOT%" --path "%~dp0game" %*
if errorlevel 1 pause
