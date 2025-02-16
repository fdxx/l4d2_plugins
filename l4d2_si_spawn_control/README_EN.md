[中文](./README.md) | English

## About
Special infected spawn control.

## Dependencies
- left4dhooks
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## ConVar
```c
// Each type of SI spawn limit.
l4d2_si_spawn_control_hunter_limit "1"
l4d2_si_spawn_control_jockey_limit "1"
l4d2_si_spawn_control_smoker_limit "1"
l4d2_si_spawn_control_boomer_limit "1"
l4d2_si_spawn_control_spitter_limit "1"
l4d2_si_spawn_control_charger_limit "1"

// SI maximum spawn limit.
l4d2_si_spawn_control_max_specials "6"

// spawn time.
l4d2_si_spawn_control_spawn_time "10.0"

// SI first spawn time (after leaving the safe area).
l4d2_si_spawn_control_first_spawn_time "10.0"

// Auto kill SI time, e.g. too far away or out of sight.
l4d2_si_spawn_control_kill_si_time "25.0"

// Block SI spawn outside of this plugin.
l4d2_si_spawn_control_block_other_si_spawn "1"

// spawn mode, see below.
l4d2_si_spawn_control_spawn_mode "0"

// Normal mode spawn range, randomly spawn from 1 to this range.
l4d2_si_spawn_control_spawn_range_normal "1500"

// NavArea mode spawn range, randomly spawn from 1 to this range.
l4d2_si_spawn_control_spawn_range_navarea "1500"

// After SI dies, wait for other SI to spawn together.
l4d2_si_spawn_control_together_spawn "0" 
```

### l4d2_si_spawn_control_spawn_mode

- 0=Normal mode. Use the official implementation of function `GetRandomPZSpawnPosition` to find the spawn position, see `l4d2_si_spawn_control_spawn_range_normal` for the spawn range.
- 2=NavArea mode. Use this plugin's own implementation of the function to find the spawn position, see `l4d2_si_spawn_control_spawn_range_navarea` for the spawn range.
- 3=Normal Mode Enhancements. Automatic switching between 0 and 2. When normal mode fails or when "panic event" starts, Use NavArea mode to find the position. For example, after a c8m3, c3m2 panic event starts, the SI in normal mode spawns very far away.
- 1=NavArea mode Enhancements. Will spawn in the nearest unseen area of the survivor, incapacitated survivors are considered unseen.

## Change Log

### v3.3
- Cvar changed: l4d2_si_spawn_control_radical_spawn ==> l4d2_si_spawn_control_spawn_mode
- Optimize performance.
- Prioritize spawning SI near real players. (for SpawnMode == 1)
- After changing the SI spawn time, immediately spawn SI at the set time.
- Fix the number of SI spawn may be abnormal.

### v3.4
- Add more spawn mode.

### v3.5
- When max SI are being spawned, Allow respawning of killed SI. To ensure the correctness of the subsequent maximum SI number.

### v3.6
- Restore official cvar to default value when unload plugin.

### v3.7
- Fix SourceMod 1.12 compile error.
- Removed Native `L4D2_CanSpawnSpecial`. Use `l4d2_si_spawn_control_block_other_si_spawn` control.
