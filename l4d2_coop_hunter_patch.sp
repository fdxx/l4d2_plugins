
#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

public Plugin myinfo =
{
	name = "L4D2 Block hunter leap",
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

	MemoryPatch mPatcher[2];

	// Can't pounce without pressing crouch button.
	mPatcher[0] = MemoryPatch.CreateFromConf(hGameData, "CLunge::IsAbilityReadyToFire::HasPlayerControlledZombies");
	if (!mPatcher[0].Validate())
		SetFailState("Verify patch failed!");
	if (!mPatcher[0].Enable())
		SetFailState("Enable patch failed!");

	// Can "wall jump" in the air(near the wall) without pressing the crouch button.
	mPatcher[1] = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnLungeStart::HasPlayerControlledZombies");
	if (!mPatcher[1].Validate())
		SetFailState("Verify patch failed!");
	if (!mPatcher[1].Enable())
		SetFailState("Enable patch failed!");

	delete hGameData;
}
