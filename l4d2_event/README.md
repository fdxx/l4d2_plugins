中文 | [English](./README_EN.md)

## About
打印游戏中触发的[事件](https://wiki.alliedmods.net/Left_4_Dead_2_Events)。开发用途。

## Command
```c
// 管理员命令。开始监听游戏事件。
// 0=关闭, 1=通过 res 文件监听, 2=通过 net_showevents 命令监听。
sm_event_listen <0|1|2>

// 管理员命令。列出所有事件名称
sm_list_events
```
