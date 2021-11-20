# TF2_PhysicsGun
Allow players to use PhysicsGun on TF2! Grab everything!
![Screenshot](https://raw.githubusercontent.com/BattlefieldDuck/TF2_PhysicsGun/master/screenshot1.png)
## Requirements
- [VPhysics](https://forums.alliedmods.net/showthread.php?t=136350)
- [TF2Items_Giveweapon](https://forums.alliedmods.net/showthread.php?p=1337899) (Only v1.0)

## Natives
Library name is `tf2physgun`
```
native bool TF2PhysGun_IsHoldingPhysicsGun(int client);
native bool TF2PhysGun_IsPhysicsGun(int entity);
native int TF2PhysGun_GetEntityHolder(int entity);
native int TF2PhysGun_GetClientHeldEntity(int client);
```

Pull requests welcome
