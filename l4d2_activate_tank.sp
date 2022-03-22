#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

public Plugin myinfo = 
{
	name = "L4D2 Activate Tank",
	author = "cravenge, fdxx",
	description = "Forces Tanks To Take Initiative In Attacking After Spawning.",
	version = "0.6",
	url = "https://forums.alliedmods.net/showthread.php?t=334690"
};

public void OnPluginStart()
{
	GameData hGameData = new GameData("l4d2_activate_tank");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_activate_tank.txt\" gamedata.");

	MemoryPatch mPatcher = MemoryPatch.CreateFromConf(hGameData, "TankBehavior::InitialContainedAction::CancelIdle");
	if (!mPatcher.Validate())
		SetFailState("Verify patch failed!");
	if (!mPatcher.Enable())
		SetFailState("Enable patch failed!");

	delete hGameData;
}
