# vscode-config-backup

把 VS Code 的用户配置定期备份到 D 盘和 U 盘。

**为什么需要**：设置、快捷键、代码片段、插件清单都放在 `%APPDATA%\Code\User`，
这个目录不在任何 git 仓库里。重装系统、换机器、或者那块 U 盘哪天坏了，这些就没了。

---

## 备份什么

只备份**人写的**那部分：

| 备份 | 说明 |
| --- | --- |
| `settings.json` | 设置 |
| `keybindings.json` | 快捷键（有才备份） |
| `tasks.json` / `mcp.json` / `argv.json` | 其它根目录 .json（有才备份） |
| `snippets\` | 代码片段 |
| `profiles\` | 配置档（有才备份） |
| `extensions.txt` | 插件清单（加 `-IncludeExtensions`） |

**不备份**：

| 跳过 | 原因 |
| --- | --- |
| `globalStorage\` | 几百 MB，且和本机绑定 |
| `workspaceStorage\` | 每个项目的临时状态 |
| `History\` | 本地文件历史，很大且没迁移价值 |

---

## 用法

```powershell
# 正常备份（默认写 D:\Backup\vscode-config 和 E:\Backup\vscode-config）
.\backup-vscode-config.ps1

# 先看看会做什么，不写文件
.\backup-vscode-config.ps1 -DryRun

# 只备份到一处，并且只留最近 3 份
.\backup-vscode-config.ps1 -Target 'D:\Backup\vscode-config' -Keep 3

# 连插件清单一起来
.\backup-vscode-config.ps1 -IncludeExtensions
```

**默认行为**：

- 每次生成一个 `yyyyMMdd-HHmmss` 目录
- 每个目标保留最近 **10** 份，自动清理更旧的
- 目标盘不存在（U 盘没插）时**跳过，不算失败**
- 每个目标写一份 `manifest.json`（备份时间、条目、文件数、字节数）
- 每个目标追加一行 `backup.log`

---

## 自动备份

```powershell
# 注册计划任务：每天 12:00 + 登录后 5 分钟
.\setup-task.ps1

# 改时间
.\setup-task.ps1 -Time 09:30

# 只要每天定时，不要登录触发
.\setup-task.ps1 -NoLogonTrigger

# 删掉
.\setup-task.ps1 -Remove
```

任务名：`VSCode-Config-Backup`

**为什么用绝对路径**：这台机器上 `python`/`code` 这类命令在计划任务里不一定能解析
（见 `misdiagnosed` #35）。任务里写的是
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` 的完整路径。

---

## 怎么恢复

```powershell
# 1. 先看最近一份有什么
Get-ChildItem D:\Backup\vscode-config | Sort-Object Name -Descending | Select-Object -First 1

# 2. 拷回去（先关掉 VS Code）
$src = 'D:\Backup\vscode-config\20261108-210036'
Copy-Item "$src\settings.json"          "$env:APPDATA\Code\User\" -Force
Copy-Item "$src\keybindings.json"       "$env:APPDATA\Code\User\" -Force
Copy-Item "$src\snippets"               "$env:APPDATA\Code\User\" -Recurse -Force

# 3. 装回插件（extensions.txt 一行一个）
Get-Content "$src\extensions.txt" | ForEach-Object { code --install-extension $_ }
```

---

## 两个注意

**① 这是"备份"，不是"同步"**

它只往目标写，从不读取目标、也不删除源。所以 U 盘里的旧备份永远不会反过来污染你的配置。

**② 别把 VS Code 本身装在 U 盘上**

这个脚本备份的只是**配置**（不到 1 MB）。
程序要装在内置盘 —— 从 U 盘运行程序会把它磨损到随机崩溃
（见 `misdiagnosed` #37，那正是这台机器 2026-11 遇到的问题）。

---

## 文件

| 文件 | 作用 |
| --- | --- |
| `backup-vscode-config.ps1` | 备份脚本本体 |
| `setup-task.ps1` | 注册 / 删除计划任务 |
| `README.md` | 这份说明 |

两个 `.ps1` 都是 **UTF-8 with BOM** —— 没有 BOM 时 Windows PowerShell 5.1 会按 GBK 解码，
中文注释会把脚本解析崩（`misdiagnosed` #31）。
