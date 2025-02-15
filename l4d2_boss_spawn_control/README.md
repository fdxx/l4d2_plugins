中文 | [English](./README_EN.md)

## About
每关产生一个 boss (Tank/Witch)

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## ConVar
```c
// 每关产生一个 boss。1=启用, 0=禁用。
l4d2_boss_spawn_control_tank_enable "1"
l4d2_boss_spawn_control_witch_enable "1"

// 阻止其他方式产生的 boss。1=启用, 0=禁用。
l4d2_boss_spawn_control_block_other_tank_spawn "1"
l4d2_boss_spawn_control_block_other_witch_spawn "1"

// mapinfo.txt文件路径。
// 见下文
l4d2_boss_spawn_control_mapinfo_path "data/mapinfo.txt"
```

## Command
```c
// 控制台命令，打印当前 flow 距离百分比。
// 见下文
sm_boss
sm_tank
sm_witch
sm_cur
sm_current

// 管理员命令，添加/删除 boss 产生的地图
// 见下文
sm_tank_spawn_map <add|remove> <MapName>
sm_witch_spawn_map <add|remove> <MapName>


// 管理员命令，添加/删除 boss 产生的静态地图
sm_tank_static_map <add|remove> <MapName>
sm_witch_static_map <add|remove> <MapName>


// 管理员命令，重新设置当前地图 boss 产生的 flow 距离百分比。
// 离开安全区域后无法使用
sm_reflow
```

## sm_boss

命令输出示例：
```c
Current: 30%
Tank: 50%
witch: 20%
```

一些特殊值解释：
```c
// 当前地图会固定产生 Tank，比如结局地图 c1m4_atrium 、机关克 c7m1_docks 等等。由 sm_tank_static_map 命令添加。
Tank: Static

// 当前地图没有使用命令添加 Tank 生成，游戏默认控制是否产生 Tank。
Tank: Defaul

// 当前地图不会产生 Tank，这不应该发生，通常是插件没有找到产生的位置。
Tank: None
```

## sm_tank_spawn_map

一个开箱即用的添加 boss 产生的地图的示例：

<details>
<summary>点击展开</summary>

```c
// Tank
sm_tank_spawn_map add c1m1_hotel
sm_tank_spawn_map add c1m2_streets
sm_tank_spawn_map add c1m3_mall

sm_tank_spawn_map add c2m1_highway
sm_tank_spawn_map add c2m2_fairgrounds
sm_tank_spawn_map add c2m3_coaster
sm_tank_spawn_map add c2m4_barns

sm_tank_spawn_map add c3m1_plankcountry
sm_tank_spawn_map add c3m2_swamp
sm_tank_spawn_map add c3m3_shantytown

sm_tank_spawn_map add c4m1_milltown_a
sm_tank_spawn_map add c4m2_sugarmill_a
sm_tank_spawn_map add c4m3_sugarmill_b
sm_tank_spawn_map add c4m4_milltown_b

sm_tank_spawn_map add c5m1_waterfront
sm_tank_spawn_map add c5m2_park
sm_tank_spawn_map add c5m3_cemetery
sm_tank_spawn_map add c5m4_quarter

sm_tank_spawn_map add c6m1_riverbank
sm_tank_spawn_map add c6m2_bedlam

sm_tank_spawn_map add c7m2_barge

sm_tank_spawn_map add c8m1_apartment
sm_tank_spawn_map add c8m2_subway
sm_tank_spawn_map add c8m3_sewers
sm_tank_spawn_map add c8m4_interior

sm_tank_spawn_map add c9m1_alleys

sm_tank_spawn_map add c10m1_caves
sm_tank_spawn_map add c10m2_drainage
sm_tank_spawn_map add c10m3_ranchhouse
sm_tank_spawn_map add c10m4_mainstreet

sm_tank_spawn_map add c11m1_greenhouse
sm_tank_spawn_map add c11m2_offices
sm_tank_spawn_map add c11m3_garage
sm_tank_spawn_map add c11m4_terminal

sm_tank_spawn_map add c12m1_hilltop
sm_tank_spawn_map add c12m2_traintunnel
sm_tank_spawn_map add c12m3_bridge
sm_tank_spawn_map add c12m4_barn

sm_tank_spawn_map add c13m1_alpinecreek
sm_tank_spawn_map add c13m3_memorialbridge

sm_tank_spawn_map add c14m1_junkyard

sm_tank_static_map add c1m4_atrium
sm_tank_static_map add c2m5_concert
sm_tank_static_map add c3m4_plantation
sm_tank_static_map add c4m5_milltown_escape
sm_tank_static_map add c5m5_bridge
sm_tank_static_map add c6m3_port
sm_tank_static_map add c7m3_port
sm_tank_static_map add c8m5_rooftop
sm_tank_static_map add c9m2_lots
sm_tank_static_map add c10m5_houseboat
sm_tank_static_map add c11m5_runway
sm_tank_static_map add c12m5_cornfield
sm_tank_static_map add c13m4_cutthroatcreek
sm_tank_static_map add c14m2_lighthouse

sm_tank_static_map add c7m1_docks
sm_tank_static_map add c13m2_southpinestream


// Witch
sm_witch_spawn_map add c1m1_hotel
sm_witch_spawn_map add c1m2_streets
sm_witch_spawn_map add c1m3_mall

sm_witch_spawn_map add c2m1_highway
sm_witch_spawn_map add c2m2_fairgrounds
sm_witch_spawn_map add c2m3_coaster
sm_witch_spawn_map add c2m4_barns

sm_witch_spawn_map add c3m1_plankcountry
sm_witch_spawn_map add c3m2_swamp
sm_witch_spawn_map add c3m3_shantytown

sm_witch_spawn_map add c4m1_milltown_a
sm_witch_spawn_map add c4m3_sugarmill_b
sm_witch_spawn_map add c4m4_milltown_b

sm_witch_spawn_map add c5m1_waterfront
sm_witch_spawn_map add c5m2_park
sm_witch_spawn_map add c5m3_cemetery
sm_witch_spawn_map add c5m4_quarter

sm_witch_spawn_map add c6m2_bedlam

sm_witch_spawn_map add c7m1_docks
sm_witch_spawn_map add c7m2_barge

sm_witch_spawn_map add c8m1_apartment
sm_witch_spawn_map add c8m2_subway
sm_witch_spawn_map add c8m3_sewers
sm_witch_spawn_map add c8m4_interior

sm_witch_spawn_map add c9m1_alleys

sm_witch_spawn_map add c10m1_caves
sm_witch_spawn_map add c10m2_drainage
sm_witch_spawn_map add c10m3_ranchhouse
sm_witch_spawn_map add c10m4_mainstreet

sm_witch_spawn_map add c11m1_greenhouse
sm_witch_spawn_map add c11m2_offices
sm_witch_spawn_map add c11m3_garage
sm_witch_spawn_map add c11m4_terminal

sm_witch_spawn_map add c12m1_hilltop
sm_witch_spawn_map add c12m2_traintunnel
sm_witch_spawn_map add c12m3_bridge
sm_witch_spawn_map add c12m4_barn

sm_witch_spawn_map add c13m1_alpinecreek
sm_witch_spawn_map add c13m2_southpinestream
sm_witch_spawn_map add c13m3_memorialbridge

sm_witch_spawn_map add c14m1_junkyard

sm_witch_static_map add c6m1_riverbank
```

</details>

## mapinfo.txt
添加禁止 boss 产生的路段，来源于：[zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework)，例如：
```vdf
"c2m2_fairgrounds"
{
    "tank_ban_flow"
    {
        "Alley choke to up top"
        {
            "min"		"56"
            "max"		"68"
        }
    }
    "witch_ban_flow"
    {
        "Ladder"
        {
            "min"		"54"
            "max"		"58"
        }
        "Start of event"
        {
            "min"		"78"
            "max"		"87"
        }
    }
}
```

## Functions
见`l4d2_boss_spawn_control.inc`
```c
native float L4D2_GetBossSpawnFlow(int type);
```

## Change Log

**v3.1**
- 删除 `Native L4D2_CanSpawnBoss`