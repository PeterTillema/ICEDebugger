#include "ti84pce.inc"

#define PROG_SIZE      0
#define PROG_START     3
#define DBG_PROG_SIZE  6
#define DBG_PROG_START 9

start:
	.db	083h
	cp	a, a				; Signify start of ICE Debugger
	ret
	
; Here we actually start; the ICE program can check for these 3 bytes to make sure the debugger is loaded
	jr	GotoDebugger

; DE = compiled program name, store it
	ld	iy, cursorImage
	ex	de, hl				; Input is DBG file
	call	_Mov9ToOP1
	call	_ChkFindSym			; Find program, must exists
	jr	c, Return
	ld	bc, 0
	ex	de, hl				; Get size
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	(iy + DBG_PROG_SIZE), bc	; Store size + pointers
	ld	(iy + DBG_PROG_START), hl	; HL points to the source program now
	dec	hl
	call	_Mov9ToOP1
	ld	a, ProgObj
	ld	(OP1), a
	call	_ChkFindSym			; Find debug program, must exists
	jr	c, Return
	ld	bc, 0
	ex	de, hl				; Get size
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	(iy + PROG_SIZE), bc		; Store pointers
	ld	(iy + PROG_START), hl
Return:
	sbc	hl, hl
	inc	hl
	ld	iy, flags
	ret

GotoDebugger:
; Backup registers and variables
; DE = current line in input program

	push	af
	push	bc
	push	de
	push	hl
	push	iy
	ld	hl, (mpLcdCtrl)
	push	hl
	ld	hl, (mpLcdUpbase)
	push	hl
	push	ix
	ld	ix, 0
	add	ix, sp
	
	push	de
	ld	iy, cursorImage
	di
	ld	a, lcdBpp1
	ld	hl, mpLcdCtrl
	ld	(hl), a
	inc	hl
	set	lcdBigEndianPixels >> 8, (hl)
	ld	hl, usbArea
	ld	(mpLcdUpbase), hl
	ld	(hl), 255
	push	hl
	pop	de
	inc	de
	ld	bc, 320 * 240 / 8 - 1
	ldir

; Backup first 2 palette entries
	ld	hl, mpLcdPalette
	ld	de, cursorImage
	ld	c, 4
	ldir
	dec	c
	dec	hl
	ld	(hl), c
	dec	hl
	ld	(hl), c
	dec	hl
	ld	(hl), b
	dec	hl
	ld	(hl), b
	pop	de
	
; Main code
	
; Restore palette, variables and registers
	ld	de, mpLcdPalette
	ld	hl, cursorImage
	ld	bc, 4
	ldir
	ld	sp, ix
	pop	ix
	pop	hl
	ld	(mpLcdUpbase), hl
	pop	hl
	ld	(mpLcdCtrl), hl
	pop	iy
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret