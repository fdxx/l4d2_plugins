#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
	name = "sm_mapex",
	author = "fdxx",
	version = "0.1",
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_mapex", Cmd_ChangeMap, ADMFLAG_ROOT);
}

Action Cmd_ChangeMap(int client, int args)
{
	if (args != 1)
	{
		char cmd[32];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Usage: %s <map>", cmd);
		return Plugin_Handled;
	}

	char map[256], foundmap[256];
	GetCmdArg(1, map, sizeof(map));
	FindMapResult result = FindMap(map, foundmap, sizeof(foundmap));

	if (result == FindMap_Found)
		ChangeMap(client, map);
	else if (result == FindMap_FuzzyMatch)
		ChangeMap(client, foundmap);
	else
		ReplyToCommand(client, "Map Not Found: %s", map);

	return Plugin_Handled;
}

void ChangeMap(int client, const char[] map)
{
	ReplyToCommand(client, "ChangeMap: %s", map);
	ServerCommand("changelevel %s", map);
}
