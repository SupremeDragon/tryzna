@echo off
rem Знімки сірого прототипу "Тризни" -> builds\shots\
setlocal

set "GODOT="
for %%G in (Godot_v4.7-stable_win64.exe) do set "GODOT=%%~$PATH:G"

if not defined GODOT (
    set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
)

if not exist "%GODOT%" (
    echo Не знайдено Godot 4.7.
    exit /b 1
)

"%GODOT%" --path "%~dp0..\game" --resolution 1280x720 res://tests/capture_shots.tscn
