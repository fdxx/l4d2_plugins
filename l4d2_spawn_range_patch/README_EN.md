[中文](./README.md) | English

## About
Make the `z_spawn_range` value have a higher priority than the VScript.

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## ConVar
```c
// 1=Enable, 0=Disable.
l4d2_spawn_range_patch_enable "1"

// Whether to exclude the final map
l4d2_spawn_range_patch_finalmap_exclude "1"
```

## Command
```c
// Admin command, add excluded maps.
sm_spawn_range_patch_exclude <map1> [map2] ...
```
