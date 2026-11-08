<#
.SYNOPSIS
备份 VS Code 的用户配置（设置 / 快捷键 / 代码片段 / 配置档）到 D 盘和 U 盘。

.DESCRIPTION
只备份 %APPDATA%\Code\User 下"人写的"那部分，跳过缓存和会话存储：

    备份    settings.json、keybindings.json、tasks.json 等根目录 .json
            snippets\、profiles\
    跳过    globalStorage\、workspaceStorage\、History\（几百 MB 且与本机绑定）

每次运行生成一个带时间戳的目录，并保留最近 N 份。

.PARAMETER Target
备份目标目录。默认 D:\Backup\vscode-config 和 E:\Backup\vscode-config（E 盘不存在时自动跳过）。

.PARAMETER Keep
每个目标保留最近几份，默认 10。

.PARAMETER DryRun
只打印将要做什么，不写任何文件。

.PARAMETER IncludeExtensions
额外记录一份已装插件清单（extensions.txt）。需要能找到 VS Code 的 code.cmd。

.EXAMPLE
.\backup-vscode-config.ps1

.EXAMPLE
.\backup-vscode-config.ps1 -DryRun

.EXAMPLE
.\backup-vscode-config.ps1 -Target 'D:\Backup\vscode-config' -Keep 5
#>
[CmdletBinding()]
param(
    [string[]]$Target = @(),
    [int]$Keep = 10,
    [switch]$DryRun,
    [switch]$IncludeExtensions
)

$ErrorActionPreference = 'Stop'

# 从 Electron 应用（如 DSH）里调用时，环境里可能有 ELECTRON_RUN_AS_NODE=1，
# 会让 Code.exe 变成 node 而拿不到插件列表。这里清掉，见 misdiagnosed #36。
if ($env:ELECTRON_RUN_AS_NODE) { $env:ELECTRON_RUN_AS_NODE = $null }

$Source = Join-Path $env:APPDATA 'Code\User'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# 只备份这些（人的配置）；其余目录是缓存/会话
$RootFiles = @('settings.json', 'keybindings.json', 'tasks.json', 'mcp.json',
               'chatLanguageModels.json', 'argv.json', 'snippets.json')
$SubDirs = @('snippets', 'profiles')

if (-not (Test-Path $Source)) {
    Write-Host "[错误] 找不到 VS Code 配置目录：$Source" -ForegroundColor Red
    exit 1
}

if (-not $Target -or $Target.Count -eq 0) {
    $Target = @('D:\Backup\vscode-config', 'E:\Backup\vscode-config')
}

function Write-Step($msg, $color = 'Gray') {
    Write-Host "  $msg" -ForegroundColor $color
}

# 收集要备份的条目
$items = @()
foreach ($f in $RootFiles) {
    $p = Join-Path $Source $f
    if (Test-Path $p) { $items += Get-Item $p }
}
foreach ($d in $SubDirs) {
    $p = Join-Path $Source $d
    if (Test-Path $p) { $items += Get-Item $p }
}

$totalFiles = 0
$totalBytes = 0
foreach ($i in $items) {
    if ($i.PSIsContainer) {
        $m = Get-ChildItem $i.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum
        $totalFiles += $m.Count
        $totalBytes += $m.Sum
    } else {
        $totalFiles += 1
        $totalBytes += $i.Length
    }
}

Write-Host "VS Code 配置备份" -ForegroundColor Cyan
Write-Host "  来源   : $Source"
Write-Host "  条目   : $($items.Count) 个（含 $totalFiles 个文件，$([math]::Round($totalBytes/1KB,1)) KB）"
Write-Host "  时间戳 : $Stamp"
foreach ($i in $items) { Write-Step "$($i.Name)" DarkGray }

if ($DryRun) {
    Write-Host "  [DryRun] 不会写入任何文件" -ForegroundColor Yellow
}

$okCount = 0
$failCount = 0

foreach ($t in $Target) {
    Write-Host ""
    Write-Host "目标：$t" -ForegroundColor Cyan

    $drive = [System.IO.Path]::GetPathRoot($t)
    if ($drive -and -not (Test-Path $drive)) {
        Write-Host "  [跳过] $drive 不存在（盘没插？）" -ForegroundColor Yellow
        continue
    }

    $dest = Join-Path $t $Stamp
    try {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            foreach ($i in $items) {
                Copy-Item $i.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
            }

            # 清单：以后想核对"这份是什么时候备份的、里面有什么"
            $manifest = [ordered]@{
                backed_up_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                source       = $Source
                files        = $totalFiles
                bytes        = $totalBytes
                items        = @($items | ForEach-Object { $_.Name })
            }

            if ($IncludeExtensions) {
                $codeCmd = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
                if (Test-Path $codeCmd) {
                    try {
                        $exts = & cmd /c "`"$codeCmd`" --list-extensions 2>&1"
                        if ($LASTEXITCODE -eq 0 -and $exts) {
                            $extFile = Join-Path $dest 'extensions.txt'
                            Set-Content -Path $extFile -Value $exts -Encoding UTF8
                            $manifest.extensions = $exts.Count
                            Write-Step "插件清单 $($exts.Count) 个" DarkGray
                        }
                    } catch {
                        Write-Step "取插件清单失败：$($_.Exception.Message)" Yellow
                    }
                }
            }

            $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $dest 'manifest.json') -Encoding UTF8
        }

        Write-Host "  [完成] $dest" -ForegroundColor Green
        $okCount++

        # 清理旧备份，只留最近 $Keep 份
        $old = Get-ChildItem $t -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
               Sort-Object Name -Descending | Select-Object -Skip $Keep
        if ($old) {
            if ($DryRun) {
                Write-Step "将清理 $($old.Count) 份旧备份" Yellow
            } else {
                foreach ($o in $old) { Remove-Item $o.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                Write-Step "清理了 $($old.Count) 份旧备份（保留最近 $Keep 份）" DarkGray
            }
        }

        if (-not $DryRun) {
            $logLine = "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  ok  $Stamp  $totalFiles files  $([math]::Round($totalBytes/1KB,1)) KB"
            Add-Content -Path (Join-Path $t 'backup.log') -Value $logLine -Encoding UTF8
        }
    } catch {
        Write-Host "  [失败] $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        if (-not $DryRun) {
            $logLine = "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  FAIL  $($_.Exception.Message)"
            try { Add-Content -Path (Join-Path $t 'backup.log') -Value $logLine -Encoding UTF8 } catch { }
        }
    }
}

Write-Host ""
if ($failCount -gt 0) {
    Write-Host "结果：$okCount 个成功，$failCount 个失败" -ForegroundColor Red
    exit 1
}
Write-Host "结果：$okCount 个目标全部成功" -ForegroundColor Green
exit 0
