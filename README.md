# Handy Floating Record Button

[English](README.md) · [中文](README.zh-CN.md)

**A small on-screen button for [Handy](https://handy.computer) — click to start talking, click again to stop. Text appears wherever you're typing. Fully local, free, zero dependencies.**

Handy normally starts and stops recording with a **keyboard hotkey** (push-to-talk). This project adds a small round button on your screen so you can **click to start, click again to stop** — no keyboard required. Useful for touch screens, lying down, or anyone who prefers a mouse.

Built entirely with **Windows built-in components** (PowerShell + WinForms + VBScript). No Python, no dependencies, no installers, no background services. The script files total only about 20 KB.

---

## Features

- **Left click** the button → starts Handy if it isn't running, then toggles recording on/off.
- **Right click** → *Exit (also close Handy)* menu: closes both the button and Handy in one go (frees GPU/VRAM instantly, handy before gaming).
- **Color follows Handy's real state** (read from Handy's log, not a guessed timer):
  - 🟢 Green = idle / ready
  - 🔴 Red = recording
  - 🟠 Orange = transcribing
- **Never steals focus** — text is pasted into whatever app you were typing in.
- **Draggable** — move the button anywhere on screen; stays on top.
- **Auto-starts with Windows** (optional, one-click installer included).
- **Local only** — no network calls, no data collection. All it does is run local PowerShell and Handy's own CLI flags.

---

## Requirements

- Windows 10 / 11 (64-bit)
- [Handy](https://github.com/cjpais/Handy/releases/latest) v0.10.x installed and working
- PowerShell 5.1 (included with Windows)

---

## Installation

1. Download / clone this repository into a folder, e.g. `C:\Handy Floating Button\`.
   The folder can be anywhere — paths are resolved relative to the scripts.

2. Make sure Handy is installed. The button finds `handy.exe` automatically in this order:
   1. `HANDY_EXE` environment variable (if set)
   2. `app\handy.exe` next to the scripts (portable Handy install — recommended)
   3. `handy.exe` next to the scripts
   4. `%LOCALAPPDATA%\Programs\Handy\handy.exe`
   5. `%ProgramFiles%\Handy\handy.exe`
   6. `handy` on your `PATH`

   If auto-detection fails, set the environment variable `HANDY_EXE` to the full path of `handy.exe`.

3. **Double-click `Start Handy button.vbs`.** A green circle appears in the bottom-right corner. Done.

4. *(Optional)* Double-click `install-autostart.cmd` to add it to Windows startup, so the button appears automatically after every login. Run `uninstall-autostart.cmd` to remove it.

> **Note:** Windows may warn about running a downloaded `.vbs`/`.ps1`. These scripts are plain text — open them in Notepad to inspect. The launch uses `-ExecutionPolicy Bypass` for the current process only; it does not change your system policy.

---

## Usage

| Action | Result |
|---|---|
| Left click | Start / stop recording (toggles) |
| Left drag | Move the button |
| Right click → Autostart ☑/☐ | Toggle Windows startup (checked = enabled) |
| Right click → Exit (also close Handy) | Close the button and Handy together |

The right-click menu closes when you click outside it, right-click again, or pick any item.

The button reads Handy's log to show the true state. By default it looks for:
- `<handy.exe folder>\Data\logs\handy.log` (portable mode)
- `%APPDATA%\com.pais.handy\logs\handy.log` (standard mode)

Override with the `HANDY_LOG` environment variable if your log lives elsewhere.

---

## How it works

Handy exposes documented CLI flags, including:

- `handy --start-hidden` — launch quietly
- `handy --toggle-transcription` — toggle recording on the running instance (exactly the same path as the hotkey)

The button is a borderless WinForms window that:
- is set `WS_EX_NOACTIVATE` so clicking it never takes focus from your target app,
- uses a circular region for the round shape,
- polls Handy's log every 300 ms to reflect the real recording/transcribing state.

This reproduces the idea from Handy PR [#2200](https://github.com/cjpais/Handy/pull/2200) (a floating record button) without recompiling Handy: the official maintainers currently do not merge new features, so this stays a standalone, zero-dependency add-on.

---

## For AI agents / automatic deployment

If you hand this repository to an AI assistant and say "deploy this", ask it to read **[AGENT.md](AGENT.md)** first — it contains the full step-by-step deploy instructions (environment detection, model choice, download + hash verification, config, validation, rollback). All settings keys, CLI flags, environment variables and log match strings are centralized in **[CONFIG-REFERENCE.md](CONFIG-REFERENCE.md)**.

Human users normally only need this README; see the configuration reference when changing behavior.

---

## Files

| File | Purpose |
|---|---|
| `handy_button.ps1` | The button logic (PowerShell + WinForms) |
| `setup.ps1` | One-shot parameterized installer for Handy + a model |
| `Start Handy button.vbs` | Silent launcher (no black console window) |
| `install-autostart.cmd` / `uninstall-autostart.cmd` | Optional: add to / remove from Windows startup |
| `README.md` / `README.zh-CN.md` | This document (English / 中文) |
| `AGENT.md` | Auto-deploy instructions for AI agents (中文) |
| `CONFIG-REFERENCE.md` | Settings & interface reference (English) |
| `LICENSE` | MIT license |

---

## Troubleshooting

- **No button appears after double-clicking the .vbs** — make sure `handy_button.ps1` is in the same folder. Try running the `.ps1` directly in a PowerShell window to see any error.
- **"Handy.exe not found" popup** — set the `HANDY_EXE` environment variable to your `handy.exe` full path, then relaunch.
- **Button shows green but recording is active** — check that your Handy log path matches one of the defaults, or set `HANDY_LOG`.
- **Text goes to the wrong window** — the button is designed not to steal focus; click into your target app first, then use the button.
- **Antivirus flags the .vbs** — VBScript launchers are sometimes flagged generically. The file only starts PowerShell with a local script; inspect it in Notepad if unsure.

---

## License

MIT — do whatever you want. Handy itself is MIT licensed; this is an independent community add-on and is not affiliated with the Handy maintainers.
