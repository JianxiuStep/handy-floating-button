<#
.SYNOPSIS
    One-shot, unattended deployment of Handy + a transcription model on Windows.

.DESCRIPTION
    Idempotent installer for AI agents and power users. Downloads the official
    Handy release, installs it in portable mode under -InstallDir, downloads
    exactly one model (hash-verified), writes a privacy-first settings file,
    and verifies the result. No extra software, no PATH changes, no reboot.

    Safe to re-run: existing files are detected and left alone.

.PARAMETER InstallDir
    Target folder. Data and models go under <InstallDir>\app\Data.
    Default: "$env:USERPROFILE\Handy"

.PARAMETER Model
    sensevoice  - SenseVoiceSmall Q5_K_M (164 MB, CPU, fastest/lightest)
    qwen3-06b   - Qwen3-ASR-0.6B Q8_0 (811 MB, more accurate Chinese)
    Default: sensevoice

.PARAMETER Backend
    cpu / gpu. gpu requires a Vulkan-capable GPU. Default: cpu

.PARAMETER Unload
    Model idle-unload timeout: min2, min5, min10, min15, hour1, never.
    'never' keeps the model (and VRAM) resident. Default: min10

.PARAMETER Hotkey
    Recording hotkey string, e.g. ctrl+alt+m. Avoid ctrl+space on Chinese IME.
    Default: ctrl+alt+m

.PARAMETER Language
    Recognition language. Default: zh

.PARAMETER SkipButton
    Do not copy the floating button scripts / autostart entry.

.EXAMPLE
    .\setup.ps1 -InstallDir 'D:\AIVoice\Handy' -Model qwen3-06b -Backend gpu -Unload min10

.EXAMPLE
    .\setup.ps1 -Model sensevoice -SkipButton
#>
param(
    [string]$InstallDir = "$env:USERPROFILE\Handy",
    [ValidateSet('sensevoice','qwen3-06b')][string]$Model = 'sensevoice',
    [ValidateSet('cpu','gpu')][string]$Backend = 'cpu',
    [ValidateSet('min2','min5','min10','min15','hour1','never')][string]$Unload = 'min10',
    [string]$Hotkey = 'ctrl+alt+m',
    [string]$Language = 'zh',
    [switch]$SkipButton
)

$ErrorActionPreference = 'Stop'

# ---- Model catalog (pinned, verified) ---------------------------------------
$CATALOG = @{
    'sensevoice' = @{
        file   = 'SenseVoiceSmall-Q5_K_M.gguf'
        id     = 'handy-computer/SenseVoiceSmall-gguf/SenseVoiceSmall-Q5_K_M.gguf'
        bytes  = 172474880
        sha256 = '622a819ef9b37dc5506f0079ddedca6ec22e272bb9b4fe950d8f13422d1ccd0b'
        rev    = '4a08b8e900b38a977e32eb08d5d0697d6e72ba04'
        repo   = 'handy-computer/SenseVoiceSmall-gguf'
    }
    'qwen3-06b' = @{
        file   = 'Qwen3-ASR-0.6B-Q8_0.gguf'
        id     = 'handy-computer/Qwen3-ASR-0.6B-gguf/Qwen3-ASR-0.6B-Q8_0.gguf'
        bytes  = 850423456
        sha256 = 'f081b2d5e23bd669d92cc331d722a8a0681943b8e6f34b48996fd5c319b5acd8'
        rev    = 'e4e16599b900eb0cb36e524514756bb92eb092b7'
        repo   = 'handy-computer/Qwen3-ASR-0.6B-gguf'
    }
}

$HANDY_VERSION = '0.10.1'
$SETUP_EXE    = "Handy_${HANDY_VERSION}_x64-setup.exe"
$SETUP_URL    = "https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/${SETUP_EXE}"
$SETUP_BYTES  = 17399128

function Log([string]$m) { Write-Host "[setup] $m" -ForegroundColor Cyan }
function Fail([string]$m) { Write-Host "[setup] ERROR: $m" -ForegroundColor Red; exit 1 }

# ---- 1. Prepare directories --------------------------------------------------
$appDir   = Join-Path $InstallDir 'app'
$dataDir  = Join-Path $appDir 'Data'
$modelDir = Join-Path $dataDir 'models'
$logDir   = Join-Path $dataDir 'logs'
foreach ($d in @($InstallDir, $appDir, $dataDir, $modelDir, $logDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
Log "Target directory: $InstallDir"

# ---- 2. Install Handy (portable) ---------------------------------------------
$exe = Join-Path $appDir 'handy.exe'
if (Test-Path $exe) {
    Log "Handy already installed at $exe - skipping download"
} else {
    $dl = Join-Path $env:TEMP $SETUP_EXE
    Log "Downloading official Handy $HANDY_VERSION installer..."
    Invoke-WebRequest -Uri $SETUP_URL -OutFile $dl -UseBasicParsing
    $size = (Get-Item $dl).Length
    if ($size -ne $SETUP_BYTES) { Fail "Installer size mismatch: $size (expected $SETUP_BYTES)" }
    Log "Installing silently to $appDir..."
    $p = Start-Process -FilePath $dl -ArgumentList @('/S', "/D=$appDir") -PassThru -Wait
    if ($p.ExitCode -ne 0) { Fail "Installer exited with code $($p.ExitCode)" }
    Remove-Item $dl -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $exe)) { Fail "handy.exe not found after install" }
    Log "Installed."
}

# ---- 3. Portable marker (all data stays in the folder) ----------------------
$marker = Join-Path $appDir 'portable'
if (-not (Test-Path $marker)) {
    [System.IO.File]::WriteAllText($marker, 'Handy Portable Mode')
    Log "Enabled portable mode."
} else { Log "Portable mode already enabled." }

# ---- 4. Download + verify exactly one model ---------------------------------
$m = $CATALOG[$Model]
$modelPath = Join-Path $modelDir $m.file
if (Test-Path $modelPath) {
    $actual = (Get-FileHash $modelPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -eq $m.sha256 -and (Get-Item $modelPath).Length -eq $m.bytes) {
        Log "Model $($m.file) already present and verified."
    } else {
        Log "Existing model failed verification - re-downloading."
        Remove-Item $modelPath -Force
    }
}
if (-not (Test-Path $modelPath)) {
    $url = "https://huggingface.co/$($m.repo)/resolve/$($m.rev)/$($m.file)"
    Log "Downloading model $($m.file) ($([math]::Round($m.bytes/1MB)) MB)..."
    Invoke-WebRequest -Uri $url -OutFile $modelPath -UseBasicParsing
    if ((Get-Item $modelPath).Length -ne $m.bytes) { Fail "Model size mismatch" }
    $actual = (Get-FileHash $modelPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $m.sha256) { Fail "Model SHA-256 mismatch: $actual" }
    Log "Model verified."
}

# ---- 5. Write privacy-first settings ----------------------------------------
$settingsPath = Join-Path $dataDir 'settings_store.json'
$customWords  = @('Codex','Remotion','FFmpeg','Whisper','Qwen3-TTS','HyperFrames','SenseVoice','WorkBuddy')
$settings = [ordered]@{
    selected_model              = $m.id
    transcribe_accelerator      = $Backend
    transcribe_gpu_device       = $null
    model_unload_timeout        = $Unload
    selected_language           = $Language
    app_language                = $(if ($Language -eq 'zh') { 'zh' } else { 'en' })
    history_limit               = 0
    recording_retention_period  = 'preserve_limit'
    post_process_enabled        = $false
    post_process_api_keys       = [ordered]@{}
    update_checks_enabled       = $false
    audio_feedback              = $true
    sound_theme                 = 'marimba'
    shortcut_activation         = 'push_to_talk'
    bindings                    = [ordered]@{
        transcribe = [ordered]@{
            id = 'transcribe'; name = 'Transcribe'
            description = 'Converts your speech into text.'
            default_binding = 'ctrl+space'; current_binding = $Hotkey
        }
    }
    custom_words                = $customWords
    filler_word_removal_enabled = $false
}
$store = [ordered]@{ settings = $settings }
$json  = $store | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Log "Wrote settings (model=$Model, backend=$Backend, unload=$Unload, hotkey=$Hotkey)."

# ---- 6. Verify startup -------------------------------------------------------
Get-Process handy -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process -FilePath $exe -ArgumentList '--start-hidden'
Start-Sleep -Seconds 8
if (-not (Get-Process handy -ErrorAction SilentlyContinue)) { Fail "Handy failed to start" }
$logFile = Join-Path $logDir 'handy.log'
if (Test-Path $logFile) {
    $tail = Get-Content $logFile -Tail 200 -Raw
    if ($tail -match 'ERROR|panic') { Log "WARNING: errors found in log - please inspect $logFile" }
    if ($tail -match [regex]::Escape($m.file)) { Log "Model discovered in log." }
}
Log "Handy is running."

# ---- 7. Floating button (optional) ------------------------------------------
if (-not $SkipButton) {
    $here = Split-Path -Parent $PSCommandPath
    foreach ($f in @('handy_button.ps1','Start Handy button.vbs')) {
        $src = Join-Path $here $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $InstallDir $f) -Force }
    }
    Log "Button scripts copied to $InstallDir. Run 'Start Handy button.vbs' to show it."
}

Log "DONE. Installed at $InstallDir"
