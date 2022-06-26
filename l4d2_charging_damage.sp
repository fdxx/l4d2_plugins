#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

ConVar g_cvMultiples;
float g_fMultiples;

public Plugin myinfo =
{
	name = "L4D2 Charging damage",
	author = "fdxx",
	description = "Adjust AI charger charging damage.",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_charging_damage_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvMultiples = CreateConVar("l4d2_charging_damage_multiples", "1.1", "0.333=Game default, 1.0=Same as real player"); 
	g_fMultiples = g_cvMultiples.FloatValue;
	g_cvMultiples.AddChangeHook(OnConVarChanged);

	ReplaceMemoryAddress();

	AutoExecConfig(true, "l4d2_charging_damage");
}

// Changes take effect in real time.
void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fMultiples = g_cvMultiples.FloatValue;
}

void ReplaceMemoryAddress()
{
	GameData hGameData = new GameData("l4d2_charging_damage");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_charging_damage.txt\" gamedata.");

	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, "Charger::OnTakeDamage::DamageMultiples");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");

	StoreToAddress(mPatch.Address + view_as<Address>(4), GetAddressOfCell(g_fMultiples), NumberType_Int32);

	delete hGameData;
}
