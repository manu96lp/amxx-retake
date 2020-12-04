#if defined _retake_included
  #endinput
#endif
#define _retake_included

enum _:Round_Status
{
	ROUND_ENDED,
	ROUND_FROZEN,
	ROUND_STARTED
}

/*
 * Se llama al producirse un evento de ronda (inicio, fin, etc.)
 */
forward re_round_event( iRoundStatus, iBombSite );