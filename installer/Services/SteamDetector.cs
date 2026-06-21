using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace RaindropsInstaller.Services
{
    public class SteamDetector
    {
        private const string GameFolder = "二万分の一の雨粒達 - One in 20,000 raindrops";
        private const string ValidationSubPath = @"resources\app\data\scenario";

        public bool ValidateGamePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return false;
            return Directory.Exists(Path.Combine(path, ValidationSubPath));
        }

        public string AutoDetectGamePath()
        {
            var libs = GetSteamLibraryPaths();
            foreach (var lib in libs)
            {
                var candidate = Path.Combine(lib, "steamapps", "common", GameFolder);
                if (ValidateGamePath(candidate))
                    return candidate;
            }
            return null;
        }

        private List<string> GetSteamLibraryPaths()
        {
            var paths = new List<string>();
            var registryKeys = new[]
            {
                @"SOFTWARE\WOW6432Node\Valve\Steam",
                @"SOFTWARE\Valve\Steam"
            };

            foreach (var keyPath in registryKeys)
            {
                TryAddSteamPath(Registry.LocalMachine, keyPath, paths);
            }
            TryAddSteamPath(Registry.CurrentUser, @"SOFTWARE\Valve\Steam", paths);

            foreach (var steamPath in new List<string>(paths))
            {
                var vdf = Path.Combine(steamPath, "steamapps", "libraryfolders.vdf");
                if (!File.Exists(vdf)) continue;

                try
                {
                    var lines = File.ReadAllLines(vdf);
                    foreach (var line in lines)
                    {
                        var match = Regex.Match(line, @"""path""\s+""([^""]+)""");
                        if (match.Success)
                        {
                            var libraryPath = match.Groups[1].Value
                                .Replace(@"\\", @"\")
                                .TrimEnd('\\');
                            if (Directory.Exists(libraryPath) && !paths.Contains(libraryPath))
                                paths.Add(libraryPath);
                        }
                    }
                }
                catch { }
            }

            return paths;
        }

        private void TryAddSteamPath(RegistryKey root, string keyPath, List<string> paths)
        {
            try
            {
                using (var key = root.OpenSubKey(keyPath))
                {
                    if (key == null) return;
                    var installPath = key.GetValue("InstallPath") as string;
                    if (!string.IsNullOrEmpty(installPath))
                    {
                        installPath = installPath.TrimEnd('\\');
                        if (Directory.Exists(installPath) && !paths.Contains(installPath))
                            paths.Add(installPath);
                    }
                }
            }
            catch { }
        }
    }
}
