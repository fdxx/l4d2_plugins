[中文](./README.md) | English

## About
Player Ban Manager.

## Dependencies
- [ripext](https://github.com/ErikMinekus/sm-ripext)

## ConVar
```c
// Database configuration name (addons/sourcemod/configs/databases.cfg).
// A table named 'l4d2_ban' will be created automatically, make sure that there are no duplicate table names.
sm_ban_player_cfg_name ""

// Steam API key
// Used to get the player name when adding the player to the ban database offline.
// https://steamcommunity.com/dev/apikey
sm_ban_player_key ""
```

## Command
```c
// Admin command, add the player to the ban database.
// ReasonNum: 1=cheating, 2=troublemaking, 3=other
sm_ban_player <SteamID> <ReasonNum>

// Admin command. delete a player from the ban database.
sm_unban_player <SteamID>

// Admin command. check if a player is banned.
sm_check_ban_player <SteamID>
```

## adminmenu
Added `BanPlayerEx` option in `sm_admin -> Player Commands` to ban players directly from the menu.
