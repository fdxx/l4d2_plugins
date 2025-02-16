[中文](./README.md) | English

## About
Print survivor kill data.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors) 

## ConVar
```c
// Total damage includes Tank damage.
l4d2_kill_mvp_add_tank_damage "1"

// Total damage includes Witch damage.
l4d2_kill_mvp_add_witch_damage "1"

// Total damage includes common infected damage.
l4d2_kill_mvp_add_ci_damage "1"

// Notify Tank damage when Tank dies.
l4d2_kill_mvp_tank_death_damage_announce "1"

// Notify Witch damage when Witch dies.
l4d2_kill_mvp_witch_death_damage_announce "1"
```

## Command
```c
// Console command. Print survivor kill data.
// By default, this will be printed auto at the end of each round.
sm_mvp

// Admin command. Clear kill data.
// Development purposes.
sm_clear_mvp
```

## Native
```c
// Get kill data.
// data: enum struct killData
native void L4D2_GetKillData(int client, any[] data);
```

