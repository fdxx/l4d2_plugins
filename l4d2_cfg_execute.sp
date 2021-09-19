#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "L4D2 Config execute",
	author = "fdxx",
	description = "",
	version = "0.1",
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("l4d2_cfg_execute", "somethings.cfg", "在服务器启动时执行的配置文件 多个文件使用;分割 (配置文件路径left4dead2/cfg/sourcemod)", FCVAR_NONE);
	AutoExecConfig(true, "l4d2_cfg_execute");
}

public void OnConfigsExecuted()
{
	// 插件启动后只执行一次
	static bool bExecute = true;
	if (bExecute)
	{
		bExecute = false;
		CreateTimer(0.2 , ExecuteCfg_Timer);
	}
}

public Action ExecuteCfg_Timer(Handle timer)
{
	char sCfgs[256];
	FindConVar("l4d2_cfg_execute").GetString(sCfgs, sizeof(sCfgs));

	if (sCfgs[0] != '\0')
	{
		char sCfgName[32][128], sLogMsg[128];
		int iNumber = ExplodeString(sCfgs, ";", sCfgName, sizeof(sCfgName), sizeof(sCfgName[]));

		for (int i = 0; i < iNumber; i++)
		{
			LogMessage("加载 %s", sCfgName[i]);
			ServerCommandEx(sLogMsg, sizeof(sLogMsg), "exec sourcemod/%s", sCfgName[i]);
			if (sLogMsg[0] != '\0')
			{
				LogError("加载 %s 错误: %s", sCfgName[i], sLogMsg);
			}
		}
	}
}
