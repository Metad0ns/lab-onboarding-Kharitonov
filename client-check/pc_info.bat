@echo off
chcp 65001 >nul

REM ============================================================
REM Тема: Диагностика клиентского компьютера
REM Автор: Харитонов
REM Дата: 29.10.2026
REM ============================================================

REM --- Путь к отчёту: рядом с pc_info.bat (%~dp0 = папка этого файла) ---
set "REPORT=%~dp0pc_report.txt"
if exist "%REPORT%" del "%REPORT%"
goto :main

REM --- Подпрограмма: выводит строку в окно и дописывает её в файл отчёта ---
:out
setlocal EnableDelayedExpansion
set "msg=%~1"
echo(!msg!
>>"%REPORT%" echo(!msg!
endlocal
exit /b

:main
REM --- Заголовок ---
call :out "========================================"
call :out "         Диагностика компьютера"
call :out "========================================"
call :out ""

REM --- Операционная система (через PowerShell, так как wmic недоступен) ---
call :out "Операционная система"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; (Get-CimInstance Win32_OperatingSystem).Caption"`) do call :out "Название: %%x"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Version"`) do call :out "Версия: %%x"
call :out ""

REM --- Процессор ---
call :out "Процессор"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name"`) do call :out "%%x"
call :out ""

REM --- Оперативная память (КБ делим на 1MB = 1048576, получаем ГБ) ---
call :out "Оперативная память"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1MB)"`) do set "RAM_TOTAL_GB=%%x"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB)"`) do set "RAM_FREE_GB=%%x"
call :out "Всего памяти: %RAM_TOTAL_GB% ГБ"
call :out "Свободно памяти: %RAM_FREE_GB% ГБ"
call :out ""

REM --- Диск C (байты делим на 1GB = 1073741824, получаем ГБ) ---
call :out "Диск C"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=''C:''').Size/1GB)"`) do set "DISK_SIZE_GB=%%x"
for /f "usebackq delims=" %%x in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=''C:''').FreeSpace/1GB)"`) do set "DISK_FREE_GB=%%x"
call :out "Размер диска: %DISK_SIZE_GB% ГБ"
call :out "Свободно: %DISK_FREE_GB% ГБ"
call :out ""

REM --- Установленные программы (через реестр: 64-битные и 32-битные) ---
call :out "Установленные программы"
call :out "----------------------------------------"
for /f "usebackq tokens=1,2,*" %%a in (`reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s ^| findstr /R /C:"^ *DisplayName  *REG_"`) do call :out "%%c"
for /f "usebackq tokens=1,2,*" %%a in (`reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s ^| findstr /R /C:"^ *DisplayName  *REG_"`) do call :out "%%c"
call :out ""

REM --- Итог ---
call :out "========================================"
call :out "Отчёт сохранён"
pause