using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace RaindropsInstaller.Services
{
    public class FontSetting
    {
        public string Name { get; set; }
        public string Description { get; set; }
    }

    public class PatchInstaller
    {
        public event Action<string, string> LogMessage;

        public void Install(string gameRoot, string patchDir, FontSetting font, bool patchSteamOverlay)
        {
            var targetDir = Path.Combine(gameRoot, @"resources\app\data\scenario");
            var backupDir = Path.Combine(gameRoot, @"resources\app\data\scenario_backup");
            var configFile = Path.Combine(gameRoot, @"resources\app\data\system\Config.tjs");

            BackupSaves(gameRoot);
            CreateBackup(targetDir, backupDir, gameRoot, configFile);
            CopyPatchFiles(patchDir, targetDir);
            InjectFontCss(gameRoot);
            UpdateConfigTjs(configFile, font);
            PatchThemeCss(gameRoot, font);
            if (patchSteamOverlay)
                PatchSteamOverlayMainJs(gameRoot);

            Log("", "info");
            Log("安裝完成！您可以直接啟動遊戲了。", "success");
            if (File.Exists(Path.Combine(gameRoot, "One_in_20000_raindrops_tyrano_data.sav")))
                Log("注意：已有存檔的字型會在下次存檔時自動更新。", "info");
            Log("如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario 即可。", "info");
        }

        private void BackupSaves(string gameRoot)
        {
            var saves = Directory.GetFiles(gameRoot, "*.sav");
            if (saves.Length == 0) return;

            var root = Path.Combine(gameRoot, "saves_backup");
            Directory.CreateDirectory(root);

            // 與最近一次的快照比對，內容相同就不重複備份
            var newest = new DirectoryInfo(root).GetDirectories()
                .OrderBy(d => d.Name, StringComparer.Ordinal).LastOrDefault();
            if (newest != null && SaveSetIdentical(saves, newest.FullName))
            {
                Log("遊戲存檔與最近一次備份相同，跳過。", "info");
                return;
            }

            // 每次都把「目前的」存檔另存成有時間戳的新快照，不覆蓋舊備份
            var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            var dest = Path.Combine(root, stamp);
            int i = 1;
            while (Directory.Exists(dest)) { dest = Path.Combine(root, $"{stamp}-{i}"); i++; }
            Directory.CreateDirectory(dest);
            Log($"發現遊戲存檔，正在備份目前進度至 saves_backup\\{Path.GetFileName(dest)} ...", "info");

            foreach (var sav in saves)
            {
                File.Copy(sav, Path.Combine(dest, Path.GetFileName(sav)), false);
                Log($"已備份存檔：{Path.GetFileName(sav)}", "success");
            }
        }

        private bool SaveSetIdentical(string[] saves, string snapshotDir)
        {
            var snapSaves = Directory.GetFiles(snapshotDir, "*.sav");
            if (snapSaves.Length != saves.Length) return false;

            foreach (var sav in saves)
            {
                var snap = Path.Combine(snapshotDir, Path.GetFileName(sav));
                if (!File.Exists(snap)) return false;
                if (!FileHash(sav).Equals(FileHash(snap), StringComparison.Ordinal)) return false;
            }
            return true;
        }

        private string FileHash(string path)
        {
            using (var sha = SHA256.Create())
            using (var fs = File.OpenRead(path))
                return BitConverter.ToString(sha.ComputeHash(fs));
        }

        private void CreateBackup(string targetDir, string backupDir, string gameRoot, string configFile)
        {
            Log("正在檢查備份...", "info");
            if (Directory.Exists(backupDir))
            {
                Log("備份資料夾已存在，跳過備份步驟。", "info");
                return;
            }

            Log("建立原始劇本備份 scenario_backup ...", "info");
            CopyDirectory(targetDir, backupDir);

            var fontCssSrc = Path.Combine(gameRoot, @"resources\app\tyrano\css\font.css");
            if (File.Exists(fontCssSrc))
                File.Copy(fontCssSrc, Path.Combine(backupDir, "font.css.bak"), true);

            if (File.Exists(configFile))
                File.Copy(configFile, Path.Combine(backupDir, "Config.tjs.bak"), true);

            var tyranoCssSrc = Path.Combine(gameRoot, @"resources\app\tyrano\tyrano.css");
            if (File.Exists(tyranoCssSrc))
                File.Copy(tyranoCssSrc, Path.Combine(backupDir, "tyrano.tyrano.css.bak"), true);

            var themeCssSrc = Path.Combine(gameRoot, @"resources\app\data\others\plugin\theme_kopanda_24_FHD\tyrano.css");
            if (File.Exists(themeCssSrc))
                File.Copy(themeCssSrc, Path.Combine(backupDir, "theme.tyrano.css.bak"), true);

            var mainJsSrc = Path.Combine(gameRoot, @"resources\app\main.js");
            if (File.Exists(mainJsSrc))
                File.Copy(mainJsSrc, Path.Combine(backupDir, "main.js.bak"), true);

            Log("備份完成。", "success");
        }

        private void CopyPatchFiles(string patchDir, string targetDir)
        {
            var files = Directory.GetFiles(patchDir, "*.ks");
            Log($"正在安裝中文劇本（{files.Length} 個檔案）...", "info");

            foreach (var file in files)
            {
                var dest = Path.Combine(targetDir, Path.GetFileName(file));
                File.Copy(file, dest, true);
            }

            Log("中文劇本覆蓋完成。", "success");
        }

        private void InjectFontCss(string gameRoot)
        {
            var fontCss = Path.Combine(gameRoot, @"resources\app\tyrano\css\font.css");
            if (!File.Exists(fontCss))
            {
                Log("找不到 font.css，無法載入內建字型。", "warn");
                return;
            }

            var content = File.ReadAllText(fontCss, Encoding.UTF8);
            if (content.Contains("NotoSerifTC"))
            {
                Log("思源宋體字型已載入，跳過。", "info");
                return;
            }

            Log("正在載入思源宋體字型（NotoSerifTC）...", "info");
            var fontFace = " @font-face { font-family: 'NotoSerifTC'; " +
                "src: url('../../data/others/NotoSerifTC-VF.ttf') format('truetype'); " +
                "font-weight:normal;font-style:normal; }";
            content = content.TrimEnd() + "\n" + fontFace + "\n";
            File.WriteAllText(fontCss, content, Encoding.UTF8);
            Log("思源宋體已載入。", "success");
        }

        private void UpdateConfigTjs(string configFile, FontSetting font)
        {
            Log($"正在設定字型為「{font.Description}」...", "info");
            if (!File.Exists(configFile))
            {
                Log("找不到 Config.tjs，無法自動設定字型；劇本補丁仍已安裝。", "warn");
                return;
            }

            var lines = File.ReadAllLines(configFile, Encoding.UTF8);
            var replacement = $";userFace={font.Name}";
            var pattern = new Regex(@"^\s*;?\s*userFace\s*=.*");

            for (int i = 0; i < lines.Length; i++)
            {
                if (pattern.IsMatch(lines[i]))
                    lines[i] = replacement;
            }

            File.WriteAllLines(configFile, lines, Encoding.UTF8);
            Log($"字型已設定為「{font.Description}」。", "success");
        }

        private void PatchThemeCss(string gameRoot, FontSetting font)
        {
            var cssFiles = new[]
            {
                Path.Combine(gameRoot, @"resources\app\tyrano\tyrano.css"),
                Path.Combine(gameRoot, @"resources\app\data\others\plugin\theme_kopanda_24_FHD\tyrano.css"),
            };

            var fontFamily = font.Name;
            var pattern = new Regex(@"font-family\s*:[^;]+;", RegexOptions.Singleline);

            foreach (var cssFile in cssFiles)
            {
                if (!File.Exists(cssFile)) continue;

                Log($"正在修正字型：{Path.GetFileName(Path.GetDirectoryName(cssFile))}\\tyrano.css ...", "info");
                var content = File.ReadAllText(cssFile, Encoding.UTF8);
                content = pattern.Replace(content, $"font-family: '{fontFamily}', sans-serif;");
                File.WriteAllText(cssFile, content, Encoding.UTF8);
            }

            Log("CSS 字型設定已全部更新。", "success");
        }

        private void PatchSteamOverlayMainJs(string gameRoot)
        {
            var mainJs = Path.Combine(gameRoot, @"resources\app\main.js");
            if (!File.Exists(mainJs))
            {
                Log("找不到 main.js，略過 Steam Overlay 修正。", "warn");
                return;
            }

            var content = File.ReadAllText(mainJs, Encoding.UTF8);
            if (content.Contains("in-process-gpu"))
            {
                Log("Steam Overlay 修正已套用過，略過。", "info");
                return;
            }

            var anchor = new Regex(@"^([ \t]*)const\s+app\s*=\s*electron\.app\s*;", RegexOptions.Multiline);
            var m = anchor.Match(content);
            if (!m.Success)
            {
                Log("main.js 格式與預期不符，未自動修改，請參考 README 手動處理。", "warn");
                return;
            }

            // 改檔前先補一份備份（使用者可能在備份資料夾已存在時才勾選此項）
            var backupMainJs = Path.Combine(gameRoot, @"resources\app\data\scenario_backup\main.js.bak");
            if (!File.Exists(backupMainJs))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(backupMainJs));
                File.Copy(mainJs, backupMainJs, false);
            }

            Log("正在套用 Steam Overlay／截圖修正（main.js）...", "info");
            var newline = content.Contains("\r\n") ? "\r\n" : "\n";
            var indent = m.Groups[1].Value;

            // 在錨點所在的整行（含換行）之後插入一行
            var lineEnd = content.IndexOf('\n', m.Index + m.Length);
            var insertAt = lineEnd < 0 ? content.Length : lineEnd + 1;
            var insertedLine = indent + "app.commandLine.appendSwitch('in-process-gpu');" + newline;
            content = content.Substring(0, insertAt) + insertedLine + content.Substring(insertAt);

            File.WriteAllText(mainJs, content, Encoding.UTF8);
            Log("Steam Overlay 修正已套用；若日後 Steam 更新遊戲被還原，需重新執行。", "success");
        }

        private void CopyDirectory(string source, string destination)
        {
            Directory.CreateDirectory(destination);
            foreach (var file in Directory.GetFiles(source))
                File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), true);
            foreach (var dir in Directory.GetDirectories(source))
                CopyDirectory(dir, Path.Combine(destination, Path.GetFileName(dir)));
        }

        private void Log(string message, string level)
        {
            LogMessage?.Invoke(message, level);
        }
    }
}
