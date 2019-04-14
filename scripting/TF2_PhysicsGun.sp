#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "3.00"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Physics Gun",
	author = PLUGIN_AUTHOR,
	description = "Brings physics gun feature to tf2!",
	version = PLUGIN_VERSION,
	url = "https://github.com/BattlefieldDuck/TF2_PhysicsGun"
};

//Hide ammo count & weapon selection
#define HIDEHUD_WEAPONSELECTION	( 1<<0 )

//Physics Gun Settings
#define WEAPON_SLOT 1

#define MODEL_PHYSICSLASER	"materials/sprites/physbeam.vmt"
#define MODEL_HALOINDEX		"materials/sprites/halo01.vmt"
#define MODEL_PHYSICSGUNVM	"models/weapons/v_superphyscannon.mdl"
#define MODEL_PHYSICSGUNWM	"models/weapons/w_physics.mdl"

static const int g_iPhysicsGunWeaponIndex = 423;//Choose Saxxy(423) because the player movement won't become a villager
static const int g_iPhysicsGunQuality = 1;
static const int g_iPhysicsGunLevel = 99-128;	//Level displays as 99 but negative level ensures this is unique

int g_iModelIndex;
int g_iHaloIndex;
int g_iPhysicsGunVM;
int g_iPhysicsGunWM;

int g_iAimingEntityRef	[MAXPLAYERS + 1]; //Aimming entity ref
int g_iEntityRef		[MAXPLAYERS + 1]; //Grabbing entity ref
int g_iGrabPointRef		[MAXPLAYERS + 1]; //Entity grabbing point
int g_iClientVMRef		[MAXPLAYERS + 1]; //Client physics gun viewmodel ref
float g_fGrabDistance	[MAXPLAYERS + 1]; //Distance between the client eye and entity grabbing point

public void OnPluginStart()
{
	RegAdminCmd("sm_pg", 			Command_EquipPhysicsGun, ADMFLAG_ROOT, "Equip a Physics Gun");
	RegAdminCmd("sm_physgun", 		Command_EquipPhysicsGun, ADMFLAG_ROOT, "Equip a Physics Gun");
	RegAdminCmd("sm_physicsgun", 	Command_EquipPhysicsGun, ADMFLAG_ROOT, "Equip a Physics Gun");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	g_iModelIndex 	= PrecacheModel(MODEL_PHYSICSLASER);
	g_iHaloIndex 	= PrecacheModel(MODEL_HALOINDEX);
	g_iPhysicsGunVM = PrecacheModel(MODEL_PHYSICSGUNVM);
	g_iPhysicsGunWM = PrecacheModel(MODEL_PHYSICSGUNWM);

	for (int client = 1; client < MAXPLAYERS; client++)
	{
		if(client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchHookPost);
	
	g_iAimingEntityRef[client] 	= INVALID_ENT_REFERENCE;
	g_iEntityRef[client] 		= INVALID_ENT_REFERENCE;
	g_iGrabPointRef[client] 	= INVALID_ENT_REFERENCE;
	g_fGrabDistance[client] = 99999.9;
	
	g_iClientVMRef[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, BlockPhysicsGunDrop);
	}
}

public void BlockPhysicsGunDrop(int entity)
{
	if(IsValidEntity(entity) && IsPhysicsGun(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action Command_EquipPhysicsGun(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	//Set physics gun as Active Weapon
	int weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	if (IsValidEntity(weapon))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	
	//Credits: FlaminSarge
	weapon = CreateEntityByName("tf_weapon_builder");
	if (IsValidEntity(weapon))
	{
		SetEntityModel(weapon, MODEL_PHYSICSGUNWM);
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_iPhysicsGunWeaponIndex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		//Player crashes if quality and level aren't set with both methods, for some reason
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityQuality", true), g_iPhysicsGunQuality);
		SetEntData(weapon, GetEntSendPropOffs(weapon, "m_iEntityLevel", true), g_iPhysicsGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", g_iPhysicsGunQuality);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", g_iPhysicsGunLevel);
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
		SetEntProp(weapon, Prop_Send, "m_nSkin", 1);
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iPhysicsGunWM);
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", g_iPhysicsGunWM, _, 0);
		SetEntProp(weapon, Prop_Send, "m_nSequence", 2);
		
		TF2_RemoveWeaponSlot(client, WEAPON_SLOT);
		DispatchSpawn(weapon);
		EquipPlayerWeapon(client, weapon);		
	}

	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		TF2_RegeneratePlayer(client);
	}
}

//ViewModel Handler
#define EF_NODRAW 32
public Action WeaponSwitchHookPost(int client, int entity)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
		
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(IsHoldingPhysicsGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) == INVALID_ENT_REFERENCE)
	{
		//Hide Original viewmodel
		int iEffects = GetEntProp(iViewModel, Prop_Send, "m_fEffects");
		iEffects |= EF_NODRAW;
		SetEntProp(iViewModel, Prop_Send, "m_fEffects", iEffects);
		 
		//Create client physics gun viewmodel
		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iPhysicsGunVM));
	}
	//Remove client physics gun viewmodel
	else if (EntRefToEntIndex(g_iClientVMRef[client]) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(EntRefToEntIndex(g_iClientVMRef[client]), "Kill");
	}
	
	return Plugin_Continue;
}

public Action BlockWeaponSwitch(int client, int entity)
{
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	ClientSettings(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
	PhysGunSettings(client, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
	
	return Plugin_Continue;
}

/********************
		Stock
*********************/
bool IsHoldingPhysicsGun(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	return (IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && IsPhysicsGun(iActiveWeapon));
}

//Credits: FlaminSarge
bool IsPhysicsGun(int entity) 
{
	if (GetEntSendPropOffs(entity, "m_iItemDefinitionIndex", true) <= 0) 
	{
		return false;
	}
	return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex") == g_iPhysicsGunWeaponIndex
		&& GetEntProp(entity, Prop_Send, "m_iEntityQuality") == g_iPhysicsGunQuality
		&& GetEntProp(entity, Prop_Send, "m_iEntityLevel") == g_iPhysicsGunLevel;
}

/* Physics gun function */
float[] GetClientEyePositionEx(int client)
{
	float pos[3]; 
	GetClientEyePosition(client, pos);
	return pos;
}

float[] GetClientEyeAnglesEx(int client)
{
	float angles[3]; 
	GetClientEyeAngles(client, angles);
	return angles;
}

float[] GetPointAimPosition(float pos[3], float angles[3], float maxtracedistance, int client)
{
	Handle trace = TR_TraceRayFilterEx(pos, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, client);

	if(TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (entity > 0)	g_iAimingEntityRef[client] = EntIndexToEntRef(entity);
		else g_iAimingEntityRef[client] = INVALID_ENT_REFERENCE;
		
		float endpos[3];
		TR_GetEndPosition(endpos, trace);
		
		if((GetVectorDistance(pos, endpos) <= maxtracedistance) || maxtracedistance <= 0)
		{
			CloseHandle(trace);
			return endpos;
		}
		else
		{
			float eyeanglevector[3];
			GetAngleVectors(angles, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
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
	return (IsValidEntity(entity)
			&& entity != client
			&& entity != EntRefToEntIndex(g_iEntityRef[client])
			&& entity != EntRefToEntIndex(g_iGrabPointRef[client])
			&& MaxClients < entity);
}

float[] GetAngleYOnly(const float angles[3])
{
	float fAngles[3];
	fAngles[1] = angles[1];

	return fAngles;
}

int CreateGrabPoint()
{
	int iGrabPos = CreateEntityByName("prop_dynamic_override");//CreateEntityByName("info_target");
	DispatchKeyValue(iGrabPos, "model", MODEL_PHYSICSGUNWM);
	
	SetEntPropFloat(iGrabPos, Prop_Send, "m_flModelScale", 0.0);
	
	DispatchSpawn(iGrabPos);
	return iGrabPos;
}

//Credits: Alienmario
void TE_SetupBeamEnts(int ent1, int ent2, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed, int flags)
{
	TE_Start("BeamEnts");
	TE_WriteEncodedEnt("m_nStartEntity", ent1);
	TE_WriteEncodedEnt("m_nEndEntity", ent2);
	TE_WriteNum("m_nModelIndex", ModelIndex);
	TE_WriteNum("m_nHaloIndex", HaloIndex);
	TE_WriteNum("m_nStartFrame", StartFrame);
	TE_WriteNum("m_nFrameRate", FrameRate);
	TE_WriteFloat("m_fLife", Life);
	TE_WriteFloat("m_fWidth", Width);
	TE_WriteFloat("m_fEndWidth", EndWidth);
	TE_WriteFloat("m_fAmplitude", Amplitude);
	TE_WriteNum("r", Color[0]);
	TE_WriteNum("g", Color[1]);
	TE_WriteNum("b", Color[2]);
	TE_WriteNum("a", Color[3]);
	TE_WriteNum("m_nSpeed", Speed);
	TE_WriteNum("m_nFadeLength", FadeLength);
	TE_WriteNum("m_nFlags", flags);
}

//Credits: FlaminSarge
#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)
int CreateVM(int client, int modelindex)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_nModelIndex", modelindex);
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent);
	return ent;
}

//Credits: FlaminSarge
Handle g_hSdkEquipWearable;
int TF2_EquipWearable(int client, int entity)
{
	if (g_hSdkEquipWearable == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("tf2items.randomizer");
		if (hGameConf == INVALID_HANDLE)
		{
			SetFailState("Couldn't load SDK functions. Could not locate tf2items.randomizer.txt in the gamedata folder.");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		if (g_hSdkEquipWearable == INVALID_HANDLE)
		{
			SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
			CloseHandle(hGameConf);
			return;
		}
	}
	if (g_hSdkEquipWearable != INVALID_HANDLE) SDKCall(g_hSdkEquipWearable, client, entity);
}

stock void ClientSettings(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(IsHoldingPhysicsGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) == INVALID_ENT_REFERENCE)
	{
		//Hide Original viewmodel
		int iEffects = GetEntProp(iViewModel, Prop_Send, "m_fEffects");
		iEffects |= EF_NODRAW;
		SetEntProp(iViewModel, Prop_Send, "m_fEffects", iEffects);
		 
		//Create client physics gun viewmodel
		g_iClientVMRef[client] = EntIndexToEntRef(CreateVM(client, g_iPhysicsGunVM));
	}
	//Remove client physics gun viewmodel
	else if (!IsHoldingPhysicsGun(client) && EntRefToEntIndex(g_iClientVMRef[client]) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(EntRefToEntIndex(g_iClientVMRef[client]), "Kill");
	}
	
	if (IsHoldingPhysicsGun(client) && buttons & IN_ATTACK)
	{
		//Block weapon switch
		SDKHook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwitch);
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_WEAPONSELECTION);
		
		//Fix client eyes angles
		if (buttons & IN_RELOAD || buttons & IN_ATTACK2 || buttons & IN_ATTACK3)
		{
			if(!(GetEntityFlags(client) & FL_FROZEN))	SetEntityFlags(client, (GetEntityFlags(client) | FL_FROZEN));
		}
		else
		{
			if(GetEntityFlags(client) & FL_FROZEN)	SetEntityFlags(client, (GetEntityFlags(client) & ~FL_FROZEN));
		}
		
	}
	else
	{
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, BlockWeaponSwitch);
		if(GetEntProp(client, Prop_Send, "m_iHideHUD") & HIDEHUD_WEAPONSELECTION)	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") &~HIDEHUD_WEAPONSELECTION);
		
		if(GetEntityFlags(client) & FL_FROZEN)	SetEntityFlags(client, (GetEntityFlags(client) & ~FL_FROZEN));
	}
}

stock void PhysGunSettings(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	static float oldfEntityPos[3], fEntityPos[3];
	float fAimpos[3];
	fAimpos = GetPointAimPosition(GetClientEyePositionEx(client), GetClientEyeAnglesEx(client), g_fGrabDistance[client], client);
	
	if (IsHoldingPhysicsGun(client) && (buttons & IN_ATTACK))
	{
		int iGrabPos = EntRefToEntIndex(g_iGrabPointRef[client]);
		if (iGrabPos == INVALID_ENT_REFERENCE)
		{
			iGrabPos = CreateGrabPoint();
			g_iGrabPointRef[client] = EntIndexToEntRef(iGrabPos);
		}
		else
		{
			TeleportEntity(iGrabPos, fAimpos, NULL_VECTOR, NULL_VECTOR);
			
			int clientvm = EntRefToEntIndex(g_iClientVMRef[client]);
			if (clientvm != INVALID_ENT_REFERENCE)
			{
				TE_SetupBeamEnts(iGrabPos, EntRefToEntIndex(g_iClientVMRef[client]), g_iModelIndex, g_iHaloIndex, 0, 15, 0.1, 1.0, 1.0, 1, 0.0, {255, 255, 255, 255}, 10, 20);
				TE_SendToClient(client);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (client != i && IsClientInGame(i))
					{
						TE_SetupBeamEnts(client, iGrabPos, g_iModelIndex, g_iHaloIndex, 0, 15, 0.1, 1.0, 1.0, 1, 0.0, {255, 255, 255, 255}, 10, 20);
						TE_SendToClient(i);
					}
				}
				
			}
			oldfEntityPos = fEntityPos;
			fEntityPos = fAimpos;
		}
		
		//Debug
		//PrintCenterText(client, "%f %f %f  AimEnt: %i GrabPos: %i Ent: %i Distance: %f"
		//, fAimpos[0], fAimpos[1], fAimpos[2], EntRefToEntIndex(g_iAimingEntityRef[client]), EntRefToEntIndex(g_iGrabPointRef[client]), EntRefToEntIndex(g_iEntityRef[client]), g_fGrabDistance[client]);
		//PrintCenterText(client, "%i %i", mouse[0], mouse[1]);
		
		int iEntity = EntRefToEntIndex(g_iEntityRef[client]);
		//When the player aim the prop
		if (EntRefToEntIndex(g_iAimingEntityRef[client]) != INVALID_ENT_REFERENCE && iEntity == INVALID_ENT_REFERENCE)
		{
			//Set the aimming entity to grabbing entity
			g_iEntityRef[client] = g_iAimingEntityRef[client];
			iEntity = EntRefToEntIndex(g_iEntityRef[client]);

			TeleportEntity(EntRefToEntIndex(g_iGrabPointRef[client]), fAimpos, GetAngleYOnly(angles), NULL_VECTOR);
			
			char szClass[32];
			GetEdictClassname(iEntity, szClass, sizeof(szClass));
			
			if((StrEqual(szClass, "prop_physics") || StrEqual(szClass, "tf_dropped_weapon")))
			{
				float dummy[3];
				TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, dummy);
			}
			
			//Set grabbing entity parent to grabbing point
			SetVariantString("!activator");
			AcceptEntityInput(iEntity, "SetParent", EntRefToEntIndex(g_iGrabPointRef[client]));

			g_fGrabDistance[client] = GetVectorDistance(GetClientEyePositionEx(client), fAimpos);
			
			fEntityPos = fAimpos;
		}
		
		//When the player grabbing prop
		if (iGrabPos != INVALID_ENT_REFERENCE && iEntity != INVALID_ENT_REFERENCE)
		{
			if (buttons & IN_RELOAD || buttons & IN_ATTACK2 || buttons & IN_ATTACK3)
			{
				//Rotate + Push and pull
				if (buttons & IN_RELOAD)
				{
					float fAngle[3];
					GetEntPropVector(iGrabPos, Prop_Send, "m_angRotation", fAngle); //1

					//Rotate in 45'
					if (buttons & IN_DUCK) 
					{
						static float iRotateCD = 0.0;
						if (iRotateCD <= 0.0)
						{
							//Get the magnitude
							int mousex = (mouse[0] < 0)? mouse[0]*-1 : mouse[0];
							int mousey = (mouse[1] < 0)? mouse[1]*-1 : mouse[1];
							
							if (mousex > mousey && mousex > 1)
							{
								(mouse[0] > 0)? (fAngle[1] += 45.0):(fAngle[1] -= 45.0);
								
								iRotateCD = 2.0;
							}
							else if (mousey > mousex && mousey > 1)
							{
								(mouse[1] > 0)? (fAngle[0] -= 45.0):(fAngle[0] += 45.0);
								
								iRotateCD = 2.0;
							}								
						}
						else if (iRotateCD > 0.0)	iRotateCD -= 0.1;
					}
					//Normal rotation
					else
					{
						fAngle[0] -= mouse[1]/6.0;
						fAngle[1] += mouse[0]/6.0;
					}
					
					TeleportEntity(iGrabPos, NULL_VECTOR, fAngle, NULL_VECTOR);
					
					AcceptEntityInput(iEntity, "ClearParent"); //2
					
					//Get the entity variables while ClearParent
					//float fEntityAngle[3];
					//GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fEntityAngle);
					
					TeleportEntity(iGrabPos, NULL_VECTOR, GetAngleYOnly(angles), NULL_VECTOR); //3
				
					SetVariantString("!activator");
					AcceptEntityInput(iEntity, "SetParent", iGrabPos); //4
					
					//Push and pull
					if(buttons & IN_FORWARD)
					{
						g_fGrabDistance[client] += 1.0;
					}				
					if(buttons & IN_BACK)
					{
						g_fGrabDistance[client] -= 1.0;
						if (g_fGrabDistance[client] < 50.0)	g_fGrabDistance[client] = 50.0;
					}
				}
				else if (buttons & IN_ATTACK2)
				{
					
				}
				//Push and pull
				else if (buttons & IN_ATTACK3)
				{
					g_fGrabDistance[client] -= mouse[1]/2.0;
					if (g_fGrabDistance[client] < 50.0)	g_fGrabDistance[client] = 50.0;
				}
			}
			else
			{
				TeleportEntity(iGrabPos, NULL_VECTOR, GetAngleYOnly(angles), NULL_VECTOR);
			}
			
			TeleportEntity(iGrabPos, fAimpos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	else
	{
		int entity = EntRefToEntIndex(g_iEntityRef[client]);
		if(entity != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(entity, "ClearParent");
			
			char szClass[32];
			GetEdictClassname(entity, szClass, sizeof(szClass));
			
			//Apply velocity
			if((StrEqual(szClass, "prop_physics") || StrEqual(szClass, "tf_dropped_weapon")))
			{
				float vector[3];
				MakeVectorFromPoints(oldfEntityPos, fEntityPos, vector);
				if (StrEqual(szClass, "prop_physics"))
				{
					ScaleVector(vector, 20.0);
				}
				else
				{
					ScaleVector(vector, 30.0);
				}
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vector);

			}
			g_iEntityRef[client] = INVALID_ENT_REFERENCE;
		}

		int iGrabPos = EntRefToEntIndex(g_iGrabPointRef[client]);
		if(iGrabPos != INVALID_ENT_REFERENCE)
		{
			RequestFrame(KillGrabPosPost, g_iGrabPointRef[client]);	
		}

		g_fGrabDistance[client] = 99999.9;
	}
}

//Normally 2 is okay but 4 is more secure
#define FRAME_DELAY 4

//Credits: Pelipoika
public void KillGrabPosPost(int entity)
{
    static int iFrame = 0;

    if(++iFrame < FRAME_DELAY)
    {
        RequestFrame(KillGrabPosPost, entity);
        return;
    }

    int iGrabPos = EntRefToEntIndex(entity);
    if(iGrabPos != INVALID_ENT_REFERENCE)
    {
        AcceptEntityInput(iGrabPos, "Kill");
    }
    
    iFrame = 0;
}