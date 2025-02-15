中文 | [English](./README_EN.md)

## About
击杀特感掉落礼品。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## ConVar
```c
// 礼品盒掉落的概率。值范围 0.0-1.0
l4d2_gift_chance "0.03"

// 通知奖励信息。
// 0=无, 1=聊天消息, 2=播放声音, 3=两者.
l4d2_gift_notify "3"

// 礼品盒自动消失的时间（以秒为单位），0=永久。
l4d2_gift_time "75"

// 配置文件路径
l4d2_gift_cfg "data/l4d2_gift.cfg"
```

## Command
```c
// 管理员命令，重载配置文件。
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
- **CheatCommand**: 客户端作弊命令。如`give xx`。
- **ClientCommand**: 客户端普通命令。 如`RegConsoleCmd`创建的命令。
- **ServerCommand**: 服务端命令。如`RegServerCmd/RegAdminCmd`创建的命令。

### command
执行的命令字符串

### weights
该奖品的权重，当礼品盒被触碰时，将根据这个权重比例随机选取一个奖品。

### message
打印的聊天消息，见`l4d2_gift_notify`。
