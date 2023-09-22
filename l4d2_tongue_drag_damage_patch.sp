#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.1"

MemoryPatch g_mPatch;

public Plugin myinfo = 
{
	name = "l4d2_tongue_drag_damage_patch",
	author = "fdxx",
	version = VERSION,
	description = "Make tongue_drag_damage_amount cvar effective in coop mode.",
};

public void OnPluginStart()
{
	CreateConVar("l4d2_tongue_drag_damage_patch_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("l4d2_tongue_drag_damage_patch", "1", "Enable or disable");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_mPatch;
	if (convar.BoolValue)
	{
		GameData hGameData = new GameData("l4d2_tongue_drag_damage_patch");

		g_mPatch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::UpdateHangingFromTongue");
		if (!g_mPatch.Validate())
			SetFailState("Verify patch failed!");
		if (!g_mPatch.Enable())
			SetFailState("Enable patch failed!");

		delete hGameData;
	}
}

