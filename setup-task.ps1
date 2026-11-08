<#
.SYNOPSIS
注册计划任务：每天定时自动备份 VS Code 配置。

.DESCRIPTION
默认建两个触发器：
  - 每天 12:00
  - 登录后 5 分钟（U 盘插着就能一起备份）

用当前用户身份、仅登录时运行（这台机器上 S4U 注册会失败，见笔记）。
用绝对路径调 powershell.exe，不依赖 PATH（见 misdiagnosed #35）。

.PARAMETER Time
每天的备份时间，默认 12:00。

.PARAMETER NoLogonTrigger
不要"登录后"触发器，只保留每天定时。

.PARAMETER Remove
删除这个计划任务。

.EXAMPLE
.\setup-task.ps1

.EXAMPLE
.\setup-task.ps1 -Time 09:30

.EXAMPLE
.\setup-task.ps1 -Remove
#>
[CmdletBinding()]
param(
    [string]$Time = '12:00',
    [switch]$NoLogonTrigger,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$TaskName = 'VSCode-Config-Backup'
$Script = Join-Path $PSScriptRoot 'backup-vscode-config.ps1'

if ($Remove) {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($t) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "[完成] 已删除计划任务 $TaskName" -ForegroundColor Green
    } else {
        Write-Host "计划任务 $TaskName 本来就不存在" -ForegroundColor Yellow
    }
    exit 0
}

if (-not (Test-Path $Script)) {
    Write-Host "[错误] 找不到备份脚本：$Script" -ForegroundColor Red
    exit 1
}

$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

$action = New-ScheduledTaskAction -Execute $ps `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Script`"" `
    -WorkingDirectory $PSScriptRoot

$triggers = @()
$triggers += New-ScheduledTaskTrigger -Daily -At $Time
if (-not $NoLogonTrigger) {
    $logon = New-ScheduledTaskTrigger -AtLogOn
    $logon.Delay = 'PT5M'
    $triggers += $logon
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "（已删除旧任务，重新注册）" -ForegroundColor DarkGray
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers `
    -Settings $settings -Principal $principal `
    -Description '备份 VS Code 用户配置到 D 盘和 U 盘' | Out-Null

$info = Get-ScheduledTaskInfo -TaskName $TaskName
$triggerText = ($triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ', '

Write-Host "[完成] 已注册计划任务：$TaskName" -ForegroundColor Green
Write-Host "  脚本   : $Script"
Write-Host "  触发器 : 每天 $Time" -NoNewline
if (-not $NoLogonTrigger) { Write-Host " + 登录后 5 分钟" } else { Write-Host "" }
Write-Host "  下次   : $($info.NextRunTime)"
Write-Host ""
Write-Host "手动跑一次：" -ForegroundColor Cyan
Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$Script`""
Write-Host "删除任务：" -ForegroundColor Cyan
Write-Host "  .\setup-task.ps1 -Remove"
