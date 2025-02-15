中文 | [English](./README_EN.md)

## About
打印幸存者击杀数据。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors) 

## ConVar
```c
// 总伤害包括 Tank 伤害。
l4d2_kill_mvp_add_tank_damage "1"

// 总伤害包括 Witch 伤害。
l4d2_kill_mvp_add_witch_damage "1"

// 总伤害包括普通感染者伤害。
l4d2_kill_mvp_add_ci_damage "1"

// Tank 死亡时通知 Tank 伤害。
l4d2_kill_mvp_tank_death_damage_announce "1"

// Witch 死亡时通知 Witch 伤害。
l4d2_kill_mvp_witch_death_damage_announce "1"
```

## Command
```c
// 控制台命令。打印幸存者击杀数据。
// 默认情况下，将在每轮结束时自动打印。
sm_mvp

// 管理员命令。清除击杀数据。
// 开发目的。
sm_clear_mvp
```

## Native
```c
// 获取击杀数据
// data: enum struct killData
native void L4D2_GetKillData(int client, any[] data);
```