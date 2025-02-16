[中文](./README.md) | English

## About
Kill special infected drops gifts.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## ConVar
```c
// The probability that the gift box will be dropped. Value range 0.0-1.0
l4d2_gift_chance "0.03"

// Notification of the reward message.
// 0=none, 1=chat message, 2=play sound, 3=both.
l4d2_gift_notify "3"

// Time (in seconds) for the gift box to auto disappear.
// 0=permanent.
l4d2_gift_time "75"

// Configuration file path.
l4d2_gift_cfg "data/l4d2_gift.cfg"
```


## Command
```c
// Admin command. Reloads the configuration file.
sm_award_reload
```

## l4d2_gift.cfg

```vdf
"AwardConfig"
{
    "0"
    {
        "type"			"CheatCommand"
        "command"		"give weapon_sniper_awp"
        "weights"		"20"
        "message"		"已获得AWP"
    }
    "1"
    {
        "type"			"CheatCommand"
        "command"		"give weapon_defibrillator"
        "weights"		"80"
        "message"		"已获得电击器"
    }
}
```

### type
- **CheatCommand**: Client cheat command. Such as `give xx`.
- **ClientCommand**: Normal client command. Such as created by `RegConsoleCmd`.
- **ServerCommand**: Server commands. Such as created by `RegServerCmd/RegAdminCmd`.

### command
The command string to execute.

### weights
The weight of the award. When the gift box is touched, an award will be randomly selected based on this weight proportion.

### message
Print chat message, see `l4d2_gift_notify`.
