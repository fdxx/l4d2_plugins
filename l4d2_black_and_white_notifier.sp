#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.3"

char logPath[PLATFORM_MAX_PATH];

ConVar CvarGlow, CvarSkullIcon, CvarMaxReviveCount;
int g_MaxReviveCount;
bool g_bGlow, g_bSkullIcon;
int g_iIcon[MAXPLAYERS+1] = {-1, ...};

#define SKULL_ICON "materials/sprites/skull_icon.vmt"

public Plugin myinfo =
{
	name = "L4D2 Black and White Notifier",
	author = "fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	BuildPath(Path_SM, logPath, sizeof(logPath), "logs/l4d2_black_and_white_notifier.log");

	CreateConVar("l4d2_black_and_white_notifier_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarGlow = CreateConVar("l4d2_black_and_white_notifier_glow", "1", "黑白的玩家发光", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarSkullIcon = CreateConVar("l4d2_black_and_white_notifier_skull_icon", "1", "黑白的玩家头上显示骷髅头图标", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarGlow.AddChangeHook(ConVarChanged);
	CvarSkullIcon.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart);

	HookEvent("revive_success", Event_Heal);
	HookEvent("heal_success", Event_Heal);
	HookEvent("player_death", Event_PlayerAction);
	HookEvent("player_spawn", Event_PlayerAction);
	HookEvent("player_team", Event_PlayerAction);
}

public void OnConfigsExecuted()
{
	CvarMaxReviveCount = FindConVar("survivor_max_incapacitated_count");
	g_MaxReviveCount = CvarMaxReviveCount.IntValue;
}

public void ConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bGlow = CvarGlow.BoolValue;
	g_bSkullIcon = CvarSkullIcon.BoolValue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	BlackAndWhiteCheck();
}

public void OnMapStart()
{
	if (!IsModelPrecached(SKULL_ICON))
	{
		PrecacheModel(SKULL_ICON, true);
	}
}

public void Event_Heal(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidSur(client))
	{
		BlackAndWhiteCheck();
	}
}

public void Event_PlayerAction(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSur(client))
	{
		BlackAndWhiteCheck();
	}
}

void BlackAndWhiteCheck()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsBaW(i))
			{
				if (g_bGlow) SetGlow(i);
				if (g_bSkullIcon) SetSkullIcon(i);
			}
			else Reset(i);
		}
	}
}

void SetGlow(int client)
{
	SetEntProp(client, Prop_Send, "m_iGlowType", 3);
	SetEntProp(client, Prop_Send, "m_glowColorOverride", 16777215);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 800);
}

// https://forums.alliedmods.net/showpost.php?p=2720796&postcount=18
void SetSkullIcon(int client)
{
	if (g_iIcon[client] > 0) return;

	int iEnt = CreateEntityByName("env_sprite");
	
	if (iEnt > 0)
	{
		DispatchKeyValue(iEnt, "model", SKULL_ICON);
		DispatchKeyValue(iEnt, "spawnflags", "3");
		DispatchKeyValue(iEnt, "rendermode", "9");
		int iColor[3];
		iColor = GetRandomColor();
		SetEntityRenderColor(iEnt, iColor[0], iColor[1], iColor[2], 200);
		DispatchKeyValue(iEnt, "scale", "0.001");
		DispatchSpawn(iEnt);
		SetVariantString("!activator");
		AcceptEntityInput(iEnt, "SetParent", client);
		SetVariantString("eyes");
		AcceptEntityInput(iEnt, "SetParentAttachment");
		TeleportEntity(iEnt, view_as<float>({-3.0, 0.0, 6.0}), NULL_VECTOR, NULL_VECTOR);
		g_iIcon[client] = iEnt;

		SDKUnhook(iEnt, SDKHook_SetTransmit, OnSetTransmit);
		SDKHook(iEnt, SDKHook_SetTransmit, OnSetTransmit);
	}
}

int[] GetRandomColor()
{
	static const int iColorGroup[][3] =
	{
		{255, 0, 0}, //red
		{0, 255, 0}, //green
		{0, 0, 255}, //blue
		{155, 0, 255}, //purple
		{0, 255, 255}, //cyan
		{255, 155, 0}, //orange
		{-1, -1, -1}, //white
		{255, 0, 150}, //pink
		{128, 255, 0}, //lime
		{128, 0, 0}, //maroon
		{0, 128, 128}, //teal
		{255, 255, 0}, //yellow
		{50, 50, 50}, //grey
		{50, 50, 50}, //gray
	};

	return iColorGroup[GetRandomInt(0, (sizeof(iColorGroup) - 1))];
}

public Action OnSetTransmit(int entity, int client)
{
	switch (GetEntProp(client, Prop_Send, "m_iObserverMode"))
	{
		//mode -1未定义 0自己 1刚死亡时 2未知 3未知 4第一视角 5第三视角 6自由视角
		case 0:
		{
			if (entity == g_iIcon[client])
			{
				return Plugin_Handled;
			}
		}
		case 4:
		{
			static int iTarget;
			iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if ((iTarget > 0) && (entity == g_iIcon[iTarget]))
			{
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

void Reset(int client)
{
	SetEntProp(client, Prop_Send, "m_iGlowType", 0);
	SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
	RemoveIcon(client);
}

void RemoveIcon(int client)
{
	if (g_iIcon[client] > 0 && IsValidEntity(g_iIcon[client]))
	{
		SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, OnSetTransmit);
		RemoveEntity(g_iIcon[client]);
		g_iIcon[client] = -1;
	}
}

bool IsBaW(int client)
{
	if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_MaxReviveCount)
	{
		return true;
	}
	return false;
}

bool IsValidSur(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}
