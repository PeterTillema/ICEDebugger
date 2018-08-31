#include "ti84pce.inc"

#define VARIABLES cursorImage
#define PROG_SIZE              0
#define PROG_START             3
#define DBG_PROG_SIZE          6
#define DBG_PROG_START         9
#define PALETTE_ENTRIES_BACKUP 12
#define INPUT_LINE             16
#define X_POS                  19
#define Y_POS                  20
#define TEMP                   21

#define SCREEN_START (usbArea & 0FFFFF8h) + 8	; Note: mask to 8 bytes!

start:
	.db	083h
	cp	a, a				; Signify start of ICE Debugger
	ret
	
; Here we actually start; the ICE program can check for these 3 bytes to make sure the debugger is loaded
; DE = compiled program name
	ld	iy, VARIABLES
	ex	de, hl				; Input is DBG file
	call	_Mov9ToOP1
	call	_ChkFindSym			; Find program, must exists
	jr	c, Return
	ex	de, hl				; Get size
	inc	hl
	inc	hl
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
	ld	iy, flags
	ld	hl, (windowHookPtr)		; Copy to safeRAM
	ld	de, DebuggerCode1
	add	hl, de
	ld	de, DebuggerCode2
	ld	bc, DebuggerCodeEnd - DebuggerCode2
	ldir
Return:
	sbc	hl, hl
	inc	hl
	ret

DebuggerCode1:
.org saveSScreen + 21945 - 260 - 2000		; See src/main.h
DebuggerCode2:
; Backup registers and variables
; DE = current line in input program

	di
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
	
	ld	iy, VARIABLES
	ld	ix, 0D13F56h			; See src/main.h
	ld	(iy + INPUT_LINE), de
	di
	ld	a, lcdBpp1
	ld	hl, mpLcdCtrl
	ld	(hl), a
	inc	hl
	set	2, (hl)
	ld	hl, SCREEN_START
	ld	(mpLcdUpbase), hl
	ld	hl, mpLcdPalette
	lea	de, iy + PALETTE_ENTRIES_BACKUP
	ld	c, 4
	ldir
	dec	c
	dec	hl
	ld	(hl), b
	dec	hl
	ld	(hl), b
	dec	hl
	ld	(hl), c
	dec	hl
	ld	(hl), c
	
MainMenu:
	call	ClearScreen
	ld	c, 0
	ld	b, 7
	ld	d, b
	ld	hl, StepThroughCodeString
	
PrintOptionsLoop:
	push	bc
	ld	a, c
	add	a, a
	add	a, a
	add	a, a
	add	a, c
	inc	a
	ld	(iy + X_POS), 1
	ld	(iy + Y_POS), a
	call	PrintString
	pop	bc
	inc	c
	djnz	PrintOptionsLoop
	call	SelectOption
	jr	z, Quit

SelectEntry:
	ld	a, e
	call	ClearScreen
	or	a, a
	jr	z, StepCode
	dec	a
	jp	z, ViewVariables
	dec	a
	jp	z, ViewMemory
	dec	a
	jp	z, ViewScreen
	dec	a
	jp	z, ViewBuffer
	dec	a
	jp	z, JumpLabel
	
Quit:
; Restore palette, usb area, variables and registers
	ld	de, mpLcdPalette
	lea	hl, iy + PALETTE_ENTRIES_BACKUP
	ld	bc, 4
	ldir
	ld	hl, usbArea
	ld	(hl), 0
	push	hl
	pop	de
	inc	de
	ld	bc, 14305
	ldir
	
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
	
StepCode:
	jp	Quit
	
ViewVariables:
	ld	hl, (iy + DBG_PROG_START) 
	xor	a, a
	cpir
	ld	b, (hl)				; Amount of variables
	inc	hl
	inc	b
	dec	b
	jr	z, NoVariablesFound1
	ld	c, 0
PrintVariableLoop:
	ld	a, c
	add	a, a
	add	a, a
	add	a, a
	add	a, c
	inc	a
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 0
	call	PrintString
	ld	(iy + X_POS), 23
	push	hl
	ld	a, c
	add	a, a
	add	a, c
	sub	a, 080h
	ld	(VariableOffset), a
VariableOffset = $+2
	ld	hl, (ix + 0)
	call	ToString
	call	PrintString
	pop	hl
	inc	c
	djnz	PrintVariableLoop
NoVariablesFound1:
	call	GetKeyAnyFast
	jp	MainMenu
	
ViewMemory:
	jp	Quit
	
ViewScreen:

ViewBuffer:
	jp	Quit
	
JumpLabel:
	ld	hl, (iy + DBG_PROG_START)
	xor	a, a
	cpir
	ld	b, (hl)				; Amount of variables
	inc	hl
	inc	b
	dec	b
	jr	z, NoVariablesFound2
SkipVariableLoop:
	ld	c, 255				; Prevent decrementing B; a variable name won't be longer than 255 bytes
	cpir
	djnz	SkipVariableLoop
NoVariablesFound2:
	ld	de, (hl)			; Amount of lines
	inc	hl
	inc	hl
	inc	hl
	add	hl, de				; Skip line lengths
	add	hl, de
	inc	hl				; Skip ending byte $FF
	ld	b, (hl)				; Amount of labels
	ld	d, b				; Amount of labels
	inc	hl
	ld	(iy + TEMP), hl			; Save pointer to recall later
	inc	b
	dec	b
	jr	z, NoLabelsFound
	ld	c, 0
GetLabelsLoop:
	ld	a, c
	add	a, a
	add	a, a
	add	a, a
	add	a, c
	inc	a
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 1
	call	PrintString
	inc	hl				; Skip label address
	inc	hl
	inc	hl
	inc	c
	djnz	GetLabelsLoop
	call	SelectOption
	jp	z, MainMenu
	ld	hl, (iy + TEMP)
	xor	a, a
	ld	c, a
	ld	b, a
	inc	e
	dec	e
	jr	z, GetLabelAddress
SkipLabelsLoop:
	cpir
	inc	hl
	inc	hl
	inc	hl
	dec	e
	jr	nz, SkipLabelsLoop
GetLabelAddress:
	cpir
	ld	de, (hl)
	ld	hl, 24				; 8 pushes/calls before return
	add	hl, sp
	ld	(hl), de
	jp	Quit
NoLabelsFound:
	call	GetKeyAnyFast
	jp	MainMenu
	
; ==============================================================
; Routines are starting here
; ==============================================================

SelectOption:
; D = max amount of options
; E = selected option
	dec	d
	ld	e, 0
PrintCursor:
	ld	a, e
	add	a, a
	add	a, a
	add	a, a
	add	a, e
	inc	a
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 0
	ld	a, '>'
	call	PrintChar
CheckKeyLoop:
	call	GetKeyAnyFast
	ld	l, 01Ch
	bit	0, (hl)
	ret	nz
	bit	6, (hl)
	jr	nz, ReturnZ
	ld	l, 01Eh
	bit	0, (hl)
	jr	nz, MoveCursorDown
	bit	3, (hl)
	jr	z, CheckKeyLoop
MoveCursorUp:
	ld	a, e
	or	a, a
	jr	z, CheckKeyLoop
	dec	e
	jr	EraseCursor
MoveCursorDown:
	ld	a, e
	cp	a, d
	jr	z, CheckKeyLoop
	inc	e
EraseCursor:
	xor	a, a
	call	PrintChar
	jr	PrintCursor
ReturnZ:
	cp	a, a
	ret
	
ToString:
	push	bc
	ld	de, TempStringData + 8
DivideLoop:
	ld	a, 10
	call	_DivHLByA
	dec	de
	add	hl, de
	add	a, '0'
	ld	(de), a
	sbc	hl, de
	jr	nz, DivideLoop
	ex	de, hl
	pop	bc
	ret
	
TempStringData:
	.db	0, 0, 0, 0, 0, 0, 0, 0, 0
	
ClearScreen:
	ld	hl, SCREEN_START
	ld	(hl), 0
	push	hl
	pop	de
	inc	de
	ld	bc, lcdWidth * lcdHeight / 8 - 1
	ldir
	ret
	
GetKeyAnyFast:
	ld	hl, mpKeyRange + (keyModeAny << 8)
	ld	(hl), h
	ld	l, keyIntStat
	xor	a, a
	ld	(hl), keyIntKeyPress
_:	bit	bKeyIntKeyPress, (hl)
	jr	z, -_
	ld	l, a
	ld	(hl), keyModeScanOnce
_:	cp	a, (hl)
	jr	nz, -_
	ld	a, 20
	jp	_DelayTenTimesAms
	
PrintString:
	ld	a, (hl)
	or	a, a
	inc	hl
	ret	z
	call	PrintChar
	inc	(iy + X_POS)
	jr	PrintString
	
PrintChar:
	push	hl
	push	de
	push	bc
	or	a, a
	sbc	hl, hl
	ld	l, (iy + X_POS)
	ld	e, (iy + Y_POS)
	ld	d, lcdWidth / 8
	mlt	de
	add	hl, de
	ld	de, SCREEN_START
	add	hl, de
	ex	de, hl
	ld	hl, _DefaultTextData
	ld	c, a
	ld	b, 8
	ld	a, b
	mlt	bc
	add	hl, bc
	ld	bc, (lcdWidth / 8) - 1
PutCharLoop:
	ldi
	inc	bc
	ex	de, hl
	add	hl, bc
	ex	de, hl
	dec	a
	jr	nz, PutCharLoop
	pop	bc
	pop	de
	pop	hl
	ret
	
StepThroughCodeString:
	.db	"Step through code", 0
VariableViewingString:
	.db	"View/edit variables", 0
MemoryViewingString:
	.db	"View/edit memory", 0
ViewScreenString:
	.db	"View screen", 0
ViewBufferString:
	.db	"View buffer", 0
JumpToLabelString:
	.db	"Jump to label", 0
QuitString:
	.db	"Quit", 0

_DefaultTextData:
	.db	$00,$00,$00,$00,$00,$00,$00,$00 ; .
	.db	$7E,$81,$A5,$81,$BD,$BD,$81,$7E ; .
	.db	$7E,$FF,$DB,$FF,$C3,$C3,$FF,$7E ; .
	.db	$6C,$FE,$FE,$FE,$7C,$38,$10,$00 ; .
	.db	$10,$38,$7C,$FE,$7C,$38,$10,$00 ; .
	.db	$38,$7C,$38,$FE,$FE,$10,$10,$7C ; .
	.db	$00,$18,$3C,$7E,$FF,$7E,$18,$7E ; .
	.db	$00,$00,$18,$3C,$3C,$18,$00,$00 ; .
	.db	$FF,$FF,$E7,$C3,$C3,$E7,$FF,$FF ; .
	.db	$00,$3C,$66,$42,$42,$66,$3C,$00 ; .
	.db	$FF,$C3,$99,$BD,$BD,$99,$C3,$FF ; .
	.db	$0F,$07,$0F,$7D,$CC,$CC,$CC,$78 ; .
	.db	$3C,$66,$66,$66,$3C,$18,$7E,$18 ; .
	.db	$3F,$33,$3F,$30,$30,$70,$F0,$E0 ; .
	.db	$7F,$63,$7F,$63,$63,$67,$E6,$C0 ; .
	.db	$99,$5A,$3C,$E7,$E7,$3C,$5A,$99 ; .
	.db	$80,$E0,$F8,$FE,$F8,$E0,$80,$00 ; .
	.db	$02,$0E,$3E,$FE,$3E,$0E,$02,$00 ; .
	.db	$18,$3C,$7E,$18,$18,$7E,$3C,$18 ; .
	.db	$66,$66,$66,$66,$66,$00,$66,$00 ; .
	.db	$7F,$DB,$DB,$7B,$1B,$1B,$1B,$00 ; .
	.db	$3F,$60,$7C,$66,$66,$3E,$06,$FC ; .
	.db	$00,$00,$00,$00,$7E,$7E,$7E,$00 ; .
	.db	$18,$3C,$7E,$18,$7E,$3C,$18,$FF ; .
	.db	$18,$3C,$7E,$18,$18,$18,$18,$00 ; .
	.db	$18,$18,$18,$18,$7E,$3C,$18,$00 ; .
	.db	$00,$18,$0C,$FE,$0C,$18,$00,$00 ; .
	.db	$00,$30,$60,$FE,$60,$30,$00,$00 ; .
	.db	$00,$00,$C0,$C0,$C0,$FE,$00,$00 ; .
	.db	$00,$24,$66,$FF,$66,$24,$00,$00 ; .
	.db	$00,$18,$3C,$7E,$FF,$FF,$00,$00 ; .
	.db	$00,$FF,$FF,$7E,$3C,$18,$00,$00 ; .
	.db	$00,$00,$00,$00,$00,$00,$00,$00 ;
	.db	$C0,$C0,$C0,$C0,$C0,$00,$C0,$00 ; !
	.db	$D8,$D8,$D8,$00,$00,$00,$00,$00 ; "
	.db	$6C,$6C,$FE,$6C,$FE,$6C,$6C,$00 ; #
	.db	$18,$7E,$C0,$7C,$06,$FC,$18,$00 ; $
	.db	$00,$C6,$CC,$18,$30,$66,$C6,$00 ; %
	.db	$38,$6C,$38,$76,$DC,$CC,$76,$00 ; &
	.db	$30,$30,$60,$00,$00,$00,$00,$00 ; '
	.db	$30,$60,$C0,$C0,$C0,$60,$30,$00 ; (
	.db	$C0,$60,$30,$30,$30,$60,$C0,$00 ; )
	.db	$00,$66,$3C,$FF,$3C,$66,$00,$00 ; *
	.db	$00,$30,$30,$FC,$FC,$30,$30,$00 ; +
	.db	$00,$00,$00,$00,$00,$60,$60,$C0 ; ,
	.db	$00,$00,$00,$FC,$00,$00,$00,$00 ; -
	.db	$00,$00,$00,$00,$00,$C0,$C0,$00 ; .
	.db	$06,$0C,$18,$30,$60,$C0,$80,$00 ; /
	.db	$7C,$CE,$DE,$F6,$E6,$C6,$7C,$00 ; 0
	.db	$30,$70,$30,$30,$30,$30,$FC,$00 ; 1
	.db	$7C,$C6,$06,$7C,$C0,$C0,$FE,$00 ; 2
	.db	$FC,$06,$06,$3C,$06,$06,$FC,$00 ; 3
	.db	$0C,$CC,$CC,$CC,$FE,$0C,$0C,$00 ; 4
	.db	$FE,$C0,$FC,$06,$06,$C6,$7C,$00 ; 5
	.db	$7C,$C0,$C0,$FC,$C6,$C6,$7C,$00 ; 6
	.db	$FE,$06,$06,$0C,$18,$30,$30,$00 ; 7
	.db	$7C,$C6,$C6,$7C,$C6,$C6,$7C,$00 ; 8
	.db	$7C,$C6,$C6,$7E,$06,$06,$7C,$00 ; 9
	.db	$00,$C0,$C0,$00,$00,$C0,$C0,$00 ; :
	.db	$00,$60,$60,$00,$00,$60,$60,$C0 ; ;
	.db	$18,$30,$60,$C0,$60,$30,$18,$00 ; <
	.db	$00,$00,$FC,$00,$FC,$00,$00,$00 ; =
	.db	$C0,$60,$30,$18,$30,$60,$C0,$00 ; >
	.db	$78,$CC,$18,$30,$30,$00,$30,$00 ; ?
	.db	$7C,$C6,$DE,$DE,$DE,$C0,$7E,$00 ; @
	.db	$38,$6C,$C6,$C6,$FE,$C6,$C6,$00 ; A
	.db	$FC,$C6,$C6,$FC,$C6,$C6,$FC,$00 ; B
	.db	$7C,$C6,$C0,$C0,$C0,$C6,$7C,$00 ; C
	.db	$F8,$CC,$C6,$C6,$C6,$CC,$F8,$00 ; D
	.db	$FE,$C0,$C0,$F8,$C0,$C0,$FE,$00 ; E
	.db	$FE,$C0,$C0,$F8,$C0,$C0,$C0,$00 ; F
	.db	$7C,$C6,$C0,$C0,$CE,$C6,$7C,$00 ; G
	.db	$C6,$C6,$C6,$FE,$C6,$C6,$C6,$00 ; H
	.db	$7E,$18,$18,$18,$18,$18,$7E,$00 ; I
	.db	$06,$06,$06,$06,$06,$C6,$7C,$00 ; J
	.db	$C6,$CC,$D8,$F0,$D8,$CC,$C6,$00 ; K
	.db	$C0,$C0,$C0,$C0,$C0,$C0,$FE,$00 ; L
	.db	$C6,$EE,$FE,$FE,$D6,$C6,$C6,$00 ; M
	.db	$C6,$E6,$F6,$DE,$CE,$C6,$C6,$00 ; N
	.db	$7C,$C6,$C6,$C6,$C6,$C6,$7C,$00 ; O
	.db	$FC,$C6,$C6,$FC,$C0,$C0,$C0,$00 ; P
	.db	$7C,$C6,$C6,$C6,$D6,$DE,$7C,$06 ; Q
	.db	$FC,$C6,$C6,$FC,$D8,$CC,$C6,$00 ; R
	.db	$7C,$C6,$C0,$7C,$06,$C6,$7C,$00 ; S
	.db	$FF,$18,$18,$18,$18,$18,$18,$00 ; T
	.db	$C6,$C6,$C6,$C6,$C6,$C6,$FE,$00 ; U
	.db	$C6,$C6,$C6,$C6,$C6,$7C,$38,$00 ; V
	.db	$C6,$C6,$C6,$C6,$D6,$FE,$6C,$00 ; W
	.db	$C6,$C6,$6C,$38,$6C,$C6,$C6,$00 ; X
	.db	$C6,$C6,$C6,$7C,$18,$30,$E0,$00 ; Y
	.db	$FE,$06,$0C,$18,$30,$60,$FE,$00 ; Z
	.db	$F0,$C0,$C0,$C0,$C0,$C0,$F0,$00 ; [
	.db	$C0,$60,$30,$18,$0C,$06,$02,$00 ; \
	.db	$F0,$30,$30,$30,$30,$30,$F0,$00 ; ]
	.db	$10,$38,$6C,$C6,$00,$00,$00,$00 ; ^
	.db	$00,$00,$00,$00,$00,$00,$00,$FF ; _
	.db	$C0,$C0,$60,$00,$00,$00,$00,$00 ; `
	.db	$00,$00,$7C,$06,$7E,$C6,$7E,$00 ; a
	.db	$C0,$C0,$C0,$FC,$C6,$C6,$FC,$00 ; b
	.db	$00,$00,$7C,$C6,$C0,$C6,$7C,$00 ; c
	.db	$06,$06,$06,$7E,$C6,$C6,$7E,$00 ; d
	.db	$00,$00,$7C,$C6,$FE,$C0,$7C,$00 ; e
	.db	$1C,$36,$30,$78,$30,$30,$78,$00 ; f
	.db	$00,$00,$7E,$C6,$C6,$7E,$06,$FC ; g
	.db	$C0,$C0,$FC,$C6,$C6,$C6,$C6,$00 ; h
	.db	$60,$00,$E0,$60,$60,$60,$F0,$00 ; i
	.db	$06,$00,$06,$06,$06,$06,$C6,$7C ; j
	.db	$C0,$C0,$CC,$D8,$F8,$CC,$C6,$00 ; k
	.db	$E0,$60,$60,$60,$60,$60,$F0,$00 ; l
	.db	$00,$00,$CC,$FE,$FE,$D6,$D6,$00 ; m
	.db	$00,$00,$FC,$C6,$C6,$C6,$C6,$00 ; n
	.db	$00,$00,$7C,$C6,$C6,$C6,$7C,$00 ; o
	.db	$00,$00,$FC,$C6,$C6,$FC,$C0,$C0 ; p
	.db	$00,$00,$7E,$C6,$C6,$7E,$06,$06 ; q
	.db	$00,$00,$FC,$C6,$C0,$C0,$C0,$00 ; r
	.db	$00,$00,$7E,$C0,$7C,$06,$FC,$00 ; s
	.db	$30,$30,$FC,$30,$30,$30,$1C,$00 ; t
	.db	$00,$00,$C6,$C6,$C6,$C6,$7E,$00 ; u
	.db	$00,$00,$C6,$C6,$C6,$7C,$38,$00 ; v
	.db	$00,$00,$C6,$C6,$D6,$FE,$6C,$00 ; w
	.db	$00,$00,$C6,$6C,$38,$6C,$C6,$00 ; x
	.db	$00,$00,$C6,$C6,$C6,$7E,$06,$FC ; y
	.db	$00,$00,$FE,$0C,$38,$60,$FE,$00 ; z
	.db	$1C,$30,$30,$E0,$30,$30,$1C,$00 ; {
	.db	$C0,$C0,$C0,$00,$C0,$C0,$C0,$00 ; |
	.db	$E0,$30,$30,$1C,$30,$30,$E0,$00 ; }
	.db	$76,$DC,$00,$00,$00,$00,$00,$00 ; ~
	.db	$00,$10,$38,$6C,$C6,$C6,$FE,$00 ; .
DebuggerCodeEnd:

.echo $ - DebuggerCode2