[中文](./README.md) | English

## About
tweaking of the attributes of weapons.

## Notes
Differences from the original plugin:
- No longer depends on left4dhooks.
- Removed the stuff that modifies tank damage.
- Added some functions for other plugins to use.
- Support for custom melee weapons for unofficial maps (Need [unlock](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_melee_spawn_control)).

## Command
```c
// Admin command, set weapon attributes.
// Names see `l4d2_weapon_attributes.inc`
sm_weapon <name> <attr> <value>

// Console command, view weapon attribute values.
sm_weapon_attributes <weapon> [attribute]

// Admin command, reset weapon attributes.
sm_weapon_attributes_reset <weapon|@all>
```

## Functions
See `l4d2_weapon_attributes.inc`
```c
native bool L4D2_SetWepAttrValue(const char[] weapon, const char[] attribute, any setValue, any &oldValue = 0);
native bool L4D2_GetWepAttrValue(const char[] weapon, const char[] attribute, any &curValue);
native bool L4D2_ResetWepAttrValue(const char[] weapon);
```

## Credits
- [left4dhooks](https://forums.alliedmods.net/showthread.php?t=321696)
- [l4d2_weapon_attributes](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_weapon_attributes.sp)
