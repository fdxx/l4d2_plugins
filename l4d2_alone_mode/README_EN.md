[中文](./README.md) | English

## About
When controlled by smoker, hunter, jockey, or charger in single player mode, it automatically releases the control and print the remaining health of the special infected.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## Notes
Single player mode is defined as meeting one of the following conditions:
- Only 1 survivor player.
- Only 1 special infected player.
- Both of the above.

## ConVar
```c
// Damage value attached to survivor players when releases control.
l4d2_alone_damage_smoker "5.0"
l4d2_alone_damage_hunter "9.0"
l4d2_alone_damage_jockey "9.0"
l4d2_alone_damage_charger "0.0"
```

## Command
```c
// Console Commands. Turns single player mode on or off manually.
// This command is not available in multiplayer.
sm_alone
```