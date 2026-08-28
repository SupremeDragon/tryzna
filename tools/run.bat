@echo off
rem Запуск "Тризни". Шукає Godot 4.7 у PATH, далі - у типовому місці winget.
setlocal

set "GODOT="
for %%G in (Godot_v4.7-stable_win64.exe) do set "GODOT=%%~$PATH:G"

if not defined GODOT (
    set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
)

if not exist "%GODOT%" (
    echo Не знайдено Godot 4.7.
    echo Встанови його ^(winget install GodotEngine.GodotEngine^) або пропиши шлях тут.
    pause
    exit /b 1
)

"%GODOT%" --path "%~dp0..\game" %*
