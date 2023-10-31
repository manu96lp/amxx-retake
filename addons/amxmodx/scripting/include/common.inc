#if defined _common_included
	#endinput
#endif

#define _common_included

/* =================================================================================
* 				[ Consts ]
* ================================================================================= */

#define FFADE_IN				0x0000	// Nothing
#define FFADE_OUT				0x0001	// Fade out (not in)
#define FFADE_MODULATE			0x0002	// Modulate (don't blend)
#define FFADE_STAYOUT			0x0004	// Ignores the duration

#define SCORE_ATTRIB_DEAD 		( 1<<0 )
#define SCORE_ATTRIB_BOMB 		( 1<<1 )
#define SCORE_ATTRIB_VIP 		( 1<<2 )

#define MAX_ENTITIES 			2048

#define PLAYER_ARRAY 			( MAX_PLAYERS + 1 )

/* =================================================================================
* 				[ Macros ]
* ================================================================================= */

#define IsPlayer(%0) 			( 1 <= %0 <= MaxClients )

#define GetPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )
#define SwitchPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 ^= ( 1 << ( %1 & 31 ) ) ) )

#define GetArrayBit(%0,%1) 		( ( %0[ %1 / 32 ] & ( 1 << ( %1 % 32 ) ) ) != 0 )
#define SetArrayBit(%0,%1) 		( %0[ %1 / 32 ] |= ( 1 << ( %1 % 32 ) ) )
#define ClearArrayBit(%0,%1) 	( %0[ %1 / 32 ] &= ~( 1 << ( %1 % 32 ) ) )

#define GetSimpleBit(%0,%1) 	( ( %0 & ( 1 << ( %1 % 32 ) ) ) != 0 )
#define SetSimpleBit(%0,%1) 	( %0 |= ( 1 << ( %1 % 32 ) ) )
#define ClearSimpleBit(%0,%1) 	( %0 &= ~( 1 << ( %1 % 32 ) ) )

#define IsVectorNull(%0) 		( ( %0[ 0 ] == 0.0 ) && ( %0[ 1 ] == 0.0 ) && ( %0[ 2 ] == 0.0 ) )

#define IsDigit(%0) 			( 48 <= %0 <= 57 )
#define IsLetter(%0) 			( ( 65 <= %0 <= 90 ) || ( 97 <= %0 <= 122 ) )

/* =================================================================================
* 				[ Stocks: Misc ]
* ================================================================================= */

stock ShowGlobalSprite( const iId, const Float:flOrigin[ 3 ], const iSprite, const Float:flScale = 1.0 )
{
	static Float:flPlayerOrigin[ 3 ];
	static Float:flViewOfs[ 3 ];
	
	static Float:flBuffer[ 3 ];
	static Float:flDifference[ 3 ];
	
	static Float:flDistanceToPoint;
	static Float:flDistanceToOrigin;
	
	static iScale;
	
	entity_get_vector( iId, EV_VEC_origin, flPlayerOrigin );
	entity_get_vector( iId, EV_VEC_view_ofs, flViewOfs );
	
	xs_vec_add( flPlayerOrigin, flViewOfs, flPlayerOrigin );
	
	if ( vector_distance( flPlayerOrigin, flOrigin ) > 4096.0 )
	{
		return false;
	}
	
	new iTrace = create_tr2( );
	
	engfunc( EngFunc_TraceLine, flPlayerOrigin, flOrigin, IGNORE_MONSTERS, iId, iTrace );
	
	get_tr2( iTrace, TR_vecEndPos, flBuffer );
	free_tr2( iTrace );
	
	flDistanceToPoint = vector_distance( flPlayerOrigin, flBuffer ) - 10.0;
	flDistanceToOrigin = vector_distance( flPlayerOrigin, flOrigin );
	
	xs_vec_sub( flOrigin, flPlayerOrigin, flDifference );
	
	xs_vec_normalize( flDifference, flDifference );
	xs_vec_mul_scalar( flDifference, flDistanceToPoint, flDifference );
	
	xs_vec_add( flPlayerOrigin, flDifference, flBuffer );
	
	iScale = floatround( 2.0 * floatmax( ( flDistanceToPoint / flDistanceToOrigin ), 0.25 ) * flScale );
	
	message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = iId );
	write_byte( TE_SPRITE );
	write_coord_f( flBuffer[ 0 ] );
	write_coord_f( flBuffer[ 1 ] );
	write_coord_f( flBuffer[ 2 ] );
	write_short( iSprite );
	write_byte( iScale );
	write_byte( 255 );
	message_end( );
	
	return true;
}

stock CreateExplosion( const iFrom = 0, const Float:flVec[ 3 ] = { 0.0, 0.0, 0.0 }, const iMagnitude = 100, const iFlags = 0 )
{
	new iEnt = create_entity( "env_explosion" );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return 0
	}
	
	new Float:flOrigin[ 3 ];
	
	( iFrom > 0 ) ?
		entity_get_vector( iFrom, EV_VEC_origin, flOrigin ) : xs_vec_copy( flVec, flOrigin );
	
	entity_set_origin( iEnt, flOrigin );
	entity_set_int( iEnt, EV_INT_spawnflags, iFlags );
	
	DispatchKeyValue( iEnt, "iMagnitude", fmt( "%3d", iMagnitude ) );
	DispatchSpawn( iEnt );
	
	force_use( iEnt, iEnt );
	
	return iEnt;
}

stock RemoveEntityByOwner( const iId, const szClassname[ ] )
{
	new iEnt;
	
	while ( ( iEnt = find_ent_by_owner( iEnt, szClassname, iId ) ) > 0 )
	{
		remove_entity( iEnt );
	}
}

stock RemoveEntityByClass( const szClassname[ ] )
{
	new iEnt;
	
	while ( ( iEnt = find_ent_by_class( iEnt, szClassname ) ) > 0 )
	{
		remove_entity( iEnt );
	}
}

stock Swap( &iFirst, &iSecond )
{
	new iSwap = iFirst;
	
	iFirst = iSecond;
	iSecond = iSwap;
}

stock ArraySum( iArray[ ], const iSize )
{
	new iSum;
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iSum = ( iSum + iArray[ i ] );
	}
	
	return iSum;
}

stock ArraySet( iArray[ ], iSize, iValue )
{
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iArray[ i ] = iValue;
	}
}

stock ArrayClearRange( Array:aArray, iFrom, iTo )
{
	if ( aArray == Invalid_Array )
	{
		return;
	}

	new iSize = ArraySize( aArray );
	new iMinTo = min( iSize, iTo );

	for ( new i = iFrom ; i < iMinTo ; i++ )
	{
		ArrayDeleteItem( aArray, iFrom );
	}
}

stock GetBitCount( const iValue )
{
	new iCount = 0;
	
	for ( new i = 0 ; i < 32 ; i++ )
	{
		if ( iValue & ( 1 << i ) )
		{
			iCount++;
		}
	}
	
	return iCount;
}

stock GetArrayBitCount( const iArray[ ], const iSize )
{
	new iCount = 0;
	
	for ( new i = 0, j = 0 ; i < iSize ; i++ )
	{
		for ( j = 0 ; j < 32 ; j++ )
		{
			if ( iArray[ i ] & ( 1<<j ) )
			{
				iCount++;
			}
		}
	}
	
	return iCount;
}

stock GetPlayerWeapons( const iId, iWeapons[ 32 ], &iNum )
{
	new iEnt = 0;
	new iCount = 0;
	
	for ( new i = CS_WEAPONSLOT_PRIMARY ; i <= CS_WEAPONSLOT_C4 ; i++ )
	{
		iEnt = get_member( iId, m_rgpPlayerItems, i );
	
		while ( iEnt > 0 )
		{
			iWeapons[ iCount++ ] = iEnt;
			
			iEnt = get_member( iEnt, m_pNext );
		}
	}
	
	iNum = iCount;
}

stock FillVector( Float:flVec[ 3 ], Float:flCoordX, Float:flCoordY, Float:flCoordZ )
{
	flVec[ 0 ] = flCoordX;
	flVec[ 1 ] = flCoordY;
	flVec[ 2 ] = flCoordZ;
}

stock bool:IsBoxFree( const Float:flOrigin[ 3 ], const Float:flSide )
{
	new Float:flVec[ 3 ];

	new Float:flMins[ 3 ];
	new Float:flMaxs[ 3 ];

	for ( new i = 0 ; i < 3 ; i++ )
	{
		flMins[ i ] = flOrigin[ i ] - flSide;
		flMaxs[ i ] = flOrigin[ i ] + flSide;
	}

	new iPointContents = 0;

	FillVector( flVec, flMins[ 0 ], flMins[ 1 ], flMins[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMins[ 0 ], flMaxs[ 1 ], flMins[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMaxs[ 0 ], flMins[ 1 ], flMins[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMaxs[ 0 ], flMaxs[ 1 ], flMins[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMins[ 0 ], flMins[ 1 ], flMaxs[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMins[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMaxs[ 0 ], flMins[ 1 ], flMaxs[ 2 ] ); iPointContents += point_contents( flVec );
	FillVector( flVec, flMaxs[ 0 ], flMaxs[ 1 ], flMaxs[ 2 ] ); iPointContents += point_contents( flVec );

	return ( iPointContents == -8 );
}

stock GetElapsedTime( const iSeconds, szData[ ], const iSize )
{
	new iMinutes = ( iSeconds / 60 );
	new iHours = ( iMinutes / 60 );
	new iDays = ( iHours / 24 );
	
	new iLen = 0;
	
	if ( iDays > 0 ) { iLen += formatex( szData[ iLen ], iSize - iLen, "%d dia%s, ", iDays, ( iDays != 1 ) ? "s" : "" ); }
	if ( iHours > 0 ) { iLen += formatex( szData[ iLen ], iSize - iLen, "%d hora%s, ", ( iHours % 24 ), ( ( iHours % 24 ) != 1 ) ? "s" : "" ); }
	
	( iMinutes > 0 ) ?
		formatex( szData[ iLen ], iSize - iLen, "%d minuto%s", ( iMinutes % 60 ), ( ( iMinutes % 60 ) != 1 ) ? "s" : "" ) :
		formatex( szData[ iLen ], iSize - iLen, "%d segundo%s", iSeconds, ( iSeconds != 1 ) ? "s" : "" );
	
	return iLen;
}
 
stock IsSpaceOrEmpty( szString[ ] )
{
	new iLen = strlen( szString );
	
	for ( new i = 0 ; i < iLen ; i++ )
	{
		if ( !isspace( szString[ i ] ) )
		{
			return false;
		}
	}
	
	return true;
}

stock PrecachePlayerModel( const szModel[ ], const bool:bGeneric = false )
{
	new szPath[ 128 ];
	new iLen;
	
	iLen = formatex( szPath, charsmax( szPath ), "models/player/%s/%s.mdl", szModel, szModel );
	
	bGeneric ?
		precache_generic( szPath ) : precache_model( szPath );
	
	formatex( szPath[ iLen - 4 ], charsmax( szPath ) - iLen, "T.mdl" );
	
	if ( file_exists( szPath ) )
	{
		bGeneric ?
			precache_generic( szPath ) : precache_model( szPath );
	}
}

stock ClientPlaySound( const iId, const szSound[ ] )
{
	client_cmd( iId, "%s ^"%s^"", ( szSound[ strlen( szSound ) - 1 ] == '3' ) ? "mp3 play" : "spk", szSound );
}

stock ClientStopSound( const iId )
{
	client_cmd( iId, "mp3 stop; stopsound" );
}

stock ReadFlagsFromCvar( const pCvar )
{
	new szFlags[ 8 ];
	
	get_pcvar_string( pCvar, szFlags, charsmax( szFlags ) );
	
	if ( ( strlen( szFlags ) == 0 ) || ( szFlags[ 0 ] == '0' ) )
	{
		return 0;
	}
	
	return read_flags( szFlags );
}

stock GetAimOrigin( const iId, Float:flAimOrigin[ 3 ], const Float:flDistance = 128.0 )
{
	new Float:flOrigin[ 3 ];
	new Float:flOther[ 3 ];
	
	get_entvar( iId, var_origin, flOrigin );
	get_entvar( iId, var_view_ofs, flOther );
	
	xs_vec_add( flOrigin, flOther, flOrigin );
	
	get_entvar( iId, var_v_angle, flOther );
	
	angle_vector( flOther, ANGLEVECTOR_FORWARD, flOther );
	
	xs_vec_mul_scalar( flOther, flDistance, flOther );
	xs_vec_add( flOrigin, flOther, flOther );
	
	trace_line( iId, flOrigin, flOther, flAimOrigin );
}

stock bool:ParseHexColor( const szInput[ ], iColor[ 3 ] )
{
	new iLen = strlen( szInput );

	if ( ( iLen < 4 ) || ( iLen > 7 ) )
	{
		return false;
	}

	new szBuffer[ 8 ];

	for ( new i = 1 ; i < 7 ; i++ )
	{
		szBuffer[ i - 1 ] = ( i < iLen ) ? szInput[ i ] : szInput[ iLen - 1 ];
	}

	new szHex[ 4 ];
	new iValues[ 3 ];

	for ( new i = 0 ; i < 3 ; i++ )
	{
		szHex[ 0 ] = szBuffer[ ( i * 2 ) ];
		szHex[ 1 ] = szBuffer[ ( i * 2 ) + 1 ];
		szHex[ 2 ] = EOS;

		iValues[ i ] = HexToDecimal( szHex );

		if ( iValues[ i ] == -1 )
		{
			return false;
		}
	}

	for ( new i = 0 ; i < 3 ; i++ )
	{
		iColor[ i ] = iValues[ i ];
	}

	return true;
}

stock HexToDecimal( const szHex[ ] )
{
	new iLen = strlen( szHex );
	new iValue = 0;

	for ( new i = 0 ; i < iLen ; i++ )
	{
		if ( IsDigit( szHex[ i ] ) )
		{
			iValue += ( power( 16, ( iLen - i - 1 ) ) * ( szHex[ i ] - 48 ) );
		}
		else
		{
			if ( !IsLetter( szHex[ i ] ) )
			{
				return -1;
			}

			iValue += ( power( 16, ( iLen - i - 1 ) ) * ( szHex[ i ] - ( ( szHex[ i ] < 97 ) ? 55 : 87 ) ) );
		}
	}

	return iValue;
}

stock ClientPrintFix( const iId, const iType, const szMessage[ ], any:... )
{
	if ( ( iId > 0 ) && !is_user_connected( iId ) )
	{
		return;
	}
	
	static iTextMsg;
	
	if ( !iTextMsg )
	{
		iTextMsg = get_user_msgid( "TextMsg" );
	}
	
	static iPlayers[ MAX_PLAYERS ];
	static iPlayersCount;
	
	static szBuffer[ 191 ];
	
	static iLen;
	static iUser;
	
	( numargs( ) < 4 ) ?
		( iLen = copy( szBuffer, charsmax( szBuffer ), szMessage ) ) :
		( iLen = vformat( szBuffer, charsmax( szBuffer ), szMessage, 4 ) );
	
	iLen = min( iLen, ( sizeof( szBuffer ) - 2 ) );
	
	if ( iId > 0 )
	{
		iPlayersCount = 1;
		iPlayers[ 0 ] = iId;
	}
	else
	{
		iPlayersCount = 0;
		
		get_players( iPlayers, iPlayersCount, "ch" );
	}
	
	while ( --iPlayersCount >= 0 )
	{
		iUser = iPlayers[ iPlayersCount ];
		
		if ( REU_GetProtocol( iUser ) != 47 )
		{
			szBuffer[ iLen ] = EOS;
			
			client_print( iUser, iType, szBuffer );
		}
		else
		{
			szBuffer[ iLen ] = '^n';
			szBuffer[ iLen + 1 ] = EOS;
			
			message_begin( MSG_ONE, iTextMsg, .player = iUser );
			write_byte( iType );
			write_string( szBuffer );
			message_end( );
		}
	}
}

stock GetGreetingsByTime( szBuffer[ ], const iSize )
{
	static const szGreetings[ ][ ] =
	{
		"Buenos dias",
		"Buenas tardes",
		"Buenas noches"
	};

	new szTime[ 4 ];

	get_time( "%H", szTime, charsmax( szTime ) );

	new iHour = str_to_num( szTime );
	new iMessage = ( iHour > 5 && iHour < 19 ) ? ( iHour < 12 ) ? 0 : 1 : 2;

	copy( szBuffer, iSize, szGreetings[ iMessage ] );
}

/* =================================================================================
* 				[ Stocks: Messages ]
* ================================================================================= */

stock SendImplosion( const iId, const Float:flOrigin[ 3 ], const iRadius, const iCount, const iLife )
{
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY ) :
		message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, iId );
	
	write_byte( TE_IMPLOSION );
	write_coord_f( flOrigin[ 0 ] );
	write_coord_f( flOrigin[ 1 ] );
	write_coord_f( flOrigin[ 2 ] );
	write_byte( iRadius );
	write_byte( iCount );
	write_byte( iLife );
	message_end( );
}

stock SendLightStyle( const iId, const iStyle, const szPattern[ ] )
{
	( iId == 0 ) ?
		message_begin( MSG_ALL, SVC_LIGHTSTYLE ) :
		message_begin( MSG_ONE, SVC_LIGHTSTYLE, _, iId );
	
	write_byte( iStyle );
	write_string( szPattern );
	message_end( );
}

stock SendFog( const iPlayer, const iRGB[ 3 ], const iDensity )
{
	static iFog;
	
	if ( !iFog )
	{
		iFog = get_user_msgid( "Fog" );
	}
	
	static const iFogDensity[ ][ ] =
	{
		{ 0, 0, 0, 0 },
		{ 111, 18, 3, 58 },
		{ 111, 18, 125, 58 },
		{ 66, 96, 27, 59 },
		{ 90, 101, 60, 59 },
		{ 90, 101, 68, 59 },
		{ 10, 41, 95, 59 },
		{ 111, 18, 125, 59 },
		{ 111, 18, 3, 60 },
		{ 68, 116, 19, 60 }
	};
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iFog ) :
		message_begin( MSG_ONE, iFog, _, iId );
	
	write_byte( iRGB[ 0 ] );
	write_byte( iRGB[ 1 ] );
	write_byte( iRGB[ 2 ] );
	write_byte( iFogDensity[ iDensity ][ 0 ] );
	write_byte( iFogDensity[ iDensity ][ 1 ] );
	write_byte( iFogDensity[ iDensity ][ 2 ] );
	write_byte( iFogDensity[ iDensity ][ 3 ] );
	message_end( );
}

stock SendScreenFade( const iId, const iRGB[ 3 ], const iDuration, const iHoldTime, const iFlag, const iAlpha )
{
	static iScreenFade;
	
	if ( !iScreenFade )
	{
		iScreenFade = get_user_msgid( "ScreenFade" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, iScreenFade ) :
		message_begin( MSG_ONE_UNRELIABLE, iScreenFade, _, iId );
	
	write_short( ( 1<<12 ) * iDuration );
	write_short( ( 1<<12 ) * iHoldTime );
	write_short( iFlag );
	write_byte( iRGB[ 0 ] );
	write_byte( iRGB[ 1 ] );
	write_byte( iRGB[ 2 ] );
	write_byte( iAlpha );
	message_end( );
}

stock SendScreenShake( const iId, const iAmplitude, const iDuration, const iFrequency )
{
	static iScreenShake;
	
	if ( !iScreenShake )
	{
		iScreenShake = get_user_msgid( "ScreenShake" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, iScreenShake ) :
		message_begin( MSG_ONE_UNRELIABLE, iScreenShake, _, iId );
		
	write_short( ( 1<<12 ) * iAmplitude );
	write_short( ( 1<<12 ) * iDuration );
	write_short( ( 1<<12 ) * iFrequency );
	message_end( );
}

stock SendTeamInfo( const iId, const iPlayer, const iTeam )
{
	static iTeamInfo;
	
	if ( !iTeamInfo )
	{
		iTeamInfo = get_user_msgid( "TeamInfo" );
	}
	
	static const szTeams[ ][ ] = { "UNASSIGNED", "TERRORIST", "CT", "SPECTATOR" };
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iTeamInfo ) :
		message_begin( MSG_ONE, iTeamInfo, .player = iId );
	
	write_byte( iPlayer );
	write_string( szTeams[ iTeam ] );
	message_end( );
}

stock SendScoreAttrib( const iId, const iPlayer, const iFlags )
{
	static iScoreAttrib;
	
	if ( !iScoreAttrib )
	{
		iScoreAttrib = get_user_msgid( "ScoreAttrib" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iScoreAttrib ) :
		message_begin( MSG_ONE, iScoreAttrib, .player = iId );
	
	write_byte( iPlayer );
	write_byte( iFlags );
	message_end( );
}

stock SendScoreInfo( const iId, const iPlayer, const iScore, const iDeaths, const iTeam )
{
	static iScoreInfo;
	
	if ( !iScoreInfo )
	{
		iScoreInfo = get_user_msgid( "ScoreInfo" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iScoreInfo ) :
		message_begin( MSG_ONE, iScoreInfo, .player = iId );
	
	write_byte( iPlayer );
	write_short( iScore );
	write_short( iDeaths );
	write_short( 0 );
	write_short( iTeam );
	message_end( );
}

stock SendRoundTime( const iId, const iTime )
{
	static iRoundTime;
	
	if ( !iRoundTime )
	{
		iRoundTime = get_user_msgid( "RoundTime" );
	}

	( iId == 0 ) ?
		message_begin( MSG_ALL, iRoundTime ) :
		message_begin( MSG_ONE, iRoundTime, .player = iId );
	
	write_short( iTime );
	message_end( );
}

stock SendStatusIcon( const iId, const iDraw, const szIcon[ ], const iRGB[ 3 ] )
{
	static iStatusIcon;
	
	if ( !iStatusIcon )
	{
		iStatusIcon = get_user_msgid( "StatusIcon" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iStatusIcon ) :
		message_begin( MSG_ONE, iStatusIcon, .player = iId );
	
	write_byte( iDraw );
	write_string( szIcon );
	
	if ( iDraw )
	{
		write_byte( iRGB[ 0 ] );
		write_byte( iRGB[ 1 ] );
		write_byte( iRGB[ 2 ] );
	}
	
	message_end( );
}

stock SendDeathMsg( const iId, const iKiller, const iVictim, const iHeadshot, const szWeapon[ ] )
{
	static iDeathMsg;
	
	if ( !iDeathMsg )
	{
		iDeathMsg = get_user_msgid( "DeathMsg" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_ALL, iDeathMsg ) :
		message_begin( MSG_ONE, iDeathMsg, .player = iId );
	
	write_byte( iKiller );
	write_byte( iVictim );
	write_byte( iHeadshot );
	write_string( szWeapon );
	
	message_end( );
}

stock SendPlayerAttachment( const iId, const iPlayer, const iSprite, const iOffset = 45, const iLife = 30 )
{
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY ) :
		message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, iId );
	
	write_byte( TE_PLAYERATTACHMENT );
	write_byte( iPlayer );
	write_coord( iOffset );
	write_short( iSprite );
	write_short( iLife );
	message_end( );
}

stock SendKillAttachments( const iId, const iPlayer )
{
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY ) :
		message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, iId );
	
	write_byte( TE_KILLPLAYERATTACHMENTS );
	write_byte( iPlayer );
	message_end( );
}

stock SendMoney( const iId, const iAmount, const iFlags )
{
	static iMoney;
	
	if ( !iMoney )
	{
		iMoney = get_user_msgid( "Money" );
	}
	
	message_begin( MSG_ONE_UNRELIABLE, iMoney, _, iId );
	write_long( iAmount );
	write_byte( iFlags );
	message_end( );
}

stock SendWeaponList( const iId, const szWeapon[ ], const iPrimaryAmmo = -1, const iMaxPrimaryAmmo = -1, const iSecondaryAmmo = -1, const iMaxSecondaryAmmo = -1, const iSlot = 0, const iNumberInSlot = 0, const iWeapon = 0, const iFlags = 0 ) 
{
	static iWeaponList;
	
	if ( !iWeaponList )
	{
		iWeaponList = get_user_msgid( "WeaponList" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, iWeaponList ) :
		message_begin( MSG_ONE_UNRELIABLE, iWeaponList, _, iId );
	
	write_string( szWeapon );
	write_byte( iPrimaryAmmo );
	write_byte( iMaxPrimaryAmmo );
	write_byte( iSecondaryAmmo );
	write_byte( iMaxSecondaryAmmo );
	write_byte( iSlot );
	write_byte( iNumberInSlot );
	write_byte( iWeapon );
	write_byte( iFlags );
	message_end( );
}

stock SendCurWeapon( const iId, const iActive, const iWeapon, const iAmmo ) 
{
	static iCurWeapon;
	
	if ( !iCurWeapon )
	{
		iCurWeapon = get_user_msgid( "CurWeapon" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, iCurWeapon ) :
		message_begin( MSG_ONE_UNRELIABLE, iCurWeapon, _, iId );
	
	write_byte( iActive );
	write_byte( iWeapon );
	write_byte( iAmmo );
	message_end( );
}

stock SendSetFOV( const iId, const iDegrees )
{
	static iSetFOV;
	
	if ( !iSetFOV )
	{
		iSetFOV = get_user_msgid( "SetFOV" );
	}
	
	( iId == 0 ) ?
		message_begin( MSG_BROADCAST, iSetFOV ) :
		message_begin( MSG_ONE_UNRELIABLE, iSetFOV, _, iId );
	
	write_byte( iDegrees );
	message_end( );
}