[中文](./README.md) | English

## About
Unlocks melee weapon spawn.

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
By default, there is a limit to the types of melee weapons that can be spawned per map, this plugin unlocks that limit.

## ConVar
```c
// Whether or not to unlock melee weapon spawn.
l4d2_melee_spawn_unlock_all "1"
```

## Command
```c
// Admin Command. Spawns a melee weapon at the current location.
sm_spawnmelee_test <meleeName>

// Admin Command. See what melee weapons the current map can spawn.
sm_meleedump
```

## Credits
- [l4d2_melee_spawn_control](https://github.com/umlka/l4d2/blob/main/l4d2_melee_spawn_control/l4d2_melee_spawn_control.sp) 

