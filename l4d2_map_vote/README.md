中文 | [English](./README_EN.md)

## About
地图投票。自动解析地图文件中名称。

## Dependencies
- [l4d2_nativevote](https://github.com/fdxx/l4d2_nativevote)
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## ConVar
```c
// 管理员是否绕过 `*TeamFlags`
// 见 sm_mapvote_attribute
l4d2_map_vote_adminteamflags "1"

// 更换地图时是否清理分数。
// 主要用于对抗模式。
l4d2_map_vote_clearscores "1"
```

## Command
```c
// 管理员命令。投票的一些设置。
// 见 https://github.com/fdxx/l4d2_config_vote
sm_mapvote_attribute <MenuTeamFlags|VoteTeamFlags|AdminOneVotePassed|AdminOneVoteAgainst> <value>

// 管理员命令。导出地图的kv信息
sm_missions_export <filename>

// 管理员命令。vpk文件热加载。
sm_missions_reload

// 管理员命令。清理分数
sm_clear_scores
```

## Translations
支持对地图名称进行翻译，但具体章节名称除外。见`l4d2_map_vote.phrases.txt`

默认只对官方地图进行了翻译，如果你想添加或修改，请注意选项名称必须和 missions 文件中`DisplayTitle`对应。可使用`sm_missions_export`导出查看。

