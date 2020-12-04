#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <xs>
#include <retake>
#include <common>

/* ===========================================================================
* 				[ Initiation & Global stuff ]
* ============================================================================ */

const MAX_ZONES = 16;

const TASK_SHOW_ZONES = 100;

const ZONES_KEYS = ( MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_4 | MENU_KEY_5 | MENU_KEY_6 | MENU_KEY_7 | MENU_KEY_8 | MENU_KEY_9 | MENU_KEY_0  );

new const g_szPrefix[ ] 		= "Retake";
new const g_szBlockZoneClass[ ]	= "BlockZone";
new const g_szInfoTarget[ ] 	= "info_target";

new g_iBombSite;
new g_iLaserBeam;

new g_iZonesCount;
new g_iZonesEnts[ MAX_ZONES ];

new Float:g_flPointA[ 3 ];
new Float:g_flPointB[ 3 ];

new g_szSaveFile[ 128 ];

/* =================================================================================
* 				[ Plugin events ]
* ================================================================================= */

public plugin_precache( )
{
	g_iLaserBeam = precache_model( "sprites/laserbeam.spr" );
}

public plugin_init( )
{
	register_plugin( "Retake Zones", "1.3", "Manu" );
	
	register_think( g_szBlockZoneClass, "OnZoneThink" );
	register_touch( g_szBlockZoneClass, "player", "OnPlayerTouchZone" );
	
	register_menucmd( register_menuid( "Zones Menu" ), ZONES_KEYS, "OnZonesMenuHandler" );
	
	register_clcmd( "say /zones", "ClientCommand_Zones" );
	register_clcmd( "say /zonas", "ClientCommand_Zones" );
	
	LoadZones( );
}

/* ===========================================================================
* 				[ Cross-Plugin Communication ]
* ============================================================================ */

public re_round_event( iRoundStatus, iBombSite )
{
	if ( iRoundStatus != ROUND_STARTED )
	{
		for ( new i = 0 ; i < g_iZonesCount ; i++ )
		{
			if ( !is_valid_ent( g_iZonesEnts[ i ] ) )
			{
				continue;
			}
			
			entity_set_int( g_iZonesEnts[ i ], EV_INT_solid, SOLID_NOT );
			entity_set_float( g_iZonesEnts[ i ], EV_FL_nextthink, 0.0 );
		}
		
		return;
	}
	
	for ( new i = 0 ; i < g_iZonesCount ; i++ )
	{
		if ( !is_valid_ent( g_iZonesEnts[ i ] ) )
		{
			continue;
		}
		
		if ( entity_get_int( g_iZonesEnts[ i ], EV_INT_iuser1 ) != iBombSite )
		{
			continue;
		}
		
		entity_set_int( g_iZonesEnts[ i ], EV_INT_solid, SOLID_TRIGGER );
		entity_set_float( g_iZonesEnts[ i ], EV_FL_nextthink, get_gametime( ) );
	}
}

/* ===========================================================================
* 				[ Zone Events ]
* ============================================================================ */

public OnZoneThink( iEnt )
{
	static Float:flPoints[ 4 ][ 3 ];
	
	static Float:flOrigin[ 3 ];
	static Float:flSize[ 3 ];
	
	entity_get_vector( iEnt, EV_VEC_origin, flOrigin );
	entity_get_vector( iEnt, EV_VEC_size, flSize );
	
	CalculateLaserCorners( flOrigin, flSize, flPoints );
	
	for ( new i = 0 ; i < 2 ; i++ )
	{
		message_begin_f( MSG_PVS, SVC_TEMPENTITY, flOrigin );
		write_byte( TE_BEAMPOINTS );
		write_coord_f( flPoints[ i * 2 ][ 0 ] );
		write_coord_f( flPoints[ i * 2 ][ 1 ] );
		write_coord_f( flPoints[ i * 2 ][ 2 ] );
		write_coord_f( flPoints[ ( i * 2 ) + 1 ][ 0 ] );
		write_coord_f( flPoints[ ( i * 2 ) + 1 ][ 1 ] );
		write_coord_f( flPoints[ ( i * 2 ) + 1 ][ 2 ] );
		write_short( g_iLaserBeam );
		write_byte( 1 );
		write_byte( 5 );
		write_byte( 10 );
		write_byte( 15 );
		write_byte( 0 );
		write_byte( 255 );
		write_byte( 0 );
		write_byte( 0 );
		write_byte( 200 );
		write_byte( 200 );
		message_end( );
	}
	
	entity_set_float( iEnt, EV_FL_nextthink, ( get_gametime( ) + 1.0 ) );
}

public OnPlayerTouchZone( iZone, iPlayer )
{
	static Float:flZoneOrigin[ 3 ];
	static Float:flPlayerOrigin[ 3 ];
	
	static Float:flSize[ 3 ];
	static Float:flAux[ 3 ];
	static Float:flSides[ 6 ];
	
	entity_get_vector( iZone, EV_VEC_origin, flZoneOrigin );
	entity_get_vector( iPlayer, EV_VEC_origin, flPlayerOrigin );
	
	entity_get_vector( iZone, EV_VEC_size, flSize );
	
	xs_vec_copy( flPlayerOrigin, flAux );
	
	for ( new i = 0, j = -1 ; i < 3 ; i++ )
	{
		for ( j = 0 ; j < 2 ; j++ )
		{
			flAux[ i ] = ( flZoneOrigin[ i ] + ( ( flSize[ i ] / 2 ) * ( ( j == 0 ) ? -1 : j ) ) );
			flSides[ i + ( j * 3 ) ] = xs_vec_distance( flPlayerOrigin, flAux );
			
			flAux[ i ] = flPlayerOrigin[ i ];
		}
	}
	
	new iClosestSide = 0;
	
	for ( new i = 1 ; i < 6 ; i++ )
	{
		if ( flSides[ i ] < flSides[ iClosestSide ] )
		{
			iClosestSide = i;
		}
	}
	
	flAux[ 0 ] = 0.0;
	flAux[ 1 ] = 0.0;
	flAux[ 2 ] = 0.0;
	
	( iClosestSide < 3 ) ?
		( flAux[ iClosestSide ] = -250.0 ) : ( flAux[ ( iClosestSide - 3 ) ] = 250.0 );
	
	entity_set_vector( iPlayer, EV_VEC_velocity, flAux );
}

public OnTaskShowZones( )
{
	new iPlayers[ MAX_PLAYERS ];
	new iPlayersCount;
	
	new Float:flOrigin[ 3 ];
	new Float:flMins[ 3 ];
	new Float:flMaxs[ 3 ];
	
	new Float:flDistance;
	new Float:flClosest;
	
	new iClosest;
	new iBombsite;
	
	get_players( iPlayers, iPlayersCount, "ch" );
	
	for ( new i = 0, j = 0 ; i < iPlayersCount ; i++ )
	{
		flClosest = 9999.0;
		iClosest = -1;
		
		for ( j = 0 ; j < g_iZonesCount ; j++ )
		{
			iBombsite = entity_get_int( g_iZonesEnts[ j ], EV_INT_iuser1 );
			
			if ( g_iBombSite != iBombsite )
			{
				continue;
			}
			
			flDistance = entity_range( iPlayers[ i ], g_iZonesEnts[ j ] );
			
			if ( flDistance > flClosest )
			{
				continue;
			}
			
			flClosest = flDistance;
			iClosest = g_iZonesEnts[ j ];
		}
		
		if ( iClosest == -1 )
		{
			continue;
		}
			
		entity_get_vector( iClosest, EV_VEC_origin, flOrigin );
		entity_get_vector( iClosest, EV_VEC_mins, flMins );
		entity_get_vector( iClosest, EV_VEC_maxs, flMaxs );
		
		xs_vec_add( flOrigin, flMins, flMins );
		xs_vec_add( flOrigin, flMaxs, flMaxs );
		
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMins[ 1 ], flMins[ 2 ], flMins[ 0 ], flMaxs[ 1 ], flMins[ 2 ] );
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMins[ 1 ], flMins[ 2 ], flMaxs[ 0 ], flMins[ 1 ], flMins[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMaxs[ 1 ], flMins[ 2 ], flMaxs[ 0 ], flMins[ 1 ], flMins[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMaxs[ 1 ], flMins[ 2 ], flMins[ 0 ], flMaxs[ 1 ], flMins[ 2 ] );
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMins[ 1 ], flMaxs[ 2 ], flMins[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMins[ 1 ], flMaxs[ 2 ], flMaxs[ 0 ], flMins[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ], flMaxs[ 0 ], flMins[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ], flMins[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMins[ 1 ], flMins[ 2 ], flMins[ 0 ], flMins[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMins[ 0 ], flMaxs[ 1 ], flMins[ 2 ], flMins[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMins[ 1 ], flMins[ 2 ], flMaxs[ 0 ], flMins[ 1 ], flMaxs[ 2 ] );
		DrawLaser( iPlayers[ i ], flMaxs[ 0 ], flMaxs[ 1 ], flMins[ 2 ], flMaxs[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] );
	}
}

/* ===========================================================================
* 				[ Client Commands ]
* ============================================================================ */

public ClientCommand_Zones( iId )
{
	if ( ~get_user_flags( iId ) & ADMIN_LEVEL_E )
	{
		client_print_color( iId, print_team_default, "^4[%s]^1 No tienes accesos para utilizar esto.", g_szPrefix );
		
		return PLUGIN_HANDLED;
	}
	
	ShowZonesMenu( iId );
	
	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Client Menus ]
* ============================================================================ */

ShowZonesMenu( iId )
{
	new szData[ 384 ], iLen;
	
	iLen = formatex( szData, charsmax( szData ), "\yZonas^n^n" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[1] \wCambiar bombsite \y(Bombsite: %s)^n^n", ( g_iBombSite > 0 ) ? "B" : "A" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[2] \wEstablecer primer punto^n" );
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[3] \wEstablecer segundo punto^n^n" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[4] \wCrear zona^n" );
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[5] \wDibujar puntos^n^n" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[6] \wBorrar zona cercana^n" );
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[7] \wBorrar ultima zona^n^n" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[8] \w%s zonas^n^n", task_exists( TASK_SHOW_ZONES ) ? "Ocultar" : "Mostrar" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[9] \wGuardar^n^n" );
	
	iLen += formatex( szData[ iLen ], charsmax( szData ) - iLen, "\r[0] \yCancelar" );
	
	show_menu( iId, ZONES_KEYS, szData, _, "Zones Menu" );
	
	return PLUGIN_HANDLED;
}

public OnZonesMenuHandler( iId, iKey )
{
	if ( ( iKey > 8 ) || !is_user_connected( iId ) )
	{
		return PLUGIN_HANDLED;
	}
	
	ClientPlaySound( iId, "common/menu1.wav" );
	
	switch ( iKey )
	{
		case 0:
		{
			( g_iBombSite == 1 ) ?
				( g_iBombSite = 0 ) : ( g_iBombSite = 1 );
		}
		case 1:
		{
			new iOrigin[ 3 ];
			
			get_user_origin( iId, iOrigin, 3 );
			
			IVecFVec( iOrigin, g_flPointA );
		}
		case 2:
		{
			new iOrigin[ 3 ];
			
			get_user_origin( iId, iOrigin, 3 );
			
			IVecFVec( iOrigin, g_flPointB );
		}
		case 3:
		{
			if ( g_iZonesCount == MAX_ZONES )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 Llegaste al maximo de zonas creadas.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			if ( !( 16.0 <= vector_distance( g_flPointA, g_flPointB ) <= 2048.0 ) )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 Los puntos estan muy lejos o muy cerca.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			new Float:flOrigin[ 3 ];
			
			new Float:flMins[ 3 ];
			new Float:flMaxs[ 3 ];
			
			xs_vec_add( g_flPointA, g_flPointB, flOrigin );
			xs_vec_div_scalar( flOrigin, 2.0, flOrigin );
			
			for ( new i = 0 ; i < 3 ; i++ )
			{
				flMins[ i ] = floatabs( ( g_flPointA[ i ] - g_flPointB[ i ] ) / 2.0 ) * -1.0;
				flMaxs[ i ] = floatabs( ( g_flPointA[ i ] - g_flPointB[ i ] ) / 2.0 );
			}
			
			new iEnt = CreateZone( g_iBombSite, flOrigin, flMins, flMaxs );
			
			if ( is_valid_ent( iEnt ) )
			{
				g_iZonesEnts[ g_iZonesCount ] = iEnt;
				g_iZonesCount++;
				
				client_print_color( iId, print_team_default,"^4[%s]^1 La zona ha sido creada correctamente.", g_szPrefix );
			}
			else
			{
				client_print_color( iId, print_team_default,"^4[%s]^1 La zona no pudo ser creada.", g_szPrefix );
			}
		}
		case 4:
		{
			if ( !( 16.0 <= vector_distance( g_flPointA, g_flPointB ) <= 2048.0 ) )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 Los puntos estan muy lejos o muy cerca.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
			write_byte( TE_BOX );
			write_coord_f( g_flPointA[ 0 ] );
			write_coord_f( g_flPointA[ 1 ] );
			write_coord_f( g_flPointA[ 2 ] );
			write_coord_f( g_flPointB[ 0 ] );
			write_coord_f( g_flPointB[ 1 ] );
			write_coord_f( g_flPointB[ 2 ] );
			write_short( 50 );
			write_byte( 250 );
			write_byte( 0 );
			write_byte( 0 );
			message_end( );
		}
		case 5:
		{
			if ( g_iZonesCount == 0 )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 No hay ninguna zona para borrar.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			new Float:flDistance;
			new Float:flClosest = 9999.0;
			
			new iBombsite;
			new iClosest = -1;
			
			for ( new i = 0 ; i < g_iZonesCount ; i++ )
			{
				iBombsite = entity_get_int( g_iZonesEnts[ i ], EV_INT_iuser1 );
				
				if ( g_iBombSite != iBombsite )
				{
					continue;
				}
				
				flDistance = entity_range( iId, g_iZonesEnts[ i ] );
				
				if ( flDistance > flClosest )
				{
					continue;
				}
				
				flClosest = flDistance;
				iClosest = i;
			}
			
			if ( iClosest == -1 )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 No hay una zona cerca tuyo para borrar.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			if ( is_valid_ent( g_iZonesEnts[ iClosest ] ) )
			{
				remove_entity( g_iZonesEnts[ iClosest ] );
			}
			
			g_iZonesCount--;
			
			for ( new i = iClosest ; i < g_iZonesCount ; i++ )
			{
				g_iZonesEnts[ i ] = g_iZonesEnts[ i + 1 ];
			}
			
			g_iZonesEnts[ g_iZonesCount ] = 0;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 La zona fue borrada correctamente.", g_szPrefix );
		}
		case 6:
		{
			if ( g_iZonesCount == 0 )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 No hay ninguna zona para borrar.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			g_iZonesCount--;
			
			if ( is_valid_ent( g_iZonesEnts[ g_iZonesCount ] ) )
			{
				remove_entity( g_iZonesEnts[ g_iZonesCount ] );
			}
			
			g_iZonesEnts[ g_iZonesCount ] = 0;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 La zona fue borrada correctamente.", g_szPrefix );
		}
		case 7:
		{
			task_exists( TASK_SHOW_ZONES ) ?
				remove_task( TASK_SHOW_ZONES ) : set_task( 1.0, "OnTaskShowZones", TASK_SHOW_ZONES, .flags = "b" );
		}
		case 8:
		{
			if ( g_iZonesCount == 0 )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 No hay ninguna zona para guardar.", g_szPrefix );
				
				goto EndSwitch;
			}
			
			SaveZones( );
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Se guardaron las zonas correctamente.", g_szPrefix );
			client_print_color( iId, print_team_default, "^4[%s]^1 Cantidad de zonas guardadas:^4 %d^1.", g_szPrefix, g_iZonesCount );
		}
	}
	
	EndSwitch:
	
	ShowZonesMenu( iId );
	
	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Zone Modules ]
* ============================================================================ */

CreateZone( const iBombSite, const Float:flOrigin[ 3 ], const Float:flMins[ 3 ], const Float:flMaxs[ 3 ] )
{
	new iEnt = create_entity( g_szInfoTarget );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return 0;
	}
	
	entity_set_string( iEnt, EV_SZ_classname, g_szBlockZoneClass );
	
	entity_set_size( iEnt, flMins, flMaxs );
	entity_set_origin( iEnt, flOrigin );
	
	entity_set_int( iEnt, EV_INT_iuser1, iBombSite );
	entity_set_int( iEnt, EV_INT_solid, SOLID_NOT );
	entity_set_int( iEnt, EV_INT_movetype, MOVETYPE_FLY );
	
	return iEnt;
}

LoadZones( )
{
	new szMap[ 32 ];
	new szData[ 128 ];
	
	get_mapname( szMap, charsmax( szMap ) );
	get_localinfo( "amxx_datadir", szData, charsmax( szData ) );
	
	add( szData, charsmax( szData ), "/retake/zones" );
	formatex( g_szSaveFile, charsmax( g_szSaveFile ), "%s/%s.dat", szData, szMap );
	
	if ( !dir_exists( szData ) )
	{
		mkdir( szData );
		
		return;
	}
	
	if ( !file_exists( g_szSaveFile ) )
	{
		return;
	}
	
	new szVector[ 9 ][ 8 ];
	new szBombSite[ 4 ];
	
	new Float:flOrigin[ 3 ];
	
	new Float:flMins[ 3 ];
	new Float:flMaxs[ 3 ];
	
	new iBombSite;
	new iEnt;
	
	new iFile = fopen( g_szSaveFile, "rt" );
	
	while ( !feof( iFile ) )
	{
		fgets( iFile, szData, charsmax( szData ) );
		trim( szData );
		
		if ( strlen( szData ) < 4 )
		{
			continue;
		}
		
		parse( szData,
			szBombSite, charsmax( szBombSite ), szVector[ 0 ], charsmax( szVector[ ] ),
			szVector[ 1 ], charsmax( szVector[ ] ), szVector[ 2 ], charsmax( szVector[ ] ),
			szVector[ 3 ], charsmax( szVector[ ] ), szVector[ 4 ], charsmax( szVector[ ] ),
			szVector[ 5 ], charsmax( szVector[ ] ), szVector[ 6 ], charsmax( szVector[ ] ),
			szVector[ 7 ], charsmax( szVector[ ] ), szVector[ 8 ], charsmax( szVector[ ] ) );
		
		iBombSite = str_to_num( szBombSite );
		
		for ( new i = 0 ; i < 3 ; i++ )
		{
			flOrigin[ i ] 	= str_to_float( szVector[ i ] );
			
			flMins[ i ] 	= str_to_float( szVector[ i + 3 ] );
			flMaxs[ i ] 	= str_to_float( szVector[ i + 6 ] );
		}
		
		iEnt = CreateZone( iBombSite, flOrigin, flMins, flMaxs );
		
		if ( is_valid_ent( iEnt ) )
		{
			g_iZonesEnts[ g_iZonesCount ] = iEnt;
			g_iZonesCount++;
		}
	}
	
	fclose( iFile );
}

SaveZones( )
{
	new Float:flOrigin[ 3 ];
	
	new Float:flMins[ 3 ];
	new Float:flMaxs[ 3 ];
	
	new iBombSite;
	
	new iFile = fopen( g_szSaveFile, "wt" );
	
	for ( new i = 0 ; i < g_iZonesCount ; i++ )
	{
		if ( !is_valid_ent( g_iZonesEnts[ i ] ) )
		{
			continue;
		}
		
		entity_get_vector( g_iZonesEnts[ i ], EV_VEC_origin, flOrigin );
		
		entity_get_vector( g_iZonesEnts[ i ], EV_VEC_mins, flMins );
		entity_get_vector( g_iZonesEnts[ i ], EV_VEC_maxs, flMaxs );
		
		iBombSite = entity_get_int( g_iZonesEnts[ i ], EV_INT_iuser1 );
		
		fprintf( iFile, "%d %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f^n",
			iBombSite, flOrigin[ 0 ], flOrigin[ 1 ], flOrigin[ 2 ], flMins[ 0 ],
			flMins[ 1 ], flMins[ 2 ], flMaxs[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] );
	}
	
	fclose( iFile );
}

/* ===========================================================================
* 				[ Laser Modules ]
* ============================================================================ */

DrawLaser( const iId, Float:flStartX, Float:flStartY, Float:flStartZ, Float:flEndX, Float:flEndY, Float:flEndZ )
{
	message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = iId );
	write_byte( TE_BEAMPOINTS );
	write_coord_f( flStartX );
	write_coord_f( flStartY );
	write_coord_f( flStartZ );
	write_coord_f( flEndX );
	write_coord_f( flEndY );
	write_coord_f( flEndZ );
	write_short( g_iLaserBeam );
	write_byte( 0 );
	write_byte( 10 );
	write_byte( 11 );
	write_byte( 10 );
	write_byte( 0 );
	write_byte( 250 );
	write_byte( 200 );
	write_byte( 0 );
	write_byte( 200 );
	write_byte( 10 );
	message_end( );
}

CalculateLaserCorners( const Float:flOrigin[ 3 ], const Float:flSize[ 3 ], Float:flPoints[ 4 ][ 3 ] )
{
	if ( flSize[ 0 ] > flSize[ 1 ] )
	{
		flPoints[ 0 ][ 0 ] = ( flOrigin[ 0 ] + ( flSize[ 0 ] / 2.0 ) );
		flPoints[ 0 ][ 1 ] = flOrigin[ 1 ];
		flPoints[ 0 ][ 2 ] = ( flOrigin[ 2 ] + ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 1 ][ 0 ] = ( flOrigin[ 0 ] - ( flSize[ 0 ] / 2.0 ) );
		flPoints[ 1 ][ 1 ] = flOrigin[ 1 ];
		flPoints[ 1 ][ 2 ] = ( flOrigin[ 2 ] - ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 2 ][ 0 ] = ( flOrigin[ 0 ] - ( flSize[ 0 ] / 2.0 ) );
		flPoints[ 2 ][ 1 ] = flOrigin[ 1 ];
		flPoints[ 2 ][ 2 ] = ( flOrigin[ 2 ] + ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 3 ][ 0 ] = ( flOrigin[ 0 ] + ( flSize[ 0 ] / 2.0 ) );
		flPoints[ 3 ][ 1 ] = flOrigin[ 1 ];
		flPoints[ 3 ][ 2 ] = ( flOrigin[ 2 ] - ( flSize[ 2 ] / 2.0 ) );
	}
	else
	{
		flPoints[ 0 ][ 0 ] = flOrigin[ 0 ];
		flPoints[ 0 ][ 1 ] = ( flOrigin[ 1 ] + ( flSize[ 1 ] / 2.0 ) );
		flPoints[ 0 ][ 2 ] = ( flOrigin[ 2 ] + ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 1 ][ 0 ] = flOrigin[ 0 ];
		flPoints[ 1 ][ 1 ] = ( flOrigin[ 1 ] - ( flSize[ 1 ] / 2.0 ) );
		flPoints[ 1 ][ 2 ] = ( flOrigin[ 2 ] - ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 2 ][ 0 ] = flOrigin[ 0 ];
		flPoints[ 2 ][ 1 ] = ( flOrigin[ 1 ] - ( flSize[ 1 ] / 2.0 ) );
		flPoints[ 2 ][ 2 ] = ( flOrigin[ 2 ] + ( flSize[ 2 ] / 2.0 ) );
		
		flPoints[ 3 ][ 0 ] = flOrigin[ 0 ];
		flPoints[ 3 ][ 1 ] = ( flOrigin[ 1 ] + ( flSize[ 1 ] / 2.0 ) );
		flPoints[ 3 ][ 2 ] = ( flOrigin[ 2 ] - ( flSize[ 2 ] / 2.0 ) );
	}
}