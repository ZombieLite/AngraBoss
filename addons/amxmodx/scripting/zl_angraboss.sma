#include < amxmodx >
#include < engine >
#include < fakemeta >
#include < hamsandwich >
#include < xs >

#define NAME 			"AngraBoss"
#define VERSION			"1.0"
#define AUTHOR			"Alexander.3"

#define NEW_SEARCH
#define MAPCHOOSER

#define AGGRESSIVE_ATTACK	random_num(1, 2)
#define AGGRESSIVE_TENTACLE	random_num(5, 10)
#define AGGRESSIVE_POISON	random_num(10, 20)
#define AGGRESSIVE_FLAME	random_num(1, 5)
#define AGGRESSIVE_PASSIVE	random_num(1, 1)

// MapEvent
new const msg_boxhp[] =		"Box health: %d"
const Float:box_health =	0.1			// Rate ( boss_hp )

#if defined MAPCHOOSER
native zl_vote_start()
#else
new boss_nextmap[25]
#endif
new boss_hp, prepare_time, Float:ability_time, Float:rage_time, Float:aggressive_time,
	speed_boss, speed_barash, dmg_attack, dmg_barash, blood_color

new Float:egg_hp, Float:egg_upspr,
	egg_blood_fire, egg_blood_regen, egg_blood_shield,
	egg_fire_dmg, Float:egg_timer_damage, 
	egg_heal_hp, egg_heal_player, egg_heal_restore, Float:egg_heal_regen, Float:egg_heal_time,
	egg_armor_max, egg_armor_add, egg_armor_destroy, Float:egg_armor_damage

static Ability
static g_BossTarget
static g_Angra
static b_Angra
static VictimID
static Float:g_MaxHp
static Counter
static bool:AttackPre, bool:Rage[3]
static AggressiveLevel
static FlyNum
static Egg[3], bool:EggHeal[33]
static EggSpr[3]
static EggPhase
static MapWall[6], MapStart[2], MapCrane, MapBox, MapButton, MapCenter[2], MapSound[12],
	Float:MapOrigin[6][3], Float:MapEggOrigin[3][3], Float:MapBreakOrigin[3][3]

native cs_set_user_team(index, team);
native cs_set_user_deaths(index, newdeaths)
native zl_boss_map()
native zl_boss_valid(index)
native zl_player_alive()
native zl_player_random()

new const Resource[][] = {
	"models/zl/npc/angra/zl_angra.mdl",			// 0 -
	"models/zl/npc/angra/zl_gibs_floor.mdl",			// 1
	"sprites/laserbeam.spr",			// 2
	"models/zl/npc/angra/zl_tentacle.mdl",		// 3 -
	"models/zl/npc/angra/zl_tentacle_walk.mdl",		// 4 -
	"models/zl/npc/angra/zl_tentacle_walk2.mdl",		// 5 -
	"sprites/zl/npc/angra/zl_poison.spr",		// 6 -
	"sprites/zl/npc/angra/zl_flame.spr",		// 7 - 
	"models/zl/npc/angra/zl_egg.mdl",			// 8 -
	"sprites/zl/npc/angra/zl_hp_shield.spr",		// 9
	"sprites/zl/npc/angra/zl_hp_regen.spr",		// 10
	"sprites/zl/npc/angra/zl_hp_flame.spr",		// 11
	"sprites/zl/npc/angra/zl_rage.spr",		// 12
	"models/zl/npc/angra/zl_gibs_box.mdl",		// 13
	"sprites/blood.spr",				// 14
	"sprites/bloodspray.spr",			// 15
	"models/bonegibs.mdl"				// 16
}
static g_Resource[sizeof Resource]
new const FILE_SETTING[] = "zl_angraboss.ini"

enum {
	Prepare,
	Walk,
	Attack,
	Tentacle,
	Poison,
	Barash,
	PhaseFLY,
	EGG,
	Phase_change
}

new const SoundList[][] = {
	"zl/npc/angra/tentacle1.wav",
	"zl/npc/angra/tentacle2.wav",
	"zl/npc/angra/poison1.wav",
	"zl/npc/angra/poison2.wav",
	"zl/npc/zombie_scenario_ready.mp3",
	"zl/npc/scenario_rush.mp3",
	"zl/npc/scenario_normal.mp3"
}

public plugin_init() {
	register_plugin(NAME, VERSION, AUTHOR)
	
	if(zl_boss_map() != 3) {
		pause("ad")
		return
	}
	
	register_logevent("BotCreate", 2, "1=Round_Start")
	
	register_think("AngraBoss", "Think_Angra")
	register_think("Timer", "Think_HP")
	register_think("BossEgg_0", "ThinkEgg_0")
	register_think("BossEgg_1", "ThinkEgg_1")
	register_think("BossEgg_2", "ThinkEgg_2")

	RegisterHam(Ham_TakeDamage, "info_target", "TakeDamage")
	RegisterHam(Ham_Spawn, "player", "PlayerSpawn", 1)
	RegisterHam(Ham_BloodColor, "info_target", "BloodColor")
	RegisterHam(Ham_Killed, "info_target", "Hook_Killed")
	RegisterHam(Ham_Killed, "player", "Hook_Killed", 1)
	
	register_touch("AngraBoss", "player", "Touch_Angra")
	register_touch("ClassTentacle", "player", "Touch_Tentacle")
	register_touch("ClassBreath", "*", "Touch_Breath")
	
	register_clcmd("say /test", "test")
	
	MapEvent()
}

public test() {
	client_print(0, print_chat, "%d", MapSound[0])
	dllfunc(DLLFunc_Use, MapSound[0], MapSound[0])
}

public PlayerSpawn(id) {
	if (!is_user_connected(id) || is_user_bot(id))
		return HAM_IGNORED
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("BarTime2"), _, id)
	write_short(Counter)
	write_short(0)
	message_end()
	
	if(pev(g_Angra, pev_takedamage) == DAMAGE_NO)	
		client_cmd(id, "mp3 play ^"sound/%s^"", SoundList[4])
	else
		client_cmd(id, "mp3 play ^"sound/%s^"", SoundList[6])
	
	return HAM_HANDLED
}
	
public BossStart() {
	static bool:OneRound
	if (OneRound)
		return
		
	g_Angra = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))	
	
	engfunc(EngFunc_SetModel, g_Angra, Resource[0])
	engfunc(EngFunc_SetSize, g_Angra, {-32.0, -32.0, -36.0}, Float:{32.0, 32.0, 96.0})
	
	new Float:mOrigin[3]
	pev(MapStart[0], pev_origin, mOrigin)
	engfunc(EngFunc_SetOrigin, g_Angra, mOrigin)

	engfunc(EngFunc_SetClientKeyValue, g_Angra, engfunc(EngFunc_GetInfoKeyBuffer, g_Angra), "model", Resource[0])
	set_pdata_int(g_Angra, 496, g_Resource[0], 4)
	
	set_pev(g_Angra, pev_classname, "AngraBoss")
	set_pev(g_Angra, pev_solid, SOLID_BBOX)
	set_pev(g_Angra, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(g_Angra, pev_takedamage, DAMAGE_NO)
	set_pev(g_Angra, pev_deadflag, DEAD_NO)
	//if (prepare_time > 10 ) 
	//	set_pev(g_Angra, pev_nextthink, get_gametime() + (11.0 + prepare_time))
	//else 
	set_pev(g_Angra, pev_nextthink, get_gametime() + 0.1)
	set_pev(g_Angra, pev_effects, pev(g_Angra, pev_effects) | EF_NODRAW)
	Anim(g_Angra, 5, 1.0)
	Ability = Prepare
	OneRound = true
}

public Think_Angra(Ent) {
	if (pev(Ent, pev_deadflag) == DEAD_DYING)
		return
	
	static Float:AbilityThink
	if (AbilityThink <= get_gametime()) {
		AbilityThink = get_gametime() + ((Rage[0]) ? (rage_time) : (ability_time))
		
		if (Rage[0]) Rage[1] = true
		BossAbility(Rage[0])
	}
	
	static Float:AgrTime
	if (AgrTime <= get_gametime()) {
		AggressiveLevel += AGGRESSIVE_PASSIVE
		AgrTime = get_gametime() + aggressive_time
	}
	
	static bool:one
	switch( Ability ) {
		case Prepare: {
			static num;
			switch(num) {
				case 0: {
					new Float:Velocity[3], Float:Angles[3], Len
					Len = Move(Ent, MapStart[1], 300.0, Velocity, Angles)
					set_pev(Ent, pev_effects, pev(Ent, pev_effects) & ~EF_NODRAW)
					set_pev(Ent, pev_velocity, Velocity)
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					if (Len < 100) {
						set_pev(g_Angra, pev_movetype, MOVETYPE_NONE)
						Anim(Ent, 0, 1.0)
						set_pev(Ent, pev_nextthink, get_gametime() + 1.8)
						num++
					}
				}
				case 1: {
					Anim(Ent, 4, 1.0)
					dllfunc(DLLFunc_Use, MapSound[11], MapSound[11])
					set_pev(Ent, pev_nextthink, get_gametime() + 6.1)
					num++
				}
				case 2: {
					set_pev(Ent, pev_movetype, MOVETYPE_NONE)
					Anim(Ent, 18, 1.0)
					set_pev(Ent, pev_nextthink, get_gametime() + 2.0)
					num++
				}
				case 3: {
					new Float:Origin[3], Float:Vector[3], Float:Origin2[3]
					set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
					pev(Ent, pev_origin, Origin)
					pev(MapCenter[1], pev_origin, Origin2)
					xs_vec_sub(Origin2, Origin, Vector)
					xs_vec_normalize(Vector, Vector)
					Vector[2] = 2.0
					xs_vec_mul_scalar(Vector, 400.0, Vector)
					set_pev(Ent, pev_velocity, Vector)
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 4: {
					g_MaxHp = float(PlayerHp(1.0))
					set_pev(Ent, pev_health, g_MaxHp)
					set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
					Anim(Ent, 2, 1.3)
					set_pev(Ent, pev_nextthink, get_gametime() + 1.6)
					num++
				}
				case 5: {
					client_cmd(0, "mp3 play ^"sound/%s^"", SoundList[6])
					set_pev(Ent, pev_takedamage, DAMAGE_YES)
					set_pev(Ent, pev_movetype, MOVETYPE_NONE)
					Anim(Ent, 3, 1.0)
					Ability = Walk
					set_pev(Ent, pev_nextthink, get_gametime() + 3.0)
					one = true
				}
			}
			return
		}
		case Walk: {
			new Float:Velocity[3], Float:Angles[3]
			if (!is_user_alive(g_BossTarget)) {
				g_BossTarget = zl_player_random()
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				return
			}
			if (one) {
				set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
				Anim(Ent, 5, 1.0)
				one = false
			}
			#if defined NEW_SEARCH
			new s_LenBuff = 99999, Len
			for(new i = 1; i <= get_maxplayers(); i++) {
				if (!is_user_alive(i) || is_user_bot(i))
					continue
						
				Len = Move(Ent, i, 500.0, Velocity, Angles)
				
				if (Len < s_LenBuff) {
					s_LenBuff = Len
					g_BossTarget = i
				}
			}
			#endif
			Move(Ent, g_BossTarget, float(speed_boss), Velocity, Angles)
			Velocity[2] ? (Velocity[2] = 0.0) : (Velocity[2])
			set_pev(Ent, pev_velocity, Velocity)
			set_pev(Ent, pev_angles, Angles)
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		}
		case Attack: {
			static num;
			switch (num) {
				case 0: {
					AttackPre = true
					Anim(Ent, 8, 1.0)
					set_pev(Ent, pev_nextthink, get_gametime() + 0.6)
					num++
					return
				}
				case 1: {
					new Float:Origin[3], Float:Origin2[3], Float:Vector[3], Float:Len
					pev(Ent, pev_origin, Origin)
					pev(VictimID, pev_origin, Origin2)
					
					xs_vec_sub(Origin2, Origin, Vector)
					Len = xs_vec_len(Vector)
					if (Len <= 140) {
						BossDamage(VictimID, float(dmg_attack + AggressiveLevel), AGGRESSIVE_ATTACK)
					}
					AttackPre = false
					one = true
					num = 0
					Ability = Walk
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					return
				}
			}
		}
		case Tentacle: {
			static num;
			static Tent[12], Tent2[12], Tent3[12]
			static Float:Tent_Origin[12][3]
			switch(num) {
				case 0: {
					new Float:Origin[3], Float:Origin2[3], Float:Vector[3], Float:Len, Float:LenBuff, AimTarget
					set_pev(Ent, pev_movetype, MOVETYPE_NONE)
					pev(Ent, pev_origin, Origin2)
					Anim(Ent, 11, 1.0)
					dllfunc(DLLFunc_Use, MapSound[10], MapSound[10])
					for(new s = 1; s <= get_maxplayers(); s++) {
						if (!is_user_alive(s) || is_user_bot(s))
							continue
						
						pev(s, pev_origin, Origin)
						xs_vec_sub(Origin, Origin2, Vector)
						Len = xs_vec_len(Vector)
						if (Len > LenBuff) {
							LenBuff = Len
							AimTarget = s
						}
					}
					for (new i; i <= charsmax(Tent); ++i) {
						Tent[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetModel, Tent[i], Resource[4])					
						set_pev(Tent[i], pev_rendermode, kRenderTransAdd)
						set_pev(Tent[i], pev_renderamt, 255.0)
						Anim(Tent[i], 0, 1.0)
					}
					for (new i; i <= charsmax(Tent2); ++i) {
						Tent2[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetModel, Tent2[i], Resource[3])
						engfunc(EngFunc_SetSize, Tent2[i], Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0})
						set_pev(Tent2[i], pev_classname, "ClassTentacle")
						set_pev(Tent2[i], pev_solid, SOLID_SLIDEBOX)
						set_pev(Tent2[i], pev_movetype, MOVETYPE_NONE)
						
					}
					for (new i; i <= charsmax(Tent3); ++i) {
						Tent3[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetModel, Tent3[i], Resource[5])
						set_pev(Tent3[i], pev_rendermode, kRenderTransAdd)
						set_pev(Tent3[i], pev_renderamt, 255.0)
					}
					new Float:t_Origin[3], Float:t_Vector[3], Float:Angles[3]
					pev(AimTarget, pev_origin, t_Origin)
					xs_vec_sub(t_Origin, Origin2, t_Vector)
					vector_to_angle(t_Vector, Angles)
					Angles[0] = 0.0
					Angles[2] = 0.0
					set_pev(Ent, pev_angles, Angles)
					
					get_position(Ent, 150.0, -100.0, 1.0, Tent_Origin[0])
					get_position(Ent, 150.0, 0.0, 1.0, Tent_Origin[1])
					get_position(Ent, 150.0, 100.0, 1.0, Tent_Origin[2])
					
					get_position(Ent, 300.0, -170.0, 1.0, Tent_Origin[3])
					get_position(Ent, 300.0, 0.0, 1.0, Tent_Origin[4])
					get_position(Ent, 300.0, 170.0, 1.0, Tent_Origin[5])
					
					get_position(Ent, 400.0, -240.0, 1.0, Tent_Origin[6])
					get_position(Ent, 400.0, 0.0, 1.0, Tent_Origin[7])
					get_position(Ent, 400.0, 240.0, 1.0,Tent_Origin[8])
					
					get_position(Ent, 500.0, -310.0, 1.0, Tent_Origin[9])
					get_position(Ent, 500.0, 0.0, 1.0, Tent_Origin[10])
					get_position(Ent, 500.0, 310.0, 1.0, Tent_Origin[11])
					
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 1: {
					Sound(Ent, 0, 0)
					for(new i = 0; i < 3; i++) engfunc(EngFunc_SetOrigin, Tent[i], Tent_Origin[i])
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 2: {
					for(new i = 3; i < 6; i++) engfunc(EngFunc_SetOrigin, Tent[i], Tent_Origin[i])
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 3: {
					for(new i = 6; i < 9; i++) engfunc(EngFunc_SetOrigin, Tent[i], Tent_Origin[i])
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 4: { // Func
					Sound(Ent, 1, 0)
					for(new i = 9; i < 12; i++) engfunc(EngFunc_SetOrigin, Tent[i], Tent_Origin[i])
					for(new i = 0; i < 3; i++) { engfunc(EngFunc_SetOrigin, Tent2[i], Tent_Origin[i]); Anim(Tent2[i], 0, 1.0);}
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 5: {
					Sound(Ent, 1, 0)
					for(new i = 0; i < 3; i++) {
						if (pev_valid(Tent[i])) engfunc(EngFunc_RemoveEntity, Tent[i])
						engfunc(EngFunc_SetOrigin, Tent3[i], Tent_Origin[i])
					}
					for(new i = 3; i < 6; i++) { engfunc(EngFunc_SetOrigin, Tent2[i], Tent_Origin[i]); Anim(Tent2[i], 0, 1.0);}
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 6: {
					Sound(Ent, 1, 0)
					for(new i = 0; i < 3; i++) {
						if (pev_valid(Tent2[i])) engfunc(EngFunc_RemoveEntity, Tent2[i])
						if (pev_valid(Tent3[i])) engfunc(EngFunc_RemoveEntity, Tent3[i])
					}
					for(new i = 3; i < 6; i++) {
						if (pev_valid(Tent[i])) engfunc(EngFunc_RemoveEntity, Tent[i])
						engfunc(EngFunc_SetOrigin, Tent3[i], Tent_Origin[i])
					}
					for(new i = 6; i < 9; i++) { engfunc(EngFunc_SetOrigin, Tent2[i], Tent_Origin[i]); Anim(Tent2[i], 0, 1.0); }
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 7: {
					Sound(Ent, 1, 0)
					for(new i = 3; i < 6; i++) {
						if (pev_valid(Tent2[i])) engfunc(EngFunc_RemoveEntity, Tent2[i])
						if (pev_valid(Tent3[i])) engfunc(EngFunc_RemoveEntity, Tent3[i])
					}
					for(new i = 6; i < 9; i++) {
						if (pev_valid(Tent[i])) engfunc(EngFunc_RemoveEntity, Tent[i])
						engfunc(EngFunc_SetOrigin, Tent3[i], Tent_Origin[i])
					}
					for(new i = 9; i < 12; i++) { engfunc(EngFunc_SetOrigin, Tent2[i], Tent_Origin[i]); Anim(Tent2[i], 0, 1.0);}
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 8: {
					for(new i = 6; i < 9; i++) {
						if (pev_valid(Tent2[i])) engfunc(EngFunc_RemoveEntity, Tent2[i])
						if (pev_valid(Tent3[i])) engfunc(EngFunc_RemoveEntity, Tent3[i])
					}
					for(new i = 9; i < 12; i++) {
						if (pev_valid(Tent[i])) engfunc(EngFunc_RemoveEntity, Tent[i])
						engfunc(EngFunc_SetOrigin, Tent3[i], Tent_Origin[i])
					}
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
					num++
				}
				case 9: {
					for(new i = 9; i < 12; i++) {
						if (pev_valid(Tent2[i])) engfunc(EngFunc_RemoveEntity, Tent2[i])
						if (pev_valid(Tent3[i])) engfunc(EngFunc_RemoveEntity, Tent3[i])
					}
					one = true
					num = 0
					Ability = Walk
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					return
				}
			}
		}
		case Poison:{		
			static number
			switch(number) {
				case 0: {
					set_pev(Ent, pev_movetype, MOVETYPE_NONE)
					Anim(Ent, 13, 1.0)
					random(2) ? dllfunc(DLLFunc_Use, MapSound[4], MapSound[4]) : dllfunc(DLLFunc_Use, MapSound[5], MapSound[5])
					set_pev(Ent, pev_nextthink, get_gametime() + 2.9)
					number++
				}
				case 1: {
					Anim(Ent, 4, 1.0)
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					number++
				}
				case 2: {
					static Float:Start_Origin[3], Float:End_Origin[3], Float:Vector[3], bool:sw_poison = false
					static Float:Rotate = -100.0, poison_change, Float:think_wait
					
					get_position(Ent, 500.0, Rotate, 65.0, End_Origin)
					get_position(Ent, 230.0, 0.0, 70.0, Start_Origin)
					
					xs_vec_sub(End_Origin, Start_Origin, Vector)
					xs_vec_normalize(Vector, Vector)
					xs_vec_mul_scalar(Vector, 1200.0, Vector)
					Spirt(Start_Origin, Vector, 6)
					
					if (think_wait < get_gametime()) {
						new EntPoison = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetOrigin, EntPoison, Start_Origin)
						engfunc(EngFunc_SetSize, EntPoison, Float:{-30.0, -30.0, -30.0}, Float:{30.0, 30.0, 30.0})
						
						set_pev(EntPoison, pev_solid, SOLID_TRIGGER)
						set_pev(EntPoison, pev_movetype, MOVETYPE_TOSS)
						set_pev(EntPoison, pev_classname, "ClassBreath")
						set_pev(EntPoison, pev_velocity, Vector)					
						
						think_wait = get_gametime() + 0.2
					}
					
					switch ( sw_poison ) {
						case 0: Rotate += 15.0
						case 1: Rotate -= 15.0
					}
					if ( Rotate >= (100.0 + AggressiveLevel)) sw_poison = true
					if ( Rotate <= (-100.0 - AggressiveLevel)) sw_poison = false
					if ( poison_change >= 100) {
						one = true
						number = 0
						Ability = Walk
						poison_change = 0
						set_pev(Ent, pev_nextthink, get_gametime() + 1.8)
						return
					}
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					poison_change++
				}
			}	
		}
		case Barash:{
			static nums
			switch (nums) {
				case 0:{
					new Float:Velocity[3], Float:Angles[3], Len
					Len = Move(Ent, MapCenter[1], float(speed_boss), Velocity, Angles)
					
					if (Len < 50) {
						Anim(Ent, 4, 1.0)
						random(2) ? dllfunc(DLLFunc_Use, MapSound[4], MapSound[4]) : dllfunc(DLLFunc_Use, MapSound[5], MapSound[5])
						nums++
						set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
						return
					}
					set_pev(Ent, pev_velocity, Velocity)
					set_pev(Ent, pev_angles, Angles)
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				}
				case 1: {
					static Float:Start_Origin[3], Float:End_Origin[3], Float:VectorBarash[3], Float:think_wait, barash_time
					
					get_position(Ent, 500.0, 0.0, 55.0, End_Origin)
					get_position(Ent, 230.0, 0.0, 60.0, Start_Origin)
					
					if (think_wait < get_gametime()) {
						new EntFlame = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetOrigin, EntFlame, Start_Origin)
						engfunc(EngFunc_SetSize, EntFlame, {-30.0, -30.0, -30.0}, {30.0, 30.0, 30.0})
						
						set_pev(EntFlame, pev_solid, SOLID_TRIGGER)
						set_pev(EntFlame, pev_movetype, MOVETYPE_TOSS)
						set_pev(EntFlame, pev_classname, "ClassBreath")
						set_pev(EntFlame, pev_velocity, VectorBarash)					
						
						think_wait = get_gametime() + 0.2
					}
					
					xs_vec_sub(End_Origin, Start_Origin, VectorBarash)
					xs_vec_normalize(VectorBarash, VectorBarash)
					xs_vec_mul_scalar(VectorBarash, 1200.0, VectorBarash)
					
					Spirt(Start_Origin, VectorBarash, 7)
					
					set_pev(Ent, pev_movetype, MOVETYPE_FLY)
					
					static Float:aVelocity[3]
					aVelocity[1] = float(speed_barash + AggressiveLevel)
					
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.01})
					set_pev(Ent, pev_avelocity, aVelocity)
					
					if ( barash_time >= 100) {
						one = true
						nums = 0
						Ability = Walk
						barash_time = 0
						set_pev(Ent, pev_avelocity, {0.0, 0.0, 0.0})
						set_pev(Ent, pev_nextthink, get_gametime() + 1.8)
						return
					}
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					barash_time++
				}
			}
		}
		case PhaseFLY: {
			static Float:tOrigin[3]
			switch (FlyNum) {
				case 0: { // Pre 1
					FlyNum++
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
					set_pev(Ent, pev_movetype, MOVETYPE_NONE)
					set_pev(Ent, pev_nextthink, get_gametime() + 3.1)
					Anim(Ent, 18, 1.0)
					dllfunc(DLLFunc_Use, MapSound[6], MapSound[6])
					set_pev(Ent, pev_movetype, MOVETYPE_FLY)
				}
				case 1: { // Pre 2
					FlyNum++
					set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
					Anim(Ent, 19, 1.0)
					set_pev(Ent, pev_movetype, MOVETYPE_FLY)
					set_pev(Ent, pev_velocity, {0.0, 0.0, 200.0})
					set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
				}
				case 2: { // Wait ( PrepareAttack )
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					if (Rage[1]) {
						set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						FlyNum = 6
						return
					}
					new Float:vOrigin[3], Float:bOrigin[3], Float:vVector[3]
					new TargetAir
					
					pev(Ent, pev_origin, bOrigin)
					
					for(new l = 1; l <= get_maxplayers(); ++l) {
						if (!is_user_alive(l) || is_user_bot(l))
							continue
						
						pev(l, pev_origin, vOrigin)
						
						vOrigin[2] = bOrigin[2]
						
						xs_vec_sub(vOrigin, bOrigin, vVector)
						
						if (xs_vec_len(vVector) > 400.0)
							TargetAir = l
					}
					
					if (TargetAir) 
						FlyNum++ 
					else {
						set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
						return
					}
					
					new Float:tAngle[3], Float:tVector[3]
					pev(TargetAir, pev_origin, tOrigin)
					
					xs_vec_sub(tOrigin, bOrigin, tVector)
					vector_to_angle(tVector, tAngle)
					
					tAngle[0] = 0.0
					tAngle[2] = 0.0
					
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					set_pev(Ent, pev_angles, tAngle)
					
					set_pev(Ent, pev_nextthink, get_gametime() + 2.0)
				}
				case 3: { // Attacked^^
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					if (Rage[1]) {
						set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						FlyNum = 6
						return
					}
					static PoisonTime, Float:think_wait
					new Float:pOrigin[3], Float:tVector[3]
					
					get_position(Ent, 50.0, 0.0, 370.0, pOrigin)
					
					xs_vec_sub(tOrigin, pOrigin, tVector)
					xs_vec_normalize(tVector, tVector)
					xs_vec_mul_scalar(tVector, 1500.0, tVector)
					
					Spirt(pOrigin, tVector, 6)
					
					if(pev(Ent, pev_fuser1) != 7123.0) {
						random(2) ? dllfunc(DLLFunc_Use, MapSound[4], MapSound[4]) : dllfunc(DLLFunc_Use, MapSound[5], MapSound[5])
						set_pev(Ent, pev_fuser1, 7123.0)
					}
					
					if (think_wait < get_gametime()) {
						new EntPoison = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetOrigin, EntPoison, pOrigin)
						engfunc(EngFunc_SetSize, EntPoison, Float:{-30.0, -30.0, -30.0}, Float:{30.0, 30.0, 30.0})
						
						set_pev(EntPoison, pev_solid, SOLID_TRIGGER)
						set_pev(EntPoison, pev_movetype, MOVETYPE_TOSS)
						set_pev(EntPoison, pev_classname, "ClassBreath")
						set_pev(EntPoison, pev_velocity, tVector)					
						
						think_wait = get_gametime() + 0.2
					}
					
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
					PoisonTime++
					
					if (PoisonTime >= 20) {
						PoisonTime = 0
						FlyNum++
					}
				}
				case 4: { // Change Position :3
					if(pev(Ent, pev_fuser2) == 5612.0) {
						Ability = Phase_change
						set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						return
					}
					set_pev(Ent, pev_fuser1, 0.0)
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					if (Rage[1]) {
						set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						FlyNum = 6
						return
					}
					new Float:rOrigin[3], Float:bOrigin[3], Float:rVector[3], Float:rAngle[3]
					static rTarget
					if (!is_user_alive(rTarget)) {
						rTarget = zl_player_random()
						set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						return
					}
					pev(Ent, pev_origin, bOrigin)
					pev(rTarget, pev_origin, rOrigin)
					
					rOrigin[2] = bOrigin[2]
					
					xs_vec_sub(rOrigin, bOrigin, rVector)
					
					if (xs_vec_len(rVector) > 70.0) {
						vector_to_angle(rVector, rAngle)
						xs_vec_normalize(rVector, rVector)
						xs_vec_mul_scalar(rVector, 250.0, rVector)
						rVector[2] = 0.0
						rAngle[0] = 0.0
						rAngle[2] = 0.0
						set_pev(Ent, pev_angles, rAngle)
						set_pev(Ent, pev_velocity, rVector)
					} else {
						set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
						FlyNum = 2
					}
					set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				}
				case 5: { // Phase2
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					static es_nn
					switch ( es_nn ) {
						case 0: {
							new Float:Velocity[3], Float:Angles[3], Len
							Len = Move(Ent, MapCenter[0], float(speed_boss), Velocity, Angles)
							
							if (Len < 30.0) {
								set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
								Anim(Ent, 19, 1.0)
								es_nn++
								return
							}
							set_pev(Ent, pev_velocity, Velocity)
							set_pev(Ent, pev_angles, Angles)
							set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
						}
						case 1: {
							if (Rage[0] && EggPhase != 1) 
								dllfunc(DLLFunc_Use, MapSound[9], MapSound[9])
							set_pev(Ent, pev_movetype, MOVETYPE_NONE)
							set_pev(Ent, pev_nextthink, get_gametime() + 1.4)
							Anim(Ent, 27, 1.0)
							es_nn++
						}
						case 2: {
							dllfunc(DLLFunc_Use, MapSound[1], MapSound[1])
							set_pev(Ent, pev_movetype, MOVETYPE_TOSS)
							set_pev(Ent, pev_nextthink, get_gametime() + 1.3)
							Anim(Ent, 28, 1.0)
							es_nn++
						}
						case 3: {
							ScreenShake(0, ((1<<12) * 8), ((2<<12) * 7))
							set_pev(Ent, pev_movetype, MOVETYPE_NONE)
							set_pev(Ent, pev_nextthink, get_gametime() + 4.3)
							Anim(Ent, 29, 1.0)
							es_nn++
						}
						case 4: {
							FlyNum = 0
							Ability = PhaseFLY
							set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
							client_cmd(0, "mp3 play ^"sound/%s^"", SoundList[5])
						}
					}
				}
				case 6: {
					set_pev(Ent, pev_velocity, {0.0, 0.0, 0.1})
					static randoms, wnum, Float:wVector[3], Float:sOrigin[3]
					switch( wnum ) {
						case 0: {
							new Float:wAngle[3]							
							switch ( random(6) ) {
								case 0: if (pev_valid(MapWall[0])) randoms = 0; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
								case 1: if (pev_valid(MapWall[1])) randoms = 1; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
								case 2: if (pev_valid(MapWall[2])) randoms = 2; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
								case 3: if (pev_valid(MapWall[3])) randoms = 3; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
								case 4: if (pev_valid(MapWall[4])) randoms = 4; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
								case 5: if (pev_valid(MapWall[5])) randoms = 5; else { set_pev(Ent, pev_nextthink, get_gametime() + 0.1); return; }
							}
													
							set_rendering(MapWall[randoms], kRenderFxNone, 255, 0, 0, kRenderTransColor, 100)
							
							get_position(Ent, 50.0, 0.0, 370.0, sOrigin)
							
							xs_vec_sub(MapOrigin[randoms], sOrigin, wVector)
							vector_to_angle(wVector, wAngle)
							wAngle[0] = 0.0
							wAngle[2] = 0.0
							set_pev(Ent, pev_angles, wAngle)
							set_pev(Ent, pev_nextthink, get_gametime() + 2.5)
							wnum++
						}
						case 1: {
							Spirt(sOrigin, wVector, 12)
							set_pev(Ent, pev_nextthink, get_gametime() + 1.3)
							wnum++
						}
						case 2: {
							set_rendering(MapWall[randoms], kRenderFxNone, 205, 0, 205, kRenderTransColor, 100)
							set_pev(Ent, pev_nextthink, get_gametime() + 2.5)
							wnum++
						}
						case 3: {
							new Float:bOrigin[3]
							xs_vec_copy(MapOrigin[randoms], bOrigin)
							Wreck(bOrigin, Float:{10.0, 10.0, 100.0}, Float:{100.0, 100.0, 100.0}, 30, 5, 40, (0x02), 1)
							set_rendering(MapWall[randoms])
							engfunc(EngFunc_RemoveEntity, MapWall[randoms])
							MapWall[randoms] = -1
							dllfunc(DLLFunc_Use, MapSound[3], MapSound[3])
							Rage[1] = false
							FlyNum = 4
							wnum = 0
							set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
						}
					}
					
				}
			}
			return			
		}
		case EGG: {
			static nn
			switch (nn) {
				case 0: {
					for (new i; i < 3; ++i) {
						Egg[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						engfunc(EngFunc_SetModel, Egg[i], Resource[8])
						engfunc(EngFunc_SetSize, Egg[i], {-20.0, -20.0, -70.0}, {20.0, 20.0, 1.0})
						engfunc(EngFunc_SetOrigin, Egg[i], MapEggOrigin[i])
						
						set_pev(Egg[i], pev_solid, SOLID_BBOX)
						set_pev(Egg[i], pev_movetype, MOVETYPE_FLY)
						
						new EggLen[10]
						formatex(EggLen, charsmax(EggLen), "BossEgg_%d", i)
						
						set_pev(Egg[i], pev_classname, EggLen)
						set_pev(Egg[i], pev_health, float(PlayerHp(egg_hp, true)))
						
						set_pev(Egg[i], pev_takedamage, DAMAGE_YES)
						set_pev(Egg[i], pev_nextthink, get_gametime() + 5.0)
						RegisterHamFromEntity(Ham_TakeDamage, Egg[i], "TakeDamage_Egg")
						
						EggSpr[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
						MapEggOrigin[i][2] += egg_upspr
						engfunc(EngFunc_SetOrigin, EggSpr[i], MapEggOrigin[i])
						engfunc(EngFunc_SetModel, EggSpr[i], Resource[11 - i])
						entity_set_float(EggSpr[i], EV_FL_scale, 0.3)
						set_pev(EggSpr[i], pev_classname, "EggSpr")
						set_pev(EggSpr[i], pev_solid, SOLID_NOT)
						set_pev(EggSpr[i], pev_movetype, MOVETYPE_NOCLIP)
					}
					set_rendering(Egg[0], kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30)
					set_rendering(Egg[1], kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 30)
					set_rendering(Egg[2], kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30)
				}
			}
			Rage[2] = true
			FlyNum = 2
			Ability = PhaseFLY
			set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
		}
		case Phase_change: {
			set_pev(Ent, pev_fuser2, 0.0)
			set_pev(MapBox, pev_health, float(PlayerHp(box_health, true)))
			set_rendering(MapBox, kRenderGlow, 255, 0, 0, kRenderFxFadeSlow, 200)
			set_rendering(MapButton, kRenderTransAlpha, 255, 0, 0, kRenderFxFadeSlow, 200)
			set_pev(MapBox, pev_takedamage, DAMAGE_YES)
			
			Ability = PhaseFLY
			FlyNum = 5
			set_pev(Ent, pev_nextthink, get_gametime() + 1.0)
		}
	}
}

public Touch_Angra(Boss, Player) {
	if (Ability != Walk || AttackPre)
		return
		
	VictimID = Player
	Ability = Attack
}

public Touch_Tentacle(T, Player) {
	if (!is_user_alive(Player))
		return
	
	ExecuteHamB(Ham_Killed, Player, b_Angra, 2)
	//make_deathmsg(b_Angra, Player, 0, "")
	AggressiveLevel += AGGRESSIVE_TENTACLE
}

public Touch_Breath(Ent, WorldEnt) {
	if (!pev_valid(Ent))
		return
		
	if (is_user_alive(WorldEnt)) {
		if (Ability == Barash) {
			BossDamage(WorldEnt, float(dmg_barash + AggressiveLevel), AGGRESSIVE_FLAME)
			return
		}
		BossDamage(WorldEnt, float(dmg_barash + AggressiveLevel), AGGRESSIVE_POISON)
	}
	engfunc(EngFunc_RemoveEntity, Ent)
}

public Think_HP(Ent) {
	if (pev(g_Angra, pev_deadflag) == DEAD_DYING) {
		message_begin(MSG_ALL, get_user_msgid("RoundTime"))
		write_short(Counter) 
		message_end()		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.9)
		return
	}
	
	if (zl_player_alive() < 1) {
		set_pev(Ent, pev_nextthink, get_gametime() + 0.9)
		Counter = floatround(float(prepare_time), floatround_round)
		return
	}
	
	static num
	switch(num) {
		case 0: { Counter = floatround(float(prepare_time), floatround_round); num++; }
		case 1: { Counter --; if (Counter <= 0) { BossStart(); num++; }}
		case 2: { Counter ++; }
	}
	
	static Float:x, Float:hp
	pev(g_Angra, pev_health, hp)
	
	x = hp * 100.0 / g_MaxHp
	
	if (pev(g_Angra, pev_effects) != EF_NODRAW) {
		message_begin(MSG_ALL, get_user_msgid("BarTime2"))
		write_short(9999)
		if (x >= 100 || x < 1) write_short(99); else write_short(floatround(x, floatround_floor))
		message_end()
	}
	
	static bool:OneHp = false
	
	switch ( floatround(x, floatround_round) ) {
		case 10..50: if (FlyNum == 2) { if (!OneHp) { Ability = EGG; OneHp = true; }}
		case 51..60: if (Ability == Walk) Ability = PhaseFLY
	}
	
	TabInfo(b_Angra, x ? x : 0.0, AggressiveLevel)
		
	message_begin(MSG_ALL, get_user_msgid("RoundTime"))
	write_short(Counter) 
	message_end()
	set_pev(Ent, pev_nextthink, get_gametime() + 1.0)

	// Egg fire
	if (Rage[0] && EggPhase != 1) {
		static Float:TimerDamage
		if (TimerDamage <= get_gametime()) {
			for(new id = 1; id <= get_maxplayers(); id++) {
				if (!is_user_alive(id) || is_user_bot(id))
					continue
				
				if (pev(id, pev_armorvalue) > 0.0) {
					set_pev(id, pev_armorvalue, pev(id, pev_armorvalue) - float(egg_armor_destroy))
					continue
				}
				ScreenFade(id, 6,0, {255, 0, 0}, 130, 1)
				BossDamage(id, float(egg_fire_dmg + AggressiveLevel / 2), 0)
			}
			TimerDamage = get_gametime() + egg_timer_damage
		}
	}
	
	// Egg Regeneration
	if (Rage[0] && EggPhase != 2) {
		static Float:TimerRegen
		if (TimerRegen <= get_gametime()) {
			static Float:a
			a = float(zl_player_alive()) * egg_heal_regen + AggressiveLevel
			set_pev(g_Angra, pev_health, pev(g_Angra, pev_health) + a)
			TimerRegen = get_gametime() + egg_heal_time
		}
	}
}

public Hook_Killed(victim, attacker, corpse) {	
	if (!zl_player_alive())	{
		set_task(6.0, "changemap")
		return HAM_IGNORED
	}
	
	if (!zl_boss_valid(victim))
		return HAM_IGNORED
		
	if (pev(victim, pev_deadflag) == DEAD_DYING)
		return HAM_IGNORED
	
	dllfunc(DLLFunc_Use, MapSound[2], MapSound[2])
	Anim(victim, 26, 1.0)
	set_pev(victim, pev_solid, SOLID_NOT)
	set_pev(victim, pev_velocity, {0.0, 0.0, 0.0})
	set_pev(victim, pev_deadflag, DEAD_DYING)
	set_task(10.0, "changemap")
	message_begin(MSG_BROADCAST, get_user_msgid("BarTime2"))
	write_short(0)
	write_short(0)
	message_end()
	return HAM_SUPERCEDE
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// TakeDamage (START)
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------

public TakeDamage(victim, wpn, attacker, Float:damage, damagebyte) {
	if (!pev_valid(victim))
		return HAM_IGNORED
	
	static ClassName[32]
	pev(victim, pev_classname, ClassName, charsmax(ClassName))
	
	if (equal(ClassName, "AngraBoss"))
		if (Rage[2]) return HAM_SUPERCEDE
	
	if (Rage[0] && EggPhase == 3) {
		if (is_user_alive(attacker)) {
			SetHamParamFloat(4, damage * egg_armor_damage)
			return HAM_HANDLED
		}
	}
	return HAM_IGNORED
}

public TakeDamage_Egg(victim, wpn, attacker, Float:damage, damagebyte) {
	if (!pev_valid(victim))
		return HAM_IGNORED
	
	static Float:EggHp[3], ClassName[32]
	new Float:Origin[3]
	pev(victim, pev_classname, ClassName, charsmax(ClassName))
	pev(victim, pev_origin, Origin)
	
	if (equal(ClassName, "BossEgg_0")) {
		pev(victim, pev_health, EggHp[0])
		if ( EggHp[0] <= damage ) {
			EggSetting(Origin, 0, {255, 0, 0})
			random(2) ? dllfunc(DLLFunc_Use, MapSound[7], MapSound[7]) : dllfunc(DLLFunc_Use, MapSound[8], MapSound[8])
			return HAM_SUPERCEDE
		} else set_pev(EggSpr[0], pev_frame, float(FrameHp(float(PlayerHp(egg_hp, true)), EggHp[0])))
	}
	if (equal(ClassName, "BossEgg_1")) {
		pev(victim, pev_health, EggHp[1])
		if ( EggHp[1] <= damage ) {
			EggSetting(Origin, 1, {0, 255, 0})
			random(2) ? dllfunc(DLLFunc_Use, MapSound[7], MapSound[7]) : dllfunc(DLLFunc_Use, MapSound[8], MapSound[8])
			return HAM_SUPERCEDE
		} else set_pev(EggSpr[1], pev_frame, float(FrameHp(float(PlayerHp(egg_hp, true)), EggHp[1])))
	}
	if (equal(ClassName, "BossEgg_2")) {
		pev(victim, pev_health, EggHp[2])
		if ( EggHp[2] <= damage ) {
			EggSetting(Origin, 2, {0, 0, 255})
			random(2) ? dllfunc(DLLFunc_Use, MapSound[7], MapSound[7]) : dllfunc(DLLFunc_Use, MapSound[8], MapSound[8])
			return HAM_SUPERCEDE
		} else set_pev(EggSpr[2], pev_frame, float(FrameHp(float(PlayerHp(egg_hp, true)), EggHp[2])))
	}
	return HAM_IGNORED
}

public TakeDamage_Box(victim, wpn, attacker, Float:damage, damagebyte) {
	if (!pev_valid(victim) || !is_user_alive(attacker))
		return HAM_IGNORED
		
	static Float:health; pev(victim, pev_health, health)
	if (health - damage > 0.0) client_print(attacker, print_center, msg_boxhp, floatround(health, floatround_round)) 
	else {
		Wreck(MapBreakOrigin[0], Float:{10.0, 10.0, 100.0}, Float:{100.0, 100.0, 100.0}, 30, 3, 15, (0x02), 13)
		Wreck(MapBreakOrigin[1], Float:{10.0, 10.0, 100.0}, Float:{100.0, 100.0, 100.0}, 30, 3, 15, (0x02), 13)
		Wreck(MapBreakOrigin[2], Float:{10.0, 10.0, 100.0}, Float:{100.0, 100.0, 100.0}, 30, 3, 15, (0x02), 13)
	}
	return HAM_HANDLED
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// TakeDamage (END)
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
public Use_Button(ent, idcaller, idactivator, use_type, Float:value) {
	static bool:use
	if (use) return HAM_SUPERCEDE
	
	Anim(MapCrane, 1, 1.0)
	dllfunc(DLLFunc_Use, MapSound[0], MapSound[0])
	set_pev(g_Angra, pev_nextthink, get_gametime() + 1.3)
	Rage[0] = true
	Rage[2] = false
	
	set_rendering(ent)
	use = true
	return HAM_HANDLED
}

public BloodColor(id) {
	if (!pev_valid(id))
		return HAM_IGNORED
		
	static ClassName[32]
	pev(id, pev_classname, ClassName, charsmax(ClassName))
	
	if (equal(ClassName, "AngraBoss")) { SetHamReturnInteger(blood_color); return HAM_SUPERCEDE; }
	if (equal(ClassName, "BossEgg_0")) { SetHamReturnInteger(egg_blood_fire); return HAM_SUPERCEDE; }
	if (equal(ClassName, "BossEgg_1")) { SetHamReturnInteger(egg_blood_regen); return HAM_SUPERCEDE; }
	if (equal(ClassName, "BossEgg_2")) { SetHamReturnInteger(egg_blood_shield); return HAM_SUPERCEDE; }
	
	return HAM_IGNORED
}

public KilledEgg(victim) {

	new Float:Origin[3], Float:Velocity[3]
	pev(victim, pev_origin, Origin)
	Origin[2] += 24.0
	Velocity[0] = random_float(-50.0,50.0)
	Velocity[1] = random_float(-50.0,50.0)
	Velocity[2] = 25.0
	Wreck(Origin, Float:{16.0, 16.0, 16.0}, Velocity, 10, 50, 30, 0x04, 16)	
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// EGG (START)
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
public ThinkEgg_0(Ent) { 
	if(!pev_valid(Ent)) return; static Float:Origin[3], victim = -1; pev(Ent, pev_origin, Origin); ShockWave(Origin, {255, 0, 0}, 15, 20, 80, 0); 
	while((victim = engfunc(EngFunc_FindEntityInSphere, victim, Origin, 120.0)) != 0) {
		if (!is_user_alive(victim)) continue;
		ScreenFade(victim, 6, 0, {255, 0, 0}, 130, 1); BossDamage(victim, float(egg_fire_dmg), 0); } 
	set_pev(Ent, pev_nextthink, get_gametime() + 5.0);
}

public ThinkEgg_1(Ent) { 
	if(!pev_valid(Ent)) return; static Float:Origin[3], victim = -1; pev(Ent, pev_origin, Origin); ShockWave(Origin, {0, 255, 0}, 15, 20, 80, 0); 
	while((victim = engfunc(EngFunc_FindEntityInSphere, victim, Origin, 120.0)) != 0) {
		if (!is_user_alive(victim)) continue;
		ScreenFade(victim, 6, 0, {0, 255, 0}, 130, 1); BossHeal(victim, egg_heal_player);} 
	set_pev(Ent, pev_nextthink, get_gametime() + 5.0);
}

public ThinkEgg_2(Ent) { 
	if(!pev_valid(Ent)) return; static Float:Origin[3], victim = -1; pev(Ent, pev_origin, Origin); ShockWave(Origin, {0, 0, 255}, 15, 20, 80, 0); 
	while((victim = engfunc(EngFunc_FindEntityInSphere, victim, Origin, 120.0)) != 0) {
		if (!is_user_alive(victim)) continue;
		ScreenFade(victim, 6, 0, {0, 0, 255}, 130, 1); BossArmor(victim, egg_armor_add); } 
	set_pev(Ent, pev_nextthink, get_gametime() + 5.0);
}
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// EGG (END)
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------

public MapEvent() {
	for (new i = 0; i <= 5; i++) {
		new szWall[10], szBreak[10], MapBreak[6]
		formatex(szWall, charsmax(szWall), "wall_%d", i)
		formatex(szBreak, charsmax(szBreak), "break_%d", i)
	
		MapWall[i] = engfunc(EngFunc_FindEntityByString, MapWall[i], "targetname", szWall)	
		MapBreak[i] = engfunc(EngFunc_FindEntityByString, MapBreak[i], "targetname", szBreak)
		
		pev(MapBreak[i], pev_origin, MapOrigin[i])
	}
	
	for (new i = 0; i < 3; i++) {
		new szEgg[10], MapEgg[3]
		formatex(szEgg, charsmax(szEgg), "egg_%d", i)
		MapEgg[i] = engfunc(EngFunc_FindEntityByString, MapEgg[i], "targetname", szEgg)
		pev(MapEgg[i], pev_origin, MapEggOrigin[i])
	}
	
	for (new i = 0; i < 3; i++) {
		new szBoxBreak[20], MapBreak[3]
		formatex(szBoxBreak, charsmax(szBoxBreak), "box_break_%d", i)
		MapBreak[i] = engfunc(EngFunc_FindEntityByString, MapBreak[i], "targetname", szBoxBreak)
		pev(MapBreak[i], pev_origin, MapBreakOrigin[i])
	}
	
	for (new i = 0; i < 12; i++) {
		new szSound[20]
		formatex(szSound, charsmax(szSound), "sound_%d", i)
		MapSound[i] = engfunc(EngFunc_FindEntityByString, MapSound[i], "targetname", szSound)
	}
	
	MapStart[0] = engfunc(EngFunc_FindEntityByString, MapStart[0], "targetname", "boss_start")
	MapStart[1] = engfunc(EngFunc_FindEntityByString, MapStart[1], "targetname", "boss_start_2")
	
	MapCenter[0] = engfunc(EngFunc_FindEntityByString, MapCenter[0], "targetname", "box_hit")
	MapCenter[1] = engfunc(EngFunc_FindEntityByString, MapCenter[1], "targetname", "center")
	
	MapCrane = engfunc(EngFunc_FindEntityByString, MapCrane, "targetname", "crane")
	MapBox = engfunc(EngFunc_FindEntityByString, MapBox, "targetname", "break_6")
	MapButton = engfunc(EngFunc_FindEntityByString, MapButton, "targetname", "button")
	
	set_pev(MapStart[0], pev_classname, "Timer")
	set_pev(MapStart[0], pev_nextthink, get_gametime() + 1.0)
	
	RegisterHamFromEntity(Ham_TakeDamage, MapBox, "TakeDamage_Box")
	RegisterHamFromEntity(Ham_Use, MapButton, "Use_Button")
}

public BotCreate() {
	if (get_playersnum() >= 30)
		return
		
	b_Angra = engfunc( EngFunc_CreateFakeClient, "AngraBoss")
	if(b_Angra) {
		dllfunc(MetaFunc_CallGameEntity, "player", b_Angra)
		cs_set_user_team(b_Angra, 1)
		set_user_info(b_Angra, "*bot", "1")
	}
}

public plugin_precache() {
	for (new i; i <= charsmax(Resource); i++)
		g_Resource[i] = precache_model(Resource[i])
		
	for (new i; i <= charsmax(SoundList); i++)
		precache_sound(SoundList[i])
}

public plugin_cfg()
	config_load()
	
config_load() {
	if (zl_boss_map() != 3)
		return
		
	new path[64]
	get_localinfo("amxx_configsdir", path, charsmax(path))
	format(path, charsmax(path), "%s/zl/%s", path, FILE_SETTING)
    
	if (!file_exists(path)) {
		new error[100]
		formatex(error, charsmax(error), "Cannot load customization file %s!", path)
		set_fail_state(error)
		return
	}
    
	new linedata[1024], key[64], value[960], section
	new file = fopen(path, "rt")
    
	while (file && !feof(file)) {
		fgets(file, linedata, charsmax(linedata))
		replace(linedata, charsmax(linedata), "^n", "")
       
		if (!linedata[0] || linedata[0] == '/') continue;
		if (linedata[0] == '[') { section++; continue; }
       
		strtok(linedata, key, charsmax(key), value, charsmax(value), '=')
		trim(key)
		trim(value)
		
		switch (section) { 
			case 1: {
				if (equal(key, "HEALTH"))
					boss_hp = str_to_num(value)
				else if (equal(key, "PREPARE"))
					prepare_time = str_to_num(value)
				else if (equal(key, "ABILITY_TIMER"))
					ability_time = str_to_float(value)
				else if (equal(key, "RAGE_TIME"))
					rage_time = str_to_float(value)
				else if (equal(key, "AGGR_TIME"))
					aggressive_time = str_to_float(value)
				else if (equal(key, "SPEED"))
					speed_boss = str_to_num(value)
				else if (equal(key, "DMG_ATTACK"))
					dmg_attack = str_to_num(value)
				else if (equal(key, "DMG_BARASH"))
					dmg_barash = str_to_num(value)
				else if (equal(key, "BLOOD_COLOR"))
					blood_color = str_to_num(value)
				#if !defined MAPCHOOSER
				else if (equal(key, "NEXT_MAP"))
					copy(boss_nextmap, charsmax(boss_nextmap), value)
				#endif
			}
			case 2: {
				if (equal(key, "EGG_RATE_HP"))
					egg_hp = str_to_float(value)
				else if (equal(key, "EGG_SPR_UP"))
					egg_upspr = str_to_float(value)  
				else if (equal(key, "EGG_BLOOD_FIRE"))
					egg_blood_fire = str_to_num(value)
				else if (equal(key, "EGG_BLOOD_REGEN"))
					egg_blood_regen = str_to_num(value)
				else if (equal(key, "EGG_BLOOD_SHIELD"))
					egg_blood_shield = str_to_num(value)
				else if (equal(key, "EGG_FIRE_DMG"))
					egg_fire_dmg = str_to_num(value)
				else if (equal(key, "EGG_TIMER_DMG"))
					egg_timer_damage = str_to_float(value)
				else if (equal(key, "EGG_HEAL_PLAYER"))
					egg_heal_player = str_to_num(value)
				else if (equal(key, "EGG_HEAL_HP"))
					egg_heal_hp = str_to_num(value)
				else if (equal(key, "EGG_HEAL_RESTORE"))
					egg_heal_restore = str_to_num(value)
				else if (equal(key, "EGG_HEAL_REGEN"))
					egg_heal_regen = str_to_float(value)
				else if (equal(key, "EGG_HEAL_TIME"))
					egg_heal_time = str_to_float(value)
				else if (equal(key, "EGG_ARMOR_MAX"))
					egg_armor_max = str_to_num(value)
				else if (equal(key, "EGG_ARMOR_ADD"))
					egg_armor_add = str_to_num(value)
				else if (equal(key, "EGG_ARMOR_DESTROY"))
					egg_armor_destroy = str_to_num(value)
				else if (equal(key, "EGG_ARMOR_DAMAGE"))
					egg_armor_damage = str_to_float(value)
			}
		}
	}
	if (file) fclose(file)
}

public changemap() {
	#if defined MAPCHOOSER
	zl_vote_start()
	#else
	server_cmd("changelevel ^"%s^"", boss_nextmap)
	#endif
}

BossAbility(bool:Rage) {	
	
	if (Ability == PhaseFLY && Rage) {
		if (FlyNum == 4 || FlyNum == 2) FlyNum = 6
		return
	}
	
	if (Ability != Walk)
		return
	
	switch (random(3)) {
		case 0: Ability = Tentacle
		case 1: Ability = Barash
		case 2: Ability = Poison
	}
}

stock Move(Start, End, Float:speed, Float:Velocity[], Float:Angles[]) {
	new Float:Origin[3], Float:Origin2[3], Float:Angle[3], Float:Vector[3], Float:Len
	pev(Start, pev_origin, Origin2)
	pev(End, pev_origin, Origin)
	xs_vec_sub(Origin, Origin2, Vector)
	Len = xs_vec_len(Vector)
	vector_to_angle(Vector, Angle)
	Angles[0] = 0.0
	Angles[1] = Angle[1]
	Angles[2] = 0.0
	xs_vec_normalize(Vector, Vector)
	xs_vec_mul_scalar(Vector, speed, Velocity)
	return floatround(Len, floatround_round)
}

stock FrameHp(Float:MaxHp, Float:HP) {
	static Float:a, Float:b
	a = HP * 100 / MaxHp
	b = 100.0 - a

	return floatround(b, floatround_round)
}

stock PlayerHp(Float:rate, bool:Alive = false) {
	new Count, Hp
	for(new id = 1; id <= get_maxplayers(); id++)
		if (((Alive) ? (is_user_alive(id)) : (is_user_connected(id))) && !is_user_bot(id))
			Count++
			
	Hp = floatround(boss_hp * Count * rate, floatround_round)
	return Hp
}

stock EggSetting(Float:Origin[3], EggNum, Color[3]) {
	if (!pev_valid(Egg[EggNum]) || !pev_valid(EggSpr[EggNum]))
		return
	
	//engfunc(EngFunc_RemoveEntity, Egg[EggNum])
	ExecuteHam(Ham_Killed, Egg[EggNum], Egg[EggNum], 2)
	engfunc(EngFunc_RemoveEntity, EggSpr[EggNum])
	ShockWave(Origin, Color, 1, 30, 30, 1)
	KilledEgg(Egg[EggNum])
	static EggDead
	EggDead++
	if (EggDead > 2) { 
		set_pev(g_Angra, pev_fuser2, 5612.0)
		Ability = Phase_change
		set_pev(g_Angra, pev_nextthink, get_gametime() + 0.1)
	}
		
	if (!EggPhase) {
		ScreenFade(0, 6, 0, Color, 200, 1)
		EggPhase = EggNum + 1
		
		if (EggNum == 1) {
			for(new id = 1; id <= get_maxplayers(); id++) {
				if (!is_user_alive(id) || is_user_bot(id))
					continue
				
				set_pev(id, pev_health, float(egg_heal_hp))
				EggHeal[id] = true
			}
		}
	}
}

stock Anim(ent, sequence, Float:speed) {		
	set_pev(ent, pev_sequence, sequence)
	set_pev(ent, pev_animtime, halflife_time())
	set_pev(ent, pev_framerate, speed)
}

stock ShockWave(Float:Orig[3], Color[3], Radius, Life, Width, disk) {
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Orig, 0)
	//message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(disk ? TE_BEAMTORUS : TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, Orig[0]) // x
	engfunc(EngFunc_WriteCoord, Orig[1]) // y
	engfunc(EngFunc_WriteCoord, Orig[2]- (disk ? 80.0 : 50.0)) // z
	engfunc(EngFunc_WriteCoord, Orig[0]) // x axis
	engfunc(EngFunc_WriteCoord, Orig[1]) // y axis
	engfunc(EngFunc_WriteCoord, Orig[2]+Radius) // z axis
	write_short(g_Resource[2]) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(Life) // life (4)
	write_byte(Width) // width (20)
	write_byte(0) // noise
	write_byte(Color[0]) // red
	write_byte(Color[1]) // green
	write_byte(Color[2]) // blue
	write_byte(255) // brightness
	write_byte(0) // speed
	message_end()
}

stock TabInfo(Ent, Float:Frags, Death) {
	if (!pev_valid(Ent))
		return
		
	cs_set_user_deaths(Ent, Death)
	set_pev(Ent, pev_frags, Frags)
	
	if (!is_user_connected(Ent) || is_user_bot(Ent))
		return
	
	/*message_begin(MSG_ALL, get_user_msgid("ScoreInfo"))
	write_byte(Ent)
	write_short(pev(Ent, pev_frags))
	write_short(get_user_deaths(Ent))
	write_short(0)
	write_short(get_user_team(Ent))
	message_end()*/
}

stock get_position(id, Float:forw, Float:right, Float:up, Float:vStart[]) {
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
    
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_angles, vAngle) // if normal entity ,use pev_angles
    
	//engfunc(EngFunc_AngleVectors, ANGLEVECTOR_FORWARD, vForward)
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
    
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock ScreenFade(id, Timer8, FadeTime, Colors[3], Alpha, type) {
	if(id) if(!is_user_connected(id)) return

	if (Timer8 > 0xFFFF) Timer8 = 0xFFFF
	if (FadeTime <= 0) FadeTime = 4
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("ScreenFade"), _, id);
	write_short(Timer8 * 1 << 12)
	write_short(FadeTime * 1 << 12)
	switch (type) {
		case 1: write_short(0x0000)		// IN ( FFADE_IN )
		case 2: write_short(0x0001)		// OUT ( FFADE_OUT )
		case 3: write_short(0x0002)		// MODULATE ( FFADE_MODULATE )
		case 4: write_short(0x0004)		// STAYOUT ( FFADE_STAYOUT )
		default: write_short(0x0001)
	}
	write_byte(Colors[0])
	write_byte(Colors[1])
	write_byte(Colors[2])
	write_byte(Alpha)
	message_end()
}

stock ScreenShake(id, duration, frequency) {	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_ALL, get_user_msgid("ScreenShake"), _, id ? id : 0);
	write_short(1<<14)
	write_short(duration)
	write_short(frequency)
	message_end()
}

stock Spirt(Float:origin[3], Float:velocity[3], num7) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(120)
	engfunc(EngFunc_WriteCoord, origin[0]) // x
	engfunc(EngFunc_WriteCoord, origin[1]) // y
	engfunc(EngFunc_WriteCoord, origin[2]) // z
	engfunc(EngFunc_WriteCoord, velocity[0]) // x
	engfunc(EngFunc_WriteCoord, velocity[1]) // y
	engfunc(EngFunc_WriteCoord, velocity[2]) // z
	write_short(g_Resource[num7])
	write_byte(10)
	write_byte(1)
	write_byte(0)
	write_byte(5)
	message_end()
}

stock Wreck(Float:Origin[3], Float:Size[3], Float:Velocity[3], RandomVelocity, Num, Life, Flag, index) {			
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, Origin[0]) // Pos.X
	engfunc(EngFunc_WriteCoord, Origin[1]) // Pos Y
	engfunc(EngFunc_WriteCoord, Origin[2]) // Pos.Z
	engfunc(EngFunc_WriteCoord, Size[0]) // Size X
	engfunc(EngFunc_WriteCoord, Size[1]) // Size Y
	engfunc(EngFunc_WriteCoord, Size[2]) // Size Z
	engfunc(EngFunc_WriteCoord, Velocity[0]) // Velocity X
	engfunc(EngFunc_WriteCoord, Velocity[1]) // Velocity Y
	engfunc(EngFunc_WriteCoord, Velocity[2]) // Velocity Z
	write_byte(RandomVelocity) // Random velocity
	write_short(g_Resource[index]) // Model/Sprite index
	write_byte(Num) // Num
	write_byte(Life) // Life
	write_byte(Flag) // Flags ( 0x02 )
	message_end()
}

stock BossDamage(victim, Float:dmg, aggressive) {
	if (!is_user_alive(victim) || is_user_bot(victim))
		return
		
	new Float:Hp
	pev(victim, pev_health, Hp)
		
	if (Hp - dmg > 0.0)
		ExecuteHamB(Ham_TakeDamage, victim, 0, victim, dmg, DMG_GENERIC)
	else {
		if (Rage[0] && EggPhase == 2 && EggHeal[victim]) {
			set_pev(victim, pev_health, float(egg_heal_restore))
			EggHeal[victim] = false
			return
		}
		ExecuteHamB(Ham_Killed, victim, b_Angra, 0)
		//make_deathmsg(b_Angra, victim, 0, knf ? "knife" : "")
		AggressiveLevel += aggressive
	}
}

stock BossHeal(victim, heal) {
	if (!is_user_alive(victim) || is_user_bot(victim))
		return
	
	new Float:Hp
	pev(victim, pev_health, Hp)
	
	if (Hp + heal >= 250.0) {
		set_pev(victim, pev_health, 255.0)
		return
	}		
	set_pev(victim, pev_health, Hp + float(heal))
}

stock BossArmor(id, armor) {
	if (!is_user_alive(id) || is_user_bot(id))
		return
		
	if (pev(id, pev_armorvalue) + armor >= float(egg_armor_max)) {
		set_pev(id, pev_armorvalue, float(egg_armor_max))
		return
	}
	set_pev(id, pev_armorvalue, pev(id, pev_armorvalue) + float(armor))
}

stock Sound(Ent, Sound, type) {
	if (type)
		client_cmd(Ent ? Ent : 0, "spk ^"%s^"", SoundList[_:Sound]) 
	else
		engfunc(EngFunc_EmitSound, Ent, CHAN_AUTO, SoundList[_:Sound], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
