[中文](./README.md) | English

## About
Spawn some melee weapons at the safe room.

## Notes
It is recommended to use [l4d2_melee_spawn_control](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_melee_spawn_control) plugin to unlock melee weapon types.

## ConVar
```c
// 0=Disable
// 1=Random, see l4d2_saferoom_melee_random_count
// 2=Fixed, see sm_saferoom_melee_add_fixed
// 3=both of the above.
l4d2_saferoom_melee_type "1"

// If randomly spawn, how many melee weapons are randomly spawn.
l4d2_saferoom_melee_random_count "6"

// If a Crowbar spawns, replace the Crowbar skin with gold.
l4d2_saferoom_melee_golden_crowbar "1"
```

## Command
```c
// Admin Command. Add fixed spawning melee weapons.
sm_saferoom_melee_add_fixed <meleeName1> [meleeName2] ...

// Admin Command. Clears the list of fixed spawned melee.
sm_saferoom_melee_reset 
```
