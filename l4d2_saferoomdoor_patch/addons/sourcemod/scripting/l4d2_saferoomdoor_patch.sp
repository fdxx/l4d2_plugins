#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.1"

MemoryPatch g_mPatch;

public Plugin myinfo = 
{
	name = "l4d2_saferoomdoor_patch",
	author = "fdxx",
	version = VERSION,
	description = "Make the starting saferoom door unable to close after being opened. Same as versus mode.",
	url = "https://github.com/fdxx/l4d2_plugins"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_saferoomdoor_patch_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("l4d2_saferoomdoor_patch", "1", "Enable or disable");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_mPatch;
	if (convar.BoolValue)
	{
		GameData hGameData = new GameData("l4d2_saferoomdoor_patch");

		g_mPatch = MemoryPatch.CreateFromConf(hGameData, "CPropDoorRotatingCheckpoint::TryOpenClose");
		if (!g_mPatch.Validate())
			SetFailState("Verify patch failed!");
		if (!g_mPatch.Enable())
			SetFailState("Enable patch failed!");

		delete hGameData;
	}
}

