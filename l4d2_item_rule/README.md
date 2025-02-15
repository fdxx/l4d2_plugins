中文 | [English](./README_EN.md)

## About
控制地图上产生的物品。

## Dependencies
- [l4d2_weapons_spawn](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_weapons_spawn) 
- left4dhooks 

## Notes
- 默认情况下，这个插件不做任何事情，需要使用命令添加物品产生规则。
- 命令使用的物品名称从`l4d2_weapons_spawn.inc`中查看

## ConVar
```c
// 将最终地图上急救包替换成药。
l4d2_item_rule_finalmap_pills "0"

// 删除物品箱。（c6m1地图上含有大量物品的箱子）
l4d2_item_rule_remove_box "0"
```

## Command
```c
// 离开安全区域后给的物品。（将调用give作弊命令）
sm_start_item <item1> [item2] ...

// 添加物品替换规则。
sm_item_replace <oldItem> <newItem>

// 添加物品限制规则。
sm_item_limit <item> <limitValue>

// 添加物品产生规则。
sm_item_spawn <map> <item> <origin> <angles> [count] [movetype]

// 重置物品规则。
sm_item_rule_reset <start_item|item_replace|item_limit|item_spawn>
```

## Example
一个开箱即用的设置示例，只有小枪和药：
<details>
<summary>点击展开</summary>

```c
sm_cvar l4d2_item_rule_finalmap_pills 1
sm_cvar l4d2_item_rule_remove_box 1

sm_item_rule_reset start_item
sm_item_rule_reset item_replace
sm_item_rule_reset item_limit
sm_item_rule_reset item_spawn

sm_start_item weapon_pain_pills health ammo

sm_item_replace weapon_smg_mp5			weapon_smg
sm_item_replace weapon_rifle			weapon_shotgun_chrome
sm_item_replace weapon_rifle_desert		weapon_pumpshotgun
sm_item_replace weapon_rifle_ak47		weapon_smg_silenced
sm_item_replace weapon_rifle_sg552		weapon_smg
sm_item_replace weapon_rifle_m60		weapon_smg
sm_item_replace weapon_grenade_launcher	weapon_smg_silenced

sm_item_replace weapon_autoshotgun		weapon_pumpshotgun
sm_item_replace weapon_shotgun_spas		weapon_shotgun_chrome

sm_item_replace weapon_hunting_rifle	weapon_smg_silenced
sm_item_replace weapon_sniper_military	weapon_pumpshotgun
sm_item_replace weapon_sniper_awp		weapon_smg
sm_item_replace weapon_sniper_scout		weapon_shotgun_chrome

sm_item_limit weapon_first_aid_kit 0
sm_item_limit weapon_pain_pills 4
sm_item_limit weapon_adrenaline 0
sm_item_limit weapon_defibrillator 0
sm_item_limit weapon_molotov 0
sm_item_limit weapon_pipe_bomb 0
sm_item_limit weapon_vomitjar 0
sm_item_limit weapon_upgradepack_incendiary 0
sm_item_limit weapon_upgradepack_explosive 0
sm_item_limit weapon_chainsaw 0
sm_item_limit weapon_gascan 0
sm_item_limit weapon_propanetank 0
sm_item_limit weapon_oxygentank 0
sm_item_limit weapon_fireworkcrate 0
sm_item_limit upgrade_laser_sight 0

sm_item_spawn "c4m3_sugarmill_b" "weapon_shotgun_chrome" "3552,-1767,263" "0,180,90" 3
sm_item_spawn "c4m3_sugarmill_b" "weapon_smg_silenced" "3549,-1738,263" "0,180,90" 3

sm_item_spawn "c4m4_milltown_b" "weapon_shotgun_chrome" "-3320,7788,156" "0,268,270" 3
sm_item_spawn "c4m4_milltown_b" "weapon_smg_silenced" "-3336,7788,156" "0,285,270" 3

// Dynamically spawned during the game.
sm_cvar director_convert_pills 0
sm_cvar sv_infected_ceda_vomitjar_probability 0.0
sm_cvar z_fallen_max_count 0
```

</details>
