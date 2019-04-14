#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Pocket Sandbox",
	author = PLUGIN_AUTHOR,
	description = "BattlefieldDuck",
	version = PLUGIN_VERSION,
	url = "https://github.com/BattlefieldDuck/TF2_PhysicsGun"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_psb", Command_PocketSandboxMenu, 0, "Open the Pocket Sandbox Menu");
	RegAdminCmd("sm_psandbox", Command_PocketSandboxMenu, 0, "Open the Pocket Sandbox Menu");
	RegAdminCmd("sm_pocketsandbox", Command_PocketSandboxMenu, 0, "Open the Pocket Sandbox Menu");
}

public Action Command_PocketSandboxMenu(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_PocketSandboxMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Pocket Sandbox - Spawn Menu\n ");
	menu.SetTitle(menuinfo);

	Format(menuinfo, sizeof(menuinfo), "|Remove\n \nprop_dynamic:");
	menu.AddItem("0", menuinfo);

	Format(menuinfo, sizeof(menuinfo), "Bookcase");
	menu.AddItem("1", menuinfo);

	//Format(menuinfo, sizeof(menuinfo), "Chair");
	//menu.AddItem("2", menuinfo);

	Format(menuinfo, sizeof(menuinfo), "Stair Wood");
	menu.AddItem("3", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Television");
	menu.AddItem("4", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Work Table\n \nprop_physics:");
	menu.AddItem("5", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Vehicles\n \ntf_dropped_weapon:");
	menu.AddItem("6", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Frying Pan\n \n");
	menu.AddItem("7", menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "Physics Gun");
	//menu.AddItem("8", menuinfo);

	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);
}

public int Handler_PocketSandboxMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		switch (StringToInt(info))
		{
			case (0): 
			{
				int entity = GetClientAimEntity(client);
				if (entity > MaxClients && IsValidEntity(entity))
				{
					AcceptEntityInput(entity, "ClearParent");
					AcceptEntityInput(entity, "Kill");
				}
			}
			case (1): CreateEntity(client, "prop_dynamic_override", "models/props_manor/bookcase_132_01.mdl");
			case (2): CreateEntity(client, "prop_dynamic_override", "models/props_spytech/chair.mdl");
			case (3): CreateEntity(client, "prop_dynamic_override", "models/props_farm/stairs_wood001a.mdl");
			case (4): CreateEntity(client, "prop_dynamic_override", "models/props_spytech/tv001.mdl");
			case (5): CreateEntity(client, "prop_dynamic_override", "models/props_spytech/work_table001.mdl");
			
			case (6): CreateEntity(client, "prop_physics_override", "models/props_vehicles/car002a.mdl");
			
			case (7): CreateDroppedWeapon(client, 264, "models/weapons/c_models/c_frying_pan/c_frying_pan.mdl");
		}
		Command_PocketSandboxMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
			
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

int CreateEntity(int client, char[] classname, char[] model)
{
	int entity = CreateEntityByName(classname);
	if (entity > MaxClients && IsValidEntity(entity))
	{
		SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(entity, Prop_Data, "m_nSolidType", 6);

		if (!IsModelPrecached(model))	PrecacheModel(model);
		DispatchKeyValue(entity, "model", model);
		
		TeleportEntity(entity, GetClientAimPosition(client, 10000.0), GetEntitySpawnAngle(client), NULL_VECTOR);
		
		DispatchSpawn(entity);
		
		return entity;
	}
	return -1;
}

int CreateDroppedWeapon(int client, int index, char[] model)
{
	int weapon = CreateEntityByName("tf_dropped_weapon");
	if (weapon > MaxClients && IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", index);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		SetEntProp(weapon, Prop_Send, "m_iItemIDLow", -1);
		SetEntProp(weapon, Prop_Send, "m_iItemIDHigh", -1);
		SetEntityModel(weapon, model);
		
		TeleportEntity(weapon, GetClientAimPosition(client, 10000.0), GetEntitySpawnAngle(client), NULL_VECTOR);
		DispatchSpawn(weapon);
		
		return weapon;
	}
	return -1;
}

float[] GetEntitySpawnAngle(int client)
{
	float angles[3]; 
	GetClientEyeAngles(client, angles);
	angles[0] = 0.0;
	angles[1] += 180.0;
	return angles;
}

int GetClientAimEntity(int client)
{
	float fOrigin[3], fAngles[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	Handle trace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	if (TR_DidHit(trace))
	{
		int iEntity = TR_GetEntityIndex(trace);
		if(iEntity > MaxClients && IsValidEntity(iEntity))
		{
			CloseHandle(trace);
			return iEntity;
		}
	}
	CloseHandle(trace);
	return -1;
}

float[] GetClientAimPosition(int client, float maxtracedistance)
{
	float pos[3], angle[3], eyeanglevector[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, angle);

	Handle trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	if(TR_DidHit(trace))
	{
		float endpos[3];
		TR_GetEndPosition(endpos, trace);
		
		if((GetVectorDistance(pos, endpos) <= maxtracedistance) || maxtracedistance <= 0)
		{
			CloseHandle(trace);
			return endpos;
		}
		else
		{
			GetAngleVectors(angle, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			AddVectors(pos, eyeanglevector, endpos);
			CloseHandle(trace);
			return endpos;
		}
	}
	CloseHandle(trace);
	return pos;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	return (IsValidEntity(entity) && entity != client && MaxClients < entity);
}