#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define FINALE_STAGE_TANK 8
bool g_bFinaleMap, g_bC7M3Map;
int g_TankCount;

public Plugin myinfo =
{
	name = "Finale Even-Numbered Tank Blocker",
	author = "Stabby, Visor",
	description = "Blocks even-numbered non-flow finale tanks.",
	version = "0.5",
	url = "http://github.com/ConfoglTeam/ProMod"
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, RoundStart_Timer);
}

public Action RoundStart_Timer(Handle timer)
{
	g_TankCount = 0;
	g_bFinaleMap = L4D_IsMissionFinalMap();
	g_bC7M3Map = IsC7M3Map();
}

public Action L4D2_OnChangeFinaleStage(int &finaleType, const char[] arg)
{
	if (!g_bC7M3Map && g_bFinaleMap && (finaleType == FINALE_STAGE_TANK))
	{
		g_TankCount++;
		if (g_TankCount >=2)
		{
			//LogMessage("阻止坦克产生");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

bool IsC7M3Map()
{
	static char sCurMap[256];
	GetCurrentMap(sCurMap, sizeof(sCurMap));
	return (strcmp(sCurMap, "c7m3_port", false) == 0);
}
