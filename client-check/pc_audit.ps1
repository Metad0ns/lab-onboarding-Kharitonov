param(
    [Parameter(Mandatory)]
    [ValidateSet('Hardware', 'Inventory', 'Audit', 'Test')]
    [string]$Mode,
    [string]$WorkDir
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Get-Hardware {
    # Каждый запрос независим. Пустое поле обработает пакетный файл.
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        if ($os.Caption) { "osName=$($os.Caption)" }
        if ($os.Version) { "osVersion=$($os.Version)" }
        if ($null -ne $os.TotalVisibleMemorySize) { "ramTotal=$([math]::Round($os.TotalVisibleMemorySize / 1MB, 1))" }
        if ($null -ne $os.FreePhysicalMemory) { "ramFree=$([math]::Round($os.FreePhysicalMemory / 1MB, 1))" }
    } catch {
        Write-Verbose "Win32_OperatingSystem: $_"
    }
    try {
        $processors = @(Get-CimInstance Win32_Processor | Where-Object Name | ForEach-Object {
            $_.Name.Trim()
        } | Select-Object -Unique)
        if ($processors.Count) { "cpuName=$($processors -join ', ')" }
    } catch {
        Write-Verbose "Win32_Processor: $_"
    }
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        if ($null -ne $disk.Size) { "diskSize=$([math]::Round($disk.Size / 1GB, 1))" }
        if ($null -ne $disk.FreeSpace) { "diskFree=$([math]::Round($disk.FreeSpace / 1GB, 1))" }
    } catch {
        Write-Verbose "Win32_LogicalDisk: $_"
    }
}

function Get-InstalledApps {
    $uninstall = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    $views = @([Microsoft.Win32.RegistryView]::Registry32)
    if ([Environment]::Is64BitOperatingSystem) {
        $views += [Microsoft.Win32.RegistryView]::Registry64
    }
    # Представление Registry32 соответствует ветке WOW6432Node на 64-разрядной Windows.
    foreach ($view in $views) {
        $root = $null
        $section = $null
        try {
            $root = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $view)
            $section = $root.OpenSubKey($uninstall)
            if ($null -eq $section) { continue }
            foreach ($key in $section.GetSubKeyNames()) {
                $app = $section.OpenSubKey($key)
                if ($null -eq $app) { continue }
                try {
                    $name = $app.GetValue('DisplayName')
                    if ($name -is [string] -and -not [string]::IsNullOrWhiteSpace($name)) {
                        $name.Trim() -replace '[\r\n\t]+', ' '
                    }
                } finally {
                    $app.Dispose()
                }
            }
        } catch {
            $message = "Не удалось полностью прочитать раздел $view реестра."
            [IO.File]::AppendAllLines((Join-Path $WorkDir 'inventory_warning.txt'), [string[]]@($message), $utf8)
        } finally {
            if ($null -ne $section) { $section.Dispose() }
            if ($null -ne $root) { $root.Dispose() }
        }
    }
}

function Get-AuditLines {
    param([string[]]$Apps, [bool]$InventoryComplete = $true)

    # Границы названий снижают число совпадений со вспомогательными компонентами.
    $baseline = @(
        @{ Name = 'Офисный пакет'; Pattern = '^(?:Microsoft (?:Office(?!\s+(?:Update|Click-to-Run))|365)|LibreOffice|(?:Apache )?OpenOffice|МойОфис|ONLYOFFICE)\b'; Suggestion = 'Для создания документов и таблиц рекомендуется LibreOffice или МойОфис.' }
        @{ Name = 'Браузер'; Pattern = '^(?:Google Chrome|Mozilla Firefox|Yandex(?:\.Browser| Browser)|Яндекс(?:\.Браузер| Браузер)|Microsoft Edge(?!\s+(?:Update|WebView)))\b'; Suggestion = 'Для доступа к корпоративным веб-сервисам рекомендуется Chrome или Firefox.' }
        @{ Name = 'Чтение PDF'; Pattern = '^(?:Adobe Acrobat|Foxit (?:PDF )?Reader|Sumatra\s?PDF)\b'; Suggestion = 'Для просмотра PDF и заполнения форм рекомендуется Acrobat Reader или Foxit PDF Reader.' }
        @{ Name = 'Архиватор'; Pattern = '^(?:7-Zip|WinRAR|WinZip)\b'; Suggestion = 'Для работы с вложениями в почте рекомендуется 7-Zip или WinRAR.' }
        @{ Name = 'Антивирус'; Pattern = '^(?:Microsoft Defender(?: Antivirus)?(?!\s+for\b)|Windows Defender|Kaspersky|ESET (?:NOD32|Endpoint|Internet Security|Smart Security|Security)|Dr\.?\s?Web)\b'; Suggestion = 'Проверьте состояние Microsoft Defender или наличие утверждённого организацией антивируса.' }
    )
    $reviewGroups = @(
        @{ Name = 'Игры и игровые платформы'; Pattern = '\b(?:Steam|Epic Games|GOG|Origin|Ubisoft Connect|Battle\.net|Riot|games?|gaming)\b'; Action = 'Уточните, нужны ли игры и игровые платформы для рабочих задач.' }
        @{ Name = 'Торрент-клиенты и файлообмен'; Pattern = '(?:\btorrent\b|[µμu]torrent|bittorrent|qBittorrent|\bVuze\b)'; Action = 'Сверьте использование файлообмена с правилами сети организации.' }
        @{ Name = 'Мессенджеры и личное общение'; Pattern = '\b(?:Discord|Telegram|WhatsApp|Viber|Skype)\b'; Action = 'Сверьте приложения с перечнем утверждённых каналов связи.' }
        @{ Name = 'Развлечения и оформление'; Pattern = '\b(?:Wallpaper Engine|OBS(?: Studio)?|Soundpad)\b'; Action = 'Уточните, нужны ли приложения для согласованных рабочих задач.' }
    )

    $recommendations = 0
    ''
    'Проверка базового офисного ПО'
    '--------------------------------------------------'
    'Эталон покрывает документы, веб-сервисы, PDF, архивы и защиту рабочего места.'
    foreach ($category in $baseline) {
        $matchesForCategory = @($Apps | Where-Object { $_ -match $category.Pattern })
        if ($matchesForCategory.Count) {
            $names = foreach ($app in $matchesForCategory) {
                if ($app -match '^Microsoft Edge\b') { "$app (компонент Windows)" }
                else { $app }
            }
            "$($category.Name): требование выполнено. $($names -join '; ')"
        } elseif ($InventoryComplete) {
            "$($category.Name): подходящая программа в списке не обнаружена. $($category.Suggestion)"
            $recommendations++
        } else {
            "$($category.Name): в доступной части списка совпадений нет. Проверка неполная."
        }
    }

    ''
    'ПО, требующее дополнительной проверки'
    '--------------------------------------------------'
    foreach ($group in $reviewGroups) {
        $flagged = @($Apps | Where-Object { $_ -match $group.Pattern })
        if ($flagged.Count) {
            "$($group.Name): $($flagged -join '; ')."
            "  Рекомендация: $($group.Action)"
            $recommendations++
        } elseif ($InventoryComplete) {
            "$($group.Name): совпадений нет."
        } else {
            "$($group.Name): в доступной части списка совпадений нет. Проверка неполная."
        }
    }
    ''
    'Совпадения служат поводом для проверки. Решение о сохранении или удалении ПО принимает администратор.'
    'При проверке учитывайте согласованные исключения и специализированные задачи.'
    'Проверка логики: в тестовый список добавлен Steam; 7-Zip сначала присутствовал, затем был исключён.'
    "Итог: категорий базового ПО проверено — $($baseline.Count); рекомендаций выдано — $recommendations."
}

switch ($Mode) {
    'Hardware' {
        [IO.File]::WriteAllLines((Join-Path $WorkDir 'hardware.txt'), [string[]]@(Get-Hardware), $utf8)
    }
    'Inventory' {
        $apps = @(Get-InstalledApps | Sort-Object -Unique)
        [IO.File]::WriteAllLines((Join-Path $WorkDir 'apps_list.txt'), [string[]]$apps, $utf8)
    }
    'Audit' {
        $listPath = Join-Path $WorkDir 'apps_list.txt'
        $hasList = [IO.File]::Exists($listPath)
        $apps = if ($hasList) { [IO.File]::ReadAllLines($listPath, $utf8) }
        $complete = $hasList -and -not (Test-Path -LiteralPath (Join-Path $WorkDir 'inventory_warning.txt'))
        $lines = @(Get-AuditLines -Apps $apps -InventoryComplete $complete)
        $numberedLines = for ($i = 0; $i -lt $lines.Count; $i++) { "$i|$($lines[$i])" }
        [IO.File]::WriteAllLines((Join-Path $WorkDir 'audit.txt'), [string[]]$numberedLines, $utf8)
    }
    'Test' {
        $officeApps = @('LibreOffice 25', 'Microsoft Edge', 'SumatraPDF', '7-Zip 25', 'ESET Endpoint Security')
        $normal = (Get-AuditLines -Apps $officeApps) -join [Environment]::NewLine
        $changedApps = @($officeApps | Where-Object { $_ -notmatch '^7-Zip' }) + @('Steam')
        $changed = (Get-AuditLines -Apps $changedApps) -join [Environment]::NewLine
        if ($normal -notmatch 'Архиватор: требование выполнено\. 7-Zip' -or
            $normal -notmatch 'Игры и игровые платформы: совпадений нет' -or
            $normal -notmatch 'рекомендаций выдано — 0' -or
            $changed -notmatch 'Архиватор: подходящая программа в списке не обнаружена.*7-Zip или WinRAR' -or
            $changed -notmatch 'Игры и игровые платформы: Steam' -or
            $changed -notmatch 'рекомендаций выдано — 2') {
            throw 'Проверка рекомендаций не пройдена.'
        }
        'Проверка пройдена: 7-Zip засчитан в эталоне; без 7-Zip дан совет об установке; Steam отмечен для проверки.'
    }
}
