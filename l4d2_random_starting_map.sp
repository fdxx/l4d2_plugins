#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "L4D2 Random starting map",
	author = "fdxx",
	description = "L4D2 Random starting map",
	version = "1.4",
	url = ""
}

public void OnPluginStart()
{
	CreateTimer(30.5, ChangeMap);
	LogMessage("[随机启动地图] 开始切换至随机地图");
}

public Action ChangeMap(Handle timer)
{
	if (!HaveRealPlayer())
	{
		switch (GetRandomInt(1, 14))
		{
			case 1: ServerCommand("changelevel c1m1_hotel");
			case 2: ServerCommand("changelevel c2m1_highway");
			case 3: ServerCommand("changelevel c3m1_plankcountry");
			case 4: ServerCommand("changelevel c4m1_milltown_a");
			case 5: ServerCommand("changelevel c5m1_waterfront");
			case 6: ServerCommand("changelevel c6m1_riverbank");	
			case 7: ServerCommand("changelevel c7m1_docks");
			case 8: ServerCommand("changelevel c8m1_apartment");
			case 9: ServerCommand("changelevel c9m1_alleys");
			case 10: ServerCommand("changelevel c10m1_caves");
			case 11: ServerCommand("changelevel c11m1_greenhouse");
			case 12: ServerCommand("changelevel c12m1_hilltop");
			case 13: ServerCommand("changelevel c13m1_alpinecreek");
			case 14: ServerCommand("changelevel c14m1_junkyard");
		}
		LogMessage("[随机启动地图] 成功切换到随机地图");
	}
	else LogMessage("[随机启动地图] 换图失败, 服务器还有真实玩家存在");
	return Plugin_Continue;
}

bool HaveRealPlayer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return true;
		}
	}
	return false;
}
