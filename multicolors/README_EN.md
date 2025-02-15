[中文](./README.md) | English

## About
Add color support for chat messages.

## Notes
Supported color tags:
```txt
{default} {teamcolor} {lightgreen} {white} {blue} {red} {yellow} {orange} {olive}
```

There is no `{green}` tag. Since most `color.inc` greens will actually show yellow in l4d2, if your plugin depends on this plugin, change `{green}` to `{olive}` or `{yellow}`. 

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

