中文 | [English](./README_EN.md)

## About
在合作模式中加入特感团队。

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## Notes
该插件只支持合作模式。

## ConVar
```c
// 特感玩家数量的最大限制。
l4d2_cz_max_special_limit "1"

// 每种类型的特感玩家数量限制。
l4d2_cz_smoker_limit "0"
l4d2_cz_boomer_limit "0"
l4d2_cz_hunter_limit "1"
l4d2_cz_spitter_limit "0"
l4d2_cz_jockey_limit "0"
l4d2_cz_charger_limit "0"
l4d2_cz_tank_limit "1"

// 特感玩家的产生时间
l4d2_cz_spawn_time "15"

// 管理员加入特感团队可以绕过 l4d2_cz_max_special_limit 的限制
l4d2_cz_admin_immunity "1"

// 阻止由 z_spawn_old 命令产生的特感玩家。
l4d2_cz_block_other_pz_respawn "1"
```

## Command
```c
// 控制台命令，加入特感团队。
sm_inf
sm_team3

// 控制台命令，加入 Tank 控制列表。
// 当 Tank 机器人产生后，将从列表中随机选取一个玩家控制 Tank。
sm_taketank
sm_tk
```

## Credits
- [control_zombies](https://github.com/umlka/l4d2/tree/main/control_zombies) 

