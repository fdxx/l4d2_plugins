[中文](./README.md) | English

## About
Join the Special infected team in coop mode.

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [multicolors](https://github.com/nosoop/SMExt-SourceScramble) 
- left4dhooks

## Notes
The plugin only support coop mode.

## ConVar
```c
// Maximum limit on the number of infected players.
l4d2_cz_max_special_limit "1"

// A limit on the number of infected players of each type.
l4d2_cz_smoker_limit "0"
l4d2_cz_boomer_limit "0"
l4d2_cz_hunter_limit "1"
l4d2_cz_spitter_limit "0"
l4d2_cz_jockey_limit "0"
l4d2_cz_charger_limit "0"
l4d2_cz_tank_limit "1"

// Infected player spawn time.
l4d2_cz_spawn_time "15"

// Admin can bypass l4d2_cz_max_special_limit to joining the infected team.
l4d2_cz_admin_immunity "1"

// Block infected players spawned by the z_spawn_old command.
l4d2_cz_block_other_pz_respawn "1"
```

## Command
```c
// Console command, join the infected team.
sm_inf
sm_team3

// Console commands. join to the Tank control queue.
// When a Tank bot is spawned, a player will be randomly selected from the queue to control the Tank.
sm_taketank
sm_tk
```

## Credits
- [control_zombies](https://github.com/umlka/l4d2/tree/main/control_zombies) 

