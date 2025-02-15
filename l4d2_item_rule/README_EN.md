[中文](./README.md) | English


## About
Controls items that spawn on the map.

## Dependencies
- [l4d2_weapons_spawn](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_weapons_spawn) 
- left4dhooks

## Notes
- By default, this plugin doesn't do anything. You need to add item spawn rules using commands.
- The item names used by the commands are viewed from `l4d2_weapons_spawn.inc`.

## ConVar
```c
// Replace final map medkit with pills.
l4d2_item_rule_finalmap_pills "0"

// Remove item boxes. (Chests containing a large number of items on the c6m1 map).
l4d2_item_rule_remove_box "0"
```

## Command
```c
// Items given after leaving the safe zone. (will invoke the give cheat command).
sm_start_item <item1> [item2] ...

// Add item replace rules.
sm_item_replace <oldItem> <newItem>

// Add item limit rules.
sm_item_limit <item> <limitValue>

// Add item spawn rules.
sm_item_spawn <map> <item> <origin> <angles> [count] [movetype]

// Reset item rules.
sm_item_rule_reset <start_item|item_replace|item_limit|item_spawn>
```

## Example
An out of the box setup example. Only T1 guns and pills:

<details>
<summary>Click to expand</summary>

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
