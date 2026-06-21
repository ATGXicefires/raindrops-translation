$ErrorActionPreference = "Stop"

function Pause-And-Exit([int]$code) {
    Write-Host ""
    Read-Host "請按 Enter 鍵結束"
    exit $code
}

try {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
    
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  二万分の一の雨粒達 - 繁體中文翻譯補丁 一鍵安裝程式" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""

    function Get-SteamLibraryPaths {
        $paths = @()
        $registryKeys = @(
            "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
            "HKLM:\SOFTWARE\Valve\Steam",
            "HKCU:\SOFTWARE\Valve\Steam"
        )

        foreach ($key in $registryKeys) {
            $prop = Get-ItemProperty -Path $key -Name "InstallPath" -ErrorAction SilentlyContinue
            if ($prop -and $prop.InstallPath) {
                $steamPath = $prop.InstallPath.TrimEnd('\\')
                if ((Test-Path $steamPath) -and ($paths -notcontains $steamPath)) {
                    $paths += $steamPath
                }
            }
        }

        foreach ($steamPath in $paths) {
            $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
            if (-not (Test-Path $vdf)) { continue }

            foreach ($line in Get-Content -LiteralPath $vdf -Encoding UTF8) {
                if ($line -match '"path"\s+"([^"]+)"') {
                    $libraryPath = ($matches[1] -replace '\\\\', '\').TrimEnd('\\')
                    if ((Test-Path $libraryPath) -and ($paths -notcontains $libraryPath)) {
                        $paths += $libraryPath
                    }
                }
            }
        }
        return $paths
    }

    function Find-GameRoot {
        $gameFolder = "二万分の一の雨粒達 - One in 20,000 raindrops"

        if (Test-Path "resources\app\data\scenario") {
            return (Get-Location).Path
        }

        Write-Host "[進度] 嘗試自動尋找 Steam 遊戲安裝目錄..." -ForegroundColor Green
        $libs = Get-SteamLibraryPaths
        foreach ($libraryPath in $libs) {
            $candidate = Join-Path $libraryPath "steamapps\common\$gameFolder"
            if (Test-Path (Join-Path $candidate "resources\app\data\scenario")) {
                Write-Host "[成功] 自動找到遊戲安裝於：$candidate" -ForegroundColor Green
                return $candidate
            }
        }

        Write-Host "[警告] 無法自動尋找遊戲目錄，請手動指定。" -ForegroundColor Yellow
        Write-Host "請將遊戲的「$gameFolder」資料夾拖曳到這個視窗，或直接貼上完整路徑。" -ForegroundColor Yellow
        $manualPath = Read-Host "輸入或貼上路徑"
        if ([string]::IsNullOrWhiteSpace($manualPath)) {
            Write-Host "[錯誤] 路徑不可為空白。" -ForegroundColor Red
            Pause-And-Exit 1
        }
        $manualPath = $manualPath.Trim('"', "'")

        if (-not (Test-Path (Join-Path $manualPath "resources\app\data\scenario"))) {
            Write-Host "[錯誤] 該路徑不正確，找不到 resources\app\data\scenario。" -ForegroundColor Red
            Pause-And-Exit 1
        }

        return $manualPath
    }

    function Select-Font {
        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host "  請選擇遊戲顯示字體：" -ForegroundColor Cyan
        Write-Host "  [1] 微軟正黑體（預設推薦）" -ForegroundColor Cyan
        Write-Host "  [2] 新細明體" -ForegroundColor Cyan
        Write-Host "  [3] 標楷體" -ForegroundColor Cyan
        Write-Host "  [4] 手動輸入其他字體名稱" -ForegroundColor Cyan
        Write-Host "========================================================" -ForegroundColor Cyan

        $choice = Read-Host "請輸入數字 (1-4)，直接按 Enter 使用預設"
        switch ($choice) {
            "2" { return @{ Name = "PMingLiU, 新細明體, serif"; Description = "新細明體" } }
            "3" { return @{ Name = "DFKai-SB, 標楷體, serif"; Description = "標楷體" } }
            "4" { return Select-Custom-Font }
            default { return @{ Name = "Microsoft JhengHei, 微軟正黑體, sans-serif"; Description = "微軟正黑體" } }
        }
    }

    function Select-Custom-Font {
        Add-Type -AssemblyName System.Drawing
        $fontCollection = New-Object System.Drawing.Text.InstalledFontCollection
        $sysFonts = @()
        foreach ($f in $fontCollection.Families) { $sysFonts += $f.Name }

        while ($true) {
            $customFont = Read-Host "請輸入字體名稱（例如：Noto Serif TC）"
            if ([string]::IsNullOrWhiteSpace($customFont)) { continue }

            Write-Host "[進度] 正在檢查字體「$customFont」是否存在..." -ForegroundColor Green
            if ($sysFonts -contains $customFont) {
                return @{ Name = $customFont; Description = $customFont }
            }

            $matchedFonts = @($sysFonts | Where-Object {
                    $_ -match [regex]::Escape($customFont) -or $customFont -match [regex]::Escape($_)
                })

            if ($matchedFonts.Count -gt 0) {
                $guess = $matchedFonts[0]
                Write-Host "[警告] 找不到完全相符的字體「$customFont」。" -ForegroundColor Yellow
                $useGuess = Read-Host "您是指「$guess」嗎？(Y/N)"
                if ($useGuess -match "^[Yy]") {
                    return @{ Name = $guess; Description = $guess }
                }
                Write-Host "請重新輸入。"
                continue
            }

            Write-Host "[錯誤] 系統字體庫中找不到任何與「$customFont」相關的字體。" -ForegroundColor Red
            Write-Host "請確認拼字是否正確，或是該字體是否已安裝。" -ForegroundColor Red
        }
    }

    function Install-NotoSerifTC([string]$gameRoot) {
        $fontCss = Join-Path $gameRoot "resources\app\tyrano\css\font.css"
        if (Test-Path $fontCss) {
            $cssContent = [System.IO.File]::ReadAllText($fontCss, [System.Text.Encoding]::UTF8)
            if ($cssContent -notmatch 'NotoSerifTC') {
                Write-Host "[進度] 正在載入思源宋體字型（NotoSerifTC）..." -ForegroundColor Green
                $notoFace = " @font-face { font-family: 'NotoSerifTC'; src: url('../../data/others/NotoSerifTC-VF.ttf') format('truetype'); font-weight:normal;font-style:normal; }"
                $cssContent = $cssContent.TrimEnd() + "`n" + $notoFace + "`n"
                [System.IO.File]::WriteAllText($fontCss, $cssContent, [System.Text.Encoding]::UTF8)
                Write-Host "[成功] 思源宋體已載入。" -ForegroundColor Green
            } else {
                Write-Host "[提示] 思源宋體字型已載入，跳過。" -ForegroundColor Green
            }
        } else {
            Write-Host "[警告] 找不到 font.css，無法載入內建字型。" -ForegroundColor Yellow
        }
    }

    function Apply-Font([string]$configFile, [hashtable]$font) {
        Write-Host ""
        Write-Host "[進度] 正在設定字型為「$($font.Description)」..." -ForegroundColor Green

        if (-not (Test-Path $configFile)) {
            Write-Host "[警告] 找不到 Config.tjs，無法自動設定字型；劇本補丁仍已安裝。" -ForegroundColor Yellow
            return
        }

        $replacement = 'userFace="' + $font.Name + '";'
        $content = Get-Content -LiteralPath $configFile -Encoding UTF8
        $updated = $content -replace '^\s*;?\s*userFace\s*=.*', $replacement
        Set-Content -LiteralPath $configFile -Value $updated -Encoding UTF8
        Write-Host "[成功] 字型已設定為「$($font.Description)」。" -ForegroundColor Green
    }

    function Test-SaveSetIdentical($saves, [string]$snapshotDir) {
        $snapSaves = @(Get-ChildItem -LiteralPath $snapshotDir -Filter "*.sav" -File -ErrorAction SilentlyContinue)
        if ($snapSaves.Count -ne $saves.Count) { return $false }
        foreach ($sav in $saves) {
            $snap = Join-Path $snapshotDir $sav.Name
            if (-not (Test-Path $snap)) { return $false }
            $h1 = (Get-FileHash -LiteralPath $sav.FullName -Algorithm SHA256).Hash
            $h2 = (Get-FileHash -LiteralPath $snap -Algorithm SHA256).Hash
            if ($h1 -ne $h2) { return $false }
        }
        return $true
    }

    function Backup-Saves([string]$gameRoot) {
        $saves = @(Get-ChildItem -LiteralPath $gameRoot -Filter "*.sav" -File -ErrorAction SilentlyContinue)
        if ($saves.Count -eq 0) { return }

        $root = Join-Path $gameRoot "saves_backup"
        if (-not (Test-Path $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }

        # 與最近一次的快照比對，內容相同就不重複備份
        $newest = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
        if ($newest -and (Test-SaveSetIdentical $saves $newest.FullName)) {
            Write-Host "[提示] 遊戲存檔與最近一次備份相同，跳過。" -ForegroundColor Green
            return
        }

        # 每次都把「目前的」存檔另存成有時間戳的新快照，不覆蓋舊備份
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $dest = Join-Path $root $stamp
        $i = 1
        while (Test-Path $dest) { $dest = Join-Path $root "$stamp-$i"; $i++ }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Write-Host "[進度] 發現遊戲存檔，正在備份目前進度至 saves_backup\$(Split-Path $dest -Leaf) ..." -ForegroundColor Green

        foreach ($sav in $saves) {
            Copy-Item -LiteralPath $sav.FullName -Destination (Join-Path $dest $sav.Name) -Force
            Write-Host "[成功] 已備份存檔：$($sav.Name)" -ForegroundColor Green
        }
    }

    function Apply-SteamOverlay([string]$gameRoot) {
        $mainJs = Join-Path $gameRoot "resources\app\main.js"
        if (-not (Test-Path $mainJs)) {
            Write-Host "[警告] 找不到 main.js，略過 Steam Overlay 修正。" -ForegroundColor Yellow
            return
        }

        $content = [System.IO.File]::ReadAllText($mainJs, [System.Text.Encoding]::UTF8)
        if ($content -match 'in-process-gpu') {
            Write-Host "[提示] Steam Overlay 修正已套用過，略過。" -ForegroundColor Green
            return
        }

        $anchor = [regex]'(?m)^([ \t]*)const\s+app\s*=\s*electron\.app\s*;'
        $m = $anchor.Match($content)
        if (-not $m.Success) {
            Write-Host "[警告] main.js 格式與預期不符，未自動修改，請參考 README 手動處理。" -ForegroundColor Yellow
            return
        }

        # 改檔前先備份 main.js（不存在才備份）
        $backupMainJs = Join-Path $gameRoot "resources\app\data\scenario_backup\main.js.bak"
        if (-not (Test-Path $backupMainJs)) {
            $backupParent = Split-Path $backupMainJs -Parent
            if (-not (Test-Path $backupParent)) { New-Item -ItemType Directory -Force -Path $backupParent | Out-Null }
            Copy-Item -LiteralPath $mainJs -Destination $backupMainJs -Force
        }

        Write-Host "[進度] 正在套用 Steam Overlay／截圖修正（main.js）..." -ForegroundColor Green
        if ($content.Contains("`r`n")) { $newline = "`r`n" } else { $newline = "`n" }
        $indent = $m.Groups[1].Value
        $lineEnd = $content.IndexOf("`n", $m.Index + $m.Length)
        if ($lineEnd -lt 0) { $insertAt = $content.Length } else { $insertAt = $lineEnd + 1 }
        $insertedLine = $indent + "app.commandLine.appendSwitch('in-process-gpu');" + $newline
        $content = $content.Substring(0, $insertAt) + $insertedLine + $content.Substring($insertAt)
        [System.IO.File]::WriteAllText($mainJs, $content, [System.Text.Encoding]::UTF8)
        Write-Host "[成功] Steam Overlay 修正已套用；若日後 Steam 更新遊戲被還原，需重新執行。" -ForegroundColor Green
    }

    $gameRoot = Find-GameRoot
    $targetDir = Join-Path $gameRoot "resources\app\data\scenario"
    $backupDir = Join-Path $gameRoot "resources\app\data\scenario_backup"
    $configFile = Join-Path $gameRoot "resources\app\data\system\Config.tjs"
    
    $patchDir = Join-Path $scriptDir "patched"
    if (-not (Test-Path $patchDir)) {
        Write-Host "[錯誤] 找不到 patched 資料夾。請確認您已經解壓縮「完整」的補丁檔案夾！" -ForegroundColor Red
        Pause-And-Exit 1
    }

    $patchFiles = @(Get-ChildItem -LiteralPath $patchDir -Filter "*.ks" -ErrorAction SilentlyContinue)
    if ($patchFiles.Count -eq 0) {
        Write-Host "[錯誤] patched 資料夾內找不到任何 .ks 劇本檔案。" -ForegroundColor Red
        Pause-And-Exit 1
    }

    Backup-Saves -gameRoot $gameRoot

    Write-Host "[進度] 正在檢查備份..." -ForegroundColor Green
    if (-not (Test-Path $backupDir)) {
        Write-Host "[進度] 建立原始劇本備份 scenario_backup ..." -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -Path "$targetDir\*" -Destination $backupDir -Recurse -Force
        Write-Host "[成功] 備份完成。" -ForegroundColor Green
    }
    else {
        Write-Host "[提示] 備份資料夾已存在，跳過備份步驟。" -ForegroundColor Green
    }

    Write-Host "[進度] 正在安裝中文劇本..." -ForegroundColor Green
    foreach ($file in $patchFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination $targetDir -Force
    }
    Write-Host "[成功] 中文劇本覆蓋完成。" -ForegroundColor Green

    Install-NotoSerifTC -gameRoot $gameRoot
    $font = Select-Font
    Apply-Font -configFile $configFile -font $font

    Write-Host ""
    $overlayChoice = Read-Host "是否要修正 Steam Overlay／截圖？會修改 main.js（預設否）[y/N]"
    if ($overlayChoice -match "^[Yy]") {
        Apply-SteamOverlay -gameRoot $gameRoot
    } else {
        Write-Host "[提示] 已略過 Steam Overlay 修正。" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  安裝完成！您可以直接啟動遊戲了。" -ForegroundColor Cyan
    Write-Host "  如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario 即可。" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Pause-And-Exit 0

}
catch {
    Write-Host ""
    Write-Host "=================== 發生未預期的錯誤 ===================" -ForegroundColor Red
    Write-Host "錯誤訊息：" $_.Exception.Message -ForegroundColor Red
    Write-Host "發生位置：" $_.InvocationInfo.PositionMessage -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Pause-And-Exit 1
}