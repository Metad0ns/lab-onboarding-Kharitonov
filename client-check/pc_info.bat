@echo off
chcp 65001 >nul

REM ============================================================
REM Тема: Диагностика клиентского компьютера
REM Автор: Харитонов
REM Дата: 26.10.2026
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
"%REPORT%" echo(!msg!

endlocal
exit /b

:main
REM --- Заголовок ---
call :out "========================================"
call :out "         Диагностика компьютера"
call :out "========================================"
call :out ""

REM --- Операционная система ---
call :out "Операционная система"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`wmic os get Caption /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do call :out "Название: %%b"
for /f "usebackq delims=" %%x in (`wmic os get Version /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do call :out "Версия: %%b"
call :out ""

REM --- Процессор ---
call :out "Процессор"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`wmic cpu get Name /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do call :out "%%b"
call :out ""

REM --- Оперативная память (значения в КБ переводим в ГБ, делим на 1048576) ---
call :out "Оперативная память"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`wmic os get TotalVisibleMemorySize /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do set "RAM_TOTAL_KB=%%b"
for /f "usebackq delims=" %%x in (`wmic os get FreePhysicalMemory /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do set "RAM_FREE_KB=%%b"
set /a RAM_TOTAL_GB=(RAM_TOTAL_KB+524288)/1048576
set /a RAM_FREE_GB=(RAM_FREE_KB+524288)/1048576
call :out "Всего памяти: %RAM_TOTAL_GB% ГБ"
call :out "Свободно памяти: %RAM_FREE_GB% ГБ"
call :out ""

REM --- Диск C (значения в байтах; set /a не умеет числа больше ~2 ГБ,
REM     поэтому отрезаем последние 6 цифр и делим на 1073,74 через *10/10737) ---
call :out "Диск C"
call :out "----------------------------------------"
for /f "usebackq delims=" %%x in (`wmic logicaldisk where "DeviceID='C:'" get Size /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do set "DISK_SIZE=%%b"
for /f "usebackq delims=" %%x in (`wmic logicaldisk where "DeviceID='C:'" get FreeSpace /format:list ^| find "="`) do for /f "tokens=1,* delims==" %%a in ("%%x") do set "DISK_FREE=%%b"
set "SIZE_MB=%DISK_SIZE:~0,-6%"
set "FREE_MB=%DISK_FREE:~0,-6%"
set /a DISK_SIZE_GB=SIZE_MB*10/10737
set /a DISK_FREE_GB=FREE_MB*10/10737
call :out "Размер диска: %DISK_SIZE_GB% ГБ"
call :out "Свободно: %DISK_FREE_GB% ГБ"
call :out ""

REM --- Установленные программы (через реестр: 64-битные и 32-битные) ---
call :out "Установленные программы"
call :out "----------------------------------------"
for /f "usebackq tokens=1,2,*" %%a in (`reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s ^| findstr /R /C:"^ *DisplayName *REG_"`) do call :out "%%c"
for /f "usebackq tokens=1,2,*" %%a in (`reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s ^| findstr /R /C:"^ *DisplayName *REG_"`) do call :out "%%c"
call :out ""

REM --- Итог ---
call :out "========================================"
call :out "Отчёт сохранён"
pause
