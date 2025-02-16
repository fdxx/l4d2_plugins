中文 | [English](./README_EN.md)

## About
提供一些加入旁观者、加入幸存者、自杀的命令。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## Notes
闲置和旁观不同，在合作模式下你执行闲置命令`go_away_from_keyboard`后，bot 会接管你的角色，但你的视角仍然会锁定在当前角色身上，按下鼠标左键可重新接管当前角色。而旁观则可以自由切换视角和移动。

## ConVar
```c
// 切换到旁观者的延迟时间，0.0=没有延迟。
l4d2_afk_commands_afk_delay "3.0"

// 玩家执行闲置 go_away_from_keyboard 命令后的动作。
// 0=游戏默认。
// 1=阻止使用闲置命令（只能使用旁观命令）。
// 2=可以无限制的使用闲置命令，默认情况下，对抗模式和只有1个人时无法使用闲置命令。
l4d2_afk_commands_idle_type "1"
```

## Command
```c
// 控制台命令，加入旁观者。
sm_afk
sm_away
sm_idle
sm_spectate
sm_spectators
sm_joinspectators
sm_jointeam1

// 控制台命令，加入幸存者。
sm_survivors
sm_sur
sm_join
sm_jg
sm_jiaru
sm_jointeam2
sm_jr

// 控制台命令，自杀。
sm_kill
sm_zs
```