#if defined _l4d2_boss_spawn_control_included
 #endinput
#endif
#define _l4d2_boss_spawn_control_included


#define FLOW_DISABLED	-3.0
#define FLOW_DEFAULT	-2.0
#define FLOW_STATIC		-1.0
#define FLOW_NONE		0.0

/**
 * Get the flow spawned by the boss.
 *
 * @param type          0=Tank, 1=Witch.
 * @return              Flow between 0.0-1.0, otherwise see FLOW_*
 */
native float L4D2_GetBossSpawnFlow(int type);


public SharedPlugin __pl_l4d2_boss_spawn_control = 
{
	name = "l4d2_boss_spawn_control",
	file = "l4d2_boss_spawn_control.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_boss_spawn_control_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_GetBossSpawnFlow");
}
#endif
