[中文](./README.md) | English

## About
Limit the number of Event Zombie Horde.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## ConVar
```c
// When there are only how many infected left, sent notification.
l4d2_horde_equaliser_notify_num "30"

// When Tank is alive, pause horde. 1=Enable, 0=Disable.
l4d2_horde_equaliser_pause_when_tank_alive "1"

// Configuration file path
l4d2_horde_equaliser_cfg "data/mapinfo.txt"
```

## mapinfo.txt
Set the number of event horde for each map. Example:

```vdf
"c2m2_fairgrounds"
{
    "horde_limit"    "120"
}
```

## Credits
- [l4d2_horde_equaliser](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_horde_equaliser.sp) 

