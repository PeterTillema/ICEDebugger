#include "ti84pce.inc"

start:
	.db	083h
	.db	07Fh				; Signify start of ICE Debugger
	ret
	
; Here we actually start; the ICE program should just check for these 3 bytes to make sure the debugger is loaded
	ret