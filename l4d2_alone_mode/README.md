中文 | [English](./README_EN.md)

## About
单人模式下被 smoker、hunter、jockey、charger 控制时自动解控，并打印特感剩余血量。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## Notes
满足以下条件之一即为单人模式：
- 只有1个幸存者玩家
- 只有1个特感玩家
- 以上两者

## ConVar
```c
// 解控时对幸存者玩家附加的伤害值。
l4d2_alone_damage_smoker "5.0"
l4d2_alone_damage_hunter "9.0"
l4d2_alone_damage_jockey "9.0"
l4d2_alone_damage_charger "0.0"
```

## Command
```c
// 控制台命令，手动开启或关闭单人模式。多人下无法使用本命令。
sm_alone
```