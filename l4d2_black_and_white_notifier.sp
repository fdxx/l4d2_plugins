#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.5"

ConVar g_cvGlow, g_cvSkullIcon, g_cvSurMaxIncapCount;
int g_iSurMaxIncapCount;
bool g_bGlow, g_bSkullIcon;
int g_iIconRef[MAXPLAYERS+1];

#define SKULL_ICON "materials/sprites/skull_icon.vmt"

public Plugin myinfo =
{
	name = "L4D2 Black and White Notifier",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_black_and_white_notifier_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvGlow = CreateConVar("l4d2_black_and_white_notifier_glow", "1", "黑白的玩家发光", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSkullIcon = CreateConVar("l4d2_black_and_white_notifier_skull_icon", "1", "黑白的玩家头上显示骷髅头图标", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvSurMaxIncapCount = FindConVar("survivor_max_incapacitated_count");

	GetCvars();

	g_cvGlow.AddChangeHook(ConVarChanged);
	g_cvSkullIcon.AddChangeHook(ConVarChanged);
	g_cvSurMaxIncapCount.AddChangeHook(ConVarChanged);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("revive_success", Event_Heal);
	HookEvent("heal_success", Event_Heal);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

void ConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bGlow = g_cvGlow.BoolValue;
	g_bSkullIcon = g_cvSkullIcon.BoolValue;
	g_iSurMaxIncapCount = g_cvSurMaxIncapCount.IntValue;
}

public void OnMapStart()
{
	CreateTimer(0.1, OnMapStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action OnMapStart_Timer(Handle timer)
{
	if (!IsModelPrecached(SKULL_ICON))
	{
		PrecacheModel(SKULL_ICON, true);
	}
	return Plugin_Continue;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (GetClientOfUserId(userid) > 0)
	{
		CreateTimer(0.1, PlayerSpawn_Timer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action PlayerSpawn_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsValidSur(client) && IsPlayerAlive(client))
	{
		RemoveIcon(client);
		ResetGlow(client);

		if (IsBlackAndWhite(client))
		{
			if (g_bGlow) SetGlow(client);
			if (g_bSkullIcon) SetSkullIcon(client);
		}
	}
	return Plugin_Continue;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int NewTeam = event.GetInt("team");

	if (client > 0 && NewTeam == 2)
	{
		CreateTimer(0.1, BlackAndWhiteCheck_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void Event_Heal(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.1, BlackAndWhiteCheck_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action BlackAndWhiteCheck_Timer(Handle timer)
{
	static int i;

	for (i = 1; i <= MaxClients; i++)
	{
		RemoveIcon(i);
	}

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (IsBlackAndWhite(i))
			{
				if (g_bGlow) SetGlow(i);
				if (g_bSkullIcon) SetSkullIcon(i);
			}
			else ResetGlow(i);
		}
	}

	return Plugin_Continue;
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSur(client))
	{
		RemoveIcon(client);
		ResetGlow(client);
	}
	return Plugin_Continue;
}

void ResetGlow(int client)
{
	SetEntProp(client, Prop_Send, "m_iGlowType", 0);
	SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
}

void RemoveIcon(int client)
{
	if (IsValidEntRef(g_iIconRef[client]))
	{
		RemoveEntity(g_iIconRef[client]);
		g_iIconRef[client] = 0;
	}	
}

bool IsValidEntRef(int ref)
{
	if (ref && EntRefToEntIndex(ref) != INVALID_ENT_REFERENCE)
		return true;
	return false;
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
	if (!IsValidEntRef(g_iIconRef[client]))
	{
		int iEnt = CreateEntityByName("env_sprite");
		if (iEnt == -1) return;
		
		g_iIconRef[client] = EntIndexToEntRef(iEnt);

		DispatchKeyValue(iEnt, "model", SKULL_ICON);
		DispatchKeyValue(iEnt, "spawnflags", "3");
		DispatchKeyValue(iEnt, "rendermode", "9");
		DispatchKeyValue(iEnt, "scale", "0.001");
		DispatchSpawn(iEnt);
		SetEntityRenderColor(iEnt, 255, 0, 0, 200);
		SetVariantString("!activator");
		AcceptEntityInput(iEnt, "SetParent", client);
		SetVariantString("eyes");
		AcceptEntityInput(iEnt, "SetParentAttachment");
		TeleportEntity(iEnt, view_as<float>({-3.0, 0.0, 9.0}), NULL_VECTOR, NULL_VECTOR);

		SDKUnhook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
		SDKHook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

Action Hook_SetTransmit(int entity, int client)
{
	static int ref;
	ref = EntIndexToEntRef(entity);
	if (ref != INVALID_ENT_REFERENCE)
	{
		switch (GetEntProp(client, Prop_Send, "m_iObserverMode"))
		{
			//mode -1未定义 0自己 1刚死亡时 2未知 3未知 4第一视角 5第三视角 6自由视角
			case 0:
			{
				if (ref == g_iIconRef[client])
					return Plugin_Handled;
			}
			case 4:
			{
				static int iTarget;
				iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				if (iTarget > 0 && ref == g_iIconRef[iTarget])
					return Plugin_Handled;
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

bool IsBlackAndWhite(int client)
{
	if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurMaxIncapCount)
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
