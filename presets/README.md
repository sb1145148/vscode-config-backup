# presets

自己满意的配置快照，**手动留的"凝固点"** —— 和每天自动备份的区别：

| | 自动备份（`D:\Backup\vscode-config\`） | 这里的 preset |
| --- | --- | --- |
| 谁触发 | 计划任务，每天 12:00 | 我，配置调顺了才存 |
| 保留几份 | 最近 10 份，自动滚动 | 不滚动，只增 |
| 能不能进 git | 不能（在本地磁盘） | **能，可以跟仓库走** |

## 现有

| 文件 | 日期 | 说明 |
| --- | --- | --- |
| `satisfied-2026-11-12.json` | 2026-11-12 | 第一版满意的：High Contrast + JetBrains Mono 13px + 淡背景图 |

## 用法

**换成这一套：**

```powershell
# 1. 先备份现在的（万一后悔）
Copy-Item "$env:APPDATA\Code\User\settings.json" "$env:APPDATA\Code\User\settings.before-preset.json" -Force

# 2. 覆盖
Copy-Item .\presets\satisfied-2026-11-12.json "$env:APPDATA\Code\User\settings.json" -Force

# 3. 完全退出 VS Code 再打开（字体/背景要重启进程）
```

**只想看某个值：**

```powershell
Get-Content .\presets\satisfied-2026-11-12.json | Select-String 'fontSize|lineHeight|colorTheme'
```

## ⚠️ 注意：里面有本机路径

这个 preset 是从**这台机器**导出的，所以包含：

| 项 | 值 | 换机器要改 |
| --- | --- | --- |
| 背景图 | `D:/Backup/Pictures/vscode-bg/anime/touhou-21-topcrop.jpg` | 图不在就删掉这个键 |
| Python 解释器 | `C:\Users\Administrator\.dsh\...\python.exe` | 要改（DSH 自带的那份） |

**字体也需要对方机器上装了** —— `JetBrains Mono` 和 `Sarasa Mono SC` 都是手动装的，不在 Windows 自带里。

## 关键项是什么

```json
"workbench.colorTheme": "Default High Contrast",     // 纯黑底、高对比
"editor.fontFamily": "'JetBrains Mono', 'Sarasa Mono SC', ...",  // 等宽 + 中文等宽兜底
"editor.fontSize": 13,
"editor.lineHeight": 1.5,                            // 1.5 是"不紧不松"
"workbench.colorCustomizations": {
    "editor.foreground": "#e8e8e8"                   // 正文提亮（High Contrast 自带是纯白，这里稍微降一点）
},
"background.fullscreen": { "opacity": 0.2 }          // 整窗一层淡图
```

## 一个经验

配置这东西**不要一次调太多项**。一次只动一个：

```
字号 → 行高 → 主题 → 正文色 → 背景
```

因为它们是**互相牵制**的：字号小会让行高显得大，背景淡会显得正文暗。

一次动一个，才知道哪个改动真正起了作用。
