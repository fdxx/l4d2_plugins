#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

ConVar CvarMelees;
char g_sMelees[512];
bool g_bMeleeSpawned;

enum
{
	MELEE_NAME,
	MELEE_MODEL
};

// Thanks https://github.com/raziEiL/l4d2_weapons/blob/master/scripting/include/l4d2_weapons.inc
static const char g_sMeleeList[][][] =
{
	{"fireaxe",			"models/weapons/melee/w_fireaxe.mdl"},			//斧头
	{"baseball_bat",	"models/weapons/melee/w_bat.mdl"},				//棒球棒
	{"cricket_bat",		"models/weapons/melee/w_cricket_bat.mdl"},		//球拍
	{"crowbar",			"models/weapons/melee/w_crowbar.mdl"},			//撬棍
	{"frying_pan",		"models/weapons/melee/w_frying_pan.mdl"},		//平底锅
	{"golfclub",		"models/weapons/melee/w_golfclub.mdl"},			//高尔夫球棍
	{"electric_guitar",	"models/weapons/melee/w_electric_guitar.mdl"},	//吉他
	{"katana",			"models/weapons/melee/w_katana.mdl"},			//武士刀
	{"machete",			"models/weapons/melee/w_machete.mdl"},			//砍刀
	{"tonfa",			"models/weapons/melee/w_tonfa.mdl"},			//警棍
	{"knife",			"models/w_models/weapons/w_knife_t.mdl"},		//小刀
	// The Last Stand update
	{"pitchfork",		"models/weapons/melee/w_pitchfork.mdl"},		//草叉
	{"shovel",			"models/weapons/melee/w_shovel.mdl"}			//铁铲
};

public Plugin myinfo =
{
	name = "Melee In The Saferoom",
	author = "$atanic $pirit, N3wton, fdxx",
	description = "Spawns melee weapons in the saferoom, at the start of each round.",
	version = "0.3"
}

public void OnPluginStart()
{
	CvarMelees = CreateConVar("l4d2_saferoom_melee_spawn_class", "fireaxe;katana;katana;machete;pitchfork;shovel", "产生的近战种类", FCVAR_NONE);
	
	CvarMelees.GetString(g_sMelees, sizeof(g_sMelees));
	CvarMelees.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "l4d2_saferoom_melee_spawn");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CvarMelees.GetString(g_sMelees, sizeof(g_sMelees));
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bMeleeSpawned = false;
	CreateTimer(1.0, SpawnMelee_Timer);
}

public void OnMapStart()
{
	CreateTimer(0.1, PrecacheModel_Timer);
}

public Action PrecacheModel_Timer(Handle timer)
{
	for (int i = 0; i < sizeof(g_sMeleeList); i++)
	{
		if (!IsModelPrecached(g_sMeleeList[i][MELEE_MODEL]))
		{
			if (PrecacheModel(g_sMeleeList[i][MELEE_MODEL], true) <= 0)
			{
				LogError("[错误] %s 模型缓存错误", g_sMeleeList[i][MELEE_MODEL]);
			}
		}
	}
	return Plugin_Continue;
}

public Action SpawnMelee_Timer(Handle timer)
{
	if (!g_bMeleeSpawned)
	{
		int client = GetInGameClient();
		if (client > 0)
		{
			float fPos[3], fAng[3]; 
			GetClientAbsOrigin(client, fPos);

			fPos[2] += 20.0;
			fAng[0] = 90.0;

			char sPieces[32][64];
			int iNum = ExplodeString(g_sMelees, ";", sPieces, sizeof(sPieces), sizeof(sPieces[]));
			
			for (int i = 0; i < iNum; i++)
			{
				SpawnMelee(sPieces[i], fPos, fAng);
			}

			g_bMeleeSpawned = true;
			return Plugin_Stop;
		}
		else CreateTimer(1.0, SpawnMelee_Timer);
	}
	return Plugin_Stop;
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

void SpawnMelee(const char[] sName, const float fPos[3], const float fAng[3])
{
	float fNewPos[3], fNewAng[3];

	fNewPos = fPos;
	fNewAng = fAng;

	fNewPos[0] += (-10.0 + GetRandomFloat(0.0, 20.0));
	fNewPos[1] += (-10.0 + GetRandomFloat(0.0, 20.0));
	fNewPos[2] += GetRandomFloat(0.0, 10.0);
	fNewAng[1] = GetRandomFloat(0.0, 360.0);

	int iMelee = CreateEntityByName("weapon_melee");
	DispatchKeyValue(iMelee, "melee_script_name", sName);
	DispatchSpawn(iMelee);
	TeleportEntity(iMelee, fNewPos, fNewAng, NULL_VECTOR);
}
