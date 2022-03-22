
#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.2"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

MemoryPatch g_mPatcher[3];

public Plugin myinfo =
{
	name = "L4D2 Coop hunter patch",
	author = "fdxx",
	description = "In coop mode, patched some hunter player behavior to be the same as versus mode.",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_coop_hunter_patch_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	GameData hGameData = new GameData("l4d2_coop_hunter_patch");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_coop_hunter_patch.txt\" gamedata.");

	// Convert leap ability to pounce.
	g_mPatcher[0] = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnLungeStart::HasPlayerControlledZombies");
	if (!g_mPatcher[0].Validate())
		SetFailState("Verify patch failed!");
	if (!g_mPatcher[0].Enable())
		SetFailState("Enable patch failed!");

	// While on the ground, can't pounce without press crouch button. (Air "wall jump" does not need press crouch button).
	g_mPatcher[1] = MemoryPatch.CreateFromConf(hGameData, "CLunge::IsAbilityReadyToFire::HasPlayerControlledZombies");
	if (!g_mPatcher[1].Validate())
		SetFailState("Verify patch failed!");
	if (!g_mPatcher[1].Enable())
		SetFailState("Enable patch failed!");

	// Unlock bonus hunter pounce damage.
	// https://forums.alliedmods.net/showthread.php?t=320024
	g_mPatcher[2] = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnPouncedOnSurvivor::HasPlayerControlledZombies");
	if (!g_mPatcher[2].Validate())
		SetFailState("Verify patch failed!");
	if (!g_mPatcher[2].Enable())
		SetFailState("Enable patch failed!");

	delete hGameData;

	// debug
	RegAdminCmd("sm_hunter_patch", Cmd_HunterPatch, ADMFLAG_ROOT, "Manually disable or enable patches");
}

Action Cmd_HunterPatch(int client, int args)
{
	if (args == 1)
	{
		int iNum = GetCmdArgInt(1);

		if (0 <= iNum <= 2)
		{
			static bool bDisable[3];
			bDisable[iNum] = !bDisable[iNum];

			switch (bDisable[iNum])
			{
				case true:
				{
					g_mPatcher[iNum].Disable();
					ReplyToCommand(client, "Disable g_mPatcher[%i]", iNum);
				}
				case false:
				{
					g_mPatcher[iNum].Enable();
					ReplyToCommand(client, "Enable g_mPatcher[%i]", iNum);
				}
			}
		}
	}
	return Plugin_Handled;
}
