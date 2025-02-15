中文 | [English](./README_EN.md)

## About
大厅匹配管理。

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
如果要使用本插件，请移除所有有关大厅匹配的参数、设置、插件、各种预定 cookie 设置等。包括但不限于`sv_allow_lobby_connect_only`，`L4D_SetLobbyReservation`、`L4D_LobbyUnreserve`、`sv_cookie`等。

## ConVar

### l4d2_lmm_unreserve_type
- 1=彻底禁止大厅匹配，并且用内存补丁禁止了通过创建大厅方式连接到服务器。
- 2=大厅满时自动移除大厅匹配（对抗8人，合作4人），并且不再恢复。

### l4d2_lmm_reservation_modify_flags
当客户端创建大厅进入服务器时，服务器会应用客户端的创建大厅时选择的模式、难度、地图等，此 cvar 对此进行控制修改。见`RMFLAG_*`，要修改哪些将这个值进行相加。

```c
#define RMFLAG_NO_MODE_CHANGE        1  // 不要更改模式
#define RMFLAG_NO_DIFFICULTY_CHANGE  2  // 不要更改难度
#define RMFLAG_FORCE_ACCESS_PUBLIC   4  // 将大厅权限 private, friends 改为 public
#define RMFLAG_FORCE_OFFICIAL_MAP    8  // 将非官方地图改为官方地图C2M1
```

## Command
```c
// 打印大厅状态
sm_lobby_status

// 设置大厅参数
// 手动关闭大厅匹配示例：sm_lobby_set 0 0 0 1
sm_lobby_set <sCookie> <bAllowLobbyConnectOnly> <bHostingLobby> <bUpdateGameType>
```
