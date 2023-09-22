// If aggresive_specials_patch_enable == 1, TANK will also take the initiative to attack.
// https://github.com/fdxx/l4d2_plugins/blob/main/aggresive_specials_patch.sp

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.7"

MemoryPatch g_mPatch;

public Plugin myinfo = 
{
	name = "L4D2 Activate Tank",
	author = "cravenge, fdxx",
	description = "Forces Tanks To Take Initiative In Attacking After Spawning.",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_activate_tank_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("l4d2_activate_tank", "1", "Enable or disable");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_mPatch;
	if (convar.BoolValue)
	{
		GameData hGameData = new GameData("l4d2_activate_tank");

		g_mPatch = MemoryPatch.CreateFromConf(hGameData, "TankBehavior::InitialContainedAction::CancelIdle");
		if (!g_mPatch.Validate())
			SetFailState("Verify patch failed!");
		if (!g_mPatch.Enable())
			SetFailState("Enable patch failed!");

		delete hGameData;
	}
}

