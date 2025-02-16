中文 | [English](./README_EN.md)

## About
当最后一个玩家离开后使服务器崩溃，以便自动重启服务器。

## Notes
在 Linux 上，服务器崩溃后会自动重启，前提是你**没有**使用`-norestart`启动项。

在 Windows 上没有自动重启机制，需要创建一个批处理脚本循环启动，并且使用`-nocrashdialog`阻止 Windows 弹出错误对话框，一个`l4d2_start.bat`例子（来源：Hatsune Imagine）：
```bat
@echo off
:l4d2
echo "L4D2 Server Starting..."
C:\l4d2server\l4d2\srcds.exe -game left4dead2 -console -nocrashdialog -port 35018 -tickrate 100 -ip 0.0.0.0 +map c2m1 +exec server.cfg
goto l4d2
pause
```

## ConVar
```c
// 自动重启前的延迟时间，如果这期间有玩家加入服务器将不会重启。
l4d2_auto_restart_delay "30.0"

// 重启方法，1=crash命令, 2=Exit
l4d2_auto_restart_method "1"

// 如果方法是 Exit，则 exitcode 值是多少
l4d2_auto_restart_exitcode "60"
```

## Command
```c
// 管理员命令，手动使服务器崩溃。
sm_restart_server
```
