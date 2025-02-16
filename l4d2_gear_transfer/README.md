中文 | [English](./README_EN.md)

## About
投掷物品和医疗物品的转移：
- 幸存者机器人可以自动拾取附近的物品。
- 幸存者机器人可以自动将物品赠送给没有该物品的玩家。
- 允许玩家将物品赠送给其他玩家（R键）

## Dependencies
- [sourcescramble](https://github.com/nosoop/SMExt-SourceScramble) 
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## Notes
和原始插件的区别在于：
- 仅支持L4D2
- 改进物品拾取和给予的方法（SDKCall）
- 没有物品交换功能

## ConVar
```c
// 机器人必须距离多近才能给物品。
l4d2_gear_transfer_bot_give_dist "150.0"

// 玩家必须距离多近才能给物品。
l4d2_gear_transfer_player_give_dist "256.0"

// 机器人必须距离多近才能拾取物品。
l4d2_gear_transfer_dist_grab "150.0"

// 机器人自动拾取/给予物品的检查频率。
// 0.0=禁用自动拾取/给予物品
l4d2_gear_transfer_check_time "1.0"

// round_start 后，机器人自动拾取/给予物品的延迟时间。
// -1.0=直到玩家离开安全区域, 0.0=没有延迟, 大于0.0=延迟时间。
l4d2_gear_transfer_delay_check "0.6"

// 机器人在收到给予的物品后多长时间才能再次给其他玩家。
l4d2_gear_transfer_delay_transfer "10.0"
```

## Credits
- [l4d_gear_transfer](https://forums.alliedmods.net/showthread.php?t=137616) 

