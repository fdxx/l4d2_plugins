
## About
在`sm_admin`菜单中添加一些开发工具。

## Dependencies
- left4dhooks


## Notes
可以在 `configs/adminmenu_sorting.txt` 中设置菜单显示的顺序。比如:

```vdf
"Menu"
{
    "l4d2_dev_menu"
    {
        "item"		"l4d2_dev_menu_kill"
        "item"		"l4d2_dev_menu_spawnspecial"
        "item"		"l4d2_dev_menu_godmode"
        "item"		"l4d2_dev_menu_noclip"
        "item"		"l4d2_dev_menu_teleport"
        "item"		"l4d2_dev_menu_giveitem"
        "item"		"l4d2_dev_menu_givehp"
        "item"		"l4d2_dev_menu_falldown"
        "item"		"l4d2_dev_menu_respawn"
        "item"		"l4d2_dev_menu_deprive"
        "item"		"l4d2_dev_menu_freeze"
    }
    // ...
}
```

## Command
除了菜单选项，另外提供一些管理员命令：
```c
// 管理员命令。杀死<特感|普通感染者|自己|幸存者|全部>
sm_kl <si|ci|me|sur|all>

// 管理员命令。对<自己|幸存者|特感>开启无敌模式，再次执行关闭。
sm_god <me|sur|si>

// 管理员命令。对<自己|幸存者|特感>开启穿墙模式，再次执行关闭。
sm_fly <me|sur|si>

// 管理员命令。传送<幸存者|特感>到自己的坐标处。
sm_tele <sur|si>
// 传送所有幸存者到安全屋。
sm_tele <saferoom>
// 传送自己到指定坐标处
sm_tele <pos0 pos1 pos2>

// 管理员命令。对<自己|幸存者|特感>回血。
sm_givehp <me|sur|si>
sm_rehp <me|sur|si>
```
