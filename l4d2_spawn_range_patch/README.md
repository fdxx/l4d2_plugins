中文 | [English](./README_EN.md)

## About
让 `z_spawn_range` 值的优先级高于 VScript 

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)
- left4dhooks

## ConVar
```c
// 1=启用, 0=禁用.
l4d2_spawn_range_patch_enable "1"

// 是否排除最终地图
l4d2_spawn_range_patch_finalmap_exclude "1"
```

## Command
```c
// 管理员命令，添加排除的地图
sm_spawn_range_patch_exclude <map1> [map2] ...
```
