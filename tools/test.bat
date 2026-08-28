@echo off
rem Димовий тест ядра "Тризни". Без вікна, повертає код 0/1.
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

"%GODOT%" --headless --path "%~dp0..\game" res://tests/smoke_fold.tscn
