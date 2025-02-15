[中文](./README.md) | English

## About
Mutation mode script execution fix.

## Dependencies
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
If the server does not have lobby matching turned on, When entering the game for the first time, The Mutation scripts don't seem to execute correctly. For example, the first aid kit in the first round of Death's Door will not replace it with pill. So we reload the current map to fix it.

## ConVar
```c
// Reloads the current map after how many seconds after the server starts.
l4d2_mutation_fix_time "0.2"
```
