#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <vphysics>
#include <morecolors>
#include <tf2_stocks>
#include <tf2items_giveweapon>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] TF2 ~ PhysicsGun",
	author = PLUGIN_AUTHOR,
	description = "Physics Gun on TF2! Grab everything!",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

#define PARTICLE "medicgun_beam_machinery"

//https://github.com/bouletmarc/hl2_ep2_content
#define MODEL_PHYSICSGUN 			"models/weapons/w_physics.mdl"
#define MODEL_PHYSICSGUNVIEWMODEL 	"models/weapons/v_superphyscannon.mdl"
#define MODEL_PHYSICSLASER 			"materials/sprites/physbeam.vmt"
#define MODEL_HALOINDEX 			"materials/sprites/halo01.vmt"
#define MODEL_BLUEGLOW 				"materials/sprites/blueglow2.vmt"

int g_iPhysicGunIndex = 8787;
int g_iPhysicGunWeaponIndex = 1001;
int g_iPhysicGunQuality = 6;

Handle g_cvForceEntity;
Handle g_cvForcePlayer;

Handle g_hHud;

int g_ModelIndex;
int g_iPhysicsGun;
int g_iPhysicsGunWorld;
int g_HaloIndex;
int g_iBlueGlow;

int g_iGrabbingEntity[MAXPLAYERS + 1][4]; //0. Entity, 1. Glow entity index, 2. Particle1 3. Particle2
float g_fGrabbingDistance[MAXPLAYERS + 1]; //MaxDistance
float g_fGrabbingDifference[MAXPLAYERS + 1][3]; //Difference
bool g_bGrabbingAttack2[MAXPLAYERS + 1];
bool g_bGrabbingRotate[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_pg_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_cvForceEntity = CreateConVar("sm_tf2sb_pg_forceentity", "70.0", "Force when throwing Entity (Default: 70.0)", 0, true, 1.0, true, 100.0);
	g_cvForcePlayer = CreateConVar("sm_tf2sb_pg_forceplayer", "20.0", "Force when throwing Player (Default: 20.0)", 0, true, 1.0, true, 100.0);
	
	RegAdminCmd("sm_pg", Command_EquipPhysicsGun, ADMFLAG_RESERVATION, "Equip Physics Gun!");
	//RegAdminCmd("sm_pg", Command_EquipPhysicsGun, 0, "Equip Physics Gun!");
	
	HookEvent("player_spawn", Event_PlayerSpawn);

	g_hHud = CreateHudSynchronizer();
} //@

//Give PhysicsGun to client
public Action Command_EquipPhysicsGun(int client, int args)
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		if(IsPlayerAlive(client))
		{
			int iWeapon = GetPlayerWeaponSlot(client, 1);
			if(IsValidEntity(iWeapon)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
			
			if(!TF2Items_CheckWeapon(g_iPhysicGunIndex))
			{		
				if(!IsModelPrecached(MODEL_PHYSICSGUN))	PrecacheModel(MODEL_PHYSICSGUN);
				TF2Items_CreateWeapon(g_iPhysicGunIndex, "tf_weapon_builder", g_iPhysicGunWeaponIndex, 1, g_iPhysicGunQuality, 99, "", -1, MODEL_PHYSICSGUN, true);
			}
			
			int PhysicsGun = TF2Items_GiveWeapon(client, g_iPhysicGunIndex);
			if(IsValidEntity(PhysicsGun))
			{
				SetEntProp(PhysicsGun, Prop_Send, "m_nSkin", 1);
				SetEntProp(PhysicsGun, Prop_Send, "m_iWorldModelIndex", g_iPhysicsGunWorld);
				SetEntProp(PhysicsGun, Prop_Send, "m_nModelIndexOverrides", g_iPhysicsGunWorld, _, 0);
				SetEntProp(PhysicsGun, Prop_Send, "m_nSequence", 2);
			}
			CPrintToChat(client, "{dodgerblue}[GMod] {aliceblue}You have equip a {aqua}Physics Gun{aliceblue}!");
			SendDialogToOne(client, 240, 248, 255, "You have equip a Physics Gun!");
		}
		else 	CPrintToChat(client, "{dodgerblue}[GMod] {aliceblue}You can NOT equip PhysicsGun when DEAD!");
	}
} //@

//-----[ Start and End ]--------------------------------------------------(
public void OnMapStart() //Precache Sound and Model
{
	g_ModelIndex = PrecacheModel(MODEL_PHYSICSLASER);
	g_HaloIndex = PrecacheModel(MODEL_HALOINDEX);
	g_iBlueGlow = PrecacheModel(MODEL_BLUEGLOW);
	g_iPhysicsGun = PrecacheModel(MODEL_PHYSICSGUNVIEWMODEL);
	g_iPhysicsGunWorld = PrecacheModel(MODEL_PHYSICSGUN);

	for (int i = 1; i < MAXPLAYERS; i++)
	{
		g_iGrabbingEntity[i][0] = -1; //Grab entity
		g_iGrabbingEntity[i][1] = -1; //tf_glow
		g_iGrabbingEntity[i][2] = -1;
		g_iGrabbingEntity[i][3] = -1;
		if(IsValidClient(i)) 
		{
			SDKHook(i, SDKHook_WeaponSwitchPost, WeaponSwitchHookPost);
		}
	}
}

public void OnClientPutInServer(int client)
{
	ResetClientAttribute(client);
	g_iGrabbingEntity[client][0] = -1; //Grab entity
	g_iGrabbingEntity[client][1] = -1; //tf_glow
	g_iGrabbingEntity[client][2] = -1;
	g_iGrabbingEntity[client][3] = -1;
	g_fGrabbingDistance[client] = 0.0;
	g_bGrabbingRotate[client] = false;
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchHookPost);
}

public void OnClientDisconnect(int client)
{
	ResetClientAttribute(client);
	g_iGrabbingEntity[client][0] = -1; //Grab entity
	g_iGrabbingEntity[client][1] = -1; //tf_glow
	g_iGrabbingEntity[client][2] = -1;
	g_iGrabbingEntity[client][3] = -1;
	g_fGrabbingDistance[client] = 0.0;
	g_bGrabbingRotate[client] = false;
	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwtich);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, WeaponSwitchHookPost);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnDroppedWeaponSpawn);
	}
}
//------------------------------------------------------------------------)

//Hook---------------------------------------------------------(
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwtich);
	}
}

public void OnDroppedWeaponSpawn(int entity)
{  
	if(IsValidEntity(entity))
	{
		if(GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex") == g_iPhysicGunWeaponIndex && GetEntProp(entity, Prop_Send, "m_iEntityQuality") == g_iPhysicGunQuality)
		{
			AcceptEntityInput(entity, "Kill");
		}
	} 
} 

public Action BlockWeaponSwtich(int client, int entity)
{
	return Plugin_Handled;	
}

public Action WeaponSwitchHookPost(int client, int entity) 
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		if(IsHoldingPhysicsGun(client))
		{
			SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", g_iPhysicsGun, 2);
			SetEntProp(iViewModel, Prop_Send, "m_nSequence", 2);
		}
		else
		{
			//Change back to default viewmodel when m_nModelIndex == g_iPhysicsGun only.
			if(GetEntProp(iViewModel, Prop_Send, "m_nModelIndex", 2) == g_iPhysicsGun)
			{
				char sArmModel[128];
				switch (TF2_GetPlayerClass(client))
				{
					case TFClass_Scout: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_scout_arms.mdl");
					case TFClass_Soldier: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_soldier_arms.mdl");
					case TFClass_Pyro: 		Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_pyro_arms.mdl");
					case TFClass_DemoMan: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_demo_arms.mdl");
					case TFClass_Heavy:		Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_heavy_arms.mdl");
					case TFClass_Engineer: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_engineer_arms.mdl");
					case TFClass_Medic: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_medic_arms.mdl");
					case TFClass_Sniper: 	Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_sniper_arms.mdl");
					case TFClass_Spy: 		Format(sArmModel, sizeof(sArmModel), "models/weapons/c_models/c_spy_arms.mdl");
				}
				if(strlen(sArmModel) > 0)	SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", PrecacheModel(sArmModel, true), 2);
			}
		}
	}	
}

//-------------------------------------------------------------)


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsValidClient(client)) //Return gay client
		return Plugin_Continue;
		
	if(IsPlayerAlive(client))
	{
		//Check Is it holding Physics Gun
		if(IsHoldingPhysicsGun(client))
		{
			//TODO: Fix fading problem
			if(TF2_GetPlayerClass(client) == TFClass_DemoMan || TF2_GetPlayerClass(client) == TFClass_Medic) //Fix medic and demo viewmodel not showing up problem
			{
				SetEntProp(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence", 2);
			}
			
			if(buttons & IN_ATTACK)	//When In_Attack
			{
				//GetAimEntity
				int iEntity = GetClientAimEntity(client);
				
				//Fix the index of Grabbing entity
				if(IsValidEntity(iEntity) && !IsValidEntity(g_iGrabbingEntity[client][0]))	
				{					
					//Hook Disable Change Weapon
					SDKHook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwtich);
					
					//Bind Entity
					g_iGrabbingEntity[client][0] = iEntity;
					
					
					if(IsValidEntity(g_iGrabbingEntity[client][2]))	
					{
						AcceptEntityInput(g_iGrabbingEntity[client][2], "Kill");
					}
					if(IsValidEntity(g_iGrabbingEntity[client][3]))	
					{
						AcceptEntityInput(g_iGrabbingEntity[client][3], "Kill");
					}
					AttachControlPointParticle(client, PARTICLE, g_iGrabbingEntity[client][0]);
					
					
					//Set Entity Outline
					if(!HasGlow(g_iGrabbingEntity[client][0]) && !IsValidEntity(g_iGrabbingEntity[client][1]))
						g_iGrabbingEntity[client][1] = CreateGlow(iEntity);
						
					//Save the Entity Distance
					g_fGrabbingDistance[client] = GetEntitiesDistance(client, g_iGrabbingEntity[client][0]);
					
					float fEOrigin[3], fEndPosition[3], fNormal[3];
					GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Data, "m_vecOrigin", fEOrigin);
					GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fNormal, tracerayfilterrocket, client);
					
					g_fGrabbingDifference[client][0] = fEOrigin[0] - fEndPosition[0];
					g_fGrabbingDifference[client][1] = fEOrigin[1] - fEndPosition[1];
					g_fGrabbingDifference[client][2] = fEOrigin[2] - fEndPosition[2];
					
					g_bGrabbingAttack2[client] = false;
					g_bGrabbingRotate[client] = false;
				}
				
				if (IsValidEntity(g_iGrabbingEntity[client][0]))
				{
					//Get Value
					float fOrigin[3], fClientAngle[3], fEOrigin[3], fEndPosition[3], fNormal[3];
					GetClientEyePosition(client, fOrigin);
					GetClientEyeAngles(client, fClientAngle);
		
					GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Data, "m_vecOrigin", fEOrigin);
						
					float fAimPosition[3];
					fAimPosition[0] = fEOrigin[0] - g_fGrabbingDifference[client][0];
					fAimPosition[1] = fEOrigin[1] - g_fGrabbingDifference[client][1];
					fAimPosition[2] = fEOrigin[2] - g_fGrabbingDifference[client][2];
					
					SetEntityGlows(client, g_iGrabbingEntity[client][0], fAimPosition);			
					
					SetHudTextParams(0.78, 0.7, 1.0, 30, 144, 255, 255, 1, 6.0, 0.1, 0.1);
					//Press R (GMod E button)
					if(buttons & IN_RELOAD && !(buttons & IN_ATTACK3))
					{
						ZeroVector(vel);
			
						float fAngle[3], fFixAngle[3];
						GetVectorAnglesTwoPoints(fOrigin, fAimPosition, fFixAngle);
						AnglesNormalize(fFixAngle);
						
						TeleportEntity(client, NULL_VECTOR, fFixAngle, NULL_VECTOR);
							
						GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Send, "m_angRotation", fAngle);
						
						ShowSyncHudText(client, g_hHud, "Angle: %i %i %i\nDistance: %im", RoundFloat(fAngle[0]), RoundFloat(fAngle[1]), RoundFloat(fAngle[2]), RoundFloat(g_fGrabbingDistance[client]/100));
						
						
						//Rotate--------------------------------------------------------------------
						if(buttons & IN_DUCK) //Accurate
						{
							if (mouse[1] != 0 && !g_bGrabbingRotate[client]) 
							{
								if(mouse[1] < -1 || mouse[1] > 1)
								{
									if(mouse[1] < -1)		
									{
										fAngle[0] += 45.0; //Up
									}
									else if(mouse[1] > 1)
									{									
										fAngle[0] -= 45.0; //Down
									}
	
									//fAngle[1]   (0 - 270) (-90 - 0)
									AnglesNormalize(fAngle);
									if(0.0 < fAngle[0] && fAngle[0] < 45.0)				fAngle[0] = 0.0;
									else if(45.0 < fAngle[0] && fAngle[0] < 90.0)		fAngle[0] = 45.0;
									else if(90.0 < fAngle[0] && fAngle[0] < 135.0)		fAngle[0] = 90.0;
									else if(135.0 < fAngle[0] && fAngle[0] < 180.0)		fAngle[0] = 135.0;							
									else if(180.0 < fAngle[0] && fAngle[0] < 225.0)		fAngle[0] = 180.0;
									else if(225.0 < fAngle[0] && fAngle[0] < 270.0)		fAngle[0] = 225.0;								
									else if(0.0 > fAngle[0] && fAngle[0] > -45.0)		fAngle[0] = -45.0;
									else if(-45.0 > fAngle[0] && fAngle[0] > -90.0)		fAngle[0] = -90.0;			
								}
							}						
							else if (mouse[0] != 0 && !g_bGrabbingRotate[client]) //Left Right
							{
								if(mouse[0] < -1 || mouse[0] > 1)
								{
									if(mouse[0] < -1)		fAngle[1] -= 45.0; //left
									else if(mouse[0] > 1)	fAngle[1] += 45.0; //right
	
									//fAngle[1]   (0 - 180) (0 - -180)
									AnglesNormalize(fAngle);
									if(0.0 < fAngle[1] && fAngle[1] < 45.0)				fAngle[1] = 0.0;
									else if(45.0 < fAngle[1] && fAngle[1] < 90.0)		fAngle[1] = 45.0;
									else if(90.0 < fAngle[1] && fAngle[1] < 135.0)		fAngle[1] = 90.0;
									else if(135.0 < fAngle[1] && fAngle[1] < 180.0)		fAngle[1] = 135.0;
									else if(0.0 > fAngle[1] && fAngle[1] > -45.0)		fAngle[1] = -45.0;
									else if(-45.0 > fAngle[1] && fAngle[1] > -90.0)		fAngle[1] = -90.0;
									else if(-90.0 > fAngle[1] && fAngle[1] > -135.0)	fAngle[1] = -135.0;
									else if(-135.0 > fAngle[1] && fAngle[1] > -180.0)	fAngle[1] = -180.0;
								}									
							}
							AnglesNormalize(fAngle);
							CreateTimer(0.3, Timer_RotateCoolDown, client);
							g_bGrabbingRotate[client] = true;
						}
						else
						{
							if (mouse[0] != 0)	
							{
								fAngle[1] += mouse[0] / 2; //Left Right
							}
							if (mouse[1] != 0)
							{
								fAngle[0] += mouse[1] / 2; //Up Down
							}					
						}

						if(buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT))
						{
							if(buttons & IN_DUCK)
							{
								fAngle[1] -= 1.0;								
							}
							else
							{
								fAngle[1] -= 2.0;
							}
						}
						else if(buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT))	
						{
							if(buttons & IN_DUCK)
							{
								fAngle[1] += 1.0;
							}
							else
							{
								fAngle[1] += 2.0;
							}
						}
						
						//--------------------------------------------------------------------------
						
						
						
						//Push and Pull-------------------------------------------------------------
						if(buttons & IN_FORWARD && !(buttons & IN_BACK))	
						{
							if(g_fGrabbingDistance[client] < 10000.0)
								g_fGrabbingDistance[client] += 10.0;
						}						
						else if(buttons & IN_BACK && !(buttons & IN_FORWARD))
						{
							if(g_fGrabbingDistance[client] > 150.0)
								g_fGrabbingDistance[client] -= 10.0;
						}		
						
						//--------------------------------------------------------------------------
						
						
						GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fNormal, tracerayfilterrocket, client);

						float fNewEntityPosition[3];					
						fNewEntityPosition[0] = fEndPosition[0] + g_fGrabbingDifference[client][0];
						fNewEntityPosition[1] = fEndPosition[1] + g_fGrabbingDifference[client][1];
						fNewEntityPosition[2] = fEndPosition[2] + g_fGrabbingDifference[client][2];
	
						AnglesNormalize(fAngle);
						TeleportEntity(g_iGrabbingEntity[client][0], fNewEntityPosition, fAngle, NULL_VECTOR);
					}
					else
					{		
						char szClass[64];
						GetEdictClassname(g_iGrabbingEntity[client][0], szClass, sizeof(szClass));
						
						ShowSyncHudText(client, g_hHud, "Obj: %s\nIndex: [%i]", szClass, g_iGrabbingEntity[client][0]);
						
						GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fNormal, tracerayfilterrocket, client);
					
						fEndPosition[0] = fEndPosition[0] + g_fGrabbingDifference[client][0];
						fEndPosition[1] = fEndPosition[1] + g_fGrabbingDifference[client][1];
						fEndPosition[2] = fEndPosition[2] + g_fGrabbingDifference[client][2];
						
						float vector[3], fZero[3];
						MakeVectorFromPoints(fAimPosition, fEndPosition, vector); //Set velocity
						
						if(StrEqual(szClass, "prop_physics") && Phys_IsGravityEnabled(g_iGrabbingEntity[client][0])) //Check is it prop_physics before Phys_IsGravityEnabled(
						{
							ScaleVector(vector, GetConVarFloat(g_cvForceEntity));
							Phys_SetVelocity(EntRefToEntIndex(g_iGrabbingEntity[client][0]), vector, fZero, true);
							Phys_Wake(g_iGrabbingEntity[client][0]);
						}	
						else if(IsValidClient(g_iGrabbingEntity[client][0])) //Is entity client?
						{
							ScaleVector(vector, GetConVarFloat(g_cvForcePlayer));
							TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, NULL_VECTOR, vector);
						}
						else TeleportEntity(g_iGrabbingEntity[client][0], fEndPosition, NULL_VECTOR, NULL_VECTOR);
					}		
					
					//Entity Face to client
					if(buttons & IN_ATTACK3)
					{
						TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, fClientAngle, NULL_VECTOR);				
					}
					
					//Freeze Entity (Only on prop_physics)
					if(buttons & IN_ATTACK2)
					{
						if(!g_bGrabbingAttack2[client])	
						{	
							char szClass[64];
							GetEdictClassname(g_iGrabbingEntity[client][0], szClass, sizeof(szClass));
							
							if (StrEqual(szClass, "prop_physics"))
							{
								if(Phys_IsPhysicsObject(g_iGrabbingEntity[client][0]))
								{
									if(Phys_IsGravityEnabled(g_iGrabbingEntity[client][0]))
									{													
										Phys_EnableGravity(g_iGrabbingEntity[client][0], false);
										Phys_EnableMotion(g_iGrabbingEntity[client][0], false);
										Phys_Sleep(g_iGrabbingEntity[client][0]);
										PrintHintText(client, "Prop freezed");
									}
									else 
									{
										Phys_EnableGravity(g_iGrabbingEntity[client][0], true);
										Phys_EnableMotion(g_iGrabbingEntity[client][0], true);
										Phys_Wake(g_iGrabbingEntity[client][0]);
										PrintHintText(client, "Prop unfreezed");
									}
								}									
							}
							CreateTimer(0.3, Timer_FreezeCoolDown, client);
							g_bGrabbingAttack2[client] = true;
						}
					}
				}		
				else 
				{
					float fEndPosition[3], fNormal[3];
					GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fNormal, tracerayfilterrocket, client);
					SetEntityGlows(client, -1, fEndPosition);
				}
			}
			else 
			{
				if(IsValidEntity(g_iGrabbingEntity[client][0]))	
				{
					SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwtich);
					g_iGrabbingEntity[client][0] = -1;
				} 
				ResetClientAttribute(client);
			}
		}
		else 
		{
			ResetClientAttribute(client);
		}
	}
	return Plugin_Continue;
} //@

public Action Timer_RotateCoolDown(Handle timer, int client)
{
	if(g_bGrabbingRotate[client]) g_bGrabbingRotate[client] = false;
}

public Action Timer_FreezeCoolDown(Handle timer, int client)
{
	if(g_bGrabbingAttack2[client])  g_bGrabbingAttack2[client] = false;
}

//-------[Stock]----------------------------------------------------------------------------------------------------(
stock bool IsValidClient(int client)
{
	if (client <= 0)	return false;
	if (client > MaxClients)	return false;
	if (!IsClientConnected(client))	return false;
	return IsClientInGame(client);
}

bool IsHoldingPhysicsGun(int client)
{ 
	int iWeapon = GetPlayerWeaponSlot(client, 1);
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
	if(IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex") == g_iPhysicGunWeaponIndex && GetEntProp(iActiveWeapon, Prop_Send, "m_iEntityQuality") == g_iPhysicGunQuality)
	{	//Check Is it Physics Gun
		return true;
	}
	return false;
} //@

stock int GetClientAimEntity(int client)
{
	float fOrigin[3], fAngles[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	
	Handle trace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	if (TR_DidHit(trace)) 
	{	
		int iEntity = TR_GetEntityIndex(trace);
		if(iEntity > 0 && IsValidEntity(iEntity))
		{
			CloseHandle(trace);
			return iEntity;
		}
	}
	CloseHandle(trace);
	return -1;
}

public bool TraceEntityFilter(int entity, int mask, any data) 
{
	return data != entity;
}

//From raindowglow.sp--------------(
stock int CreateGlow(int iEnt)
{
	if(!HasGlow(iEnt))
	{
		char oldEntName[64];
		GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
		
		char strName[126], strClass[64];
		GetEntityClassname(iEnt, strClass, sizeof(strClass));
		Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
		DispatchKeyValue(iEnt, "targetname", strName);

		char strGlowColor[18];
		Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", 135, 224, 230, 255);
	
		int ent = CreateEntityByName("tf_glow");
		if(IsValidEntity(ent))
		{
			DispatchKeyValue(ent, "targetname", "RainbowGlow");
			DispatchKeyValue(ent, "target", strName);
			DispatchKeyValue(ent, "Mode", "0");
			DispatchKeyValue(ent, "GlowColor", strGlowColor);
			DispatchSpawn(ent);
	
			AcceptEntityInput(ent, "Enable");
			
			//Change name back to old name because we don't need it anymore.
			SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
			return ent;
		}
	}
	return -1;
}

stock bool HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	return false;
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, "RainbowGlow"))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}
//---------------------------------)

void SetEntityGlows(int client, int iEntity, float fEndPosition[3]) //Set the Glow and laser
{
	float fEndOnEntityPosition[3], fLocal_Origin[3], fLocal_EOrigin[3];
	CopyVector(fEndPosition, fLocal_EOrigin);
	
	GetClientEyePosition(client, fLocal_Origin);
	fLocal_Origin[2] -= 5.0;
		
	if(IsValidEntity(iEntity))
	{
		//Glow on Grab Entity
		GetClientSightEnd(fLocal_Origin, fLocal_EOrigin, fEndOnEntityPosition);
		TE_SetupGlowSprite(fEndOnEntityPosition, g_iBlueGlow, 0.1, 0.3, 5);	
		TE_SendToAll();
		
		//Glow on Client
		TE_SetupGlowSprite(fLocal_Origin, g_iBlueGlow, 0.1, 0.3, 5);
		TE_SendToAll();
		
		//Laser on client and Entity
		TE_SetupBeamPoints(fLocal_Origin, fLocal_EOrigin, g_ModelIndex, g_HaloIndex, 0, 15, 0.1, 0.5, 1.5, 1, 0.0, {255, 255, 255, 255}, 10);
		TE_SendToAll();	
	}
	else
	{
		//Laser on client and Aim position
		TE_SetupBeamPoints(fLocal_Origin, fLocal_EOrigin, g_ModelIndex, g_HaloIndex, 0, 15, 0.1, 0.11, 0.1, 1, 0.0, {255, 255, 255, 255}, 1);
		TE_SendToAll();
	}
}

void ResetClientAttribute(int client)
{
	if(IsValidEntity(g_iGrabbingEntity[client][1]))	
	{
		AcceptEntityInput(g_iGrabbingEntity[client][1], "Kill");
		g_iGrabbingEntity[client][1] = -1;
	}
	if(IsValidEntity(g_iGrabbingEntity[client][0]))	
	{
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwtich);
		g_iGrabbingEntity[client][0] = -1;
	}
	if(IsValidEntity(g_iGrabbingEntity[client][2]))	
	{
		AcceptEntityInput(g_iGrabbingEntity[client][2], "Kill");
		g_iGrabbingEntity[client][2] = -1;
	}
	if(IsValidEntity(g_iGrabbingEntity[client][3]))	
	{
		AcceptEntityInput(g_iGrabbingEntity[client][3], "Kill");
		g_iGrabbingEntity[client][3] = -1;
	}
}


stock float GetEntitiesDistance(int entity1, int entity2)
{
	float fOrigin1[3];
	GetEntPropVector(entity1, Prop_Send, "m_vecOrigin", fOrigin1);
	
	float fOrigin2[3];
	GetEntPropVector(entity2, Prop_Send, "m_vecOrigin", fOrigin2);
	
	return GetVectorDistance(fOrigin1, fOrigin2);
}

void GetClientSightEnd(float TE_ClientEye[3], float TE_iEye[3], float out[3])
{
    TR_TraceRayFilter(TE_ClientEye, TE_iEye, MASK_SOLID, RayType_EndPoint, TraceRayDontHitPlayers);
    if (TR_DidHit())
        TR_GetEndPosition(out);
}

public bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
    if (0 < entity <= MaxClients)
        return false;

    return true;
}

stock bool GetClientAimPosition(int client, float maxtracedistance, float resultvecpos[3], float resultvecnormal[3], TraceEntityFilter Tfunction, int filter)
{
	float cleyepos[3], cleyeangle[3], eyeanglevector[3];
	GetClientEyePosition(client, cleyepos); 
	GetClientEyeAngles(client, cleyeangle);
	
	Handle traceresulthandle = INVALID_HANDLE;
	
	traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, Tfunction, filter);
	
	if(TR_DidHit(traceresulthandle) == true){
		
		float endpos[3];
		TR_GetEndPosition(endpos, traceresulthandle);
		TR_GetPlaneNormal(traceresulthandle, resultvecnormal);
		
		if((GetVectorDistance(cleyepos, endpos) <= maxtracedistance) || maxtracedistance <= 0){
			
			resultvecpos[0] = endpos[0];
			resultvecpos[1] = endpos[1];
			resultvecpos[2] = endpos[2];
			
			CloseHandle(traceresulthandle);
			return true;
			
		}
		else
		{	
			GetAngleVectors(cleyeangle, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			
			AddVectors(cleyepos, eyeanglevector, resultvecpos);
			
			CloseHandle(traceresulthandle);
			return true;
		}	
	}
	CloseHandle(traceresulthandle);
	return false;
}

public bool tracerayfilterrocket(int entity, int mask, any data)
{
	if (IsValidEntity(entity))
		return false;
	
	return true;	
}

float GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
	static float tmpVec[3];
	tmpVec[0] = vEndPos[0] - vStartPos[0];
	tmpVec[1] = vEndPos[1] - vStartPos[1];
	tmpVec[2] = vEndPos[2] - vStartPos[2];
	GetVectorAngles(tmpVec, vAngles);
}

void AnglesNormalize(float vAngles[3])
{
	while (vAngles[0] > 89.0)vAngles[0] -= 360.0;
	while (vAngles[0] < -89.0)vAngles[0] += 360.0;
	while (vAngles[1] > 180.0)vAngles[1] -= 360.0;
	while (vAngles[1] < -180.0)vAngles[1] += 360.0;
}

void SendDialogToOne(int client, int red, int green, int blue, const char[] text, any ...)
{
	char message[100];
	VFormat(message, sizeof(message), text, 4);	
	
	KeyValues kv = new KeyValues("Stuff", "title", message);
	kv.SetColor("color", red, green, blue, 255);
	kv.SetNum("level", 1);
	kv.SetNum("time", 10);
	
	CreateDialog(client, kv, DialogType_Msg);

	delete kv;
}

stock void ZeroVector(float vector[3])
{
	vector[0] = 0.0;
	vector[1] = 0.0;
	vector[2] = 0.0;
}

stock void CopyVector(const float input[3], float out[3])
{
	out[0] = input[0];
	out[1] = input[1];
	out[2] = input[2];
}

void AttachControlPointParticle(int ent, char[] strParticle, int controlpoint)
{
	int particle = CreateEntityByName("info_particle_system");
	int particle2 = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(particle))
	{ 
		char tName[128];
		Format(tName, sizeof(tName), "SimpleBuild:%i", ent);
		DispatchKeyValue(ent, "targetname", tName);

		char cpName[128];
		Format(cpName, sizeof(cpName), "SimpleBuildd:%i", ent);
		DispatchKeyValue(controlpoint, "targetname", cpName);

		char cp2Name[128];
		Format(cp2Name, sizeof(cp2Name), "tf2particle%i", controlpoint);

		DispatchKeyValue(particle2, "targetname", cp2Name);
		DispatchKeyValue(particle2, "parentname", cpName);

		float pos[3], m_vecMaxs[3], cAng[3];
		GetClientAbsAngles(ent, cAng);
		GetEntPropVector(controlpoint, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(controlpoint, Prop_Send, "m_vecMaxs", m_vecMaxs);
		
		pos[2] += (m_vecMaxs[2] / 2.0);
		
		SetEntPropVector(particle, Prop_Data, "m_angRotation", cAng);
		SetEntPropVector(particle2, Prop_Data, "m_vecOrigin", pos);
		
		SetVariantString(cpName);
		AcceptEntityInput(particle2, "SetParent");

		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", strParticle);
		DispatchKeyValue(particle, "cpoint1", cp2Name);

		DispatchSpawn(particle);

		SetVariantString(tName);
		AcceptEntityInput(particle, "SetParent");

		SetVariantString("flag");
		AcceptEntityInput(particle, "SetParentAttachment");
		cAng[0] -= 270.0;
		cAng[1] -= 69.0;
		SetEntPropVector(particle, Prop_Send, "m_angRotation", cAng);
		//The particle is finally ready
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
	
		g_iGrabbingEntity[ent][2] = EntIndexToEntRef(particle);
		g_iGrabbingEntity[ent][3] = EntIndexToEntRef(particle2);
	}
}