#if defined _inc_tf2physicsgun
#endinput
#endif
#define _inc_tf2physicsgun

/**
 * Check the active weapon for this client
 * @return true if the weapon is the PhysicsGun
 */
native bool TF2PhysGun_IsHoldingPhysicsGun(int client);
/**
 * Check the specified weapon entity
 * @return true if the weapon is the PhysicsGun
 */
native bool TF2PhysGun_IsPhysicsGun(int entity);
/**
 * Do a reverse lookup from the entity to the client holding it.
 * This funtion is designed to be used like <code>if (TF2PhysGun_GetEntityHolder(ent))</code>
 * to check if the entity is currently held and thus will return 0 if it's not held by a player.
 * @return the client index or 0 if the entity is not held
 */
native int TF2PhysGun_GetEntityHolder(int entity);
/**
 * Get the entity a client is holding
 * @return the held entity or INVALID_ENT_REFERENCE if none
 */
native int TF2PhysGun_GetClientHeldEntity(int client);

public SharedPlugin __pl_tf2physgun = 
{
    name = "tf2physgun",
    file = "TF2_PhysicsGun.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tf2physgun_SetNTVOptional()
{
	MarkNativeAsOptional("TF2PhysGun_IsHoldingPhysicsGun");
	MarkNativeAsOptional("TF2PhysGun_IsPhysicsGun");
	MarkNativeAsOptional("TF2PhysGun_GetEntityHolder");
	MarkNativeAsOptional("TF2PhysGun_GetClientHeldEntity");
}
#endif