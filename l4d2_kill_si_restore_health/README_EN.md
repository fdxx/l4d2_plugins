[中文](./README.md) | English

## About
Restore health values after kill Special infected.

## Notes

Related plugin：[l4d2_lifesteal](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_lifesteal)

- `l4d2_lifesteal`: Restore health in real time when dealing damage to special infected.
- `l4d2_kill_si_restore_health`: Restore health only after killing special infected.


## ConVar
```c
// How much health is restored by kill each type of Special infected.
l4d2_kill_smoker_restore_health "0"
l4d2_kill_boomer_restore_health "0"
l4d2_kill_hunter_restore_health "0"
l4d2_kill_spitter_restore_health "0"
l4d2_kill_jockey_restore_health "0"
l4d2_kill_charger_restore_health "0"
l4d2_kill_witch_restore_health "10"
l4d2_kill_tank_restore_health "0"

// Maximum limit for Restore health values.
l4d2_kill_si_restore_health_Limit "110"
```
