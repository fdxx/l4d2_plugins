/**
  * Modify m_flPlaybackRate based on the following:
  * 
  * Ellis Hunter Pounce Getup Anim:    79 Frames.
  * Other Survivors Pounce Getup Anim: 64 Frames.
  * 79 / 64 = 1.234375
*/

#pragma semicolon 1
#pragma newdecls required

#define VERSION "1.1"

#include <sourcemod>
#include <dhooks>
#include <sdkhooks>

#define ANIM_ELLIS_HUNTER_GETUP 625

ConVar
	g_cvEnable,
	g_cvRate;

bool
	g_bEnable,
	g_bHookAnim[MAXPLAYERS];

float
	g_fRate;

public Plugin myinfo =
{
    name = "L4D2 Ellis Hunter Band aid Fix",
    author = "Sir (with pointers from Rena), fdxx",
    description = "Band-aid fix for Ellis' getup not matching the other Survivors",
    version = VERSION,
    url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	InitGamaData();
	
	CreateConVar("l4d2_ellis_hunter_bandaid_fix_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("l4d2_ellis_hunter_bandaid_fix_enable", "1", "", FCVAR_NONE);
	g_cvRate = CreateConVar("l4d2_ellis_hunter_bandaid_fix_rate", "1.3", "", FCVAR_NONE);

	GetCvars();

	g_cvEnable.AddChangeHook(OnConVarChanged);
	g_cvRate.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", Event_BotReplacedPlayer);

	HookEvent("pounce_end", Event_PounceEnd);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnable = g_cvEnable.BoolValue;
	g_fRate = g_cvRate.FloatValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	static int i;
	for (i = 0; i <= MaxClients; i++)
	{
		g_bHookAnim[i] = false;
	}
}

void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	g_bHookAnim[GetClientOfUserId(event.GetInt("player"))] = false;
}

public void OnClientDisconnect(int client)
{
	g_bHookAnim[client] = false;
}

void Event_PounceEnd(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bEnable) return;

	static int client;
	client = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidSur(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_survivorCharacter") == 3 && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		g_bHookAnim[client] = true;
	}
}

MRESReturn mreOnSelectWeightedSequencePost(int client, DHookReturn hReturn)
{
	if (client > 0 && client <= MaxClients)
	{
		if (!g_bHookAnim[client]) return MRES_Ignored;

		static int iSequence;
		iSequence = hReturn.Value;

		if (iSequence == ANIM_ELLIS_HUNTER_GETUP)
		{
			g_bHookAnim[client] = false;
			SDKUnhook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
			SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
		}
	}

	return MRES_Ignored;
}

void OnClientPostThinkPost(int client)
{
	// We can assume client is valid as SDKUnhook is called automatically on disconnect.
	// Check the team and sequence, should suffice.
	if (GetClientTeam(client) == 2 && GetEntProp(client, Prop_Send, "m_nSequence") == ANIM_ELLIS_HUNTER_GETUP)
	{
		//PrintToServer("m_flPlaybackRate = %.2f", GetEntPropFloat(client, Prop_Send, "m_flPlaybackRate"));
		SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fRate);
	}
	else SDKUnhook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
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

void InitGamaData()
{
	GameData hGameData = new GameData("l4d2_ellis_hunter_bandaid_fix");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_ellis_hunter_bandaid_fix.txt\" gamedata.");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CBaseAnimating::SelectWeightedSequence");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: CBaseAnimating::SelectWeightedSequence");
	if (!dDetour.Enable(Hook_Post, mreOnSelectWeightedSequencePost))
		SetFailState("Failed to detour post: CBaseAnimating::SelectWeightedSequence");

	delete hGameData;
}
