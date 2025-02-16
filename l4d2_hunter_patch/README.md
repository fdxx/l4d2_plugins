中文 | [English](./README_EN.md)

## About
在对抗模式和合作模式下，Hunter 的行为有点不同，这个插件可以启用或禁用这些功能。

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## Notes
如果启用，将适用于所有模式、Hunter 机器人、Hunter 玩家。

## ConVar

### l4d2_hunter_patch_convert_leap
- 是否将跳跃转换为突袭。0=游戏默认, 1=始终, 2=永不。
- Hunter 有跳跃技能，和突袭不同，跳跃不能击倒幸存者。在合作模式下主要用于让 Hunter 逃跑，在对抗模式下，跳跃被转换为突袭。

### l4d2_hunter_patch_crouch_pounce
- 在地面上时，是否需要按蹲键才能突袭。0=游戏默认, 1=始终, 2=永不。
- 在对抗模式下默认需要。

### l4d2_hunter_patch_bonus_damage
- 是否启用额外的突袭伤害。0=游戏默认, 1=始终, 2=永不。
- 和 [[L4D2] Hunter Pounce Damage](https://forums.alliedmods.net/showthread.php?p=2675236) 插件做相同的事情，这个插件只是使用 [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble) 扩展的版本。
- 默认情况下，游戏只在对抗模式中为 Hunter 启用高扑伤害，由官方 cvar`z_hunter_max_pounce_bonus_damage`控制。

### l4d2_hunter_patch_pounce_interrupt
- 是否启用"pounce_interrupt"。0=游戏默认, 1=始终, 2=永不。
- 默认情况下，Hunter 机器人比 Hunter 玩家更难"空爆"。这是因为游戏只为真实玩家启用了"pounce_interrupt"，当 Hunter 在空中受到一定伤害时，会直接杀死它，由官方 cvar`z_pounce_damage_interrupt`控制（合作 = 50，对比 = 150）。 
- 如果在合作模式下启用，建议也将`z_pounce_damage_interrupt`设置为`150`，以保持和对抗模式体验一致。

## Command
```c
// 管理员命令。打印 cvar 的值
sm_hunter_patch_print_cvars
```