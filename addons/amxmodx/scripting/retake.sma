#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <xs>
#include <sqlx>
#include <reapi>

/* =================================================================================
* 				[ Initiation & Global stuff ]
* ================================================================================= */

#define MAX_SPAWNS 					128

#define BOMB_SITE_COUNT 			2
#define EQUIPMENT_COUNT 			3

#define GROUP_COUNT 				4

#define MAX_PLAYERS 				32
#define PLAYER_ARRAY 				33

#define IsPlayer(%0) 				( 1 <= %0 <= MAX_PLAYERS )

#define GetPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )

#define ClientPlaySound(%0,%1) 		client_cmd( %0, "spk ^"%s^"", %1 )

const XO_WEAPON 				= 4;
const XO_PLAYER 				= 5;

const m_bStartDefuse 			= 97;
const m_flDefuseCountDown 		= 99;
const m_flC4Blow 				= 100;
const m_fHasPrimary 			= 116;

const WEAPONS_PISTOLS_START 	= 0;
const WEAPONS_PISTOLS_END 		= 4;

const WEAPONS_SMGS_START 		= 5;
const WEAPONS_SMGS_END 			= 8;

const WEAPONS_RIFLES_START 		= 9;
const WEAPONS_RIFLES_END 		= 11;

const WEAPONS_TEAM_DIFFERENCE 	= 12;

const WEAPONS_SCOUT_INDEX 		= 24;
const WEAPONS_AWP_INDEX 		= 25;

const EQUIPMENT_SCOUT_CHANCE 	= 35;
const EQUIPMENT_AWP_CHANCE 		= 35;

const TASK_JOIN_TEAM			= 1000;
const TASK_TIMER 				= 1100;
const TASK_FIX_MENU 			= 1200;
const TASK_RESTART 				= 1300;
const TASK_PLANT_BOMB 			= 1400;
const TASK_SHOW_MESSAGE			= 1500;

enum _:Queries
{
	QUERY_IGNORE,
	QUERY_LOAD,
	QUERY_INSERT
}

enum _:Round_Status
{
	ROUND_ENDED,
	ROUND_FROZEN,
	ROUND_STARTED
}

enum _:Equipments
{
	EQUIPMENT_PISTOL,
	EQUIPMENT_SMG,
	EQUIPMENT_FULL
}

enum _:Settings
{
	SETTINGS_T_SCOUT = ( 1 << 0 ),
	SETTINGS_T_AWP = ( 1 << 1 ),
	SETTINGS_CT_SCOUT = ( 1 << 2 ),
	SETTINGS_CT_AWP = ( 1 << 3 ),
	SETTINGS_T_GUNS_CHOSEN = ( 1 << 4 ),
	SETTINGS_CT_GUNS_CHOSEN = ( 1 << 5 )
}

enum _:Spawn_Struct
{
	Spawn_Site,
	Spawn_Team,
	Spawn_Group,
	
	bool:Spawn_Available,
	
	Float:Spawn_Origin[ 3 ],
	Float:Spawn_Angles[ 3 ]
}

enum _:Weapon_Struct
{
	Weapon_Alias[ 32 ],
	Weapon_Name[ 32 ],
	Weapon_Id,
	Weapon_Ammo
}

enum _:Grenade_Struct
{
	Grenade_Id,
	Grenade_Name[ 32 ],
	Grenade_Carry
}

enum _:Player_Struct
{
	Player_Id,
	Player_Settings,
	
	Player_Name[ 32 ],
	
	Player_Pistol[ 2 ],
	Player_SMG[ 2 ],
	Player_Rifle[ 2 ],
	
	Player_Menu_Bombsite,
	Player_Menu_Group,
	
	Player_Join_Time
}

new const g_iWeaponMenuStart[ ] 	= { WEAPONS_PISTOLS_START, WEAPONS_SMGS_START, WEAPONS_RIFLES_START };
new const g_iWeaponMenuEnd[ ] 		= { WEAPONS_PISTOLS_END, WEAPONS_SMGS_END, WEAPONS_RIFLES_END };

new const g_szWeaponMenuNames[ ][ ] = { "Pistola", "SMG", "Rifle" };

new const g_szEquipmentNames[ ][ ] 	= { "ECO", "FORZADA", "FULLBUY" };
new const g_iEquipmentChances[ ] 	= { 20, 20, 60 };

new const g_sGrenades[ ][ Grenade_Struct ] =
{
	{ CSW_HEGRENADE, "weapon_hegrenade", 1 },
	{ CSW_FLASHBANG, "weapon_flashbang", 2 },
	{ CSW_SMOKEGRENADE, "weapon_smokegrenade", 1 }
};

new const g_sWeapons[ ][ Weapon_Struct ] =
{
	{ "9x19mm Sidearm", "weapon_glock18", CSW_GLOCK18, 120 },
	{ "K&M .45 Tactica", "weapon_usp", CSW_USP, 100 },
	{ "228 Compact", "weapon_p228", CSW_P228, 52 },
	{ "Night Hawk .50C", "weapon_deagle", CSW_DEAGLE, 35 },
	{ ".40 Dual Elites", "weapon_elite", CSW_ELITE, 120 },
	
	{ "Ingram MAC-10", "weapon_mac10", CSW_MAC10, 100 },
	{ "K&M Submachine-gun", "weapon_mp5navy", CSW_MP5NAVY, 120 },
	{ "K&M UMP45", "weapon_ump45", CSW_UMP45, 100 },
	{ "ES C90", "weapon_p90", CSW_P90, 100 },
	
	{ "IDF Defender", "weapon_galil", CSW_GALIL, 90 },
	{ "CV-47 Kalashnikova", "weapon_ak47", CSW_AK47, 90 },
	{ "Krieg 552 Commando", "weapon_sg552", CSW_SG552, 90 },
	
	{ "9x19mm Sidearm", "weapon_glock18", CSW_GLOCK18, 120 },
	{ "K&M .45 Tactica", "weapon_usp", CSW_USP, 100 },
	{ "228 Compact", "weapon_p228", CSW_P228, 52 },
	{ "Night Hawk .50C", "weapon_deagle", CSW_DEAGLE, 35 },
	{ "ES Five-Seven", "weapon_fiveseven", CSW_FIVESEVEN, 100 },
	
	{ "Schmidt Machine Pistol", "weapon_tmp", CSW_TMP, 120 },
	{ "K&M Submachine-gun", "weapon_mp5navy", CSW_MP5NAVY, 120 },
	{ "K&M UMP45", "weapon_ump45", CSW_UMP45, 100 },
	{ "ES C90", "weapon_p90", CSW_P90, 100 },
	
	{ "Clarion 5.56", "weapon_famas", CSW_FAMAS, 90 },
	{ "Maverick M4A1 Carbine", "weapon_m4a1", CSW_M4A1, 90 },
	{ "Bullup", "weapon_aug", CSW_AUG, 90 },
	
	{ "Schmidt Scout", "weapon_scout", CSW_SCOUT, 90 },
	{ "Magnum Sniper Rifle", "weapon_awp", CSW_AWP, 30 }
};

new const g_szCustomSpawnModels[ ][ ] =
{
	"",
	"models/player/terror/terror.mdl",
	"models/player/gign/gign.mdl",
	""
};

new const g_szMapParameters[ ] 		= "info_map_parameters";

new const g_szInfoTargetClass[ ] 	= "info_target";
new const g_szCustomSpawnClass[ ] 	= "CustomSpawn";

new g_iIsConnected;
new g_iIsAlive;
new g_iIsLogged;

new g_iRoundStatus;
new g_iRoundCount;
new g_iBombSite;
new g_iHudObject;
new g_iEquipment;
new g_iMaxPlayers;

new g_iBarTime;
new g_iRoundTime;
new g_iShowTimer;
new g_iScenario;

new g_pSpawn;
new g_pRoundEvent;

new bool:g_bSniperGiven[ 2 ];
new bool:g_bTerroristWin;
new bool:g_bShowingSpawns;

new Handle:g_hConnection;

new Array:g_aSpawns;

new Float:g_flBombSpot[ BOMB_SITE_COUNT ][ 3 ];
new g_sPlayers[ PLAYER_ARRAY ][ Player_Struct ];

/* =================================================================================
* 				[ Plugin events ]
* ================================================================================= */

public plugin_precache( )
{
	CreateMapEntities( );
	
	g_pSpawn = register_forward( FM_Spawn, "OnSpawn_Pre", false );
}

public plugin_init( )
{
	register_plugin( "Retake", "1.3", "Manu" );
	
	unregister_forward( FM_Spawn, g_pSpawn, false );
	
	register_forward( FM_ClientUserInfoChanged, "OnClientUserInfoChanged_Pre", false );
	register_forward( FM_GetGameDescription, "OnGetGameDescription_Pre", false );
	
	RegisterHam( Ham_Spawn, "player", "OnPlayerSpawn_Post", true );
	RegisterHam( Ham_Killed, "player", "OnPlayerKilled_Post", true );
	RegisterHam( Ham_CS_Item_CanDrop, "weapon_c4", "OnBombCanDrop_Pre", false );
	
	RegisterHookChain( RG_CBasePlayer_HintMessageEx, "OnPlayerHintMessageEx_Pre", false );
	
	register_event( "BarTime", "OnDefuseStart", "be", "1=5", "1=10" );
	register_event( "SendAudio", "OnTerroristsWin", "a", "2&%!MRAD_terwin" );
	
	register_logevent( "OnTargetBombed", 6, "3=Target_Bombed" );
	
	register_event( "HLTV", "OnRoundCommence", "a", "1=0", "2=0" );
	
	register_logevent( "OnRoundStart", 2, "1=Round_Start" );
	register_logevent( "OnRoundEnd", 2, "1=Round_End" );
	
	register_logevent( "OnRoundEnd", 2, "0=World triggered", "1&Restart_Round_" );
	register_logevent( "OnRoundEnd", 2, "0=World triggered", "1=Game_Commencing" );
	
	register_message( get_user_msgid( "BombDrop" ), "OnMessageBombDrop" );
	register_message( get_user_msgid( "ShowMenu" ), "OnMessageShowMenu" );
	register_message( get_user_msgid( "VGUIMenu" ), "OnMessageVGUIMenu" );
	
	register_clcmd( "jointeam", "ClientCommand_ChooseTeam" );
	register_clcmd( "chooseteam", "ClientCommand_ChooseTeam" );
	
	register_clcmd( "say /manage", "ClientCommand_Manage" );
	register_clcmd( "say /configurar", "ClientCommand_Manage" );
	
	register_clcmd( "say guns", "ClientCommand_Weapons" );
	register_clcmd( "say /guns", "ClientCommand_Weapons" );
	register_clcmd( "say armas", "ClientCommand_Weapons" );
	register_clcmd( "say /armas", "ClientCommand_Weapons" );
	
	SQL_Init( );
	SQL_CreateTable( );
	
	Initialize( );
}

public plugin_cfg( )
{
	LoadMapData( );
	LoadConfig( );
}

/* =================================================================================
* 				[ Delete Map Entities ]
* ================================================================================= */

public OnSpawn_Pre( iEnt )
{
	if ( !pev_valid( iEnt ) )
	{
		return FMRES_IGNORED;
	}
	
	new szClassname[ 32 ];
	
	pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) );
	
	if ( equal( szClassname, g_szMapParameters ) )
	{
		engfunc( EngFunc_RemoveEntity, iEnt );
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

/* =================================================================================
* 				[ Events ]
* ================================================================================= */

public OnRoundCommence( )
{
	CheckGameStatus( );
	
	ClearAvailableSpawns( );
	
	g_iRoundStatus = ROUND_FROZEN;
	
	g_iBombSite = random( BOMB_SITE_COUNT );
	g_iEquipment = RandomizeEquipment( );
	
	BalanceTeams( );
	
	if ( !g_bTerroristWin || ( ++g_iRoundCount == 3 ) )
	{
		SwitchTeams( );
		
		g_iRoundCount = 0;
	}
	
	g_bTerroristWin = false;
	
	set_task( 1.0, "OnTaskShowMessage", TASK_SHOW_MESSAGE, .flags = "a", .repeat = 5 );
	
	ExecuteForward( g_pRoundEvent, _, g_iRoundStatus, g_iBombSite );
}

public OnRoundStart( )
{
	g_iRoundStatus = ROUND_STARTED;
	
	set_task( 0.1, "OnTaskPlantBomb", TASK_PLANT_BOMB );
	set_task( 1.0, "OnTaskUpdateTimer", TASK_TIMER );
	
	ExecuteForward( g_pRoundEvent, _, g_iRoundStatus, g_iBombSite );
}

public OnRoundEnd( )
{
	g_iRoundStatus = ROUND_ENDED;
	
	remove_task( TASK_TIMER );
	remove_task( TASK_SHOW_MESSAGE );
	remove_task( TASK_PLANT_BOMB );
	
	g_bSniperGiven[ 0 ] = false;
	g_bSniperGiven[ 1 ] = false;
	
	LetWaitingPlayersJoin( );
	
	ExecuteForward( g_pRoundEvent, _, g_iRoundStatus, g_iBombSite );
}

public OnDefuseStart( iId )
{
	new iCount = 0;
	
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsAlive, iPlayer ) )
		{
			continue;
		}
		
		if ( get_member( iPlayer, m_iTeam ) == TEAM_TERRORIST )
		{
			iCount++;
		}
	}
	
	if ( iCount > 0 )
	{
		return PLUGIN_CONTINUE;
	}
	
	new iEnt = find_ent_by_model( -1, "grenade", "models/w_c4.mdl" );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	new iDelay = read_data( 1 );
	
	new Float:flGametime = get_gametime( );
	new Float:flBlow = get_pdata_float( iEnt, m_flC4Blow );
	
	if ( ( flBlow - flGametime ) < float( iDelay ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	set_pdata_float( iEnt, m_flDefuseCountDown, 0.0 );
	
	message_begin( MSG_ONE, g_iBarTime, .player = iId );
	write_short( 0 );
	message_end( );
	
	return PLUGIN_CONTINUE;
}

public OnTargetBombed( )
{
	g_bTerroristWin = true;
}

public OnTerroristsWin( )
{
	g_bTerroristWin = true;
}

/* =================================================================================
* 				[ Tasks ]
* ================================================================================= */

public OnTaskJoinTeam( iTask )
{
	new iId = ( iTask - TASK_JOIN_TEAM );
	
	if ( !GetPlayerBit( g_iIsConnected, iId ) )
	{
		return;
	}
	
	( g_iRoundStatus != ROUND_ENDED ) ?
		rg_join_team( iId, TEAM_SPECTATOR ) : rg_join_team( iId, TeamName:GetNeededTeam( ) );
}

public OnTaskUpdateTimer( )
{
	new iTimer = get_cvar_num( "mp_c4timer" );
	
	message_begin( MSG_BROADCAST, g_iShowTimer );
	message_end( );
	
	message_begin( MSG_BROADCAST, g_iRoundTime );
	write_short( iTimer );
	message_end( );
	
	message_begin( MSG_BROADCAST, g_iScenario );
	write_byte( 1 );
	write_string( "bombticking1" );
	write_byte( 150 );
	write_short( 20 );
	message_end( );
}

public OnTaskFixMenu( iTask )
{
	new iId = ( iTask - TASK_FIX_MENU );
	
	if ( !GetPlayerBit( g_iIsConnected, iId ) )
	{
		return;
	}
	
	set_member( iId, m_iMenu, 0, XO_PLAYER );
}

public OnTaskPlantBomb( iTask )
{
	PlantBomb( );
}

public OnTaskShowMessage( iTask )
{
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsAlive, iPlayer ) )
		{
			continue;
		}
		
		set_dhudmessage( 250, 170, 50, -1.0, 0.15, 0, 0.0, 1.0 );
		show_dhudmessage( iPlayer, "RONDA %s^nHAY QUE %s EL SITE [%c]",
			g_szEquipmentNames[ g_iEquipment ], ( get_member( iPlayer, m_iTeam ) == TEAM_CT ) ? "RECUPERAR" : "DEFENDER", ( 65 + g_iBombSite ) );
	}
}

/* =================================================================================
* 				[ Messages ]
* ================================================================================= */

public OnMessageBombDrop( iMessage, iDest, iId )
{
	new iFlag = get_msg_arg_int( 4 );
	
	if ( !iFlag )
	{
		return PLUGIN_CONTINUE;
	}
	
	set_msg_arg_float( 1, ARG_COORD, g_flBombSpot[ g_iBombSite ][ 0 ] );
	set_msg_arg_float( 2, ARG_COORD, g_flBombSpot[ g_iBombSite ][ 1 ] );
	set_msg_arg_float( 3, ARG_COORD, g_flBombSpot[ g_iBombSite ][ 2 ] );
	
	return PLUGIN_CONTINUE;
}

public OnMessageShowMenu( iMessage, iDest, iId )
{
	new szData[ 32 ];
	
	get_msg_arg_string( 4, szData, charsmax( szData ) );
	
	if ( containi( szData, "Team_Select" ) == -1 )
	{
		return PLUGIN_CONTINUE;
	}
	
	set_task( 0.1, "OnTaskFixMenu", iId + TASK_FIX_MENU );
	
	return PLUGIN_HANDLED;
}

public OnMessageVGUIMenu( iMessage, iDest, iId )
{
	new iMenu = get_msg_arg_int( 1 );
	
	if ( iMenu != 2 )
	{
		return PLUGIN_CONTINUE;
	}
	
	set_task( 0.1, "OnTaskFixMenu", iId + TASK_FIX_MENU );
	
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Player events ]
* ================================================================================= */

public OnPlayerSpawn_Post( iId )
{
	if ( !is_user_alive( iId ) )
	{
		return HAM_IGNORED;
	}
	
	SetPlayerBit( g_iIsAlive, iId );
	
	new iTeam = get_member( iId, m_iTeam );
	
	if ( !( 0 < iTeam < 3 ) )
	{
		return HAM_IGNORED;
	}
	
	SetPlayerPosition( iId );
	SetPlayerEquipment( iId );
	
	set_pdata_float( iId, 198, 9999.0 );
	
	if ( ~g_sPlayers[ iId ][ Player_Settings ] & ( 1 << ( iTeam + 3 ) ) )
	{
		ShowWeaponsMenu( iId, 0, iTeam );
	}
	
	return HAM_IGNORED;
}

public OnPlayerKilled_Post( iVictim, iKiller, iShouldGib )
{
	ClearPlayerBit( g_iIsAlive, iVictim );
	
	set_hudmessage( 250, 210, 40, 0.1, 0.6, 1, 0.5, 5.0 );
	ShowSyncHudMsg( iVictim, g_iHudObject, "Recuerda que puedes elegir tus armas y tus^npreferencias escribiendo guns en el chat" );
}

public OnPlayerHintMessageEx_Pre( iId, szMessage[ ], Float:flDuration, bool:bDisplayIfPlayerDead, bool:bOverride )
{
	SetHookChainReturn( ATYPE_BOOL, false );
	
	return HC_SUPERCEDE;
}

/* =================================================================================
* 				[ General forwards ]
* ================================================================================= */

public OnClientUserInfoChanged_Pre( iId, pBuffer ) 
{
	if ( !GetPlayerBit( g_iIsConnected, iId ) )
	{
		return FMRES_IGNORED;
	}
	
	new szName[ 32 ];
	
	engfunc( EngFunc_InfoKeyValue, pBuffer, "name", szName, charsmax( szName ) );
	
	if ( equal( szName, g_sPlayers[ iId ][ Player_Name ] ) )
	{
		return FMRES_IGNORED;
	}
	
	ClearPlayerBit( g_iIsLogged, iId );
	
	copy( g_sPlayers[ iId ][ Player_Name ], charsmax( g_sPlayers[ ][ Player_Name ] ), szName );
	
	LoadPlayerData( iId );
	
	return FMRES_IGNORED;
}

public OnGetGameDescription_Pre( )
{
	forward_return( FMV_STRING, "Retake" );
	
	return FMRES_SUPERCEDE;
}

public OnBombCanDrop_Pre( iEnt )
{
	SetHamReturnInteger( 0 );
	
	return HAM_SUPERCEDE;
}

/* =================================================================================
* 				[ Client commands ]
* ================================================================================= */

public ClientCommand_Manage( const iId )
{
	if ( ~get_user_flags( iId ) & ADMIN_LEVEL_E )
	{
		return PLUGIN_HANDLED;
	}
	
	ShowCustomSpawns( g_sPlayers[ iId ][ Player_Menu_Bombsite ] );
	
	ShowManagementMenu( iId );
	
	return PLUGIN_HANDLED;
}

public ClientCommand_Weapons( const iId )
{
	new iTeam = get_member( iId, m_iTeam );
	
	if ( ( iTeam != _:TEAM_TERRORIST ) && ( iTeam != _:TEAM_CT ) )
	{
		return PLUGIN_HANDLED;
	}
	
	ShowWeaponsMenu( iId, 0, iTeam );
	
	return PLUGIN_HANDLED;
}

public ClientCommand_ChooseTeam( iId )
{
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Client menus ]
* ================================================================================= */

ShowManagementMenu( const iId )
{
	new szData[ 64 ];
	
	new iMenu = menu_create( "Configuracion", "ManagementMenuHandler" );
	
	formatex( szData, charsmax( szData ), "Cambiar bombsite \y(Bombsite: %s)", ( g_sPlayers[ iId ][ Player_Menu_Bombsite ] > 0 ) ? "B" : "A" );
	menu_additem( iMenu, szData );
	
	formatex( szData, charsmax( szData ), "Cambiar grupo \y(Grupo: %d)^n", ( g_sPlayers[ iId ][ Player_Menu_Group ] + 1 ) );
	menu_additem( iMenu, szData );
	
	menu_additem( iMenu, "Crear spawn terrorista" );
	menu_additem( iMenu, "Crear spawn anti-terrorista^n" );
	
	menu_additem( iMenu, "Borrar spawn apuntado" );
	menu_additem( iMenu, "Borrar spawns del bombsite" );
	menu_additem( iMenu, "Borrar spawns del mapa^n" );
	
	menu_additem( iMenu, "Setear spot de bomba^n" );
	
	menu_additem( iMenu, "Guardar^n^n" );
	
	menu_additem( iMenu, "Cancelar" );
	
	menu_setprop( iMenu, MPROP_PERPAGE, 0 );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public ManagementMenuHandler( iId, iMenu, iItem )
{
	menu_destroy( iMenu );
	
	if ( ( iItem == MENU_EXIT ) || ( iItem > 8 ) )
	{
		HideCustomSpawns( );
		
		return PLUGIN_HANDLED;
	}
	
	ClientPlaySound( iId, "buttons/lightswitch2.wav" );
	
	switch ( iItem )
	{
		case 0:
		{
			( g_sPlayers[ iId ][ Player_Menu_Bombsite ] == ( BOMB_SITE_COUNT - 1 ) ) ?
				( g_sPlayers[ iId ][ Player_Menu_Bombsite ] = 0 ) :
				( g_sPlayers[ iId ][ Player_Menu_Bombsite ]++ );
		}
		case 1:
		{
			( g_sPlayers[ iId ][ Player_Menu_Group ] == ( GROUP_COUNT - 1 ) ) ?
				( g_sPlayers[ iId ][ Player_Menu_Group ] = 0 ) :
				( g_sPlayers[ iId ][ Player_Menu_Group ]++ );
		}
		case 2, 3:
		{
			new Float:flOrigin[ 3 ];
			new Float:flAngles[ 3 ];
			
			entity_get_vector( iId, EV_VEC_origin, flOrigin );
			entity_get_vector( iId, EV_VEC_v_angle, flAngles );
			
			new sSpawn[ Spawn_Struct ];
			
			xs_vec_copy( flOrigin, sSpawn[ Spawn_Origin ] );
			xs_vec_copy( flAngles, sSpawn[ Spawn_Angles ] );
			
			sSpawn[ Spawn_Site ] 		= g_sPlayers[ iId ][ Player_Menu_Bombsite ];
			sSpawn[ Spawn_Group ] 		= g_sPlayers[ iId ][ Player_Menu_Group ];
			sSpawn[ Spawn_Team ] 		= ( iItem - 1 );
			sSpawn[ Spawn_Available ] 	= true;
			
			ArrayPushArray( g_aSpawns, sSpawn );
		}
		case 4:
		{
			new iEnt = FindCustomSpawn( iId );
			
			if ( iEnt > 0 )
			{
				new iItem = entity_get_int( iEnt, EV_INT_iuser1 );
				
				remove_entity( iEnt );
				
				ArrayDeleteItem( g_aSpawns, iItem );
			}
		}
		case 5:
		{
			new sSpawn[ Spawn_Struct ];
			
			new iSize = ArraySize( g_aSpawns );
			
			for ( new i = 0 ; i < iSize ; i++ )
			{
				ArrayGetArray( g_aSpawns, i, sSpawn );
				
				if ( sSpawn[ Spawn_Site ] != g_sPlayers[ iId ][ Player_Menu_Bombsite ] )
				{
					continue;
				}
				
				ArrayDeleteItem( g_aSpawns, i );
				
				i--; iSize--;
			}
		}
		case 6:
		{
			ArrayClear( g_aSpawns );
		}
		case 7:
		{
			new Float:flOrigin[ 3 ];
			
			entity_get_vector( iId, EV_VEC_origin, flOrigin );
			
			xs_vec_copy( flOrigin, g_flBombSpot[ g_sPlayers[ iId ][ Player_Menu_Bombsite ] ] );
		}
		case 8:
		{
			SaveMapData( );
		}
	}
	
	HideCustomSpawns( );
	ShowCustomSpawns( g_sPlayers[ iId ][ Player_Menu_Bombsite ] );
	
	ShowManagementMenu( iId );
	
	return PLUGIN_HANDLED;
}

ShowWeaponsMenu( const iId, const iStep, const iTeam )
{
	new szNum[ 16 ];
	
	new iMenu = 0;
	
	if ( iStep < 3 )
	{
		iMenu = menu_create( g_szWeaponMenuNames[ iStep ], "WeaponsMenuHandler" );
		
		for ( new i = g_iWeaponMenuStart[ iStep ] ; i <= g_iWeaponMenuEnd[ iStep ] ; i++ )
		{
			formatex( szNum, charsmax( szNum ), "%d %d %d", iStep, iTeam, ( i + ( ( iTeam - 1 ) * WEAPONS_TEAM_DIFFERENCE ) ) );
			menu_additem( iMenu, g_sWeapons[ ( i + ( ( iTeam - 1 ) * WEAPONS_TEAM_DIFFERENCE ) ) ][ Weapon_Alias ], szNum );
		}
	}
	else
	{
		if ( iStep == 3 )
		{
			iMenu = menu_create( "¿Permitir Scout?", "WeaponsMenuHandler" );
			
			formatex( szNum, charsmax( szNum ), "%d %d %d", iStep, iTeam, true );
			menu_additem( iMenu, "Si, permitir", szNum );
			
			formatex( szNum, charsmax( szNum ), "%d %d %d", iStep, iTeam, false );
			menu_additem( iMenu, "No, gracias", szNum );
		}
		else
		{
			iMenu = menu_create( "¿Permitir AWP?", "WeaponsMenuHandler" );
			
			formatex( szNum, charsmax( szNum ), "%d %d %d", iStep, iTeam, true );
			menu_additem( iMenu, "Si, permitir", szNum );
			
			formatex( szNum, charsmax( szNum ), "%d %d %d", iStep, iTeam, false );
			menu_additem( iMenu, "No, gracias", szNum );
		}
	}
	
	menu_setprop( iMenu, MPROP_BACKNAME, "Anterior" );
	menu_setprop( iMenu, MPROP_NEXTNAME, "Siguiente" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Cancelar" );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public WeaponsMenuHandler( iId, iMenu, iItem )
{
	if ( iItem == MENU_EXIT )
	{
		menu_destroy( iMenu );
		
		return PLUGIN_HANDLED;
	}
	
	ClientPlaySound( iId, "buttons/lightswitch2.wav" );
	
	new szData[ 16 ];
	
	new iAccess;
	new iCallback;
	
	menu_item_getinfo( iMenu, iItem, iAccess, szData, charsmax( szData ), _, _, iCallback );
	menu_destroy( iMenu );
	
	new szStep[ 4 ];
	new szTeam[ 4 ];
	new szNum[ 4 ];
	
	parse( szData, szStep, charsmax( szStep ), szTeam, charsmax( szTeam ), szNum, charsmax( szNum ) );
	
	new iStep = str_to_num( szStep );
	new iTeam = str_to_num( szTeam );
	new iNum = str_to_num( szNum );
	
	g_sPlayers[ iId ][ Player_Settings ] |= ( 1 << ( iTeam + 3 ) );
	
	if ( iStep < 3 )
	{
		switch ( iStep )
		{
			case( 0 ): g_sPlayers[ iId ][ Player_Pistol ][ iTeam - 1 ] = iNum;
			case( 1 ): g_sPlayers[ iId ][ Player_SMG ][ iTeam - 1 ] = iNum;
			case( 2 ): g_sPlayers[ iId ][ Player_Rifle ][ iTeam - 1 ] = iNum;
		}
	}
	else
	{
		new iSpace = ( ( iTeam - 1 ) * 2 );
		new iFlags = ( iStep == 3 ) ? ( 1 << ( 0 + iSpace ) ) : ( 1 << ( 1 + iSpace ) );
		
		( iNum == 0 ) ?
			( g_sPlayers[ iId ][ Player_Settings ] &= ~iFlags ) : ( g_sPlayers[ iId ][ Player_Settings ] |= iFlags );
	}
	
	if ( iStep < 4 )
	{
		ShowWeaponsMenu( iId, ( iStep + 1 ), iTeam );
	}
	else
	{
		if ( GetPlayerBit( g_iIsLogged, iId ) )
		{
			SavePlayerData( iId );
		}
	}
	
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Client connection ]
* ================================================================================= */

public client_putinserver( iId )
{
	SetPlayerBit( g_iIsConnected, iId );
	
	LoadDefaultData( iId );
	LoadPlayerData( iId );
	
	set_task( 1.0, "OnTaskJoinTeam", ( iId + TASK_JOIN_TEAM ) );
	
	CheckGameStatus( );
}

public client_disconnected( iId )
{
	ClearPlayerBit( g_iIsConnected, iId );
	ClearPlayerBit( g_iIsLogged, iId );
	ClearPlayerBit( g_iIsAlive, iId );
	
	ClearPlayerData( iId );
	
	remove_task( iId + TASK_JOIN_TEAM );
	remove_task( iId + TASK_FIX_MENU );
	
	CheckGameStatus( );
}

/* =================================================================================
* 				[ Initialize ]
* ================================================================================= */

Initialize( )
{
	g_iRoundStatus 	= ROUND_STARTED;
	
	g_iMaxPlayers 	= get_maxplayers( );
	g_iHudObject 	= CreateHudSyncObj( );
	
	g_iScenario 	= get_user_msgid( "Scenario" );
	g_iShowTimer 	= get_user_msgid( "ShowTimer" );
	g_iRoundTime 	= get_user_msgid( "RoundTime" );
	g_iBarTime 		= get_user_msgid( "BarTime" );
	
	g_aSpawns 		= ArrayCreate( Spawn_Struct, 1 );
	
	g_pRoundEvent 	= CreateMultiForward( "re_round_event", ET_IGNORE, FP_CELL, FP_CELL );
	
	for ( new i = 0 ; i < BOMB_SITE_COUNT ; i++ )
	{
		xs_vec_copy( Float:{ 0.0, 0.0, 0.0 }, g_flBombSpot[ i ] );
	}
}

/* =================================================================================
* 				[ Game management ]
* ================================================================================= */

CheckGameStatus( )
{
	new iTerrorists = 0;
	new iCounters = 0;
	new iTotal = 0;
	
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
		{
			continue;
		}
		
		iTotal++;
		
		if ( pev_valid( iPlayer ) != 2 )
		{
			continue;
		}
		
		switch ( get_pdata_int( iPlayer, 114 ) )
		{
			case 1: iTerrorists++;
			case 2: iCounters++;
		}
	}
	
	if ( ( iTotal < 2 ) || ( ( iTerrorists >= 1 ) && ( iCounters >= 1 ) ) )
	{
		return;
	}
	
	server_cmd( "sv_restartround 5" );
	
	set_dhudmessage( 250, 170, 50, -1.0, 0.15, 0, 0.0, 5.0 );
	show_dhudmessage( 0, "EL JUEGO ESTA POR COMENZAR" );
}

/* =================================================================================
* 				[ Bomb modules ]
* ================================================================================= */

PlantBomb( )
{
	if ( xs_vec_equal( g_flBombSpot[ g_iBombSite ], Float:{ 0.0, 0.0, 0.0 } ) )
	{
		return false;
	}
	
	new iEnt = find_ent_by_class( -1, "weapon_c4" );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return false;
	}
	
	new iOwner = get_member( iEnt, m_pPlayer );
	
	if ( !GetPlayerBit( g_iIsAlive, iOwner ) )
	{
		new iBackpack = get_entvar( iEnt, var_owner );
		
		if ( !is_valid_ent( iBackpack ) )
		{
			return false;
		}
		
		for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
		{
			if ( GetPlayerBit( g_iIsAlive, iPlayer ) && ( get_member( iPlayer, m_iTeam ) == _:TEAM_TERRORIST ) )
			{
				iOwner = iPlayer; break;
			}
		}
		
		if ( iOwner <= 0 )
		{
			return false;
		}
		
		set_entvar( iBackpack, var_flags, ( get_entvar( iBackpack, var_flags ) | FL_ONGROUND ) );
		fake_touch( iBackpack, iOwner );
	}
	
	new sSignals[ UnifiedSignals ];
	
	get_member( iOwner, m_signals, sSignals );
	
	sSignals[ US_State ] |= _:SIGNAL_BOMB;
	
	set_member( iOwner, m_signals, sSignals );
	set_entvar( iOwner, var_flags, ( get_entvar( iOwner, var_flags ) | FL_ONGROUND ) );
	
	set_member( iEnt, m_C4_bStartedArming, true );
	set_member( iEnt, m_C4_fArmedTime, 0.0 );
	
	ExecuteHamB( Ham_Weapon_PrimaryAttack, iEnt );
	
	iEnt = FindC4( );
	
	if ( is_valid_ent( iEnt ) )
	{
		set_entvar( iEnt, var_origin, g_flBombSpot[ g_iBombSite ] );
	}
	
	return true;
}

FindC4( )
{
	new iEnt = 0;
	
	do
	{
		iEnt = find_ent_by_class( iEnt, "grenade" );
	}
	while ( ( iEnt > 0 ) && !get_member( iEnt, m_Grenade_bIsC4 ) )
	
	return iEnt;
}

/* =================================================================================
* 				[ Team management ]
* ================================================================================= */

GetNeededTeam( )
{
	new iCount[ 2 ];
	
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
		{
			continue;
		}
		
		switch ( get_member( iPlayer, m_iTeam ) )
		{
			case( TEAM_TERRORIST ): iCount[ 0 ]++;
			case( TEAM_CT ): iCount[ 1 ]++;
		}
	}
	
	return ( ( iCount[ 0 ] == 0 ) || ( iCount[ 0 ] < ( iCount[ 1 ] - 1 ) ) ) ? ( _:TEAM_TERRORIST ) : ( _:TEAM_CT );
}

BalanceTeams( )
{
	new iPlayers[ 2 ][ MAX_PLAYERS ];
	new iCount[ 2 ];
	
	new iTeam = 0;
	
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
		{
			continue;
		}
		
		iTeam = get_member( iPlayer, m_iTeam );
		
		if ( ( iTeam != _:TEAM_TERRORIST ) && ( iTeam != _:TEAM_CT ) )
		{
			continue;
		}
		
		iPlayers[ iTeam - 1 ][ iCount[ iTeam - 1 ]++ ] = iPlayer;
	}
	
	new iTotal = ( iCount[ 0 ] + iCount[ 1 ] );
	
	if ( iTotal < 2 )
	{
		return;
	}
	
	new iTerrorists = max( 1, ( iTotal - ( ( iTotal / 2 ) + 1 ) ) );
	
	if ( iCount[ 0 ] == iTerrorists )
	{
		return;
	}
	
	new iNeeded = abs( iTerrorists - iCount[ 0 ] );
	new iWithdraw = ( ( iTerrorists - iCount[ 0 ] ) < 0 ) ? 0 : 1;
	
	new CsTeams:iJoin = ( iWithdraw == 0 ) ? CS_TEAM_CT : CS_TEAM_T;
	
	for ( new i = 0, j = 0 ; i < iNeeded ; i++ )
	{
		j = random( iCount[ iWithdraw ] );
		
		cs_set_user_team( iPlayers[ iWithdraw ][ j ], iJoin );
		
		iCount[ iWithdraw ]--;
		
		iPlayers[ iWithdraw ][ j ] = iPlayers[ iWithdraw ][ iCount[ iWithdraw ] ];
		iPlayers[ iWithdraw ][ iCount[ iWithdraw ] ] = 0;
	}
}

SwitchTeams( )
{
	new iTerrorists[ MAX_PLAYERS ];
	new iCounters[ MAX_PLAYERS ];
	
	new iCount[ 2 ];
	
	new iTeam = 0;
	
	for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
	{
		if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
		{
			continue;
		}
		
		iTeam = get_member( iPlayer, m_iTeam );
		
		if ( ( iTeam != _:TEAM_TERRORIST ) && ( iTeam != _:TEAM_CT ) )
		{
			continue;
		}
		
		switch ( iTeam )
		{
			case( TEAM_TERRORIST ): iTerrorists[ iCount[ iTeam - 1 ]++ ] = iPlayer;
			case( TEAM_CT ): iCounters[ iCount[ iTeam - 1 ]++ ] = iPlayer;
		}
	}
	
	if ( ( iCount[ 0 ] == 0 ) || ( iCount[ 1 ] == 0 ) || ( iCount[ 0 ] > iCount[ 1 ] ) )
	{
		return;
	}
	
	for ( new i = 0, j = 0, k = 0 ; i < iCount[ 0 ] ; i++ )
	{
		k = -1;
		
		for ( j = 0 ; j < iCount[ 1 ] ; j++ )
		{
			if ( ( k == -1 ) || ( entity_get_float( iCounters[ j ], EV_FL_frags ) > entity_get_float( iCounters[ k ], EV_FL_frags ) ) )
			{
				k = j;
			}
		}
		
		cs_set_user_team( iCounters[ k ], CS_TEAM_T );
		
		iCount[ 1 ] = max( 0, ( iCount[ 1 ] - 1 ) );
		
		iCounters[ k ] = iCounters[ iCount[ 1 ] ];
		iCounters[ iCount[ 1 ] ] = 0;
	}
	
	for ( new i = 0 ; i < iCount[ 0 ] ; i++ )
	{
		cs_set_user_team( iTerrorists[ i ], CS_TEAM_CT );
	}
}

LetWaitingPlayersJoin( )
{
	new iPlayers[ 32 ];
	new iPlayersNum;
	
	get_players( iPlayers, iPlayersNum );
	
	if ( iPlayersNum < 2 )
	{
		return;
	}
	
	set_cvar_num( "mp_limitteams", 0 );
	
	for ( new i = 0 ; i < iPlayersNum ; i++ )
	{
		if ( 0 < get_member( iPlayers[ i ], m_iTeam ) < 3 )
		{
			continue;
		}
		
		if ( task_exists( iPlayers[ i ] + TASK_JOIN_TEAM ) )
		{
			continue;
		}
		
		set_task( 1.0, "OnTaskJoinTeam", ( iPlayers[ i ] + TASK_JOIN_TEAM ) );
	}
}

/* =================================================================================
* 				[ Equipment & Position ]
* ================================================================================= */

SetPlayerEquipment( const iId )
{
	new iTeam = get_member( iId, m_iTeam );
	
	if ( ( iTeam != _:TEAM_TERRORIST ) && ( iTeam != _:TEAM_CT ) )
	{
		return;
	}
	
	new iWeapon = 0;
	new iGrenades = 0;
	new iDefuser = 0;
	new iSpace = 0;
	
	switch ( g_iEquipment )
	{
		case EQUIPMENT_PISTOL:
		{
			iWeapon = g_sPlayers[ iId ][ Player_Pistol ][ iTeam - 1 ];
			
			if ( random_num( 1, 100 ) <= 50 )
			{
				iGrenades = 1;
				iDefuser = 100;
				
				cs_set_user_armor( iId, 0, CS_ARMOR_NONE );
			}
			else
			{
				cs_set_user_armor( iId, 100, CS_ARMOR_KEVLAR );
			}
		}
		case EQUIPMENT_SMG:
		{
			iWeapon = g_sPlayers[ iId ][ Player_SMG ][ iTeam - 1 ];
			
			iGrenades = 1;
			iDefuser = 40;
			
			iSpace = ( ( iTeam - 1 ) * 2 );
			
			if ( ( g_sPlayers[ iId ][ Player_Settings ] & ( 1 << ( 0 + iSpace ) ) ) && !g_bSniperGiven[ iTeam - 1 ] && ( random( 100 ) <= EQUIPMENT_SCOUT_CHANCE ) )
			{
				iWeapon = WEAPONS_SCOUT_INDEX;
				
				g_bSniperGiven[ iTeam - 1 ] = true;
			}
		}
		case EQUIPMENT_FULL:
		{
			iWeapon = g_sPlayers[ iId ][ Player_Rifle ][ iTeam - 1 ];
			
			iGrenades = 1;
			iDefuser = 60;
			
			iSpace = ( ( iTeam - 1 ) * 2 );
			
			if ( ( g_sPlayers[ iId ][ Player_Settings ] & ( 1 << ( 1 + iSpace ) ) ) && !g_bSniperGiven[ iTeam - 1 ] && ( random( 100 ) <= EQUIPMENT_AWP_CHANCE ) )
			{
				iWeapon = WEAPONS_AWP_INDEX;
				
				g_bSniperGiven[ iTeam - 1 ] = true;
			}
		}
	}
	
	strip_user_weapons( iId );
	
	set_pdata_int( iId, m_fHasPrimary, 0, XO_PLAYER );
	
	give_item( iId, "weapon_knife" );
	give_item( iId, g_sWeapons[ iWeapon ][ Weapon_Name ] );
	
	cs_set_user_bpammo( iId, g_sWeapons[ iWeapon ][ Weapon_Id ], g_sWeapons[ iWeapon ][ Weapon_Ammo ] );
	
	if ( g_iEquipment != EQUIPMENT_PISTOL )
	{
		cs_set_user_armor( iId, 100, CS_ARMOR_VESTHELM );
		
		new iPistol = g_sPlayers[ iId ][ Player_Pistol ][ iTeam - 1 ];
		
		if ( ( iWeapon == WEAPONS_SCOUT_INDEX ) || ( iWeapon == WEAPONS_AWP_INDEX ) )
		{
			iPistol = 3;
		}
		
		give_item( iId, g_sWeapons[ iPistol ][ Weapon_Name ] );
		
		cs_set_user_bpammo( iId, g_sWeapons[ iPistol ][ Weapon_Id ], g_sWeapons[ iPistol ][ Weapon_Ammo ] );
	}
	
	if ( iGrenades > 0 )
	{
		new iGrenade = 0;
		new iRandom = 0;
		
		do
		{
			iRandom = random( 100 );
			iGrenade = ( ( iRandom % 2 ) > 0 ) ? ( ( iRandom % 3 ) > 0 ) ? 1 : 2 : 0;
			
			if ( cs_get_user_bpammo( iId, g_sGrenades[ iGrenade ][ Grenade_Id ] ) >= g_sGrenades[ iGrenade ][ Grenade_Carry ] )
			{
				continue;
			}
			
			give_item( iId, g_sGrenades[ iGrenade ][ Grenade_Name ] );
			
			iGrenades--;
		}
		while ( iGrenades > 0 )
	}
	
	if ( ( iTeam == _:TEAM_CT ) && ( iDefuser > 0 ) && ( random( 100 ) <= iDefuser ) )
	{
		cs_set_user_defuse( iId );
	}
}

SetPlayerPosition( const iId )
{
	new iTeam = get_member( iId, m_iTeam );
	
	if ( ( iTeam != _:TEAM_TERRORIST ) && ( iTeam != _:TEAM_CT ) )
	{
		return false;
	}
	
	new sSpawn[ Spawn_Struct ];
	
	new iTotal[ GROUP_COUNT ];
	new iAvailable[ GROUP_COUNT ];
	
	new iSize = ArraySize( g_aSpawns );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		ArrayGetArray( g_aSpawns, i, sSpawn );
		
		if ( ( sSpawn[ Spawn_Site ] != g_iBombSite ) || ( sSpawn[ Spawn_Team ] != iTeam ) )
		{
			continue;
		}
		
		iTotal[ sSpawn[ Spawn_Group ] ]++;
		
		if ( sSpawn[ Spawn_Available ] )
		{
			iAvailable[ sSpawn[ Spawn_Group ] ]++;
		}
	}
	
	new iChances[ GROUP_COUNT ];
	
	new iTotalChances = 0;
	
	for ( new i = 0 ; i < GROUP_COUNT ; i++ )
	{
		if ( iAvailable[ i ] == 0 )
		{
			continue;
		}
		
		iChances[ i ] = ( ( 100 * iAvailable[ i ] ) / iTotal[ i ] );
		iTotalChances = ( iTotalChances + iChances[ i ] );
	}
	
	if ( iTotalChances == 0 )
	{
		return false;
	}
	
	new iRandom = random_num( 1, iTotalChances );
	
	new iSum = 0;
	new iGroup = 0;
	
	for ( iGroup = 0 ; iGroup < GROUP_COUNT ; iGroup++ )
	{
		if ( iChances[ iGroup ] == 0 )
		{
			continue;
		}
		
		iSum += iChances[ iGroup ];
		
		if ( iRandom <= iSum )
		{
			break;
		}
	}
	
	new iCount = ( random( iAvailable[ iGroup ] ) + 1 );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		ArrayGetArray( g_aSpawns, i, sSpawn );
		
		if ( ( sSpawn[ Spawn_Site ] != g_iBombSite ) || ( sSpawn[ Spawn_Team ] != iTeam ) )
		{
			continue;
		}
		
		if ( ( sSpawn[ Spawn_Group ] != iGroup ) || !sSpawn[ Spawn_Available ] )
		{
			continue;
		}
		
		if ( --iCount > 0 )
		{
			continue;
		}
		
		sSpawn[ Spawn_Available ] = false;
		
		ArraySetArray( g_aSpawns, i, sSpawn );
		
		break;
	}
	
	new Float:flOrigin[ 3 ];
	new Float:flAngles[ 3 ];
	
	xs_vec_copy( sSpawn[ Spawn_Origin ], flOrigin );
	xs_vec_copy( sSpawn[ Spawn_Angles ], flAngles );
	
	entity_set_origin( iId, flOrigin );
	entity_set_vector( iId, EV_VEC_angles, flAngles );
	
	entity_set_int( iId, EV_INT_fixangle, 1 );
	
	return true;
}

RandomizeEquipment( )
{
	new iChances = 0;
	
	for ( new i = 0 ; i < Equipments ; i++ )
	{
		iChances += g_iEquipmentChances[ i ];
	}
	
	new iSum = 0;
	new iRandom = random_num( 1, iChances );
	
	for ( new i = 0 ; i < Equipments ; i++ )
	{
		iSum += g_iEquipmentChances[ i ];
		
		if ( iRandom <= iSum )
		{
			return i;
		}
	}
	
	return 0;
}

/* =================================================================================
* 				[ Clearers ]
* ================================================================================= */

ClearAvailableSpawns( )
{
	new sSpawn[ Spawn_Struct ];
	
	new iSize = ArraySize( g_aSpawns );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		ArrayGetArray( g_aSpawns, i, sSpawn );
		
		if ( sSpawn[ Spawn_Available ] )
		{
			continue;
		}
		
		sSpawn[ Spawn_Available ] = true;
		
		ArraySetArray( g_aSpawns, i, sSpawn );
	}
}

ClearPlayerData( const iId )
{
	g_sPlayers[ iId ][ Player_Id ] 				= 0;
	g_sPlayers[ iId ][ Player_Settings ] 		= 0;
	
	g_sPlayers[ iId ][ Player_Menu_Bombsite ] 	= 0;
	g_sPlayers[ iId ][ Player_Menu_Group ] 		= 0;
	
	g_sPlayers[ iId ][ Player_Name ][ 0 ] 		= '^0';
	
	for ( new i = 0 ; i < 2 ; i++ )
	{
		g_sPlayers[ iId ][ Player_Pistol ][ i ] 	= 0;
		g_sPlayers[ iId ][ Player_SMG ][ i ] 	= 0;
		g_sPlayers[ iId ][ Player_Rifle ][ i ] 	= 0;
	}
}

/* =================================================================================
* 				[ Load & Save data ]
* ================================================================================= */

LoadConfig( )
{
	new szFile[ 64 ];
	
	get_localinfo( "amxx_configsdir", szFile, charsmax( szFile ) );
	add( szFile, charsmax( szFile ), "/retake.cfg" );
	
	if ( file_exists( szFile ) )
	{
		server_cmd( "exec ^"%s^"", szFile );
	}
}

LoadMapData( )
{
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	add( szDir, charsmax( szDir ), "/retake" );
	
	if ( !dir_exists( szDir ) )
	{
		mkdir( szDir );
	}
	
	new szMap[ 32 ];
	new szFile[ 64 ];
	
	get_mapname( szMap, charsmax( szMap ) );
	formatex( szFile, charsmax( szFile ), "%s/%s.dat", szDir, szMap );
	
	if ( !file_exists( szFile ) )
	{
		return;
	}
	
	new iFile = fopen( szFile, "r" );
	
	new szBuffer[ 128 ];
	
	new szTeam[ 4 ];
	new szSite[ 4 ];
	new szGroup[ 4 ];
	
	new szOrigin[ 3 ][ 8 ];
	new szAngles[ 3 ][ 8 ];
	
	new sSpawn[ Spawn_Struct ];
	
	for ( new i = 0, j = 0 ; i < BOMB_SITE_COUNT ; i++ )
	{
		fgets( iFile, szBuffer, charsmax( szBuffer ) );
		trim( szBuffer );
		
		parse( szBuffer, szOrigin[ 0 ], charsmax( szOrigin[ ] ), szOrigin[ 1 ], charsmax( szOrigin[ ] ), szOrigin[ 2 ], charsmax( szOrigin[ ] ) );
		
		for ( j = 0 ; j < 3 ; j++ )
		{
			g_flBombSpot[ i ][ j ] = str_to_float( szOrigin[ j ] );
		}
	}
	
	new i = 0;
	
	while ( !feof( iFile ) )
	{
		fgets( iFile, szBuffer, charsmax( szBuffer ) );
		trim( szBuffer );
		
		if ( !szBuffer[ 0 ] )
		{
			continue;
		}
		
		parse( szBuffer,
			szSite, charsmax( szSite ),
			szGroup, charsmax( szGroup ),
			szTeam, charsmax( szTeam ),
			szOrigin[ 0 ], charsmax( szOrigin[ ] ),
			szOrigin[ 1 ], charsmax( szOrigin[ ] ),
			szOrigin[ 2 ], charsmax( szOrigin[ ] ),
			szAngles[ 0 ], charsmax( szAngles[ ] ),
			szAngles[ 1 ], charsmax( szAngles[ ] ),
			szAngles[ 2 ], charsmax( szAngles[ ] )
		);
		
		sSpawn[ Spawn_Site ] 		= str_to_num( szSite );
		sSpawn[ Spawn_Group ] 		= str_to_num( szGroup );
		sSpawn[ Spawn_Team ] 		= str_to_num( szTeam );
		
		sSpawn[ Spawn_Available ] 	= true;
		
		for ( i = 0 ; i < 3 ; i++ )
		{
			sSpawn[ Spawn_Origin ][ i ] = _:str_to_float( szOrigin[ i ] );
			sSpawn[ Spawn_Angles ][ i ] = _:str_to_float( szAngles[ i ] );
		}
		
		ArrayPushArray( g_aSpawns, sSpawn );
	}
	
	fclose( iFile );
}

SaveMapData( )
{
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	add( szDir, charsmax( szDir ), "/retake" );
	
	if ( !dir_exists( szDir ) )
	{
		mkdir( szDir );
	}
	
	new szMap[ 32 ];
	new szFile[ 64 ];
	
	get_mapname( szMap, charsmax( szMap ) );
	formatex( szFile, charsmax( szFile ), "%s/%s.dat", szDir, szMap );
	
	new iFile = fopen( szFile, "w" );
	
	fprintf( iFile, "%0.2f %0.2f %0.2f^n", g_flBombSpot[ 0 ][ 0 ], g_flBombSpot[ 0 ][ 1 ], g_flBombSpot[ 0 ][ 2 ] );
	fprintf( iFile, "%0.2f %0.2f %0.2f^n", g_flBombSpot[ 1 ][ 0 ], g_flBombSpot[ 1 ][ 1 ], g_flBombSpot[ 1 ][ 2 ] );
	
	new sSpawn[ Spawn_Struct ];
	
	new iSize = ArraySize( g_aSpawns );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		ArrayGetArray( g_aSpawns, i, sSpawn );
		
		fprintf( iFile, "%d %d %d %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f^n",
			sSpawn[ Spawn_Site ], sSpawn[ Spawn_Group ], sSpawn[ Spawn_Team ], sSpawn[ Spawn_Origin ][ 0 ], sSpawn[ Spawn_Origin ][ 1 ],
			sSpawn[ Spawn_Origin ][ 2 ], sSpawn[ Spawn_Angles ][ 0 ], sSpawn[ Spawn_Angles ][ 1 ], sSpawn[ Spawn_Angles ][ 2 ] );
	}
	
	fclose( iFile );
}

/* =================================================================================
* 				[ Player data ]
* ================================================================================= */

LoadPlayerData( const iId )
{
	SQL_Query( iId, QUERY_LOAD, "SELECT * FROM users WHERE name=^"%s^"",
		g_sPlayers[ iId ][ Player_Name ] );
}

SavePlayerData( const iId )
{
	SQL_Query( iId, QUERY_IGNORE, "UPDATE users SET settings=%d, pistol_t=%d, pistol_ct=%d, smg_t=%d, smg_ct=%d, rifle_t=%d, rifle_ct=%d WHERE id=%d",
		g_sPlayers[ iId ][ Player_Settings ], g_sPlayers[ iId ][ Player_Pistol ][ 0 ],
		g_sPlayers[ iId ][ Player_Pistol ][ 1 ], g_sPlayers[ iId ][ Player_SMG ][ 0 ],
		g_sPlayers[ iId ][ Player_SMG ][ 1 ], g_sPlayers[ iId ][ Player_Rifle ][ 0 ], 
		g_sPlayers[ iId ][ Player_Rifle ][ 1 ], g_sPlayers[ iId ][ Player_Id ] );
}

LoadDefaultData( const iId )
{
	get_user_name( iId, g_sPlayers[ iId ][ Player_Name ], charsmax( g_sPlayers[ ][ Player_Name ] ) );
	
	g_sPlayers[ iId ][ Player_Settings ] = 0;
	
	g_sPlayers[ iId ][ Player_Pistol ][ 0 ] = WEAPONS_PISTOLS_START;
	g_sPlayers[ iId ][ Player_Pistol ][ 1 ] = ( WEAPONS_PISTOLS_START + WEAPONS_TEAM_DIFFERENCE );
	
	g_sPlayers[ iId ][ Player_SMG ][ 0 ] = WEAPONS_SMGS_START;
	g_sPlayers[ iId ][ Player_SMG ][ 1 ] = ( WEAPONS_SMGS_START + WEAPONS_TEAM_DIFFERENCE );
	
	g_sPlayers[ iId ][ Player_Rifle ][ 0 ] = WEAPONS_RIFLES_START;
	g_sPlayers[ iId ][ Player_Rifle ][ 1 ] = ( WEAPONS_RIFLES_START + WEAPONS_TEAM_DIFFERENCE );
}

/* =================================================================================
* 				[ Show Spawns While Editing ]
* ================================================================================= */

CreateCustomSpawn( const iTeam, const Float:flOrigin[ 3 ], const Float:flAngles[ 3 ] )
{
	new iEnt = create_entity( g_szInfoTargetClass );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return -1;
	}
	
	entity_set_string( iEnt, EV_SZ_classname, g_szCustomSpawnClass );
	
	entity_set_model( iEnt, g_szCustomSpawnModels[ iTeam ] );
	entity_set_size( iEnt, Float:{ -16.0, -16.0, -36.0 }, Float:{ 16.0, 16.0, 36.0 } );
	
	entity_set_origin( iEnt, flOrigin );
	entity_set_vector( iEnt, EV_VEC_angles, flAngles );
	
	entity_set_int( iEnt, EV_INT_solid, SOLID_TRIGGER );
	entity_set_int( iEnt, EV_INT_movetype, MOVETYPE_FLY );
	
	entity_set_int( iEnt, EV_INT_sequence, 1 );
	entity_set_int( iEnt, EV_INT_weaponanim, 1 );
	
	entity_set_float( iEnt, EV_FL_animtime, get_gametime( ) );
	entity_set_float( iEnt, EV_FL_framerate, 1.0 );
	entity_set_float( iEnt, EV_FL_frame, 0.0 );
	
	entity_set_byte( iEnt, EV_BYTE_controller1, 125 );
	entity_set_byte( iEnt, EV_BYTE_controller2, 125 );
	entity_set_byte( iEnt, EV_BYTE_controller3, 125 );
	entity_set_byte( iEnt, EV_BYTE_controller4, 125 );
	
	return iEnt;
}

FindCustomSpawn( const iId )
{
	new Float:flOrigin[ 3 ];
	new Float:flEnd[ 3 ];
	new Float:flStart[ 3 ];
	new Float:flViewOfs[ 3 ];
	new Float:flAngles[ 3 ];
	
	get_entvar( iId, var_origin, flOrigin );
	get_entvar( iId, var_view_ofs, flViewOfs );
	get_entvar( iId, var_v_angle, flAngles );
	
	xs_vec_add( flOrigin, flViewOfs, flStart );
	
	angle_vector( flAngles, ANGLEVECTOR_FORWARD, flAngles );
	
	xs_vec_mul_scalar( flAngles, 2048.0, flAngles );
	xs_vec_add( flStart, flAngles, flEnd );
	
	new iEnt = 0;
	
	while ( ( iEnt = find_ent_by_class( iEnt, g_szCustomSpawnClass ) ) > 0 )
	{
		engfunc( EngFunc_TraceModel, flStart, flEnd, HULL_POINT, iEnt, 0 );
		
		if ( get_tr2( 0, TR_pHit ) == iEnt )
		{
			return iEnt;
		}
	}
	
	return -1;
}

ShowCustomSpawns( const iBombsite )
{
	if ( g_bShowingSpawns )
	{
		return;
	}
	
	g_bShowingSpawns = true;
	
	new sSpawn[ Spawn_Struct ];
	
	new iSpawnsCount = ArraySize( g_aSpawns );
	
	new Float:flOrigin[ 3 ];
	new Float:flAngles[ 3 ];
	
	new iEnt;
	
	for ( new i = 0 ; i < iSpawnsCount ; i++ )
	{
		ArrayGetArray( g_aSpawns, i, sSpawn );
		
		if ( sSpawn[ Spawn_Site ] != iBombsite )
		{
			continue;
		}
		
		xs_vec_copy( sSpawn[ Spawn_Origin ], flOrigin );
		
		flAngles[ 1 ] = sSpawn[ Spawn_Angles ][ 1 ];
		
		iEnt = CreateCustomSpawn( sSpawn[ Spawn_Team ], flOrigin, flAngles );
		
		if ( iEnt > 0 )
		{
			entity_set_int( iEnt, EV_INT_iuser1, i );
		}
	}
}

HideCustomSpawns( )
{
	if ( !g_bShowingSpawns )
	{
		return;
	}
	
	g_bShowingSpawns = false;
	
	new iEnt = 0;
	
	while ( ( iEnt = find_ent_by_class( iEnt, g_szCustomSpawnClass ) ) > 0 )
	{
		remove_entity( iEnt );
	}
}

/* =================================================================================
* 				[ Create entities ]
* ================================================================================= */

CreateMapEntities( )
{
	new iEnt = create_entity( "info_map_parameters" );
	
	DispatchKeyValue( iEnt, "buying", "3" );
	DispatchSpawn( iEnt );
}

/* =================================================================================
* 				[ Data base ]
* ================================================================================= */

SQL_Init( )
{
	new szType[ 16 ];
	
	SQL_SetAffinity( "sqlite" );
	SQL_GetAffinity( szType, charsmax( szType ) );
	
	if ( !equal( szType, "sqlite" ) ) 
	{
		log_to_file( "sql_error.log", "No se pudo setear la afinidad del driver a SQLite (Modulo deshabilitado?)." );
		
		set_fail_state( "Error en la conexion" );
	}
	
	g_hConnection = SQL_MakeDbTuple( "", "", "", "retake" );
}

SQL_CreateTable( )
{
	new szTable[ 1024 ];
	new iLen;
	
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "CREATE TABLE IF NOT EXISTS users (" );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "id INTEGER PRIMARY KEY AUTOINCREMENT," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "name VARCHAR( 32 ) UNIQUE COLLATE NOCASE," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "settings INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "pistol_t INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "pistol_ct INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "smg_t INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "smg_ct INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "rifle_t INTEGER NOT NULL DEFAULT 0," );
	iLen += formatex( szTable[ iLen ], charsmax( szTable ) - iLen, "rifle_ct INTEGER NOT NULL DEFAULT 0 )" );
	
	new iData[ 2 ];
	
	iData[ 0 ] = 0;
	iData[ 1 ] = QUERY_IGNORE;
	
	SQL_ThreadQuery( g_hConnection, "SQL_QueryHandler", szTable, iData, sizeof( iData ) );
}

SQL_Query( const iPlayer, const iQuery, const szBuffer[ ], any:... )
{
	new iData[ 2 ];
	new szQuery[ 256 ];
	
	iData[ 0 ] = iPlayer;
	iData[ 1 ] = iQuery;
	
	( numargs( ) > 3 ) ?
		vformat( szQuery, charsmax( szQuery ), szBuffer, 4 ) :
		copy( szQuery, charsmax( szQuery ), szBuffer );
	
	SQL_ThreadQuery( g_hConnection, "SQL_QueryHandler", szQuery, iData, sizeof( iData ) );
}
 
public SQL_QueryHandler( iFailState, Handle:hQuery, szError[ ], iErrcode, iData[ ], iDatalen, Float:flTime )
{
	new iId = iData[ 0 ];
	new iQuery = iData[ 1 ];
	
	if ( iFailState < TQUERY_SUCCESS )
	{
		log_to_file( "sql_error.log", "(Code: %d) %s", iErrcode, szError );
		
		return;
	}
	
	if ( ( iQuery == QUERY_IGNORE ) || !GetPlayerBit( g_iIsConnected, iId ) )
	{
		return;
	}
	
	switch ( iQuery )
	{
		case QUERY_LOAD: 
		{
			if ( SQL_NumResults( hQuery ) <= 0 )
			{
				SQL_Query( iId, QUERY_INSERT, "INSERT INTO users ( name ) VALUES ( ^"%s^" )", g_sPlayers[ iId ][ Player_Name ] );
				
				return;
			}
			
			g_sPlayers[ iId ][ Player_Id ] 			= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "id" ) );
			g_sPlayers[ iId ][ Player_Settings ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "settings" ) );
			
			g_sPlayers[ iId ][ Player_Pistol ][ 0 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "pistol_t" ) );
			g_sPlayers[ iId ][ Player_Pistol ][ 1 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "pistol_ct" ) );
			
			g_sPlayers[ iId ][ Player_SMG ][ 0 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "smg_t" ) );
			g_sPlayers[ iId ][ Player_SMG ][ 1 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "smg_ct" ) );
			
			g_sPlayers[ iId ][ Player_Rifle ][ 0 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "rifle_t" ) );
			g_sPlayers[ iId ][ Player_Rifle ][ 1 ] 	= SQL_ReadResult( hQuery, SQL_FieldNameToNum( hQuery, "rifle_ct" ) );
			
			SetPlayerBit( g_iIsLogged, iId );
		}
		case QUERY_INSERT:
		{
			g_sPlayers[ iId ][ Player_Id ] = SQL_GetInsertId( hQuery );
			
			SetPlayerBit( g_iIsLogged, iId );
		}
	}
}