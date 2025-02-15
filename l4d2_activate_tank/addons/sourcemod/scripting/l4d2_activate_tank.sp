#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.8"

#define TA_ATTACK	1
#define TA_WAIT		2

MemoryPatch g_mPatchs[3];

public Plugin myinfo = 
{
	name = "L4D2 Activate Tank",
	author = "cravenge, fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
};

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_activate_tank_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("l4d2_activate_tank", "1", "0=default, 1=Attack, 2=Wait");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
}

void Init()
{
	delete g_mPatchs[TA_ATTACK];
	delete g_mPatchs[TA_WAIT];
	
	GameData hGameData = new GameData("l4d2_activate_tank");

	char buffer[128];
	strcopy(buffer, sizeof(buffer), "TankBehavior::InitialContainedAction::Attack");
	g_mPatchs[TA_ATTACK] = MemoryPatch.CreateFromConf(hGameData, buffer);
	if (!g_mPatchs[TA_ATTACK].Validate())
		SetFailState("Verify patch failed: %s", buffer);

	strcopy(buffer, sizeof(buffer), "TankBehavior::InitialContainedAction::Wait");
	g_mPatchs[TA_WAIT] = MemoryPatch.CreateFromConf(hGameData, buffer);
	if (!g_mPatchs[TA_WAIT].Validate())
		SetFailState("Verify patch failed: %s", buffer);

	delete hGameData;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_mPatchs[TA_ATTACK].Disable();
	g_mPatchs[TA_WAIT].Disable();

	int value = convar.IntValue;
	if (value != TA_ATTACK && value != TA_WAIT)
		return;

	if (!g_mPatchs[value].Enable())
		SetFailState("Enable patch failed!");
}

