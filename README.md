# 二万分の一の雨粒達 — 繁體中文翻譯補丁

為視覺小說《**二万分の一の雨粒達 — One in 20,000 raindrops**》製作的非官方繁體中文翻譯補丁。

> **請支持正版！** 作者目前處於失業狀態，遊戲售價非常便宜，劇情也很棒。購買正版是對作者最好的支持。
>
> Steam 商店頁面：https://store.steampowered.com/app/4800570/__One_in_20000_raindrops/
>
> 作者官網：https://syato-sombrero.tumblr.com

本補丁為推廣目的製作，翻譯使用 Claude Opus 4.6 完成。目前僅經過簡單測試，後續會進行額外潤色。

> **未來計畫：** 之後將對遊戲進行完整漢化，包含遊戲介面（選單、按鈕、系統文字等）的中文化，敬請期待。

## 翻譯進度

| 場景 | 翻譯進度 | 人工校對 |
|------|------|------|
| scene1 | 1271 / 1271 ✅ | ✅ 完成 |
| scene2 | 1017 / 1017 ✅ | 🔄 進行中 |
| scene3 | 604 / 604 ✅ | ⬚ 未開始 |
| scene4 | 889 / 889 ✅ | ⬚ 未開始 |
| scene5 | 624 / 624 ✅ | ⬚ 未開始 |
| scene6 | 325 / 325 ✅ | ⬚ 未開始 |
| _preview | 323 / 895 🔄 | ⬚ 未開始 |

正篇（scene1–scene6）已全部翻譯完成。`_preview` 是試玩預覽腳本，與正篇內容重疊，優先度較低。

## 安裝方式

提供圖形化一鍵安裝程式，不需要任何技術知識！

### 1. 下載並解壓縮
下載本補丁的壓縮檔，解壓縮到任何地方（桌面、下載資料夾皆可）。

### 2. 執行安裝程式
雙擊 **`RaindropsInstaller.exe`** 啟動安裝介面。

安裝程式會：
- **自動偵測** Steam 遊戲安裝位置（也可手動瀏覽選擇）
- 讓您選擇遊戲顯示字型（推薦「思源宋體」）
- 自動備份原始檔案、安裝翻譯補丁、設定字型

看到「安裝完成！」提示後，即可直接啟動遊戲享受繁體中文。

> **備用方案：** 若 exe 無法執行，可雙擊 `install.bat` 或 `install.vbs`（需要 PowerShell）。

### 還原方法
安裝程式會自動在遊戲目錄建立 `scenario_backup` 備份。
若要還原日文原版，將 `scenario_backup` 內的檔案覆蓋回 `scenario` 資料夾，或透過 Steam「驗證遊戲檔案完整性」即可。

## 倉庫結構

```
patched/                    補丁檔（已翻譯的 .ks 劇本）← 安裝時用這個
jp/                         翻譯工作表（JSON），每個 .ks 劇本一個
_glossary.md                角色名與專有名詞對照表
RaindropsInstaller.exe      圖形化安裝程式（C# WPF）
installer/                  安裝程式原始碼
install.bat / install.vbs   備用安裝啟動器（fallback）
install-gui.ps1             PowerShell GUI 安裝器（備用）
tools/
  extract.py                從遊戲 .ks 抽取日文到 JSON 工作表
  reinject.py               將 JSON 中的翻譯回填成 .ks 補丁
```

## 已知問題

- `_preview.ks`（試玩預覽）尚未完全翻譯，未翻譯的部分會保留日文原文
- AI 翻譯可能存在語意不精確之處，人工校對潤色進行中（詳見上方表格）

## Steam Overlay / 截圖無法使用

本遊戲使用 Electron 引擎，Steam Overlay（Shift+Tab）和 Steam 截圖（F12）預設無法正常運作。這是因為 Electron 的 Chromium 渲染管線與 Steam Overlay 的 DirectX/OpenGL hook 不相容。

**修正方法：** 編輯遊戲目錄下的 `resources\app\main.js`，在檔案開頭的 `const app = electron.app;` 之後加上一行：

```js
app.commandLine.appendSwitch('in-process-gpu');
```

儲存後重新啟動遊戲即可。注意 Steam 更新遊戲時可能會覆蓋此修改，需要重新加上。

## 授權

本補丁為非官方粉絲翻譯，僅供推廣用途。遊戲所有權利歸原作者所有。
