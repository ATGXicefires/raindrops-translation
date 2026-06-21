$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$patchDir = Join-Path $scriptDir "patched"
if (-not (Test-Path $patchDir)) {
    [System.Windows.MessageBox]::Show(
        "找不到 patched 資料夾。`n請確認您已經解壓縮「完整」的補丁檔案夾！",
        "錯誤", "OK", "Error") | Out-Null
    exit 1
}
$patchFiles = @(Get-ChildItem -LiteralPath $patchDir -Filter "*.ks" -ErrorAction SilentlyContinue)
if ($patchFiles.Count -eq 0) {
    [System.Windows.MessageBox]::Show(
        "patched 資料夾內找不到任何 .ks 劇本檔案。",
        "錯誤", "OK", "Error") | Out-Null
    exit 1
}

# ── Load system fonts ────────────────────────────────────────────────────────

$fontCollection = New-Object System.Drawing.Text.InstalledFontCollection
$script:allFonts = @()
foreach ($f in $fontCollection.Families) { $script:allFonts += $f.Name }

# ── Banner ───────────────────────────────────────────────────────────────────

$bannerPath = Join-Path $scriptDir "assets\banner.jpg"
$bannerBase64 = ""
if (Test-Path $bannerPath) {
    $bannerBytes = [System.IO.File]::ReadAllBytes($bannerPath)
    $bannerBase64 = [System.Convert]::ToBase64String($bannerBytes)
}

# ── XAML ─────────────────────────────────────────────────────────────────────

$xamlString = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="二万分の一の雨粒達 — 繁體中文翻譯補丁安裝"
    Width="620" Height="680"
    WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize"
    Background="#1B2838"
    FontFamily="Microsoft JhengHei, Segoe UI"
    FontSize="13">

    <Window.Resources>
        <Style x:Key="InstallButton" TargetType="Button">
            <Setter Property="Background" Value="#67C1F5"/>
            <Setter Property="Foreground" Value="#1B2838"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Height" Value="44"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="20,8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#8AD4FF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#4FB3E8"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#3D5A80"/>
                                <Setter Property="Foreground" Value="#8F98A0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BrowseButton" TargetType="Button">
            <Setter Property="Background" Value="#2A475E"/>
            <Setter Property="Foreground" Value="#C6D4DF"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="4" Padding="14,6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3D5A80"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1E3448"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="GroupBox">
            <Setter Property="BorderBrush" Value="#2A475E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Foreground" Value="#67C1F5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,8,10,8"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E2D3D"/>
            <Setter Property="Foreground" Value="#E0E8F0"/>
            <Setter Property="BorderBrush" Value="#3D5A80"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CaretBrush" Value="#E0E8F0"/>
            <Setter Property="SelectionBrush" Value="#67C1F5"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="FontWeight" Value="Normal"/>
        </Style>

        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="#E0E8F0"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Setter Property="Margin" Value="0,0,18,0"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Banner -->
        <Grid Grid.Row="0">
            <Image x:Name="imgBanner" Height="150" Stretch="UniformToFill"
                   VerticalAlignment="Top" HorizontalAlignment="Center"/>
            <Border Background="#1B2838" Opacity="0.45" Height="150"/>
            <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                <TextBlock Text="二万分の一の雨粒達" FontSize="22" FontWeight="Bold"
                           Foreground="White" HorizontalAlignment="Center">
                    <TextBlock.Effect>
                        <DropShadowEffect ShadowDepth="2" BlurRadius="8" Color="Black" Opacity="0.7"/>
                    </TextBlock.Effect>
                </TextBlock>
                <TextBlock Text="繁體中文翻譯補丁安裝程式" FontSize="13"
                           Foreground="#B0C4DE" HorizontalAlignment="Center" Margin="0,3,0,0">
                    <TextBlock.Effect>
                        <DropShadowEffect ShadowDepth="1" BlurRadius="5" Color="Black" Opacity="0.6"/>
                    </TextBlock.Effect>
                </TextBlock>
            </StackPanel>
        </Grid>

        <!-- Content -->
        <Grid Grid.Row="1" Margin="20,14,20,16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- Game Path -->
            <GroupBox Grid.Row="0" Header="遊戲安裝路徑">
                <StackPanel>
                    <DockPanel>
                        <Button x:Name="btnBrowse" Content="瀏覽..." DockPanel.Dock="Right"
                                Style="{StaticResource BrowseButton}" Margin="8,0,0,0"/>
                        <TextBox x:Name="txtGamePath" IsReadOnly="True"
                                 FontSize="12" VerticalContentAlignment="Center" Height="30"/>
                    </DockPanel>
                    <TextBlock x:Name="lblPathStatus" FontWeight="Normal" FontSize="11.5"
                               Margin="0,6,0,0" TextWrapping="Wrap"/>
                </StackPanel>
            </GroupBox>

            <!-- Font Selection -->
            <GroupBox Grid.Row="1" Header="遊戲顯示字型">
                <StackPanel>
                    <WrapPanel Margin="0,0,0,4">
                        <RadioButton x:Name="rbFont1" Content="思源宋體（推薦）" GroupName="font" IsChecked="True"/>
                        <RadioButton x:Name="rbFont2" Content="微軟正黑體" GroupName="font"/>
                        <RadioButton x:Name="rbFont3" Content="標楷體" GroupName="font"/>
                        <RadioButton x:Name="rbFont4" Content="自訂" GroupName="font"/>
                    </WrapPanel>
                    <StackPanel x:Name="pnlCustomFont" Visibility="Collapsed">
                        <TextBox x:Name="txtCustomFont" FontSize="12"
                                 Height="28" Margin="0,4,0,0"
                                 VerticalContentAlignment="Center"/>
                        <TextBlock FontWeight="Normal" FontSize="10.5"
                                   Foreground="#6B7B8D" Margin="0,2,0,4"
                                   Text="輸入關鍵字搜尋，或從下方列表點選"/>
                        <ListBox x:Name="lstFonts" Height="110"
                                 Background="#0F1923" Foreground="#E0E8F0"
                                 BorderBrush="#3D5A80" BorderThickness="1"
                                 FontSize="12" FontWeight="Normal"
                                 ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                    </StackPanel>
                </StackPanel>
            </GroupBox>

            <!-- Install Button -->
            <Button x:Name="btnInstall" Grid.Row="2" Content="安 裝 翻 譯 補 丁"
                    Style="{StaticResource InstallButton}" Margin="0,4,0,12"/>

            <!-- Log -->
            <GroupBox Grid.Row="3" Header="安裝紀錄">
                <TextBox x:Name="txtLog" IsReadOnly="True" TextWrapping="Wrap"
                         FontFamily="Consolas, Microsoft JhengHei" FontSize="11.5"
                         Background="#0F1923" Foreground="#B8C7D6"
                         VerticalScrollBarVisibility="Auto" BorderThickness="0"/>
            </GroupBox>
        </Grid>
    </Grid>
</Window>
"@

[xml]$xaml = $xamlString
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$imgBanner     = $window.FindName("imgBanner")
$txtGamePath   = $window.FindName("txtGamePath")
$btnBrowse     = $window.FindName("btnBrowse")
$lblPathStatus = $window.FindName("lblPathStatus")
$rbFont1       = $window.FindName("rbFont1")
$rbFont2       = $window.FindName("rbFont2")
$rbFont3       = $window.FindName("rbFont3")
$rbFont4       = $window.FindName("rbFont4")
$pnlCustomFont = $window.FindName("pnlCustomFont")
$txtCustomFont = $window.FindName("txtCustomFont")
$lstFonts      = $window.FindName("lstFonts")
$btnInstall    = $window.FindName("btnInstall")
$txtLog        = $window.FindName("txtLog")

# Load banner image
if ($bannerBase64) {
    $bitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
    $stream = New-Object System.IO.MemoryStream(,[System.Convert]::FromBase64String($bannerBase64))
    $bitmapImage.BeginInit()
    $bitmapImage.StreamSource = $stream
    $bitmapImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmapImage.EndInit()
    $bitmapImage.Freeze()
    $imgBanner.Source = $bitmapImage
}

# Populate font list
foreach ($fontName in $script:allFonts) {
    $lstFonts.Items.Add($fontName) | Out-Null
}

# ── Helper ───────────────────────────────────────────────────────────────────

function Write-Log([string]$msg, [string]$level = "info") {
    $prefix = switch ($level) {
        "success" { "[成功] " }
        "warn"    { "[警告] " }
        "error"   { "[錯誤] " }
        default   { "[進度] " }
    }
    if ($txtLog.Text.Length -gt 0) {
        $txtLog.AppendText("`r`n$prefix$msg")
    } else {
        $txtLog.AppendText("$prefix$msg")
    }
    $txtLog.ScrollToEnd()
    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Set-PathStatus([string]$text, [string]$color) {
    $lblPathStatus.Text = $text
    $lblPathStatus.Foreground = $color
}

# ── Business Logic ───────────────────────────────────────────────────────────

function Get-SteamLibraryPaths {
    $paths = @()
    $registryKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\SOFTWARE\Valve\Steam"
    )
    foreach ($key in $registryKeys) {
        try {
            $prop = Get-ItemProperty -Path $key -Name "InstallPath" -ErrorAction Stop
            if ($prop -and $prop.InstallPath) {
                $steamPath = $prop.InstallPath.TrimEnd('\')
                if ((Test-Path $steamPath) -and ($paths -notcontains $steamPath)) {
                    $paths += $steamPath
                }
            }
        } catch {}
    }
    foreach ($steamPath in @($paths)) {
        $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
        if (-not (Test-Path $vdf)) { continue }
        foreach ($line in Get-Content -LiteralPath $vdf -Encoding UTF8) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $libraryPath = ($matches[1] -replace '\\\\', '\').TrimEnd('\')
                if ((Test-Path $libraryPath) -and ($paths -notcontains $libraryPath)) {
                    $paths += $libraryPath
                }
            }
        }
    }
    return $paths
}

function Find-GameRoot-Auto {
    $gameFolder = "二万分の一の雨粒達 - One in 20,000 raindrops"

    if (Test-Path "resources\app\data\scenario") {
        return (Get-Location).Path
    }

    Write-Log "嘗試自動尋找 Steam 遊戲安裝目錄..."
    $libs = Get-SteamLibraryPaths
    foreach ($libraryPath in $libs) {
        $candidate = Join-Path $libraryPath "steamapps\common\$gameFolder"
        if (Test-Path (Join-Path $candidate "resources\app\data\scenario")) {
            Write-Log "自動找到遊戲安裝於：$candidate" "success"
            return $candidate
        }
    }

    Write-Log "無法自動偵測 Steam 遊戲目錄，請使用「瀏覽」按鈕手動選擇。" "warn"
    return $null
}

function Test-GamePath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    return (Test-Path (Join-Path $path "resources\app\data\scenario"))
}

function Get-FontSetting {
    if ($rbFont1.IsChecked) {
        return @{ Name = "NotoSerifTC, Microsoft JhengHei, sans-serif"; Description = "思源宋體" }
    }
    if ($rbFont2.IsChecked) {
        return @{ Name = "Microsoft JhengHei, 微軟正黑體, sans-serif"; Description = "微軟正黑體" }
    }
    if ($rbFont3.IsChecked) {
        return @{ Name = "DFKai-SB, 標楷體, serif"; Description = "標楷體" }
    }
    if ($rbFont4.IsChecked) {
        $custom = $txtCustomFont.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($custom)) { return $null }
        return @{ Name = $custom; Description = $custom }
    }
    return @{ Name = "Microsoft JhengHei, 微軟正黑體, sans-serif"; Description = "微軟正黑體" }
}

function Install-Patch([string]$gameRoot, [hashtable]$font) {
    $targetDir  = Join-Path $gameRoot "resources\app\data\scenario"
    $backupDir  = Join-Path $gameRoot "resources\app\data\scenario_backup"
    $configFile = Join-Path $gameRoot "resources\app\data\system\Config.tjs"

    Write-Log "正在檢查備份..."
    if (-not (Test-Path $backupDir)) {
        Write-Log "建立原始劇本備份 scenario_backup ..."
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -Path "$targetDir\*" -Destination $backupDir -Recurse -Force
        # Also back up font.css and Config.tjs
        $fontCssSrc = Join-Path $gameRoot "resources\app\tyrano\css\font.css"
        if (Test-Path $fontCssSrc) {
            Copy-Item -LiteralPath $fontCssSrc -Destination (Join-Path $backupDir "font.css.bak") -Force
        }
        if (Test-Path $configFile) {
            Copy-Item -LiteralPath $configFile -Destination (Join-Path $backupDir "Config.tjs.bak") -Force
        }
        Write-Log "備份完成。" "success"
    } else {
        Write-Log "備份資料夾已存在，跳過備份步驟。"
    }

    Write-Log "正在安裝中文劇本（$($patchFiles.Count) 個檔案）..."
    foreach ($file in $patchFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination $targetDir -Force
    }
    Write-Log "中文劇本覆蓋完成。" "success"

    # Load NotoSerifTC via font.css
    $fontCss = Join-Path $gameRoot "resources\app\tyrano\css\font.css"
    if (Test-Path $fontCss) {
        $cssContent = [System.IO.File]::ReadAllText($fontCss, [System.Text.Encoding]::UTF8)
        if ($cssContent -notmatch 'NotoSerifTC') {
            Write-Log "正在載入思源宋體字型（NotoSerifTC）..."
            $notoFace = " @font-face { font-family: 'NotoSerifTC'; src: url('../../data/others/NotoSerifTC-VF.ttf') format('truetype'); font-weight:normal;font-style:normal; }"
            $cssContent = $cssContent.TrimEnd() + "`n" + $notoFace + "`n"
            [System.IO.File]::WriteAllText($fontCss, $cssContent, [System.Text.Encoding]::UTF8)
            Write-Log "思源宋體已載入。" "success"
        } else {
            Write-Log "思源宋體字型已載入，跳過。"
        }
    } else {
        Write-Log "找不到 font.css，無法載入內建字型。" "warn"
    }

    Write-Log "正在設定字型為「$($font.Description)」..."
    if (-not (Test-Path $configFile)) {
        Write-Log "找不到 Config.tjs，無法自動設定字型；劇本補丁仍已安裝。" "warn"
    } else {
        $replacement = 'userFace="' + $font.Name + '";'
        $content = Get-Content -LiteralPath $configFile -Encoding UTF8
        $updated = $content -replace '^\s*;?\s*userFace\s*=.*', $replacement
        Set-Content -LiteralPath $configFile -Value $updated -Encoding UTF8
        Write-Log "字型已設定為「$($font.Description)」。" "success"
    }

    Write-Log ""
    Write-Log "安裝完成！您可以直接啟動遊戲了。" "success"
    Write-Log "如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario 即可。"
}

# ── Events ───────────────────────────────────────────────────────────────────

$window.Add_Loaded({
    $result = Find-GameRoot-Auto
    if ($result) {
        $txtGamePath.Text = $result
        Set-PathStatus "✓ 已自動偵測到遊戲安裝目錄" "#66BB6A"
    } else {
        Set-PathStatus "請使用「瀏覽」按鈕選擇遊戲安裝資料夾" "#FFA726"
    }
})

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "請選擇遊戲「二万分の一の雨粒達」的安裝資料夾"
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = $dialog.SelectedPath
        if (Test-GamePath $selected) {
            $txtGamePath.Text = $selected
            Set-PathStatus "✓ 路徑有效" "#66BB6A"
            Write-Log "已選擇遊戲路徑：$selected" "success"
        } else {
            $txtGamePath.Text = $selected
            Set-PathStatus "✗ 該路徑不正確，找不到 resources\app\data\scenario" "#EF5350"
            Write-Log "選擇的路徑無效：$selected" "error"
        }
    }
})

# Font radio buttons
$rbFont4.Add_Checked({
    $pnlCustomFont.Visibility = "Visible"
})
$rbFont4.Add_Unchecked({
    $pnlCustomFont.Visibility = "Collapsed"
})

# Font search / filter
$script:updatingFromList = $false
$txtCustomFont.Add_TextChanged({
    if ($script:updatingFromList) { return }
    $filter = $txtCustomFont.Text.Trim()
    $lstFonts.Items.Clear()
    foreach ($fontName in $script:allFonts) {
        if ([string]::IsNullOrEmpty($filter) -or $fontName -like "*$filter*") {
            $lstFonts.Items.Add($fontName) | Out-Null
        }
    }
})

# Font list selection
$lstFonts.Add_SelectionChanged({
    if ($lstFonts.SelectedItem) {
        $script:updatingFromList = $true
        $txtCustomFont.Text = $lstFonts.SelectedItem.ToString()
        $txtCustomFont.CaretIndex = $txtCustomFont.Text.Length
        $script:updatingFromList = $false
    }
})

$btnInstall.Add_Click({
    $gamePath = $txtGamePath.Text.Trim()
    if (-not (Test-GamePath $gamePath)) {
        Set-PathStatus "✗ 請先選擇有效的遊戲安裝路徑" "#EF5350"
        Write-Log "尚未選擇有效的遊戲路徑，無法安裝。" "error"
        return
    }

    $font = Get-FontSetting
    if ($null -eq $font) {
        Write-Log "請選擇或輸入自訂字體名稱。" "error"
        return
    }

    if ($rbFont4.IsChecked) {
        if ($script:allFonts -notcontains $font.Name) {
            $matched = @($script:allFonts | Where-Object {
                $_ -like "*$($font.Name)*" -or $font.Name -like "*$_*"
            })
            if ($matched.Count -gt 0) {
                $answer = [System.Windows.MessageBox]::Show(
                    "找不到完全相符的字體「$($font.Name)」。`n`n您是指「$($matched[0])」嗎？",
                    "字體確認", "YesNo", "Question")
                if ($answer -eq "Yes") {
                    $font = @{ Name = $matched[0]; Description = $matched[0] }
                } else {
                    Write-Log "請重新選擇正確的字體。" "warn"
                    return
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "系統字體庫中找不到任何與「$($font.Name)」相關的字體。`n請確認拼字是否正確，或是該字體是否已安裝。",
                    "找不到字體", "OK", "Warning") | Out-Null
                Write-Log "找不到字體「$($font.Name)」。" "error"
                return
            }
        }
    }

    $btnInstall.IsEnabled = $false
    $btnBrowse.IsEnabled = $false
    $rbFont1.IsEnabled = $false
    $rbFont2.IsEnabled = $false
    $rbFont3.IsEnabled = $false
    $rbFont4.IsEnabled = $false
    $txtCustomFont.IsEnabled = $false
    $lstFonts.IsEnabled = $false

    try {
        Install-Patch -gameRoot $gamePath -font $font
        [System.Windows.MessageBox]::Show(
            "安裝完成！您可以直接啟動遊戲了。`n`n如需還原，請將 scenario_backup 內的檔案覆蓋回 scenario，`n或使用 Steam 的「驗證遊戲檔案完整性」功能。",
            "安裝成功", "OK", "Information") | Out-Null
    }
    catch {
        Write-Log "安裝過程中發生錯誤：$($_.Exception.Message)" "error"
        [System.Windows.MessageBox]::Show(
            "安裝過程中發生錯誤：`n$($_.Exception.Message)",
            "錯誤", "OK", "Error") | Out-Null
    }
    finally {
        $btnInstall.IsEnabled = $true
        $btnBrowse.IsEnabled = $true
        $rbFont1.IsEnabled = $true
        $rbFont2.IsEnabled = $true
        $rbFont3.IsEnabled = $true
        $rbFont4.IsEnabled = $true
        $txtCustomFont.IsEnabled = $true
        $lstFonts.IsEnabled = $true
    }
})

# ── Show ─────────────────────────────────────────────────────────────────────

$window.ShowDialog() | Out-Null
