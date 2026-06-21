# 二万分の一の雨粒達 — 繁體中文翻譯補丁

為視覺小說《**二万分の一の雨粒達 — One in 20,000 raindrops**》製作的非官方繁體中文翻譯補丁。

> **請支持正版！** 作者目前處於失業狀態，遊戲售價非常便宜，劇情也很棒。購買正版是對作者最好的支持。
>
> Steam 商店頁面：https://store.steampowered.com/app/4800570/__One_in_20000_raindrops/
>
> 作者官網：https://syato-sombrero.tumblr.com

本補丁為推廣目的製作，翻譯使用 Claude Opus 4.6 完成。目前僅經過簡單測試，後續會進行額外潤色。

## 翻譯進度

| 場景 | 進度 | 狀態 |
|------|------|------|
| scene1 | 1271 / 1271 | ✅ 完成 |
| scene2 | 1017 / 1017 | ✅ 完成 |
| scene3 | 604 / 604 | ✅ 完成 |
| scene4 | 889 / 889 | ✅ 完成 |
| scene5 | 624 / 624 | ✅ 完成 |
| scene6 | 325 / 325 | ✅ 完成 |
| _preview | 323 / 895 | 🔄 部分完成 |
| **合計** | **5053 / 5625** | **89.8%** |

正篇（scene1–scene6）已全部翻譯完成。`_preview` 是試玩預覽腳本，與正篇內容重疊，優先度較低。

## 安裝方式

我們提供了一鍵安裝腳本，讓安裝過程變得非常簡單！不再需要手動找遊戲資料夾。

### 1. 下載並解壓縮
下載本補丁的壓縮檔，並將其解壓縮到您電腦上的任何地方（桌面、下載資料夾皆可）。
資料夾內應包含 `patched` 資料夾、`install.bat` 與 `install.ps1`。

### 2. 執行安裝
雙擊執行 `install.bat`。
腳本會**自動在您的電腦中尋找遊戲的安裝位置**（支援 Steam 版自動偵測）。
如果自動尋找失敗，腳本會提示您手動將遊戲資料夾拖曳進視窗。

### 3. 字型設定
腳本會自動完成備份與劇本安裝，接著會提示您選擇想要的遊戲顯示字型（推薦選擇 `1` 微軟正黑體）。

看到「安裝完成！」提示後，即可關閉視窗，正常啟動遊戲享受繁體中文！

### 還原方法
安裝腳本會自動在 `resources\app\data\` 下建立 `scenario_backup`。
若要還原日文原版，只需將 `scenario_backup` 內的檔案覆蓋回 `scenario` 資料夾，或透過 Steam「驗證遊戲檔案完整性」即可還原。

## 倉庫結構

```
jp/              翻譯工作表（JSON），每個 .ks 劇本一個
patched/         產生的補丁檔（已翻譯的 .ks 劇本）← 安裝時用這個
_glossary.md     角色名與專有名詞對照表
install.bat      一鍵安裝啟動器
install.ps1      實際安裝流程腳本
tools/
  extract.py     從遊戲 .ks 抽取日文到 JSON 工作表
  reinject.py    將 JSON 中的翻譯回填成 .ks 補丁
```

## 已知問題

- `_preview.ks`（試玩預覽）尚未完全翻譯，未翻譯的部分會保留日文原文
- AI 翻譯可能存在語意不精確之處，後續會進行人工潤色

## Steam Overlay / 截圖無法使用

本遊戲使用 Electron 引擎，Steam Overlay（Shift+Tab）和 Steam 截圖（F12）預設無法正常運作。這是因為 Electron 的 Chromium 渲染管線與 Steam Overlay 的 DirectX/OpenGL hook 不相容。

**修正方法：** 編輯遊戲目錄下的 `resources\app\main.js`，在檔案開頭的 `const app = electron.app;` 之後加上一行：

```js
app.commandLine.appendSwitch('in-process-gpu');
```

儲存後重新啟動遊戲即可。注意 Steam 更新遊戲時可能會覆蓋此修改，需要重新加上。

## 授權

本補丁為非官方粉絲翻譯，僅供推廣用途。遊戲所有權利歸原作者所有。
