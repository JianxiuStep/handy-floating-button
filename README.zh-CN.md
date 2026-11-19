# Handy 悬浮录音按钮

[English](README.md) · [中文](README.zh-CN.md)

**给 [Handy](https://handy.computer) 加一个屏幕上的小圆钮:点一下开始说话,再点一下结束——识别出的文字直接打进你正在输入的任何地方。完全本地、免费、零依赖。**

Handy 本身用键盘快捷键(按住说话)触发录音。这个小小的附加组件给你一个**可以用鼠标点击的按钮**,特别适合触摸屏、躺着用、或者单纯不喜欢记快捷键的人。整个项目只有几个纯文本脚本(共约 20KB),**不需要安装 Python、.NET 之外的任何东西,不改注册表,不联网上传任何数据**。

---

## 它解决什么问题

- 不想按键盘?用鼠标点按钮就能说话。
- 想一眼知道现在是不是在录音?按钮会变色。
- 打游戏怕占显存?右键一下退出,立刻释放。
- 每次开机都要手动开?可选一键加入开机自启。

## 功能

- **左键点一下**:如果 Handy 没开就自动启动,然后开始录音;再点一下停止并识别。
- **右键**:弹出"退出(同时关闭 Handy)"菜单,一键释放显存/资源。
- **颜色跟着 Handy 的真实状态走**(读它的日志,不是瞎猜的计时器):
  - 🟢 绿 = 空闲/待命
  - 🔴 红 = 正在录音
  - 🟠 橙 = 正在识别
- **不会抢走输入焦点**:文字照样打进你原来在用的输入框(记事本、微信、Codex 都行)。
- **可以拖动**:按住左键拖到屏幕任何位置,始终浮在最上层。
- **可选开机自启**:附带安装/卸载脚本。
- **纯本地**:不联网、不收集数据,只是调用本机的 PowerShell 和 Handy 自己的命令。

## 效果

一个绿色小圆钮出现在屏幕右下角(默认位置),写着"录"。点它变红"停",再点变橙"…",识别完回到绿色。就这么简单。

## 要求

- Windows 10 / 11(64 位)
- 已安装并可正常使用 [Handy](https://github.com/cjpais/Handy/releases/latest) v0.10.x
- PowerShell 5.1(Windows 自带)

## 安装

1. 把本仓库下载/克隆到任意文件夹,例如 `C:\Handy 悬浮按钮\`。文件夹放哪都行,路径是相对的。

2. 确认 Handy 已安装。按钮会按以下顺序自动找 `handy.exe`:
   1. 环境变量 `HANDY_EXE`
   2. 脚本同目录下的 `app\handy.exe`(推荐:便携版 Handy 就放这里)
   3. 脚本同目录下的 `handy.exe`
   4. `%LOCALAPPDATA%\Programs\Handy\handy.exe`
   5. `%ProgramFiles%\Handy\handy.exe`
   6. `PATH` 里的 `handy`

   自动找不到时,设置环境变量 `HANDY_EXE` 指向 handy.exe 的完整路径即可。

3. **双击 `Start Handy button.vbs`**,右下角出现绿色圆钮,完成。

4. *(可选)* 双击 `install-autostart.cmd` 加入开机自启;不想自启了运行 `uninstall-autostart.cmd`。

### 想一次装好 Handy + 模型?用 setup.ps1

不想手动装 Handy、下模型、配隐私项?在 PowerShell 里运行(把路径换成你的):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -InstallDir 'D:\AIVoice\Handy' -Model sensevoice -Backend cpu -Unload min10
```

可选参数:`-Model sensevoice|qwen3-06b`、`-Backend cpu|gpu`、`-Unload min5|min10|never`、`-Hotkey ctrl+alt+m`、`-Language zh`、`-SkipButton`。脚本可重复运行,已装好且校验通过的部分会自动跳过。AI 助手部署时直接读脚本头部的参数说明即可。

> Windows 可能提示下载的自制脚本有风险。这些脚本都是纯文本,用记事本打开就能看内容。启动器用了 `-ExecutionPolicy Bypass`,只作用于当前这一次启动,不会改你系统的执行策略。

## 使用

| 操作 | 效果 |
|---|---|
| 左键点按钮 | 开始 / 停止录音 |
| 左键拖动 | 移动按钮位置 |
| 右键 → 开机自启 ☑/☐ | 勾选/取消开机自启(打勾即已启用) |
| 右键 → 退出(同时关闭 Handy) | 按钮和 Handy 一起关闭,立刻释放显存 |

右键菜单点外面、再点一次右键、或点任一项都会自动关闭。

## 给 AI 助手 / 自动部署

如果你把本仓库交给 AI 助手并说"按文档部署",请让它先读 **[AGENT.md](AGENT.md)**——里面是完整的自动部署指令(环境检测、模型选择、下载校验、配置、验证、失败回退)。所有配置项、CLI 参数、环境变量、日志匹配串集中在 **[CONFIG-REFERENCE.md](CONFIG-REFERENCE.md)**。

人工用户一般只需要看本文件;需要改任何行为时再查配置参考。

## 原理

Handy 提供了官方命令行参数 `--toggle-transcription`(切换录音)和 `--start-hidden`(静默启动)。这个按钮本质是一个无边框的 WinForms 窗口:

- 设置 `WS_EX_NOACTIVATE`,点击时不会抢走你目标程序的焦点;
- 用圆形区域画出圆钮;
- 每 300 毫秒读一次 Handy 的日志来显示真实状态。

这复刻了 Handy 官方 PR [#2200](https://github.com/cjpais/Handy/pull/2200) 里"浮动录音按钮"的思路,但**不需要重新编译 Handy**(官方目前处于功能冻结期,不合并新功能)。所以它始终保持为一个独立、零依赖的小插件。

## 文件说明

| 文件 | 作用 |
|---|---|
| `handy_button.ps1` | 按钮核心逻辑(PowerShell + WinForms) |
| `setup.ps1` | 一键部署 Handy + 模型(参数化,可重复运行) |
| `Start Handy button.vbs` | 无黑框启动器 |
| `install-autostart.cmd` / `uninstall-autostart.cmd` | 可选:加入/移除开机自启 |
| `README.md` / `README.zh-CN.md` | 本文档(英文 / 中文) |
| `AGENT.md` | 给 AI 的自动部署指令(中文) |
| `CONFIG-REFERENCE.md` | 配置项与接口速查(英文) |
| `LICENSE` | MIT 许可 |

## 常见问题

- **双击 vbs 后没出现按钮**:确认 `handy_button.ps1` 和 vbs 在同一目录。可以直接在 PowerShell 里运行 ps1 看报错。
- **弹窗说 Handy.exe not found**:设置环境变量 `HANDY_EXE` 为 handy.exe 完整路径,再启动一次。
- **按钮一直是绿色但明明在录音**:检查日志路径是否符合默认规则,或用 `HANDY_LOG` 指定。
- **文字打到了错误的窗口**:按钮设计成不抢焦点,请先点进目标输入框再用按钮。
- **杀毒软件报毒**:VBScript 启动器偶尔被误报。它只是启动 PowerShell 运行本地脚本,用记事本打开即可核对。

## 许可

MIT。这是独立社区插件,与 Handy 官方维护者无关联;Handy 本身也是 MIT 许可。
