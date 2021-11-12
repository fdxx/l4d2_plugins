#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "L4D2 community5 fix",
	author = "fdxx",
	description = "第一次启动服务器时重置当前地图",
	version = "0.1",
	url = ""
}

public void OnConfigsExecuted()
{
	static bool bProcessed;

	if (!bProcessed)
	{
		bProcessed = true;
		CreateTimer(3.0, ChangeMap_Timer);
	}
}

public Action ChangeMap_Timer(Handle timer)
{
	char sMapName[256];
	if (GetCurrentMap(sMapName, sizeof(sMapName)) > 1)
	{
		ServerCommand("changelevel %s", sMapName);
	}
	else LogError("无法获取当前地图, 重置地图失败");
	return Plugin_Continue;
}
