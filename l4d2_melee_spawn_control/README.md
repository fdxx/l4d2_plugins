中文 | [English](./README_EN.md)

## About
解锁近战武器生成。

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
默认情况下，每张地图能够产生的近战武器种类有限制，这个插件解除了这个限制。

## ConVar
```c
// 是否解锁近战武器生成。
l4d2_melee_spawn_unlock_all "1"
```

## Command
```c
// 管理员命令，在当前位置产生一把近战武器。
sm_spawnmelee_test <meleeName>

// 管理员命令，查看当前地图能够产生哪些近战武器。
sm_meleedump
```

## Credits
- [l4d2_melee_spawn_control](https://github.com/umlka/l4d2/blob/main/l4d2_melee_spawn_control/l4d2_melee_spawn_control.sp) 

