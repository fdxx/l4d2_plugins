[中文](./README.md) | English

## About
lobby match manager.

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
If you want to use this plugin, please remove: all parameters, settings, plugins, various reservation cookie settings, etc. regarding lobby matching. including but not limited to: `sv_allow_lobby_connect_only`, `L4D_SetLobbyReservation`, `L4D_LobbyUnreserve`, `sv_cookie`, etc.

## ConVar

### l4d2_lmm_unreserve_type
- 1=Lobby match is completely disabled, and connecting to the server by creating a lobby is disabled with a memory patch.
- 2=Lobby match are auto removed when the lobby is full (8-player versus, 4-player coop) and will not be restored. 


### l4d2_lmm_reservation_modify_flags
When a client creates a lobby and enters the server, the server applies the mode, difficulty, map, etc. chosen by the client when creating the lobby, This cvar controls modifications to this. See `RMFLAG_*`. To modify which, sum this value.

```c
#define RMFLAG_NO_MODE_CHANGE        1  // no mode change
#define RMFLAG_NO_DIFFICULTY_CHANGE  2  // no difficulty change 
#define RMFLAG_FORCE_ACCESS_PUBLIC   4  // private, friends -> public
#define RMFLAG_FORCE_OFFICIAL_MAP    8  // unofficial map -> official map C2M1
```

## Command
```c
// Print lobby status
sm_lobby_status

// Setting lobby Parameters
// Example of manually turning off lobby matching: sm_lobby_set 0 0 0 1
sm_lobby_set <sCookie> <bAllowLobbyConnectOnly> <bHostingLobby> <bUpdateGameType>
```
