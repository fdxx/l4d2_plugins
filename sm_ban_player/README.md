中文 | [English](./README_EN.md)

## About
玩家封禁管理。

## Dependencies
- [ripext](https://github.com/ErikMinekus/sm-ripext)

## ConVar
```c
// 数据库配置名称 (addons/sourcemod/configs/databases.cfg)
// 将自动创建名为 l4d2_ban 的表，请确保表名没有重复。
sm_ban_player_cfg_name ""

// Steam API 密钥
// 用于离线将玩家添加到封禁数据库时获取玩家名称。
// https://steamcommunity.com/dev/apikey
sm_ban_player_key ""
```

## Command
```c
// 管理员命令，将玩家添加到封禁数据库。
// ReasonNum：1=作弊，2=捣乱，3=其他
sm_ban_player <SteamID> <ReasonNum>

// 管理员命令，将玩家从封禁数据库删除。
sm_unban_player <SteamID>

// 管理员命令，检查某个玩家是否被封禁。
sm_check_ban_player <SteamID>
```

## adminmenu
在 `sm_admin -> 玩家命令` 中添加了`BanPlayerEx`选项，用于从菜单中直接选择玩家进行封禁。
