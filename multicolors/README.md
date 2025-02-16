中文 | [English](./README_EN.md)

## About
为聊天消息增加颜色支持。

## Notes
支持的颜色标签：
```txt
{default} {teamcolor} {lightgreen} {white} {blue} {red} {yellow} {orange} {olive}
```

没有`{green}`标签。因为在 l4d2 中，大多数`color.inc`的绿色实际上会显示黄色，如果你的插件要依赖这个插件，请将`{green}`更改到`{olive}`或`{yellow}`。

## Functions
```c
CPrintToChat(int client, const char[] message, any ...);
CPrintToChatAll(const char[] message, any ...);
CPrintToChatEx(int client, int author, const char[] message, any ...);
CPrintToChatAllEx(int author, const char[] message, any ...);
```

## Credits
- [Multi-Colors](https://github.com/Bara/Multi-Colors) 
- [colors.inc](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/include/colors.inc)

