#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <dhooks>

char g_sLogPath[PLATFORM_MAX_PATH];
int g_iGetUserCmdOffset;

public Plugin myinfo =
{
	name = "L4D2 Lag Compensation Null CUserCmd fix",
	author = "fdxx",
	description = "Prevent crash: CLagCompensationManager::StartLagCompensation with NULL CUserCmd!!!",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_null_cusercmd_fix_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);
}

void Init()
{
	GameData hGameData = new GameData("l4d2_null_cusercmd_fix");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_null_cusercmd_fix.txt\" gamedata.");

	g_iGetUserCmdOffset = hGameData.GetOffset("CBasePlayer::GetCurrentUserCommand");
	if (g_iGetUserCmdOffset == -1)
		SetFailState("Failed to get offset");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CLagCompensationManager::StartLagCompensation");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour");
	if (!dDetour.Enable(Hook_Pre, OnStartLagCompensationPre))
		SetFailState("Failed to enable DynamicDetour");

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_null_cusercmd_fix.log");
}

MRESReturn OnStartLagCompensationPre(Address pThis, DHookParam hParams)
{
	int client = hParams.Get(1);
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		int team = GetClientTeam(client);
		if (team == 2 || team == 3)
		{
			Address pClient = hParams.GetAddress(1);
			Address pCUserCmd = LoadFromAddress(pClient + view_as<Address>(g_iGetUserCmdOffset), NumberType_Int32);
			if (pCUserCmd == Address_Null)
			{
				LogToFileEx(g_sLogPath, "Prevent crash success: %N null CUserCmd.", client);
				return MRES_Supercede;
			}

			/*
			int weaponselect = LoadFromAddress(pCUserCmd + view_as<Address>(44), NumberType_Int32);
			int impulse = LoadFromAddress(pCUserCmd + view_as<Address>(40), NumberType_Int8);
			float viewangles0 = LoadFromAddress(pCUserCmd + view_as<Address>(12), NumberType_Int32);
			float viewangles1 = LoadFromAddress(pCUserCmd + view_as<Address>(16), NumberType_Int32);
			float viewangles2 = LoadFromAddress(pCUserCmd + view_as<Address>(20), NumberType_Int32);
			PrintToServer("%N weaponselect = %i, impulse = %i, viewangles = %.1f %.1f %.1f", client, weaponselect, impulse, viewangles0, viewangles1, viewangles2);
			*/
		}
	}
	return MRES_Ignored;
}
