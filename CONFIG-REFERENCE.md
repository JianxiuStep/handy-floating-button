# Configuration Reference

Machine-readable reference for AI agents and contributors. All keys/values verified against Handy v0.10.1 source and runtime logs.

## Paths

| Item | Portable install (recommended) | Standard install |
|---|---|---|
| Executable | `<INSTALL_DIR>\app\handy.exe` | `%LOCALAPPDATA%\Programs\Handy\handy.exe` |
| Portable marker | `<INSTALL_DIR>\app\portable` (content starts with `Handy Portable Mode`) | n/a |
| Data dir | `<INSTALL_DIR>\app\Data\` | `%APPDATA%\com.pais.handy\` |
| Settings | `<Data>\settings_store.json` | same name under data dir |
| Models | `<Data>\models\` | same |
| Log | `<Data>\logs\handy.log` | `<Data>\logs\handy.log` |
| Recordings | `<Data>\recordings\` (cleaned per retention) | same |
| History DB | `<Data>\history.db` | same |

## Settings file schema

File JSON shape: `{ "settings": { ... } }`. Missing keys fall back to defaults (verified in source). Write with UTF-8.

### Keys used by this project

| Key | Type | Values | Effect |
|---|---|---|---|
| `selected_model` | string | model id (see Models) | Active transcription model |
| `transcribe_accelerator` | string | `auto` / `cpu` / `gpu` | Compute backend preference. `gpu` may normalize to `auto`; `auto` still selects Vulkan when available |
| `transcribe_gpu_device` | string\|null | null or device id | null = automatic device selection |
| `model_unload_timeout` | string | `never`, `immediately`, `min2`, `min5`, `min10`, `min15`, `hour1` | Idle unload. **`never` = never unload (keeps VRAM), NOT "disable history"** |
| `selected_language` | string | `zh`, `en`, `yue`, `ja`, `ko`, `auto` | Recognition language |
| `app_language` | string | `zh`, `en`, `ja`, ... | UI language |
| `history_limit` | int | 0 = off | Max history entries. Only effective with `recording_retention_period: preserve_limit` |
| `recording_retention_period` | string | `preserve_limit`, `never`, `days3`, `weeks2`, `months3` | **`never` = never DELETE anything. To disable history use `preserve_limit` + `history_limit: 0`** |
| `post_process_enabled` | bool | false | Cloud AI post-processing. Keep false for privacy |
| `post_process_api_keys` | object | `{}` | All provider keys empty = no cloud API |
| `update_checks_enabled` | bool | false | Disable GitHub update check |
| `audio_feedback` | bool | true | Play start/stop sounds |
| `sound_theme` | string | `marimba`, `pop`, `custom` | Sound set |
| `shortcut_activation` | string | `push_to_talk`, `toggle`, `hold_or_toggle` | Hotkey behavior |
| `bindings` | object | see below | Shortcut bindings |
| `custom_words` | string[] | e.g. `["Codex","Qwen3-ASR"]` | Vocabulary hint (supported by Whisper & Qwen3-ASR: log shows `vocabulary=true`) |
| `filler_word_removal_enabled` | bool | false | Local filler-word cleanup |

`bindings` entry shape:
```json
"transcribe": {
  "id": "transcribe",
  "name": "Transcribe",
  "description": "Converts your speech into text.",
  "default_binding": "ctrl+space",
  "current_binding": "ctrl+alt+m"
}
```
Keys: `transcribe`, `transcribe_with_post_process`, `cancel`. Avoid `ctrl+space` on Chinese IME systems.

## Models (official catalog, verified hashes)

| Model id | File in `models\` | Bytes | SHA-256 | Default quant |
|---|---|---:|---|---|
| `handy-computer/SenseVoiceSmall-gguf/SenseVoiceSmall-Q5_K_M.gguf` | `SenseVoiceSmall-Q5_K_M.gguf` | 172474880 | `622a819ef9b37dc5506f0079ddedca6ec22e272bb9b4fe950d8f13422d1ccd0b` | Q5_K_M |
| `handy-computer/Qwen3-ASR-0.6B-gguf/Qwen3-ASR-0.6B-Q8_0.gguf` | `Qwen3-ASR-0.6B-Q8_0.gguf` | 850423456 | `f081b2d5e23bd669d92cc331d722a8a0681943b8e6f34b48996fd5c319b5acd8` | Q8_0 |

SenseVoice download URL (pinned revision `4a08b8e900b38a977e32eb08d5d0697d6e72ba04`):
`https://huggingface.co/handy-computer/SenseVoiceSmall-gguf/resolve/4a08b8e900b38a977e32eb08d5d0697d6e72ba04/SenseVoiceSmall-Q5_K_M.gguf`

Qwen3-ASR-0.6B download URL (pinned revision `e4e16599b900eb0cb36e524514756bb92eb092b7`):
`https://huggingface.co/handy-computer/Qwen3-ASR-0.6B-gguf/resolve/e4e16599b900eb0cb36e524514756bb92eb092b7/Qwen3-ASR-0.6B-Q8_0.gguf`

Handy auto-discovers any catalog `.gguf` dropped into `models\` with the exact filename and marks it downloaded (log: `Discovered catalog quant in models dir`).

## Handy CLI flags (v0.10.1)

| Flag | Meaning |
|---|---|
| `--start-hidden` | Launch with main window hidden |
| `--toggle-transcription` | Toggle recording on the running instance (same path as hotkey) |
| `--toggle-post-process` | Toggle recording with post-processing (cloud — avoid for privacy) |
| `--cancel` | Cancel current operation |
| `--transcribe-file <WAV>` | Headless transcribe a 16 kHz mono WAV, then exit |
| `--model <ID>` | Model for `--transcribe-file` |
| `--device-index <N>` | Force compute device index (see `--list-devices`) |
| `--list-devices` | List compute devices with indices |
| `--list-models` | List available model ids |
| `--repeat <N>` | Repeat transcription N times (report fastest) |
| `--json` | Machine-readable JSON output |
| `--debug`, `--help` | Verbose logging / help |

`--transcribe-file --json` output fields: `audio_secs`, `best_ms`, `bound_backend`, `load_ms`, `model`, `requested_device`, `rtf`, `text`, `transcribe_ms`.

## Button script interfaces

The floating button reads Handy's state from its log. Matching strings (must stay in sync with Handy's log format):

| State | Log substring | Button color |
|---|---|---|
| Recording | `Recording requested for binding transcribe` | red |
| Transcribing | `recording stopped after` | orange |
| Idle | `Transcription completed in` / `Recording produced no audio samples` / `TranscribeAction::cancel` | green |

Environment variable overrides for the button:

| Variable | Purpose |
|---|---|
| `HANDY_EXE` | Full path to handy.exe (overrides auto-detection) |
| `HANDY_LOG` | Full path to handy.log (overrides auto-detection) |

Auto-detection order for exe: `$HANDY_EXE` → `<script dir>\app\handy.exe` → `<script dir>\handy.exe` → `%LOCALAPPDATA%\Programs\Handy\handy.exe` → `%ProgramFiles%\Handy\handy.exe` → `handy` on PATH.

Log detection: `$HANDY_LOG` → `<exe dir>\Data\logs\handy.log` → `%APPDATA%\com.pais.handy\logs\handy.log`.

Windows API used by button: `WS_EX_NOACTIVATE` (`0x08000000`) so clicking never steals focus; `ShowWindow(console, 0)` hides the PowerShell console.

## Install flags

Handy NSIS installer silent install:
```
Handy_0.10.1_x64-setup.exe /S /D=<INSTALL_DIR>\app
```
`/D` must be the LAST argument and the path must NOT be quoted.

## Privacy defaults (recommended)

```
history_limit = 0
recording_retention_period = preserve_limit
post_process_enabled = false
post_process_api_keys = {}
update_checks_enabled = false
```
