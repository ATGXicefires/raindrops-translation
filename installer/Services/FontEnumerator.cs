using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Media;

namespace RaindropsInstaller.Services
{
    public static class FontEnumerator
    {
        public static List<string> GetInstalledFonts()
        {
            return Fonts.SystemFontFamilies
                .Select(f => f.Source)
                .OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }

        public static bool FontExists(string name, List<string> fonts)
        {
            return fonts.Any(f => f.Equals(name, StringComparison.OrdinalIgnoreCase));
        }

        public static string FindClosestMatch(string query, List<string> fonts)
        {
            return fonts.FirstOrDefault(f =>
                f.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0 ||
                query.IndexOf(f, StringComparison.OrdinalIgnoreCase) >= 0);
        }
    }
}
