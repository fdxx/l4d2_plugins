中文 | [English](./README_EN.md)

## About
调整武器的属性。

## Notes
和原始插件的区别：
- 不再依赖 left4dhooks
- 删除了修改 Tank 伤害的东西。
- 添加了一些函数供其他插件使用。
- 支持三方图的自定义近战武器。

## Command
```c
// 管理员命令，设置武器属性。
// 名称见`l4d2_weapon_attributes.inc`
sm_weapon <name> <attr> <value>

// 控制台命令，查看武器属性值。
sm_weapon_attributes <weapon> [attribute]

// 管理员命令，重置武器属性。
sm_weapon_attributes_reset <weapon|@all>
```

## Functions
见`l4d2_weapon_attributes.inc`
```c
native bool L4D2_SetWepAttrValue(const char[] weapon, const char[] attribute, any setValue, any &oldValue = 0);
native bool L4D2_GetWepAttrValue(const char[] weapon, const char[] attribute, any &curValue);
native bool L4D2_ResetWepAttrValue(const char[] weapon);
```

## Credits
- [left4dhooks](https://forums.alliedmods.net/showthread.php?t=321696)
- [l4d2_weapon_attributes](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_weapon_attributes.sp)
