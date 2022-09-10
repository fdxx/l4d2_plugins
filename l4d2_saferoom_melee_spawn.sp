#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_weapons_spawn> // https://github.com/fdxx/l4d2_plugins/blob/main/include/l4d2_weapons_spawn.inc

ConVar g_cvMeleeWeapons;
char g_sMeleeWeapons[512];

public Plugin myinfo =
{
	name = "Melee In The Saferoom",
	author = "$atanic $pirit, N3wton, fdxx",
	description = "Spawns melee weapons in the saferoom, at the start of each round.",
	version = "0.4"
}

public void OnPluginStart()
{
	g_cvMeleeWeapons = CreateConVar("l4d2_saferoom_melee_spawn_class", "fireaxe;katana;katana;machete;pitchfork;shovel", "产生的近战种类", FCVAR_NONE);
	g_cvMeleeWeapons.GetString(g_sMeleeWeapons, sizeof(g_sMeleeWeapons));
	g_cvMeleeWeapons.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "l4d2_saferoom_melee_spawn");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvMeleeWeapons.GetString(g_sMeleeWeapons, sizeof(g_sMeleeWeapons));
}

public void OnMapStart()
{
	L4D2Wep_PrecacheModel();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_sMeleeWeapons[0] != '\0')
		CreateTimer(1.0, SpawnMelee_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action SpawnMelee_Timer(Handle timer)
{
	int client = GetInGameClient();
	if (client > 0)
	{
		float fPos[3]; 
		char sMelee[16][64];
		int pieces;
		
		GetClientEyePosition(client, fPos);
		pieces = ExplodeString(g_sMeleeWeapons, ";", sMelee, sizeof(sMelee), sizeof(sMelee[]));

		for (int i; i < pieces; i++)
		{
			L4D2Wep_Spawn(sMelee[i], fPos);
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
