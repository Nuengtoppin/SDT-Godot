@echo off
rem Launches the game with the debug build (Godot editor binary + debug native extension).
rem The console window shows the log; it is also written to %APPDATA%\Godot\app_userdata\SDT Godot\logs\godot.log
rem Extra arguments are passed to Godot, e.g.  run_debug.bat --verbose
rem Godot: the GODOT environment variable, else run_debug.local.bat next to this file (not in git; it can
rem contain e.g.  set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe), else godot.exe on PATH.
if not defined GODOT if exist "%~dp0run_debug.local.bat" call "%~dp0run_debug.local.bat"
if not defined GODOT set GODOT=godot.exe
if exist "%GODOT%" goto found
where "%GODOT%" >nul 2>nul
if not errorlevel 1 goto found
echo Godot was not found ("%GODOT%").
echo Install Godot 4.7.2 and create run_debug.local.bat next to this file containing:
echo     set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe
echo (see README.md).
pause
exit /b 1
:found
rem First run after downloading: Godot imports the assets once (a few minutes) before the game can start. The
rem marker is written only after a complete import, so an interrupted import is redone.
if not exist "%~dp0game\.godot\sdt_import_done" goto first
powershell -NoProfile -Command "$m=(Get-Item '%~dp0game\.godot\sdt_import_done').LastWriteTime; foreach ($d in 'src','flash','scenes','debug') { if (Get-ChildItem -Path ('%~dp0game\' + $d) -Recurse -Filter *.gd -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $m } | Select-Object -First 1) { exit 1 } }; exit 0"
if errorlevel 1 goto update
goto run
:first
echo First run: importing the game assets, this takes a few minutes...
"%GODOT%" --headless --path "%~dp0game" --import
if errorlevel 1 (
	echo The asset import failed; see the messages above.
	pause
	exit /b 1
)
echo.> "%~dp0game\.godot\sdt_import_done"
goto run
:update
rem After an update (git pull, new download): scripts newer than the marker may add classes, which Godot only
rem registers during an import. A quick import (a few seconds) does that.
echo Scripts changed since the last import: updating...
"%GODOT%" --headless --path "%~dp0game" --import >nul 2>nul
echo.> "%~dp0game\.godot\sdt_import_done"
:run
"%GODOT%" --path "%~dp0game" %*
if errorlevel 1 pause
