#include "ti84pce.inc"

start:
	.db	083h
	cp	a, a				; Signify start of ICE Debugger
	ret
	
; Here we actually start; the ICE program can check for these 3 bytes to make sure the debugger is loaded
	push	af
	push	bc
	push	de
	push	hl
	ld	a, (mpLcdCtrl)
	push	af
	ld	hl, (mpLcdLpbase)
	push	hl
	push	ix
	ld	ix, 0
	add	ix, sp
	
	; main code
	
	ld	sp, ix
	pop	ix
	pop	hl
	ld	(mpLcdLpbase), hl
	pop	af
	ld	(mpLcdCtrl), a
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret