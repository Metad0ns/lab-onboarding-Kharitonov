@echo off
chcp 65001 >nul
setlocal DisableDelayedExpansion
title Аудит клиентского компьютера

REM Тема: Диагностика и аудит клиентского компьютера. Автор: Харитонов. Дата: 19.11.2026.
set "report=%~dp0pc_report.txt"
set "helper=%~dp0pc_audit.ps1"
set "work=%TEMP%\pc-check-%RANDOM%-%RANDOM%-%RANDOM%"
set "writeFailed="
type nul >"%report%"
if errorlevel 1 (
    echo Не удалось создать файл отчёта "%report%".
    pause
    exit /b 1
)

REM --- Заголовок и время формирования ---
call :log "=================================================="
call :log "Диагностика и аудит клиентского компьютера"
call :log "Дата и время формирования: %date% %time%"
call :log "=================================================="
md "%work%" 2>nul
if errorlevel 1 (
    call :log "Не удалось создать временную папку для диагностики."
    pause
    exit /b 1
)

REM --- Сбор данных и сброс переменных перед чтением результатов CIM ---
call :log ""
call :log "Собираются сведения об ОС, процессоре, памяти и диске C…"
for %%K in (osName osVersion cpuName ramTotal ramFree diskSize diskFree) do set "%%K="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%helper%" -Mode Hardware -WorkDir "%work%"
if exist "%work%\hardware.txt" for /f "usebackq tokens=1,* delims==" %%A in ("%work%\hardware.txt") do set "%%A=%%B"

REM --- Операционная система ---
call :section "Операционная система"
call :field osName "Название"
call :field osVersion "Версия"

REM --- Процессор ---
call :section "Процессор"
call :field cpuName "Название"

REM --- Оперативная память ---
call :section "Оперативная память"
call :field ramTotal "Всего памяти" " ГБ"
call :field ramFree "Свободно памяти" " ГБ"

REM --- Диск C ---
call :section "Диск C"
call :field diskSize "Размер диска" " ГБ"
call :field diskFree "Свободно" " ГБ"

REM --- Программы и рекомендации по списку названий из реестра ---
call :section "Установленные программы"
call :log "Выполняется опрос 64- и 32-разрядных разделов реестра…"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%helper%" -Mode Inventory -WorkDir "%work%"
if not exist "%work%\apps_list.txt" (
    call :log "Не удалось получить список программ."
) else (
    for /f "usebackq eol=| delims=" %%L in ("%work%\apps_list.txt") do (
        set "line=%%L"
        call :writeLine
    )
)
if exist "%work%\inventory_warning.txt" for /f "usebackq delims=" %%L in ("%work%\inventory_warning.txt") do (
    set "line=%%L"
    call :writeLine
)

call :log ""
call :log "Выполняется сверка списка программ с офисным эталоном…"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%helper%" -Mode Audit -WorkDir "%work%"
if not exist "%work%\audit.txt" (
    call :log "Не удалось сформировать результаты проверки программ."
) else (
    REM Номера строк сохраняют пустые строки при чтении через for /f.
    for /f "usebackq tokens=1,* delims=|" %%A in ("%work%\audit.txt") do (
        set "line=%%B"
        call :writeLine
    )
)

REM --- Завершение и очистка временных результатов ---
del /q "%work%\hardware.txt" "%work%\apps_list.txt" "%work%\inventory_warning.txt" "%work%\audit.txt" 2>nul
rd "%work%" 2>nul
call :log "=================================================="
set "line=Путь к отчёту: %report%"
call :writeLine
if defined writeFailed (
    echo Не удалось полностью записать отчёт.
) else (
    call :log "Отчёт сохранён"
    if defined writeFailed echo Не удалось полностью записать отчёт.
)
pause
if defined writeFailed exit /b 1
exit /b 0

REM --- Поле с подстановкой понятного сообщения при пустом результате ---
:field
set "line=%~2: данные получить не удалось"
if defined %~1 (
    setlocal EnableDelayedExpansion
    set "line=%~2: !%~1!%~3"
    call :writeLine
    if defined writeFailed (endlocal & set "writeFailed=1") else endlocal
) else (
    call :writeLine
)
exit /b

:section
call :log ""
call :log "%~1"
call :log "--------------------------------------------------"
exit /b

REM --- Вывод в окно и отчёт. Данные реестра минуют повторный разбор CALL ---
:log
set "line=%~1"
:writeLine
setlocal EnableDelayedExpansion
echo(!line!
>>"!report!" echo(!line!
if errorlevel 1 (
    endlocal
    set "writeFailed=1"
    exit /b 1
)
endlocal
exit /b 0
