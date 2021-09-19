#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_weapons>

ConVar CvarMelees;
char g_sMelees[256];
bool g_bMeleeSpawned;

//https://github.com/raziEiL/l4d2_weapons/blob/master/scripting/include/l4d2_weapons.inc
static const char l_sMeleeNames[][] =
{
	"fireaxe",			//斧头
	"baseball_bat",		//棒球棒
	"cricket_bat",		//球拍
	"crowbar",			//撬棍
	"frying_pan",		//平底锅
	"golfclub",			//高尔夫球棍
	"electric_guitar",	//吉他
	"katana",			//武士刀
	"machete",			//砍刀
	"tonfa",			//警棍
	"knife",			//小刀
	// The Last Stand update
	"pitchfork",		//草叉
	"shovel",			//铁铲
};

public Plugin myinfo =
{
	name = "Melee In The Saferoom",
	author = "$atanic $pirit, N3wton, fdxx",
	description = "Spawns melee weapons in the saferoom, at the start of each round.",
	version = "0.2"
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
	L4D2Wep_PrecacheMeleeModels();
	L4D2Wep_OnMapStart();
}

public Action SpawnMelee_Timer(Handle timer)
{
	if (!g_bMeleeSpawned)
	{
		int client = GetInGameClient();
		if (client > 0)
		{
			float vOrigin[3]; 
			float vAngles[3];
			GetClientAbsOrigin(client, vOrigin);

			vOrigin[2] += 20.0;
			vAngles[0] = 90.0;

			char sPieces[32][256];
			int iNumPieces = ExplodeString(g_sMelees, ";", sPieces, sizeof(sPieces), sizeof(sPieces[]));
			
			for (int p = 0; p < iNumPieces; p++)
			{
				int iMeleeID = L4D2Wep_MeleeNameToID(sPieces[p]);
				if (iMeleeID != -1)
				{
					L4D2Wep_SpawnMelee_Ex(iMeleeID, vOrigin, vAngles);
				}
				else LogError("Melee name wrong!");
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

void L4D2Wep_SpawnMelee_Ex(int meleeID, const float vPos[3], const float vAng[3])
{
	float vOrigin[3];
	float vAngles[3];
	vOrigin = vPos;
	vAngles = vAng;
	
	vOrigin[0] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[1] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[2] += GetRandomFloat(0.0, 10.0);
	vAngles[1] = GetRandomFloat(0.0, 360.0);

	int iMeleeSpawn = CreateEntityByName("weapon_melee");
	DispatchKeyValue(iMeleeSpawn, "melee_script_name", l_sMeleeNames[meleeID]);
	DispatchSpawn(iMeleeSpawn);
	TeleportEntity(iMeleeSpawn, vOrigin, vAngles, NULL_VECTOR);
}
