@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
color 0A
echo ========================================================
echo   二万分の一の雨粒達 — 繁體中文翻譯補丁 一鍵安裝程式
echo ========================================================
echo.

set "TARGET_DIR=resources\app\data\scenario"
set "BACKUP_DIR=resources\app\data\scenario_backup"
set "CONFIG_FILE=resources\app\data\system\Config.tjs"
set "PATCH_DIR=patched"

:: 1. 檢查是否在遊戲目錄
if not exist "%TARGET_DIR%" (
    color 0C
    echo [錯誤] 找不到遊戲目錄。
    echo 請確保您已將此安裝程式（install.bat 與 patched 資料夾）
    echo 放在遊戲的根目錄下（與 "二万分の一の雨粒達 - One in 20,000 raindrops.exe" 同一個資料夾）。
    echo.
    pause
    exit /b 1
)

:: 2. 檢查是否有 patch 檔案
if not exist "%PATCH_DIR%" (
    color 0C
    echo [錯誤] 找不到 patched 資料夾。請確認您解壓縮了完整的補丁檔案。
    echo.
    pause
    exit /b 1
)

:: 3. 備份
echo [進度] 正在檢查備份...
if not exist "%BACKUP_DIR%" (
    echo [進度] 建立原始劇本備份 (scenario_backup)...
    xcopy "%TARGET_DIR%" "%BACKUP_DIR%" /E /I /H /Y >nul
    if errorlevel 1 (
        color 0C
        echo [錯誤] 備份失敗！可能沒有權限，請嘗試以系統管理員身分執行。
        pause
        exit /b 1
    )
    echo [成功] 備份完成。
) else (
    echo [提示] 備份已存在，跳過備份步驟。
)

:: 4. 覆蓋檔案
echo [進度] 正在安裝中文劇本...
xcopy "%PATCH_DIR%\*.ks" "%TARGET_DIR%\" /Y >nul
if errorlevel 1 (
    color 0C
    echo [錯誤] 劇本覆蓋失敗！可能沒有權限，請嘗試以系統管理員身分執行。
    pause
    exit /b 1
)
echo [成功] 中文劇本安裝完成。

:: 5. 修改 Config.tjs 字型設定
echo.
echo ========================================================
echo   請選擇遊戲顯示字體：
echo   [1] 微軟正黑體 (預設推薦，最清晰)
echo   [2] 新細明體 (傳統風格)
echo   [3] 標楷體
echo   [4] 手動輸入其他字體名稱
echo ========================================================
set /p FONT_CHOICE="請輸入數字 (1-4) 並按 Enter (直接按 Enter 使用預設): "

set "FONT_NAME=Microsoft JhengHei, 微軟正黑體, sans-serif"
set "FONT_DESC=微軟正黑體"

if "%FONT_CHOICE%"=="2" (
    set "FONT_NAME=PMingLiU, 新細明體, serif"
    set "FONT_DESC=新細明體"
)
if "%FONT_CHOICE%"=="3" (
    set "FONT_NAME=DFKai-SB, 標楷體, serif"
    set "FONT_DESC=標楷體"
)
if "%FONT_CHOICE%"=="4" goto custom_font
goto apply_font

:custom_font
set /p CUSTOM_FONT="請輸入字體名稱 (例如: Noto Serif TC): "
if "!CUSTOM_FONT!"=="" goto custom_font

echo [進度] 正在檢查字體「!CUSTOM_FONT!」是否存在...
:: 執行 PowerShell 檢查字體並嘗試猜測
set "FONT_CHECK_RESULT="
for /f "delims=" %%i in ('powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; $fonts=(New-Object System.Drawing.Text.InstalledFontCollection).Families.Name; $inputFont=$env:CUSTOM_FONT; if ($fonts -contains $inputFont) { Write-Output 'EXACT' } else { $matches=$fonts | Where-Object { $_ -match [regex]::Escape($inputFont) -or $inputFont -match [regex]::Escape($_) }; if ($matches) { Write-Output ('GUESS:' + $matches[0]) } else { Write-Output 'NONE' } }"') do set "FONT_CHECK_RESULT=%%i"

if "!FONT_CHECK_RESULT!"=="EXACT" (
    set "FONT_NAME=!CUSTOM_FONT!"
    set "FONT_DESC=!CUSTOM_FONT!"
    goto apply_font
)

if "!FONT_CHECK_RESULT:~0,6!"=="GUESS:" (
    set "GUESS_FONT=!FONT_CHECK_RESULT:~6!"
    color 0E
    echo [警告] 找不到完全相符的字體「!CUSTOM_FONT!」。
    set /p USE_GUESS="您是指「!GUESS_FONT!」嗎？ (Y/N): "
    color 0A
    if /i "!USE_GUESS!"=="Y" (
        set "FONT_NAME=!GUESS_FONT!"
        set "FONT_DESC=!GUESS_FONT!"
        goto apply_font
    ) else (
        echo 請重新輸入字體名稱。
        goto custom_font
    )
)

color 0C
echo [錯誤] 系統字體庫中找不到任何與「!CUSTOM_FONT!」相關的字體。
echo 請確認拼字是否正確，或是字體是否有正確安裝到 Windows。
color 0A
echo.
goto custom_font

:apply_font
echo.
echo [進度] 正在設定字型為「%FONT_DESC%」...
if exist "%CONFIG_FILE%" (
    :: 使用 PowerShell 取代 Config.tjs 中的字型設定，並取消註解 (移除開頭的分號)
    powershell -Command "(Get-Content '%CONFIG_FILE%' -Encoding UTF8) -replace '^\s*;?\s*userFace\s*=.*', 'userFace=\"%FONT_NAME%\"' | Set-Content '%CONFIG_FILE%' -Encoding UTF8"
    if errorlevel 1 (
        color 0E
        echo [警告] 字型設定修改失敗，中文字可能顯示為方塊。
        echo 若發生此情況，請參閱 README.md 手動設定字型。
    ) else (
        echo [成功] 字型已設定為「%FONT_DESC%」。
    )
) else (
    color 0E
    echo [警告] 找不到 Config.tjs，無法自動設定字型。但這不影響劇情翻譯。
)

echo.
echo ========================================================
echo   安裝完成！您可以直接啟動遊戲了。
echo   如果想要還原，請將 scenario_backup 的內容覆蓋回 scenario 即可。
echo ========================================================
echo.
pause
