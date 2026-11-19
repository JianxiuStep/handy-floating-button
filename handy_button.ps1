param([switch]$Launch)

# Handy floating record button - pure Windows built-ins (PowerShell + WinForms).
# Left click : start Handy if needed, then toggle recording.
# Right click: toggle a small popup menu (autostart checkbox / exit).
# Button color follows Handy's REAL state from its log, never a guessed timer.
# UI strings use Unicode code points so the file has no encoding dependencies.

if ($Launch) {
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) | Out-Null
    exit 0
}

# --- Single-instance guard ----------------------------------------------------
$script:AppMutex = $null
$mutexCreated = $false
try {
    $script:AppMutex = New-Object System.Threading.Mutex($true, 'Local\HandyFloatingButton_Singleton', [ref]$mutexCreated)
} catch {
    $mutexCreated = $true
}
if (-not $mutexCreated) {
    if ($script:AppMutex) { $script:AppMutex.Dispose() }
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class HandyNative {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
'@

$console = [HandyNative]::GetConsoleWindow()
if ($console -ne [IntPtr]::Zero) { [HandyNative]::ShowWindow($console, 0) | Out-Null }

# --- Locate Handy -------------------------------------------------------------
function Find-HandyExe {
    if ($env:HANDY_EXE -and (Test-Path $env:HANDY_EXE)) { return $env:HANDY_EXE }
    $d = Split-Path -Parent $PSCommandPath
    foreach ($c in @((Join-Path $d 'app\handy.exe'), (Join-Path $d 'handy.exe'),
                     (Join-Path $env:LOCALAPPDATA 'Programs\Handy\handy.exe'),
                     (Join-Path $env:ProgramFiles 'Handy\handy.exe'))) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    $cmd = Get-Command handy -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}
function Find-HandyLog {
    if ($env:HANDY_LOG -and (Test-Path $env:HANDY_LOG)) { return $env:HANDY_LOG }
    $ed = Split-Path -Parent $script:EXE
    foreach ($c in @((Join-Path $ed 'Data\logs\handy.log'),
                     (Join-Path $env:APPDATA 'com.pais.handy\logs\handy.log'))) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}
$script:EXE = Find-HandyExe
if (-not $script:EXE) {
    [System.Windows.Forms.MessageBox]::Show('Handy.exe not found. Set HANDY_EXE.', 'Handy Button', 'OK', 'Warning') | Out-Null
    exit 1
}
$script:LOG = Find-HandyLog

# --- State + UI strings (Unicode code points) --------------------------------
$script:busy = $false; $script:pressAt = 0
$script:dragging = $false; $script:moved = $false
$script:down = New-Object System.Drawing.Point
$script:origin = New-Object System.Drawing.Point
$script:displayState = -1

$TEXT_IDLE = [string][char]0x5F55                                        # record
$TEXT_REC  = [string][char]0x505C                                        # stop
$TEXT_BUSY = [string][char]0x2026                                        # ...
$TEXT_TIP  = [string][char]0x5DE6+[string][char]0x952E+[string][char]0x5F55+[string][char]0x97F3+[string][char]0xFF0C+[string][char]0x53F3+[string][char]0x952E+[string][char]0x83DC+[string][char]0x5355
$TEXT_AUTO = [string][char]0x5F00+[string][char]0x673A+[string][char]0x81EA+[string][char]0x542F
$TEXT_EXIT = [string][char]0x9000+[string][char]0x51FA+[string][char]0xFF08+[string][char]0x540C+[string][char]0x65F6+[string][char]0x5173+[string][char]0x95ED+' Handy'+[string][char]0xFF09
$CHK_ON  = [string][char]0x2611
$CHK_OFF = [string][char]0x2610

$script:AutoStartCmd = Join-Path ([Environment]::GetFolderPath('Startup')) 'HandyButton.cmd'
$script:Launcher = Join-Path (Split-Path -Parent $PSCommandPath) 'Start Handy button.vbs'

# --- Main round button --------------------------------------------------------
$size = 74
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Handy Record Button'
$form.FormBorderStyle = 'None'; $form.TopMost = $true; $form.ShowInTaskbar = $false
$form.StartPosition = 'Manual'
$form.ClientSize = New-Object System.Drawing.Size($size, $size)
$form.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
$gp = New-Object System.Drawing.Drawing2D.GraphicsPath
$gp.AddEllipse(0, 0, $size, $size)
$form.Region = New-Object System.Drawing.Region($gp)
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($wa.Right - $size - 60), ($wa.Bottom - $size - 60))

$form.Add_Paint({
    $g = $_.Graphics
    if ($script:displayState -eq 1) { $txt = $TEXT_REC }
    elseif ($script:displayState -eq 2) { $txt = $TEXT_BUSY }
    else { $txt = $TEXT_IDLE }
    $f = New-Object System.Drawing.Font('Microsoft YaHei', 16, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($txt, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0,0,$size,$size)), $sf)
    $f.Dispose()
})
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($form, $TEXT_TIP)

# --- Custom popup menu --------------------------------------------------------
$menuForm = New-Object System.Windows.Forms.Form
$menuForm.FormBorderStyle = 'FixedSingle'; $menuForm.TopMost = $true
$menuForm.ShowInTaskbar = $false; $menuForm.StartPosition = 'Manual'
$menuForm.ClientSize = New-Object System.Drawing.Size(196, 76)
$menuForm.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)

function New-MenuItem([string]$text, [int]$top) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Dock = 'None'
    $l.Location = New-Object System.Drawing.Point(0, $top)
    $l.Size = New-Object System.Drawing.Size(196, 38)
    $l.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $l.Padding = New-Object System.Windows.Forms.Padding(14, 0, 0, 0)
    $l.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10)
    $l.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $l
}
$autoItem = New-MenuItem '' 0
$exitItem = New-MenuItem $TEXT_EXIT 38
$menuForm.Controls.Add($autoItem)
$menuForm.Controls.Add($exitItem)

function Update-AutoItem {
    $mark = if (Test-Path $script:AutoStartCmd) { $CHK_ON } else { $CHK_OFF }
    $autoItem.Text = $mark + ' ' + $TEXT_AUTO
}
$autoItem.Add_Click({
    if (Test-Path $script:AutoStartCmd) {
        Remove-Item $script:AutoStartCmd -Force -ErrorAction SilentlyContinue
    } else {
        $line = '@echo off' + [Environment]::NewLine + 'start "" wscript.exe "' + $script:Launcher + '"'
        [System.IO.File]::WriteAllText($script:AutoStartCmd, $line)
    }
    Update-AutoItem
    Hide-Menu
})
$exitItem.Add_Click({
    Get-Process -Name handy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.Application]::Exit()
})

# --- Menu show/hide -----------------------------------------------------------
# No global IMessageFilter: on a WS_EX_NOACTIVATE host it makes the menu's
# visible-state tracking unreliable (menu stops reappearing after close).
# Instead: close on item click (above), on button click, and when the menu
# loses activation (clicking anywhere else) via Deactivate + a watchdog timer.
function Show-Menu {
    Update-AutoItem
    $x = [Math]::Min([System.Windows.Forms.Control]::MousePosition.X, $wa.Right - $menuForm.Width - 8)
    $y = [Math]::Min([System.Windows.Forms.Control]::MousePosition.Y, $wa.Bottom - $menuForm.Height - 8)
    $menuForm.Location = New-Object System.Drawing.Point($x, $y)
    $script:menuShownAt = Get-Date
    $menuForm.Show()
    $menuForm.BringToFront()
    $menuForm.Activate()
}
function Hide-Menu {
    if ($menuForm.Visible) { $menuForm.Hide() }
}
$menuForm.Add_Deactivate({ Hide-Menu })

$script:menuShownAt = $null
$menuWatch = New-Object System.Windows.Forms.Timer
$menuWatch.Interval = 200
$menuWatch.Add_Tick({
    if (-not $menuForm.Visible) { return }
    if ($script:menuShownAt -and (((Get-Date) - $script:menuShownAt).TotalMilliseconds -lt 700)) { return }
    $fg = [HandyNative]::GetForegroundWindow()
    if ($fg -eq [IntPtr]::Zero) { return }
    if ($fg -eq $menuForm.Handle) { return }
    Hide-Menu
})
$menuWatch.Start()

# --- Read Handy's real state from log ----------------------------------------
function Get-RealState {
    if (-not $script:LOG -or -not (Test-Path $script:LOG)) { return 0 }
    try { $lines = Get-Content $script:LOG -Tail 120 -ErrorAction SilentlyContinue }
    catch { return $script:displayState }
    $st = 0
    foreach ($line in $lines) {
        if ($line -match 'Recording requested for binding transcribe') { $st = 1 }
        elseif ($line -match 'recording stopped after') { $st = 2 }
        elseif ($line -match 'Transcription completed in') { $st = 0 }
        elseif ($line -match 'Recording produced no audio samples') { $st = 0 }
        elseif ($line -match 'TranscribeAction::cancel') { $st = 0 }
    }
    return $st
}
function Apply-State([int]$st) {
    if ($st -eq $script:displayState) { return }
    $script:displayState = $st
    if ($st -eq 1) { $form.BackColor = [System.Drawing.Color]::FromArgb(244, 67, 54) }
    elseif ($st -eq 2) { $form.BackColor = [System.Drawing.Color]::FromArgb(255, 152, 0) }
    else { $form.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80) }
    $form.Invalidate()
}
$poll = New-Object System.Windows.Forms.Timer
$poll.Interval = 300
$poll.Add_Tick({
    $st = Get-RealState
    if ($st -ne 0) { $script:busy = $false; $script:pressAt = 0; Apply-State $st; return }
    if ($script:busy) {
        if (($script:pressAt -gt 0) -and (((Get-Date) - $script:pressAt).TotalSeconds -ge 4)) {
            $script:busy = $false; $script:pressAt = 0
        }
        return
    }
    Apply-State 0
})
function Invoke-RecordToggle {
    if ($script:busy) { return }
    $running = @(Get-Process -Name handy -ErrorAction SilentlyContinue).Count -gt 0
    if (-not $running) {
        Start-Process -FilePath $script:EXE -ArgumentList '--start-hidden' | Out-Null
        Start-Sleep -Seconds 4
    }
    $script:busy = $true; $script:pressAt = Get-Date
    Start-Process -FilePath $script:EXE -ArgumentList '--toggle-transcription' -WindowStyle Hidden | Out-Null
}

# --- Mouse --------------------------------------------------------------------
$form.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true; $script:moved = $false
        $script:down = [System.Windows.Forms.Control]::MousePosition
        $script:origin = $form.Location
    } elseif ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        if ($menuForm.Visible) { Hide-Menu } else { Show-Menu }
    }
})
$form.Add_MouseMove({
    if ($script:dragging) {
        $p = [System.Windows.Forms.Control]::MousePosition
        $dx = $p.X - $script:down.X; $dy = $p.Y - $script:down.Y
        if (([Math]::Abs($dx) + [Math]::Abs($dy)) -gt 12) { $script:moved = $true }
        if ($script:moved) { $form.Location = New-Object System.Drawing.Point(($script:origin.X + $dx), ($script:origin.Y + $dy)) }
    }
})
$form.Add_MouseUp({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $false
        if ($menuForm.Visible) { Hide-Menu; return }
        if (-not $script:moved) {
            $p = $form.PointToClient([System.Windows.Forms.Control]::MousePosition)
            $cx = $size / 2.0
            if ([Math]::Sqrt([Math]::Pow($p.X - $cx, 2) + [Math]::Pow($p.Y - $cx, 2)) -le $cx) {
                Invoke-RecordToggle
            }
        }
    }
})

$form.Add_Shown({
    $h = $form.Handle
    $ex = [HandyNative]::GetWindowLong($h, -20)
    [HandyNative]::SetWindowLong($h, -20, ($ex -bor 0x08000000)) | Out-Null  # WS_EX_NOACTIVATE
    Apply-State (Get-RealState)
    $poll.Start()
})
[System.Windows.Forms.Application]::Run($form)
