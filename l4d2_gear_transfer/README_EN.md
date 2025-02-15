[中文](./README.md) | English

## About
Transfer of thrown items and medical items:
- Survivor bots can auto pick up nearby items.
- Survivor bots can auto give items to players who do not have the item.
- Allow players to give items to other players (press R key)

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## Notes
The differences from the original plugin are:
- L4D2 support only.
- Improvements to item pickup and give (SDKCall).
- No item exchange function.

## ConVar
```c
// How close the bot must be to give items.
l4d2_gear_transfer_bot_give_dist "150.0"

// How close the player must be to give item.
l4d2_gear_transfer_player_give_dist "256.0"

// How close the bot must be to pickup item.
l4d2_gear_transfer_dist_grab "150.0"

// How often to check for bots auto pickup/give items. 
// 0.0=disable auto pickup/give items.
l4d2_gear_transfer_check_time "1.0"

// Delay time for bots to auto pickup/give items after round_start.
// -1.0=until player_left_safe_area, 0.0=no delay, greater than 0.0=delay time.
l4d2_gear_transfer_delay_check "0.6"

// After a bot receives a given item, How long before it can be given to another player again.
l4d2_gear_transfer_delay_transfer "10.0"
```

## Credits
- [l4d_gear_transfer](https://forums.alliedmods.net/showthread.php?t=137616) 


