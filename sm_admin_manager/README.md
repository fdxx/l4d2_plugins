中文 | [English](./README_EN.md)

## About
使用命令添加或删除管理员。

## Command
```c
// 管理员命令。添加管理员。
// name: 不必是唯一的，空字符串""为匿名管理员。
sm_addadmin <name> <SteamID/!IP/SteamName> <flag> [immunity] [password]

// 管理员命令。删除管理员。
sm_deladmin <SteamID/!IP/SteamName>

// 管理员命令。查看管理员列表。
sm_listadmin
```

## Credits
- [admin-flatfile](https://github.com/alliedmodders/sourcemod/tree/master/plugins/admin-flatfile) 

