using System;
using System.IO;
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

        public void Install(string gameRoot, string patchDir, FontSetting font)
        {
            var targetDir = Path.Combine(gameRoot, @"resources\app\data\scenario");
            var backupDir = Path.Combine(gameRoot, @"resources\app\data\scenario_backup");
            var configFile = Path.Combine(gameRoot, @"resources\app\data\system\Config.tjs");

            CreateBackup(targetDir, backupDir, gameRoot, configFile);
            CopyPatchFiles(patchDir, targetDir);
            InjectFontCss(gameRoot);
            UpdateConfigTjs(configFile, font);
            ClearElectronCache();

            Log("", "info");
            Log("安裝完成！您可以直接啟動遊戲了。", "success");
            Log("如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario 即可。", "info");
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
            var replacement = $"userFace=\"{font.Name}\";";
            var pattern = new Regex(@"^\s*;?\s*userFace\s*=.*");

            for (int i = 0; i < lines.Length; i++)
            {
                if (pattern.IsMatch(lines[i]))
                    lines[i] = replacement;
            }

            File.WriteAllLines(configFile, lines, Encoding.UTF8);
            Log($"字型已設定為「{font.Description}」。", "success");
        }

        private void ClearElectronCache()
        {
            var cacheDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "tyranogame");

            if (!Directory.Exists(cacheDir))
            {
                Log("未偵測到 Electron 快取，跳過。", "info");
                return;
            }

            Log("正在清除 Electron 快取（避免首次啟動失敗）...", "info");
            try
            {
                Directory.Delete(cacheDir, true);
                Log("Electron 快取已清除。", "success");
            }
            catch (Exception ex)
            {
                Log($"快取清除失敗（遊戲可能正在執行）：{ex.Message}", "warn");
                Log("如首次啟動異常，請關閉遊戲後重新啟動即可。", "warn");
            }
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
