[中文](./README.md) | English

## About
Manage idle players.

## Notes
Idle player definition: no mouse, keyboard, or voice action for a certain period of time.

## ConVar
```c
// After how many seconds idle players will be forced to switch to the spectator team. 0.0=disabled
l4d2_afk_manager_spec_time "90.0"

// After how many seconds idle spectator players (players who are forced to switch to spectator) will be kicked off the server. 0.0=disabled
l4d2_afk_manager_kick_time "180.0"

// How many players the server reaches before a player is kicked from the server.
l4d2_afk_manager_kick_players_limit "4"

// Forced switch to spectator exclusion TANK.
l4d2_afk_manager_exclude_tank "1"

// Forced switch to spectator exclusion admin.
l4d2_afk_manager_exclude_admin "1"

// Force switch to spectator exclusion dead player.
l4d2_afk_manager_exclude_dead "1"
```
