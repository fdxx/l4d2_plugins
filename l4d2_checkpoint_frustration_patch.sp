#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

MemoryPatch g_mPatch;

public Plugin myinfo =
{
	name = "L4D2 Checkpoint frustration patch",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_checkpoint_frustration_patch_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	GameData hGameData = new GameData("l4d2_checkpoint_frustration_patch");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_checkpoint_frustration_patch.txt\" gamedata.");

	g_mPatch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::UpdateZombieFrustration::IsAnySurvivorInExitCheckpoint");
	if (!g_mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!g_mPatch.Enable())
		SetFailState("Enable patch failed.");

	delete hGameData;

	RegAdminCmd("sm_frustration_patch", Cmd_Patch, ADMFLAG_ROOT);
}

Action Cmd_Patch(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_frustration_patch [0 or 1]");
		return Plugin_Handled;
	}

	g_mPatch.Disable();
	if (GetCmdArgInt(1) >= 1)
	{
		if (!g_mPatch.Enable())
			ReplyToCommand(client, "Enable frustration patch failed.");
	}
	return Plugin_Handled;
}
