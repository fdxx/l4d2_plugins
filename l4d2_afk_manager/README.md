中文 | [English](./README_EN.md)

## About
对闲置玩家进行管理。

## Notes
闲置玩家定义：一定时间内，没有鼠标、键盘、语音操作。

## ConVar
```c
// 多少秒后闲置的玩家将被强制切换到旁观队伍。0.0=禁用
l4d2_afk_manager_spec_time "90.0"

// 多少秒后闲置的旁观玩家（被强制切换到旁观的玩家）将被踢出服务器。0.0=禁用
l4d2_afk_manager_kick_time "180.0"

// 服务器达到多少玩家后，才会将玩家踢出服务器。
l4d2_afk_manager_kick_players_limit "4"

// 强制切换到旁观排除 TANK
l4d2_afk_manager_exclude_tank "1"

// 强制切换到旁观排除管理员
l4d2_afk_manager_exclude_admin "1"

// 强制切换到旁观排除死亡玩家
l4d2_afk_manager_exclude_dead "1"
```