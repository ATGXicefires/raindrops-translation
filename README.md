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

### 1. 下載補丁

下載本倉庫的 `patched/` 資料夾中的所有 `.ks` 檔案。

### 2. 備份遊戲原檔

備份遊戲目錄下的劇本資料夾：

```
<Steam遊戲目錄>\二万分の一の雨粒達 - One in 20,000 raindrops\resources\app\data\scenario
```

建議將整個 `scenario` 資料夾複製一份（例如改名為 `scenario_backup`）。

### 3. 覆蓋劇本檔

將 `patched/` 中的 `.ks` 檔案複製到上述 `scenario` 資料夾中，覆蓋同名檔案。

### 4. 啟動遊戲

正常啟動遊戲即可看到中文。

### 5. 修復字型（若中文顯示為方框）

遊戲內建的日文字型不包含所有繁體中文字，可能導致部分文字顯示為方框。解決方式如下：

1. 複製一個繁體中文字型到遊戲資料夾，例如：

   ```
   C:\Windows\Fonts\NotoSerifTC-VF.ttf
   → resources\app\data\others\NotoSerifTC-VF.ttf
   ```

2. 在 `resources\app\tyrano\css\font.css` **最前面**新增：

   ```css
   @font-face {
     font-family: 'RaindropsTC';
     src: url('../../data/others/NotoSerifTC-VF.ttf') format('truetype');
     font-weight: 400;
     font-style: normal;
   }
   ```

3. 在 `resources\app\data\system\Config.tjs` 中將：

   ```
   ;userFace=dejima-mincho-r227
   ```

   改為：

   ```
   ;userFace=RaindropsTC
   ```

4. 重新啟動遊戲。

### 還原方法

將備份的 `scenario_backup` 內容覆蓋回 `scenario` 資料夾，或透過 Steam 驗證遊戲檔案完整性即可還原。

## 倉庫結構

```
jp/              翻譯工作表（JSON），每個 .ks 劇本一個
patched/         產生的補丁檔（已翻譯的 .ks 劇本）← 安裝時用這個
_glossary.md     角色名與專有名詞對照表
tools/
  extract.py     從遊戲 .ks 抽取日文到 JSON 工作表
  reinject.py    將 JSON 中的翻譯回填成 .ks 補丁
```

## 已知問題

- `_preview.ks`（試玩預覽）尚未完全翻譯，未翻譯的部分會保留日文原文
- AI 翻譯可能存在語意不精確之處，後續會進行人工潤色

## 授權

本補丁為非官方粉絲翻譯，僅供推廣用途。遊戲所有權利歸原作者所有。
