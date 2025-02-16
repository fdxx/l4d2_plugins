[中文](./README.md) | English

## About
Use the command to add or remove administrators.

## Command
```c
// Admin command. Add an administrator.
// name: doesn't have to be unique, empty string "" for anonymous administrators.
sm_addadmin <name> <SteamID/!IP/SteamName> <flag> [immunity] [password]

// Admin command. remove an administrators.
sm_deladmin <SteamID/!IP/SteamName>

// Admin command. View the list of administrators.
sm_listadmin
```

## Credits
- [admin-flatfile](https://github.com/alliedmodders/sourcemod/tree/master/plugins/admin-flatfile) 

