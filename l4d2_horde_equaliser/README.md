中文 | [English](./README_EN.md)

## About
限制机关尸潮的数量。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## ConVar
```c
// 剩下这个数量的感染者时会进行通知。
l4d2_horde_equaliser_notify_num "30"

// Tank 活着时暂停机关尸潮。1=启用，0=禁用
l4d2_horde_equaliser_pause_when_tank_alive "1"

// 配置文件路径
l4d2_horde_equaliser_cfg "data/mapinfo.txt"
```

## mapinfo.txt
为每个地图设置机关尸潮的数量。例如：

```vdf
"c2m2_fairgrounds"
{
    "horde_limit"    "120"
}
```

## Credits
- [l4d2_horde_equaliser](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_horde_equaliser.sp) 

