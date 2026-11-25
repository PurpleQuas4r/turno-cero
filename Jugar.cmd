@echo off
setlocal
if defined GODOT_EXE (
    set "TURNO_CERO_GODOT=%GODOT_EXE%"
) else (
    set "TURNO_CERO_GODOT=E:\Godot\Godot_v4.0-stable_win64.exe"
)
if not exist "%TURNO_CERO_GODOT%" (
    echo No se encontro el ejecutable de Godot. Define GODOT_EXE con la ruta al ejecutable.
    echo Puedes abrir project.godot desde el gestor de proyectos de Godot.
    pause
    exit /b 1
)

set "TURNO_CERO_PROFILE=%TEMP%\TurnoCero-Godot"
if not exist "%TURNO_CERO_PROFILE%" mkdir "%TURNO_CERO_PROFILE%"
set "APPDATA=%TURNO_CERO_PROFILE%"
set "LOCALAPPDATA=%TURNO_CERO_PROFILE%"

if /i "%~1"=="--editor" (
    start "" "%TURNO_CERO_GODOT%" --path "%~dp0." --editor
    exit /b
)

if not exist "%~dp0.godot\imported\luchadores.png-*.ctex" (
    "%TURNO_CERO_GODOT%" --headless --path "%~dp0." --editor --quit
    if not exist "%~dp0.godot\imported\luchadores.png-*.ctex" (
        echo Godot no pudo importar los sprites. Abre project.godot desde el editor.
        pause
        exit /b 1
    )
)
start "" "%TURNO_CERO_GODOT%" --path "%~dp0."
