中文 | [English](./README_EN.md)

## About
在安全屋产生一些近战武器。

## Notes
建议使用 [l4d2_melee_spawn_control](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_melee_spawn_control) 插件解锁近战武器种类。

## ConVar
```c
// 0=禁用
// 1=随机，见 l4d2_saferoom_melee_random_count
// 2=固定，见 sm_saferoom_melee_add_fixed
// 3=以上两者
l4d2_saferoom_melee_type "1"

// 如果随机产生，则随机产生多少个近战武器。
l4d2_saferoom_melee_random_count "6"

// 如果产生撬棍，将撬棍皮肤替换成金色。
l4d2_saferoom_melee_golden_crowbar "1"
```

## Command
```c
// 管理员命令，添加固定产生的近战武器
sm_saferoom_melee_add_fixed <meleeName1> [meleeName2] ...

// 管理员命令，清空固定产生的近战列表。
sm_saferoom_melee_reset 
```
