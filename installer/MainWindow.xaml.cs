using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using RaindropsInstaller.Services;

namespace RaindropsInstaller
{
    public partial class MainWindow : Window
    {
        private readonly SteamDetector _steamDetector = new SteamDetector();
        private readonly PatchInstaller _patchInstaller = new PatchInstaller();
        private List<string> _allFonts;
        private bool _updatingFromList;
        private string _baseDir;
        private string _patchDir;

        public MainWindow()
        {
            InitializeComponent();
            _patchInstaller.LogMessage += WriteLog;
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            _baseDir = FindBaseDirectory();
            _patchDir = Path.Combine(_baseDir, "zh_patched");

            if (!Directory.Exists(_patchDir) || Directory.GetFiles(_patchDir, "*.ks").Length == 0)
            {
                MessageBox.Show(
                    "找不到 zh_patched 資料夾或其中沒有 .ks 檔案。\n請確認您已經解壓縮「完整」的補丁檔案夾！",
                    "錯誤", MessageBoxButton.OK, MessageBoxImage.Error);
                Close();
                return;
            }

            LoadBanner();
            LoadFonts();
            AutoDetectGamePath();
        }

        private void LoadBanner()
        {
            var bannerPath = Path.Combine(_baseDir, "assets", "banner.jpg");
            if (!File.Exists(bannerPath)) return;

            try
            {
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.UriSource = new Uri(bannerPath, UriKind.Absolute);
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.EndInit();
                bitmap.Freeze();
                imgBanner.Source = bitmap;
            }
            catch { }
        }

        private void LoadFonts()
        {
            _allFonts = FontEnumerator.GetInstalledFonts();
            foreach (var font in _allFonts)
                lstFonts.Items.Add(font);
        }

        private void AutoDetectGamePath()
        {
            WriteLog("嘗試自動尋找 Steam 遊戲安裝目錄...", "info");
            var path = _steamDetector.AutoDetectGamePath();
            if (path != null)
            {
                txtGamePath.Text = path;
                SetPathStatus("✓ 已自動偵測到遊戲安裝目錄", "#66BB6A");
                WriteLog($"自動找到遊戲安裝於：{path}", "success");
            }
            else
            {
                SetPathStatus("請使用「瀏覽」按鈕選擇遊戲安裝資料夾", "#FFA726");
                WriteLog("無法自動偵測 Steam 遊戲目錄，請使用「瀏覽」按鈕手動選擇。", "warn");
            }
        }

        private void BtnBrowse_Click(object sender, RoutedEventArgs e)
        {
            var selected = FolderPicker.Show("請選擇遊戲「二万分の一の雨粒達」的安裝資料夾");
            if (selected == null) return;

            txtGamePath.Text = selected;
            if (_steamDetector.ValidateGamePath(selected))
            {
                SetPathStatus("✓ 路徑有效", "#66BB6A");
                WriteLog($"已選擇遊戲路徑：{selected}", "success");
            }
            else
            {
                SetPathStatus("✗ 該路徑不正確，找不到 resources\\app\\data\\scenario", "#EF5350");
                WriteLog($"選擇的路徑無效：{selected}", "error");
            }
        }

        private void RbFont4_Checked(object sender, RoutedEventArgs e)
        {
            pnlCustomFont.Visibility = Visibility.Visible;
            Height += 160;
        }

        private void RbFont4_Unchecked(object sender, RoutedEventArgs e)
        {
            pnlCustomFont.Visibility = Visibility.Collapsed;
            Height -= 160;
        }

        private void TxtCustomFont_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            if (_updatingFromList) return;
            var filter = txtCustomFont.Text.Trim();
            lstFonts.Items.Clear();
            foreach (var font in _allFonts)
            {
                if (string.IsNullOrEmpty(filter) ||
                    font.IndexOf(filter, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    lstFonts.Items.Add(font);
                }
            }
        }

        private void LstFonts_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            if (lstFonts.SelectedItem == null) return;
            _updatingFromList = true;
            txtCustomFont.Text = lstFonts.SelectedItem.ToString();
            txtCustomFont.CaretIndex = txtCustomFont.Text.Length;
            _updatingFromList = false;
        }

        private void BtnInstall_Click(object sender, RoutedEventArgs e)
        {
            var gamePath = txtGamePath.Text.Trim();
            if (!_steamDetector.ValidateGamePath(gamePath))
            {
                SetPathStatus("✗ 請先選擇有效的遊戲安裝路徑", "#EF5350");
                WriteLog("尚未選擇有效的遊戲路徑，無法安裝。", "error");
                return;
            }

            var font = GetFontSetting();
            if (font == null)
            {
                WriteLog("請選擇或輸入自訂字體名稱。", "error");
                return;
            }

            if (rbFont4.IsChecked == true)
            {
                if (!FontEnumerator.FontExists(font.Name, _allFonts))
                {
                    var match = FontEnumerator.FindClosestMatch(font.Name, _allFonts);
                    if (match != null)
                    {
                        var answer = MessageBox.Show(
                            $"找不到完全相符的字體「{font.Name}」。\n\n您是指「{match}」嗎？",
                            "字體確認", MessageBoxButton.YesNo, MessageBoxImage.Question);
                        if (answer == MessageBoxResult.Yes)
                            font = new FontSetting { Name = match, Description = match };
                        else
                        {
                            WriteLog("請重新選擇正確的字體。", "warn");
                            return;
                        }
                    }
                    else
                    {
                        MessageBox.Show(
                            $"系統字體庫中找不到任何與「{font.Name}」相關的字體。\n請確認拼字是否正確，或是該字體是否已安裝。",
                            "找不到字體", MessageBoxButton.OK, MessageBoxImage.Warning);
                        WriteLog($"找不到字體「{font.Name}」。", "error");
                        return;
                    }
                }
            }

            SetControlsEnabled(false);
            try
            {
                _patchInstaller.Install(gamePath, _patchDir, font, chkSteamOverlay.IsChecked == true);
                MessageBox.Show(
                    "安裝完成！您可以直接啟動遊戲了。\n\n如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario，\n或使用 Steam 的「驗證遊戲檔案完整性」功能。",
                    "安裝成功", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                WriteLog($"安裝過程中發生錯誤：{ex.Message}", "error");
                MessageBox.Show(
                    $"安裝過程中發生錯誤：\n{ex.Message}",
                    "錯誤", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                SetControlsEnabled(true);
            }
        }

        private FontSetting GetFontSetting()
        {
            if (rbFont1.IsChecked == true)
                return new FontSetting { Name = "NotoSerifTC, Microsoft JhengHei, sans-serif", Description = "思源宋體" };
            if (rbFont2.IsChecked == true)
                return new FontSetting { Name = "Microsoft JhengHei, 微軟正黑體, sans-serif", Description = "微軟正黑體" };
            if (rbFont3.IsChecked == true)
                return new FontSetting { Name = "DFKai-SB, 標楷體, serif", Description = "標楷體" };
            if (rbFont4.IsChecked == true)
            {
                var custom = txtCustomFont.Text.Trim();
                if (string.IsNullOrEmpty(custom)) return null;
                return new FontSetting { Name = custom, Description = custom };
            }
            return new FontSetting { Name = "Microsoft JhengHei, 微軟正黑體, sans-serif", Description = "微軟正黑體" };
        }

        private void SetControlsEnabled(bool enabled)
        {
            btnInstall.IsEnabled = enabled;
            btnBrowse.IsEnabled = enabled;
            rbFont1.IsEnabled = enabled;
            rbFont2.IsEnabled = enabled;
            rbFont3.IsEnabled = enabled;
            rbFont4.IsEnabled = enabled;
            txtCustomFont.IsEnabled = enabled;
            lstFonts.IsEnabled = enabled;
            chkSteamOverlay.IsEnabled = enabled;
        }

        private void WriteLog(string message, string level)
        {
            var prefix = "";
            switch (level)
            {
                case "success": prefix = "[成功] "; break;
                case "warn": prefix = "[警告] "; break;
                case "error": prefix = "[錯誤] "; break;
                default: prefix = "[進度] "; break;
            }

            if (string.IsNullOrEmpty(message))
            {
                txtLog.AppendText("\r\n");
            }
            else if (txtLog.Text.Length > 0)
            {
                txtLog.AppendText($"\r\n{prefix}{message}");
            }
            else
            {
                txtLog.AppendText($"{prefix}{message}");
            }
            txtLog.ScrollToEnd();
            Dispatcher.Invoke(DispatcherPriority.Render, new Action(() => { }));
        }

        private void SetPathStatus(string text, string color)
        {
            lblPathStatus.Text = text;
            lblPathStatus.Foreground = new System.Windows.Media.SolidColorBrush(
                (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(color));
        }

        private string FindBaseDirectory()
        {
            var exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            if (Directory.Exists(Path.Combine(exeDir, "zh_patched")))
                return exeDir;

            var parent = Directory.GetParent(exeDir);
            while (parent != null)
            {
                if (Directory.Exists(Path.Combine(parent.FullName, "zh_patched")))
                    return parent.FullName;
                parent = parent.Parent;
            }
            return exeDir;
        }
    }
}
