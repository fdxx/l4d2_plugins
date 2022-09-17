#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_weapons_spawn> // https://github.com/fdxx/l4d2_plugins/blob/main/include/l4d2_weapons_spawn.inc

ConVar g_cvMeleeWeapons, g_cvGoldenCrowbar;
char g_sMeleeWeapons[512];
bool g_bGoldenCrowbar;

public Plugin myinfo =
{
	name = "Melee In The Saferoom",
	author = "$atanic $pirit, N3wton, fdxx",
	description = "Spawns melee weapons in the saferoom, at the start of each round.",
	version = "0.5"
}

public void OnPluginStart()
{
	g_cvMeleeWeapons = CreateConVar("l4d2_saferoom_melee_spawn_class", "fireaxe;katana;katana;machete;pitchfork;shovel;crowbar", "产生的近战种类", FCVAR_NONE);
	g_cvGoldenCrowbar = CreateConVar("l4d2_saferoom_melee_golden_crowbar", "1", "黄金撬棍", FCVAR_NONE);

	OnConVarChanged(null, "", "");

	g_cvMeleeWeapons.AddChangeHook(OnConVarChanged);
	g_cvGoldenCrowbar.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	AutoExecConfig(true, "l4d2_saferoom_melee_spawn");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvMeleeWeapons.GetString(g_sMeleeWeapons, sizeof(g_sMeleeWeapons));
	g_bGoldenCrowbar = g_cvGoldenCrowbar.BoolValue;
}

public void OnMapStart()
{
	L4D2Wep_PrecacheModel();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_sMeleeWeapons[0] != '\0')
		CreateTimer(1.0, SpawnMelee_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

Action SpawnMelee_Timer(Handle timer)
{
	int client = GetInGameClient();
	if (client > 0)
	{
		float fPos[3]; 
		char sMelee[16][64];
		int pieces, entity;
		
		GetClientEyePosition(client, fPos);
		pieces = ExplodeString(g_sMeleeWeapons, ";", sMelee, sizeof(sMelee), sizeof(sMelee[]));

		for (int i; i < pieces; i++)
		{
			entity = L4D2Wep_Spawn(sMelee[i], fPos);

			if (g_bGoldenCrowbar && !strcmp(sMelee[i], "crowbar") && entity > MaxClients)
				SetEntProp(entity, Prop_Send, "m_nSkin", 1);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

int GetInGameClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			return i;
		}
	}
	return 0;
}
