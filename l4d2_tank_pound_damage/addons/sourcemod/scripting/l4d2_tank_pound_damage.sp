#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

ConVar
	g_cvNormal,
	g_cvImpossible;

float
	g_fNormal,
	g_fImpossible;

public Plugin myinfo =
{
	name = "L4D2 Tank pound damage",
	author = "fdxx",
	description = "Adjust tank pound damage on incapacitated survivors. (coop mode)",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_tank_pound_damage_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvNormal = CreateConVar("l4d2_tank_pound_damage_normal", "50.0", "Easy, Normal, Hard difficulty damage, 75.0=Game default");
	g_cvImpossible = CreateConVar("l4d2_tank_pound_damage_impossible", "150.0", "Impossible difficulty damage, 150.0=Game default"); 
	
	OnConVarChanged(null, "", "");

	g_cvNormal.AddChangeHook(OnConVarChanged);
	g_cvImpossible.AddChangeHook(OnConVarChanged);

	ReplaceMemoryAddress();

	// AutoExecConfig(true, "l4d2_tank_pound_damage");
}

// Changes take effect in real time.
void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fNormal = g_cvNormal.FloatValue;
	g_fImpossible = g_cvImpossible.FloatValue;
}

void ReplaceMemoryAddress()
{
	GameData hGameData = new GameData("l4d2_tank_pound_damage");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_tank_pound_damage.txt\" gamedata.");

	int iOffset = hGameData.GetOffset("opcode");
	if (iOffset == -1)
		SetFailState("Failed to get offset: opcode");

	MemoryPatch mPatch;
	char sBuffer[64];

	strcopy(sBuffer, sizeof(sBuffer), "CDirector::GetTankDamage::Normal");
	mPatch = MemoryPatch.CreateFromConf(hGameData, sBuffer);
	if (!mPatch.Validate())
		SetFailState("Verify patch failed: \"%s\"", sBuffer);
	if (!mPatch.Enable())
		SetFailState("Enable patch failed: \"%s\"", sBuffer);
	StoreToAddress(mPatch.Address + view_as<Address>(iOffset), GetAddressOfCell(g_fNormal), NumberType_Int32);

	strcopy(sBuffer, sizeof(sBuffer), "CDirector::GetTankDamage::Impossible");
	mPatch = MemoryPatch.CreateFromConf(hGameData, sBuffer);
	if (!mPatch.Validate())
		SetFailState("Verify patch failed: \"%s\"", sBuffer);
	if (!mPatch.Enable())
		SetFailState("Enable patch failed: \"%s\"", sBuffer);
	StoreToAddress(mPatch.Address + view_as<Address>(iOffset), GetAddressOfCell(g_fImpossible), NumberType_Int32);

	delete hGameData;
}
