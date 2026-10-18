# Video Preview Creator
# Creates one MP4 preview per video in <selected folder>\media\videos.
# Videos 30 seconds or shorter are converted in full to MP4. Longer videos get
# a 30-second preview avoiding the first and last 30 seconds whenever possible.
# Original files are never modified.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Give the PowerShell-hosted window its own Windows taskbar identity instead of the generic >_ PowerShell identity.
if (-not ('VPC.TaskbarIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VPC {
    public static class TaskbarIdentity {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
    }
}
'@
}
try { [void][VPC.TaskbarIdentity]::SetCurrentProcessExplicitAppUserModelID('Cutter81.VideoPreviewCreator.v1_1') } catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ClipDuration = 30
$script:LogWriter = $null
$script:IsRunning = $false
$script:VideoExtensions = @('.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm','.m4v','.mpg','.mpeg','.ts','.mts','.m2ts','.vob','.ogv','.3gp')

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Video Preview Creator v1.2'
$form.Size = New-Object System.Drawing.Size(800, 700)
$form.MinimumSize = New-Object System.Drawing.Size(740, 660)
$form.StartPosition = 'CenterScreen'
$form.ShowInTaskbar = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
# Use the actual Razor Blade .ico extracted by the launcher; no programmatic drawing.
$iconPath = Join-Path $PSScriptRoot 'VideoPreviewCreator-RazorBlade.ico'
if (Test-Path -LiteralPath $iconPath) {
    try {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
    } catch {
        # Leave the window usable if Windows cannot load the icon for any reason.
    }
}

$header = New-Object System.Windows.Forms.Label
$header.Text = 'Video Preview Creator'
$header.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$header.AutoSize = $true
$header.Location = New-Object System.Drawing.Point(18, 14)
$form.Controls.Add($header)

$subheader = New-Object System.Windows.Forms.Label
$subheader.Text = 'Random 30-second MP4 previews, with short videos preserved in full.'
$subheader.AutoSize = $false
$subheader.Size = New-Object System.Drawing.Size(740, 30)
$subheader.Location = New-Object System.Drawing.Point(20, 62)
$form.Controls.Add($subheader)

$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Text = 'Source folder:'
$folderLabel.AutoSize = $true
$folderLabel.Location = New-Object System.Drawing.Point(20, 108)
$form.Controls.Add($folderLabel)

$folderBox = New-Object System.Windows.Forms.TextBox
$folderBox.Location = New-Object System.Drawing.Point(20, 131)
$folderBox.Size = New-Object System.Drawing.Size(610, 26)
$folderBox.Anchor = 'Top,Left,Right'
$form.Controls.Add($folderBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(640, 129)
$browseButton.Size = New-Object System.Drawing.Size(120, 30)
$browseButton.Anchor = 'Top,Right'
$form.Controls.Add($browseButton)

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = 'Output: <source folder>\media\videos'
$outputLabel.AutoSize = $true
$outputLabel.Location = New-Object System.Drawing.Point(20, 175)
$form.Controls.Add($outputLabel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = 'Create Previews'
$startButton.Location = New-Object System.Drawing.Point(20, 213)
$startButton.Size = New-Object System.Drawing.Size(145, 34)
$form.Controls.Add($startButton)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(200, 219)
$progress.Size = New-Object System.Drawing.Size(540, 23)
$progress.Anchor = 'Top,Left,Right'
$progress.Minimum = 0
$progress.Value = 0
$form.Controls.Add($progress)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = 'Activity log'
$logLabel.AutoSize = $true
$logLabel.Location = New-Object System.Drawing.Point(20, 269)
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(20, 293)
$logBox.Size = New-Object System.Drawing.Size(700, 296)
$logBox.Anchor = 'Top,Left,Right'
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$logBox.ForeColor = [System.Drawing.Color]::Gainsboro
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$logBox.HideSelection = $false
$form.Controls.Add($logBox)

function Write-Activity {
    param([string]$Message, [System.Drawing.Color]$Color = [System.Drawing.Color]::Gainsboro)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    if ($script:LogWriter) {
        $script:LogWriter.WriteLine($line)
        $script:LogWriter.Flush()
    }
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.SelectionLength = 0
    $logBox.SelectionColor = $Color
    $logBox.AppendText($line + [Environment]::NewLine)
    $logBox.SelectionColor = $logBox.ForeColor
    $logBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Find-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-VideoDuration {
    param([string]$ProbePath, [string]$InputPath)
    $result = & $ProbePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $InputPath 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $parsed = 0.0
    $text = ($result | Select-Object -First 1).ToString().Trim()
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, $culture, [ref]$parsed)) { return $parsed }
    return $null
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the folder containing the videos to process.'
    $dialog.ShowNewFolderButton = $false
    if (Test-Path $folderBox.Text -PathType Container) { $dialog.SelectedPath = $folderBox.Text }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderBox.Text = $dialog.SelectedPath
        $outputLabel.Text = 'Output: ' + (Join-Path $dialog.SelectedPath 'media\videos')
    }
})

$startButton.Add_Click({
    if ($script:IsRunning) { return }
    $inputDir = $folderBox.Text.Trim()
    if (-not (Test-Path -LiteralPath $inputDir -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show('Choose a valid source folder first.', 'Video Preview Creator', 'OK', 'Warning') | Out-Null
        return
    }

    $ffmpeg = Find-Tool 'ffmpeg.exe'
    if (-not $ffmpeg) { $ffmpeg = Find-Tool 'ffmpeg' }
    $ffprobe = Find-Tool 'ffprobe.exe'
    if (-not $ffprobe) { $ffprobe = Find-Tool 'ffprobe' }
    if (-not $ffmpeg -or -not $ffprobe) {
        [System.Windows.Forms.MessageBox]::Show('FFmpeg and FFprobe must be installed and available on PATH. No files were processed.', 'Video Preview Creator', 'OK', 'Error') | Out-Null
        return
    }

    $outputDir = Join-Path $inputDir 'media\videos'
    $logPath = Join-Path $inputDir '000-VideoPeviewCreator.txt'
    try {
        New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction Stop | Out-Null
        $script:LogWriter = New-Object System.IO.StreamWriter($logPath, $true, (New-Object System.Text.UTF8Encoding($false)))
        $script:LogWriter.AutoFlush = $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not create the output folder or open the log file:`r`n$($_.Exception.Message)", 'Video Preview Creator', 'OK', 'Error') | Out-Null
        return
    }

    $script:IsRunning = $true
    $startButton.Enabled = $false
    $browseButton.Enabled = $false
    $folderBox.Enabled = $false
    try {
        Write-Activity '============================================================' ([System.Drawing.Color]::Silver)
        Write-Activity '             Video Preview Creator by Cutter81' ([System.Drawing.Color]::White)
        Write-Activity '============================================================' ([System.Drawing.Color]::Silver)
        Write-Activity "Source folder: $inputDir"
        Write-Activity "Output folder: $outputDir"
        Write-Activity "Activity log: $logPath"
        Write-Activity 'READY.' ([System.Drawing.Color]::LightGreen)

        $videos = @(Get-ChildItem -LiteralPath $inputDir -File -ErrorAction Stop | Where-Object { $script:VideoExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)
        if ($videos.Count -eq 0) {
            Write-Activity 'No supported video files found in the selected folder.' ([System.Drawing.Color]::Khaki)
            return
        }

        $progress.Value = 0
        $progress.Maximum = $videos.Count
        $successCount = 0
        $skipCount = 0
        $failCount = 0
        Write-Activity ("Found {0} video file(s)." -f $videos.Count) ([System.Drawing.Color]::White)

        for ($i = 0; $i -lt $videos.Count; $i++) {
            $video = $videos[$i]
            Write-Activity "Processing: $($video.Name)"
            $duration = Get-VideoDuration -ProbePath $ffprobe -InputPath $video.FullName
            if ($null -eq $duration -or $duration -le 0) {
                Write-Activity "SKIPPED — could not determine a valid duration: $($video.Name)" ([System.Drawing.Color]::Khaki)
                $skipCount++
                $progress.Value = $i + 1
                continue
            }

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($video.Name)
            $outputPath = Join-Path $outputDir ($baseName + '.mp4')
            if (Test-Path -LiteralPath $outputPath) {
                Write-Activity "SKIPPED — output already exists; not overwriting: $outputPath" ([System.Drawing.Color]::Khaki)
                $skipCount++
                $progress.Value = $i + 1
                continue
            }

            if ($duration -le $script:ClipDuration) {
                Write-Activity ("Video is {0:N2}s (30s or shorter); preserving the entire video as MP4." -f $duration)
                $ffArgs = @('-hide_banner','-loglevel','error','-i',$video.FullName,'-map','0:v:0','-map','0:a?','-sn','-dn','-c:v','libx264','-preset','veryfast','-crf','20','-c:a','aac','-b:a','192k','-movflags','+faststart','-n',$outputPath)
            } else {
                # Prefer a random clip entirely between the first and final 30 seconds.
                # This is possible only when the source is at least 90 seconds long.
                # For 30–90 second sources, use the centered 30 seconds as the fairest
                # fallback because avoiding both ends is mathematically impossible.
                if ($duration -ge ($script:ClipDuration * 3)) {
                    $minStart = $script:ClipDuration
                    $maxStart = [math]::Floor($duration - ($script:ClipDuration * 2))
                    $startSecond = Get-Random -Minimum ([int]$minStart) -Maximum ([int]$maxStart + 1)
                    Write-Activity ("Duration: {0:N2}s; random preview starts at {1}s, avoiding the first and final 30 seconds." -f $duration, $startSecond)
                } else {
                    $startSecond = [math]::Floor(($duration - $script:ClipDuration) / 2)
                    Write-Activity ("Duration: {0:N2}s; using the centered 30-second fallback at {1}s; avoiding both 30-second end zones is impossible for a video shorter than 90 seconds." -f $duration, $startSecond)
                }
                $ffArgs = @('-hide_banner','-loglevel','error','-ss',[string]$startSecond,'-i',$video.FullName,'-t','30','-map','0:v:0','-map','0:a?','-sn','-dn','-c:v','libx264','-preset','veryfast','-crf','20','-c:a','aac','-b:a','192k','-movflags','+faststart','-n',$outputPath)
            }

            $ffOutput = & $ffmpeg @ffArgs 2>&1
            $ffExit = $LASTEXITCODE
            if ($ffExit -eq 0 -and (Test-Path -LiteralPath $outputPath) -and (Get-Item -LiteralPath $outputPath).Length -gt 0) {
                Write-Activity "SUCCESS — created $outputPath" ([System.Drawing.Color]::LightGreen)
                $successCount++
            } else {
                if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue }
                $detail = ($ffOutput | Out-String).Trim()
                if (-not $detail) { $detail = "FFmpeg exited with code $ffExit." }
                Write-Activity "FAILED — $($video.Name): $detail" ([System.Drawing.Color]::Salmon)
                $failCount++
            }
            $progress.Value = $i + 1
        }

        Write-Activity '------------------------------------------------------------' ([System.Drawing.Color]::Silver)
        Write-Activity ("Finished. Created: {0} | Skipped: {1} | Failed: {2}" -f $successCount, $skipCount, $failCount) ([System.Drawing.Color]::White)
    } catch {
        Write-Activity "ERROR: $($_.Exception.Message)" ([System.Drawing.Color]::Salmon)
    } finally {
        if ($script:LogWriter) { $script:LogWriter.Flush(); $script:LogWriter.Dispose(); $script:LogWriter = $null }
        $script:IsRunning = $false
        $startButton.Enabled = $true
        $browseButton.Enabled = $true
        $folderBox.Enabled = $true
    }
})

$script:CursorVisible = $true
$script:CursorStarted = $false
$script:CursorPosition = -1
$script:CursorGlyph = [string][char]0x2588
$cursorTimer = New-Object System.Windows.Forms.Timer
$cursorTimer.Interval = 500
$cursorTimer.Add_Tick({
    if (-not $script:CursorStarted -and $script:CursorPosition -ge 0 -and $script:CursorPosition -lt $logBox.TextLength) {
        $logBox.Select($script:CursorPosition, 1)
        if ($script:CursorVisible) { $logBox.SelectedText = ' ' }
        else { $logBox.SelectedText = $script:CursorGlyph }
        $script:CursorVisible = -not $script:CursorVisible
        $logBox.Select($logBox.TextLength, 0)
    }
})
$form.Add_Shown({
    $logBox.Clear()
    $logBox.AppendText("============================================================`r`n")
    $logBox.AppendText("             Video Preview Creator v1.2 by Cutter81`r`n")
    $logBox.AppendText("============================================================`r`nREADY.`r`n")
    # Put the blinking block on its own line directly beneath READY.
    $logBox.AppendText($script:CursorGlyph)
    $script:CursorPosition = $logBox.TextLength - 1
    $script:CursorVisible = $true
    $logBox.Select($logBox.TextLength, 0)
    $logBox.ScrollToCaret()
    $cursorTimer.Start()
})
$startButton.Add_Click({ $script:CursorStarted = $true; $cursorTimer.Stop() })
$browseButton.Add_Click({ $script:CursorStarted = $true; $cursorTimer.Stop() })
$form.Add_FormClosed({ $cursorTimer.Stop(); $cursorTimer.Dispose(); if ($script:LogWriter) { $script:LogWriter.Dispose(); $script:LogWriter = $null } })
[void]$form.ShowDialog()
