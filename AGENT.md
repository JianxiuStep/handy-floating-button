# Handy 本地语音输入 —— AI 自动部署指令

> **给 AI 助手的说明**:把本文件完整交给具备终端与文件操作能力的 AI(WorkBuddy / Claude Code / Cursor / Codex 等),并说"按这份文档部署"。AI 应严格按本文完成检测 → 决策 → 安装 → 配置 → 验证 → 报告全过程。所有命令均为 Windows PowerShell / Git Bash 可直接执行的形式,变量以 `<...>` 标注,执行前请替换为实际值。

> ⚠️ **平台限制:仅支持 Windows 10/11**。若目标机器是 macOS 或 Linux,立即停止并告知用户本项目不支持,不要尝试移植或安装。

---

## 0. 铁律(任何情况下不得违反)

1. **只从官方源下载**:Handy 只从 `github.com/cjpais/Handy/releases` 下载;模型只从 `huggingface.co/handy-computer/...` 或其官方镜像 `blob.handy.computer` 下载。**禁止 winget、禁止第三方打包版**。
2. **不扩大安装范围**:不安装 Python、CUDA Toolkit、Docker、FFmpeg、语音框架;不改动用户已有的任何环境(例如用户自己搭的 TTS/语音相关项目)。
3. **数据全部落在用户指定目录**:默认 `<用户选择的目录>\Handy`(例如 `C:\Handy` 或 `D:\Handy`)。用 Tauri 便携模式使配置/模型/日志/录音都进 exe 旁的 `Data\`,**C 盘 AppData 必须零残留**。
4. **完整性校验**:安装包比对官方字节数;模型比对官方 SHA-256;不符则删除重下。
5. **隐私默认**:本地识别、云端后处理关闭、所有 API Key 为空、历史记录关闭、自动更新关闭。不改防火墙/Defender、不装证书。
6. **只装用户确认的模型**:未经用户明确同意,不要下载第二个模型。
7. **最小化磁盘**:装完删除安装包、`.partial`、临时文件;保留的模型数不超过用户确认的范围。

---

## 1. 环境探测(先做,把结果报告给用户)

执行并保存输出:

```powershell
# 系统 / CPU / GPU / 内存 / 磁盘
Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber
Get-CimInstance Win32_Processor | Select Name,NumberOfCores
Get-CimInstance Win32_VideoController | Select Name,@{N='VRAM_MB';E={[math]::Round($_.AdapterRAM/1MB)}}
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select DeviceID,@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,1)}}
Get-NetAdapter | Where Status -eq 'Up' | Select Name
```

记录:系统版本、CPU 型号、是否有 NVIDIA/AMD 独显及显存、各盘剩余空间、目标安装盘符(空间紧张的盘要避开)。

同时确认 Handy 是否已装、是否已有相关进程:

```powershell
Get-Process handy -ErrorAction SilentlyContinue
Test-Path "$env:LOCALAPPDATA\Programs\Handy\handy.exe"
```

---

## 2. 决策(依据用户需求 + 硬件)

### 2.1 模型选择表(官方 catalog 基准,错误率越低越准)

| 模型 ID | 体积 | CPU 速度 | 中文错误率 | 说明 |
|---|---:|---:|---:|---|
| `sense-voice-int8` 系列 SenseVoiceSmall Q5_K_M | 164 MB | 19.7× | 10.1% | 极小极快,零显存,默认首选 |
| `Qwen3-ASR-0.6B` Q8_0 | 811 MB | 5.3× | 7.6% | 中文更准,GPU 热身後 27× |
| `Qwen3-ASR-1.7B` Q8_0 | 2.0 GB | 2.5× | 7.1% | 极致准确,占用大 |

> 注:最新版 Handy(v0.10.x)已把旧的 160MB `sense-voice-int8` ONNX 模型替换为 GGUF 版 `SenseVoiceSmall`,仍属 SenseVoice 家族、CPU 运行、支持中/英/日/韩/粤语。

**决策规则**:用户没特别要求时选 SenseVoice Q5_K_M(最小占用)。用户要"更准"或"试试大模型"时选 Qwen3-ASR-0.6B Q8_0。除非用户明确要求,不要选 1.7B 或更大模型。

### 2.2 后端(CPU / GPU)

- 用户CPU够强、要求零显存/玩游戏 → CPU。
- 有 NVIDIA/AMD 独显且支持 Vulkan、用户接受占用几百 MB~1GB 显存 → GPU。
- GPU 首次加载会把权重搬进显存(SenseVoice 无此问题;Qwen3 约 1.3 秒),之后常驻高速。
- 用户玩游戏且显存紧张 → 必须配闲置自动卸载,不要设 `never`(见 3.4)。

### 2.3 闲置卸载时间(`model_unload_timeout`)

| 值 | 行为 |
|---|---|
| `never` | 永不卸载,显存/内存常驻占用(游戏用户慎用) |
| `min2` / `min5` / `min10` / `min15` / `hour1` | 闲置对应时长后卸载模型,释放资源 |
| `immediately` | 每次识别后立刻卸载 |

默认 `min5`。玩游戏的用户推荐 `min10`(日常保持热,打游戏超 10 分钟自动释放)。

---

## 3. 执行步骤

### 3.1 下载官方 Handy 安装包

固定版本 v0.10.1(如官方 latest 已更新,以 releases/latest 为准并同步改下面文件名/大小):

```bash
curl -fL --retry 3 -o "<DOWNLOAD_DIR>/Handy_0.10.1_x64-setup.exe" \
  "https://github.com/cjpais/Handy/releases/download/v0.10.1/Handy_0.10.1_x64-setup.exe"
stat -c '%s' "<DOWNLOAD_DIR>/Handy_0.10.1_x64-setup.exe"   # 期望 17399128
```

### 3.2 静默安装 + 便携模式

```powershell
$exe = "<DOWNLOAD_DIR>\Handy_0.10.1_x64-setup.exe"
Start-Process $exe -ArgumentList '/S','/D=<INSTALL_DIR>\app' -Wait
Start-Sleep -Seconds 3
Test-Path "<INSTALL_DIR>\app\handy.exe"   # 必须为 True
```

在 exe 旁放便携标记(内容必须以此开头,否则不生效):

```powershell
Set-Content -Path "<INSTALL_DIR>\app\portable" -Value "Handy Portable Mode" -NoNewline -Encoding ascii
```

验证:C 盘不得出现 `com.pais.handy`:

```powershell
@("$env:APPDATA\com.pais.handy","$env:LOCALAPPDATA\com.pais.handy","$env:USERPROFILE\.cache\huggingface") | ForEach-Object { Test-Path $_ }
```

### 3.3 下载模型(仅用户确认的那个)

目录:`<INSTALL_DIR>\app\Data\models\`

**SenseVoice Q5_K_M**:

```bash
curl -fL --retry 3 -o "<...>/models/SenseVoiceSmall-Q5_K_M.gguf" \
  "https://huggingface.co/handy-computer/SenseVoiceSmall-gguf/resolve/4a08b8e900b38a977e32eb08d5d0697d6e72ba04/SenseVoiceSmall-Q5_K_M.gguf"
```
大小 `172474880`;SHA-256 `622a819ef9b37dc5506f0079ddedca6ec22e272bb9b4fe950d8f13422d1ccd0b`。

**Qwen3-ASR-0.6B Q8_0**:

```bash
curl -fL --retry 3 -o "<...>/models/Qwen3-ASR-0.6B-Q8_0.gguf" \
  "https://huggingface.co/handy-computer/Qwen3-ASR-0.6B-gguf/resolve/e4e16599b900eb0cb36e524514756bb92eb092b7/Qwen3-ASR-0.6B-Q8_0.gguf"
```
大小 `850423456`;SHA-256 `f081b2d5e23bd669d92cc331d722a8a0681943b8e6f34b48996fd5c319b5acd8`。

校验:

```bash
stat -c '%s' "<model file>"
sha256sum "<model file>"
```

不匹配就删掉重下,不要将就。

### 3.4 写配置 `Data\settings_store.json`

结构为 `{"settings": {...}}`。**缺字段会安全回退默认值**,所以只写需要覆盖的键即可。下面是隐私优先的最小模板(按决策替换模型/后端/卸载时间):

```json
{
  "settings": {
    "settings_schema_version": 3,
    "selected_model": "handy-computer/SenseVoiceSmall-gguf/SenseVoiceSmall-Q5_K_M.gguf",
    "transcribe_accelerator": "cpu",
    "model_unload_timeout": "min5",
    "selected_language": "zh",
    "app_language": "zh",
    "history_limit": 0,
    "recording_retention_period": "preserve_limit",
    "post_process_enabled": false,
    "post_process_api_keys": {},
    "update_checks_enabled": false,
    "audio_feedback": true,
    "sound_theme": "marimba",
    "shortcut_activation": "push_to_talk",
    "bindings": {
      "transcribe": {
        "id": "transcribe", "name": "Transcribe",
        "description": "Converts your speech into text.",
        "default_binding": "ctrl+space", "current_binding": "ctrl+alt+m"
      }
    },
    "custom_words": ["Codex","Remotion","FFmpeg","Whisper","Qwen3-TTS","HyperFrames","SenseVoice","WorkBuddy"],
    "filler_word_removal_enabled": false
  }
}
```

**关键陷阱**:`recording_retention_period` 的 `never` 含义是"永不删除",与"关闭历史"完全相反!要关闭历史必须用 `preserve_limit` + `history_limit: 0`。

切换 Qwen3 + GPU 时改这几个键:

```json
"selected_model": "handy-computer/Qwen3-ASR-0.6B-gguf/Qwen3-ASR-0.6B-Q8_0.gguf",
"transcribe_accelerator": "gpu",
"transcribe_gpu_device": null,
"model_unload_timeout": "min10"
```

> `transcribe_accelerator: "gpu"` 在源码迁移中可能被规范化显示为 `auto`,但 `auto` 在有 Vulkan 设备时会自动选 GPU,实测有效。

快捷键避开中文输入法冲突:不要用 `ctrl+space`。用户已有习惯时**不要覆盖**,先读现有 bindings 再决定。

### 3.5 启动与验证

```powershell
Start-Process "<INSTALL_DIR>\app\handy.exe"
Start-Sleep -Seconds 10
Get-Process handy -ErrorAction SilentlyContinue | Select Id,WorkingSet64
```

检查日志 `<INSTALL_DIR>\app\Data\logs\handy.log`:
- 必须出现 `Discovered catalog quant in models dir: <model id>`(模型被识别为已下载)
- 必须出现 `loaded CPU backend` 或 `using selected vulkan device`(后端正确)
- 不得有 `ERROR` / `panic`

### 3.6 客观性能测试(无需真人说话)

Handy 支持无头转写,用任意 16kHz 单声道 WAV:

```bash
"<INSTALL_DIR>/app/handy.exe" --transcribe-file "<test.wav>" \
  --model "<model id>" --device-index 0 --repeat 3 --json
```

输出 JSON 含 `best_ms`、`rtf`、`text`、`bound_backend`。CPU 测试去掉 `--device-index`。这能在交付前给出可复现的速度与准确率数据。

### 3.7 浮动按钮(可选)

把本仓库的 `handy_button.ps1` 与 `Start Handy button.vbs` 复制到 `<INSTALL_DIR>`(即 app 的上一级,脚本会自动在 `app\handy.exe` 找到主程序)。双击 `Start Handy button.vbs` 启动。需要自启则运行 `install-autostart.cmd`。

按钮自动定位 Handy 的顺序、环境变量覆盖见 `CONFIG-REFERENCE.md`。

---

## 4. 验收清单(逐项确认后再报告完成)

- [ ] Handy 版本记录(从 releases 或 About 获取)
- [ ] 安装位置在用户指定目录,C 盘无 `com.pais.handy` 残留
- [ ] 便携标记文件存在且内容正确
- [ ] 模型字节数与 SHA-256 均匹配官方
- [ ] 日志确认模型被识别、后端正确、无 ERROR
- [ ] 隐私项确认:history 0、post_process 空 key、update off
- [ ] 快捷键不与中文输入法冲突
- [ ] 磁盘占用统计(总占用、各子目录、剩余空间)
- [ ] 客观测试耗时记录(CPU/GPU 各自 best_ms)
- [ ] 安装包/临时文件已删除
- [ ] 需要真人完成的项目明确列出(麦克风听写、断网测试、玩游戏时的显存表现)

---

## 5. 失败回退

| 症状 | 处理 |
|---|---|
| 安装器 `/D` 未生效 | NSIS 的 `/D` 必须是最后一个参数且路径不加引号;确认后重试 |
| 模型未被识别 | 文件名必须与官方完全一致(含大小写);放对 `Data\models\`;重启 Handy |
| GPU 未被选用 | 用 `--list-devices` 看索引;`--device-index N` 强制指定;检查 Vulkan 驱动 |
| GPU 首次特别慢 | 正常,权重搬显存所致;用 `--repeat 3` 看热身后的 `best_ms` |
| 中文词组识别成谐音 | 把正确写法加入 `custom_words`;中文谐音+数字效果有限,建议用户改说英文型号 |
| 词库不生效 | 确认 Handy 重启过;日志中应有 `vocabulary_terms=<N>` |
| 按钮不显示 | 不要用 `-WindowStyle Hidden/Minimized` 启动承载 WinForms 的 PowerShell;用 vbs 启动器 |
| 按钮颜色乱跳 | 按钮应读 Handy 真实日志,不要用固定计时器猜状态 |

---

## 6. 接口与扩展

所有可配置项、CLI 参数、环境变量、日志匹配串、settings 键名,集中在 **`CONFIG-REFERENCE.md`**。AI 需要改任何行为时先查该文件,不要猜键名。

## 7. 一键安装脚本(可选,推荐给 AI)

`setup.ps1` 把第 3 节的全部步骤做成了参数化、可重复执行(幂等)的脚本。AI 可先读它的 `param` 块与注释,再一条命令部署:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File setup.ps1 `
  -InstallDir 'C:\Handy' -Model qwen3-06b -Backend gpu -Unload min10
```

参数(详见脚本头注释):`-InstallDir` 目标目录、`-Model sensevoice|qwen3-06b`、`-Backend cpu|gpu`、`-Unload min2|min5|min10|min15|hour1|never`、`-Hotkey`、`-Language`、`-SkipButton`。

脚本会自动:建目录 → 下载校验官方安装包 → 静默安装 → 启用便携模式 → 下载并 SHA-256 校验模型 → 写隐私优先配置 → 启动验证 → 复制按钮脚本。已存在且校验通过的文件会跳过。

**注意**:脚本写死的是 v0.10.1 与两个模型的固定哈希。若官方 latest 更新,先按 `CONFIG-REFERENCE.md` 更新脚本顶部的 `$HANDY_VERSION` / `$CATALOG` 再运行。手动按第 3 节执行同样有效且更可控。
