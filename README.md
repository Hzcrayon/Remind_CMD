[README.md](https://github.com/user-attachments/files/29425272/README.md)
# Remind Tool

一个简单、轻量的 Windows 命令行提醒工具。  
A simple and lightweight command-line reminder tool for Windows.

Remind Tool 可以通过一条命令创建定时提醒，并在指定时间弹出 Windows 系统通知。提醒由 Windows Task Scheduler 调度，因此关闭命令行窗口后仍然有效。

Remind Tool lets you schedule reminders from CMD or PowerShell. It uses Windows Task Scheduler, so reminders can still run after the terminal window is closed.

## Features / 功能

- 创建相对时间提醒，例如 5 分钟后、1 小时后
- 创建指定时间提醒，例如今天 15:30 或某个日期的 09:00
- 查看待触发提醒列表
- 取消单个提醒或取消全部提醒
- 使用 Windows Toast 通知提醒用户
- 数据保存在本地，不需要网络服务

- Create relative-time reminders, such as in 5 minutes or in 1 hour
- Create reminders at a specific time or date
- List pending reminders
- Cancel one reminder or all reminders
- Show reminders through Windows Toast notifications
- Store reminder data locally

## Requirements / 运行环境

- Windows
- PowerShell 5.1 or later
- CMD or PowerShell

## Quick Start / 快速开始

First, make sure this folder is added to your Windows `PATH`, then run:

```cmd
remind install
```

Create your first reminder:

```cmd
remind 5m "测试提醒"
```

After 5 minutes, you should receive a Windows notification.

## Usage / 使用方法

```cmd
remind <time> "<message>"
remind at <time> "<message>"
remind list
remind cancel <ID>
remind cancel all
remind install
remind help
```

## Examples / 示例

Relative-time reminders / 相对时间提醒:

```cmd
remind 30s "站起来活动一下"
remind 5m "喝水"
remind 1h "开会"
remind 1h20m "休息一下"
remind 1d "明天检查任务"
```

Specific-time reminders / 指定时间提醒:

```cmd
remind at 15:30 "开会"
remind at 2026-06-28 09:00 "提交报告"
```

Manage reminders / 管理提醒:

```cmd
remind list
remind cancel abc12345
remind cancel all
```

## Time Formats / 时间格式

| Format | Meaning |
| --- | --- |
| `30s` | 30 seconds later / 30 秒后 |
| `5m` or `5min` | 5 minutes later / 5 分钟后 |
| `1h` | 1 hour later / 1 小时后 |
| `1h20m` | 1 hour 20 minutes later / 1 小时 20 分钟后 |
| `1d` | 1 day later / 1 天后 |
| `1:30` | 1 hour 30 minutes later / 1 小时 30 分钟后 |
| `15:30` | Today at 15:30, or tomorrow if already passed / 今天 15:30，若已过则为明天 |
| `2026-06-28 09:00` | Specific date and time / 指定日期和时间 |

## Files / 文件说明

| File | Description |
| --- | --- |
| `remind.cmd` | CMD entry point. Calls the PowerShell script. |
| `remind-main.ps1` | Main logic: time parsing, task scheduling, and reminder management. |
| `notify.ps1` | Notification script called by scheduled tasks. |
| `run-notify-hidden.vbs` | Runs notification script with a hidden window. |
| `remind.config.json` | Configuration file for app name, sound, and data location. |
| `RemindToolData/reminders.json` | Local reminder data, created automatically. |

## How It Works / 工作原理

1. When you create a reminder, the tool registers a one-time Windows scheduled task.
2. At the target time, the task runs `notify.ps1`.
3. `notify.ps1` shows a Windows Toast notification and clears the reminder record.

中文说明：

1. 创建提醒时，工具会在 Windows 计划任务中注册一个一次性任务。
2. 到达指定时间后，计划任务会运行 `notify.ps1`。
3. `notify.ps1` 弹出 Windows 系统通知，并清理对应的提醒记录。

## Configuration / 配置

You can edit `remind.config.json` to change notification behavior.

可以编辑 `remind.config.json` 调整通知行为。

```json
{
  "version": "1.0.0",
  "appDisplayName": "Remind Tool",
  "soundEnabled": true,
  "playSound": "ms-winsoundevent:Notification.Reminder",
  "dataDirectory": ".\\RemindToolData"
}
```

## Troubleshooting / 常见问题

**Q: I did not receive a notification. / 没有收到通知怎么办？**

- Make sure you have run `remind install`.
- Check that Windows notifications are enabled.
- Run `remind list` to confirm the reminder still exists.
- Make sure the scheduled time has not already been cancelled.

**Q: Will reminders survive after closing the terminal? / 关闭命令行后提醒还有效吗？**

Yes. Reminders are scheduled through Windows Task Scheduler.

会。提醒通过 Windows 计划任务调度，关闭 CMD 或 PowerShell 后仍然有效。

**Q: How do I remove all reminders? / 如何取消所有提醒？**

```cmd
remind cancel all
```

## Version / 版本

Current version: `v1.0.0`

## License / 许可证

No license has been added yet. If you plan to share this project publicly, consider adding a license file.

目前还没有添加许可证。如果你打算公开分享这个项目，建议之后添加一个开源许可证文件。
