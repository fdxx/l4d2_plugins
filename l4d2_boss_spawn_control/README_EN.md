[中文](./README.md) | English

## About
Each chapter spawn a boss (Tank/Witch).

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## ConVar
```c
// Each chapter spawn a boss. 1=Enable, 0=Disable.
l4d2_boss_spawn_control_tank_enable "1"
l4d2_boss_spawn_control_witch_enable "1"

// Block boss spawned by other means. 1=Enable, 0=Disable.
l4d2_boss_spawn_control_block_other_tank_spawn "1"
l4d2_boss_spawn_control_block_other_witch_spawn "1"

// Path to the mapinfo.txt file.
// See below.
l4d2_boss_spawn_control_mapinfo_path "data/mapinfo.txt"
```

## Command
```c
// Console command. Prints the current flow distance percentage.
// See below.
sm_boss
sm_tank
sm_witch
sm_cur
sm_current

// Admin command. Add/remove boss spawned maps.
// See below.
sm_tank_spawn_map <add|remove> <MapName>
sm_witch_spawn_map <add|remove> <MapName>


// Admin command. Add/remove boss spawned static maps.
sm_tank_static_map <add|remove> <MapName>
sm_witch_static_map <add|remove> <MapName>


// Admin command. Reset the flow percentage spawned by the current map boss
// Cannot be used after leaving the safe zone.
sm_reflow
```

## sm_boss

Example of command output:
```c
Current: 30%
Tank: 50%
witch: 20%
```

Some special values explained:
```c
// The current map is static spawn Tanks, such as the final map c1m4_atrium, event map c7m1_docks, and so on. Added by the sm_tank_static_map command.
Tank: Static

// The current map does not have a command to add Tank spawning, the game defaults to controlling whether or not Tank are spawned.
Tank: Defaul

// The current map doesn't spawn Tank, which shouldn't happen, usually because the plugin doesn't find the location where it spawns.
Tank: None
```

## sm_tank_spawn_map

An out-of-the-box example of adding a boss spawned map:

<details>
<summary>Click to expand</summary>

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
Add section of road that prohibit boss spawn, from: [zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework), for example:

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
See`l4d2_boss_spawn_control.inc`
```c
native float L4D2_GetBossSpawnFlow(int type);
```

## Change Log

**v3.1**
- Delete `Native L4D2_CanSpawnBoss`
