================================================================================
  Remind Tool v1.0.0 - Windows 系统提醒工具
================================================================================

简介
----
Remind Tool 是一个轻量级 Windows 命令行提醒工具。在 CMD 或 PowerShell 中
输入一条命令，即可在指定时间收到 Windows 系统 Toast 通知。

提醒通过「Windows 计划任务」调度，关闭命令行窗口后仍然有效，重启电脑后
也会保留（只要到了触发时间且你已登录）。


快速开始
--------
1. 确保本文件夹 (Scripts) 已加入系统 PATH 环境变量
2. 打开 CMD，运行初始化:

     remind install

3. 创建你的第一个提醒:

     remind 5m "测试提醒"

4. 五分钟后你会收到 Windows 系统通知。


命令一览
--------

  remind <时间> "<内容>"       创建相对时间提醒
  remind at <时间> "<内容>"    创建绝对时间提醒
  remind list                  列出所有待触发提醒
  remind cancel <ID>           取消指定提醒
  remind cancel all            取消全部提醒
  remind install               初始化/安装工具
  remind help                  显示帮助


相对时间格式
------------
  30s           30 秒后
  5m / 5min     5 分钟后
  1h            1 小时后
  1h20m         1 小时 20 分钟后
  1h20min       同上
  1d            1 天后
  1:30          1 小时 30 分钟后
  90m           90 分钟后


绝对时间格式
------------
  remind at 15:30 "开会"                 今天 15:30（若已过则明天）
  remind at 2025-06-28 09:00 "提交报告"   指定日期和时间


使用示例
--------
  remind 1h "起床"
  remind 1h20m "喝水"
  remind 30m "休息一下"
  remind at 18:00 "下班"
  remind list
  remind cancel abc12345
  remind cancel all


文件说明
--------
  remind.cmd           CMD 入口，调用 PowerShell 脚本
  remind-main.ps1      核心逻辑（解析时间、计划任务、管理提醒）
  notify.ps1           通知触发脚本（由计划任务调用）
  remind.config.json   配置文件（通知名称、声音等）
  README.txt           本说明文件

数据文件（自动创建，在本目录下）:
  .\RemindToolData\reminders.json   提醒列表


安装 PATH（若尚未添加）
-----------------------
方法一 - 图形界面:
  1. Win + R -> sysdm.cpl -> 高级 -> 环境变量
  2. 在「用户变量」或「系统变量」中找到 Path
  3. 添加本文件夹路径，例如: D:\GUI_Beauties\Scripts
  4. 重新打开 CMD

方法二 - 命令行（用户级）:
  setx PATH "%PATH%;D:\GUI_Beauties\Scripts"

  注意: 需重新打开 CMD 窗口才能生效。


工作原理
--------
1. 创建提醒时，工具在 Windows 计划任务中注册一个一次性任务
2. 到达指定时间后，任务运行 notify.ps1 脚本
3. notify.ps1 弹出 Windows Toast 通知，并自动清理该提醒记录


常见问题
--------
Q: 没有收到通知？
A: - 确认已运行 remind install
   - 确认创建提醒时 CMD 没有报错
   - 检查 Windows 通知中心是否关闭了 Remind Tool 的通知
   - 用 remind list 确认提醒仍在列表中

Q: 提醒在关机期间会丢失吗？
A: 计划任务设置了 StartWhenAvailable，开机登录后会补触发错过的提醒。

Q: 如何修改通知声音？
A: 编辑 remind.config.json 中的 playSound 字段，或设置 soundEnabled 为 false。

Q: 卸载？
A: 1. remind cancel all
   2. 删除 .\RemindToolData\ 文件夹
   3. 从 PATH 中移除本目录（可选）


版本
----
  v1.0.0  初始版本

================================================================================
