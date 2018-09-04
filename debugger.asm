#include "ti84pce.inc"



#define VARIABLES cursorImage + 500		; Apparently the GRAPHX lib uses cursorImage to fill the screen
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
#define BREAKPOINTS_START SCREEN_START + (lcdWidth * lcdHeight / 8)
#define AMOUNT_OF_OPTIONS      9

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
	ex	de, hl
	inc	hl
	inc	hl
	ld	(iy + DBG_PROG_START), hl	; HL points to the source program now
	dec	hl
	call	_Mov9ToOP1
	ld	a, ProgObj
	ld	(OP1), a
	call	_ChkFindSym			; Find debug program, must exists
	jr	c, Return
	call	_ChkInRAM
	ex	de, hl
	ld	bc, 0
	jr	nc, +_
	ld	c, 9
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
_:	ld	c, (hl)				; Get size
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
.org saveSScreen + 21945 - 260 - 4000		; See src/main.h
DebuggerCode2:
; Backup registers and variables

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
	
	ld	hl, mpLcdPalette
	lea	de, iy + PALETTE_ENTRIES_BACKUP
	ld	bc, 4
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
	
MainMenuSetLCDConfig:
	ld	a, lcdBpp1
	ld	hl, mpLcdCtrl
	ld	(hl), a
	inc	hl
	set	2, (hl)
	ld	hl, SCREEN_START
	ld	(mpLcdUpbase), hl
	
MainMenu:
	call	ClearScreen
	ld	c, 0
	ld	b, AMOUNT_OF_OPTIONS
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
	jp	z, ViewSlots
	dec	a
	jp	z, ViewScreen
	dec	a
	jp	z, ViewBuffer
	dec	a
	jp	z, Breakpoints
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
	ld	(iy + X_POS), 1
	ld	(iy + Y_POS), 1
	ld	hl, (iy + PROG_START)
	ld	bc, (iy + PROG_SIZE)
GetBASICTokenLoopDispColon:
	ld	a, ':'
	call	PrintChar
GetBASICTokenLoop:
	ld	a, b
	or	a, c
	jr	z, BASICProgramDone
	ld	a, (iy + X_POS)
	cp	a, 40
	jr	z, DontDisplayToken
	ld	a, (hl)
	cp	a, tEnter
	jr	z, AdvanceLine
	push	bc
	push	hl
	call	_Get_Tok_Strng
	ld	hl, OP3
	call	PrintString
	pop	hl
	pop	bc
DontDisplayToken:
	ld	a, (hl)
	call	_IsA2ByteTok
	inc	hl
	dec	bc
	jr	nz, +_
	inc	hl
	dec	bc
_:	jr	GetBASICTokenLoop
AdvanceLine:
	ld	(iy + X_POS), 1
	ld	a, (iy + Y_POS)
	add	a, 9
	ld	(iy + Y_POS), a
	inc	hl
	dec	bc
	cp	a, 229 - 7
	jr	c, GetBASICTokenLoopDispColon
BASICProgramDone:
	ld	hl, SCREEN_START + (228 * lcdWidth / 8)
	ld	de, 0FFFFFFh
	ld	b, 5
_:	ld	(hl), de
	inc	hl
	inc	hl
	inc	hl
	ld	(hl), de
	inc	hl
	inc	hl
	inc	hl
	ld	(hl), e
	inc	hl
	ld	(hl), e
	inc	hl
	djnz	-_
	ld	(iy + Y_POS), 231
	ld	(iy + X_POS), 0
	ld	hl, StepString
	call	PrintString
	call	GetKeyAnyFast
	jp	MainMenu
	
ViewVariables:
	ld	hl, (iy + DBG_PROG_START) 
	xor	a, a
	cpir
	inc	hl				; Skip FILEIOC functions pointer
	inc	hl
	inc	hl
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
	
ViewSlots:
	ld	hl, (iy + DBG_PROG_START)
	xor	a, a
	cpir
	ld	hl, (hl)			; Pointer to FILEIOC functions
	add	hl, de
	or	a, a
	sbc	hl, de
	jp	z, AllSlotsClosed
	ld	bc, 4
	inc	hl
	ld	de, (hl)			; IsArchived
	ld	(IsArchived_SMC), de
	add	hl, bc
	ld	de, (hl)			; Tell
	ld	(Tell_SMC), de
	add	hl, bc
	ld	de, (hl)			; GetSize
	ld	(GetSize_SMC), de
	add	hl, bc
	ld	de, (hl)			; GetDataPtr
	ld	(GetDataPtr_SMC), de
	add	hl, bc
	ld	de, (hl)			; GetVATPtr
	ld	(GetVATPtr_SMC), de
	add	hl, bc
	ld	de, (hl)			; GetName
	ld	(GetName_SMC), de
	
	ld	(iy + X_POS), 0
	ld	(iy + Y_POS), 0
	ld	hl, SlotOptionsString
	call	PrintString
	ld	b, 5
	ld	c, 1
GetSlotLoop:
	push	bc
	ld	a, c
	add	a, a
	add	a, a
	add	a, a
	add	a, c
	inc	a
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 0
	ld	a, c
	add	a, '0'
	call	PrintChar
	ld	a, ':'
	call	PrintChar
	ld	(iy + X_POS), 28
GetSize_SMC = $+1
	call	0
	inc	hl
	add	hl, de
	or	a, a
	sbc	hl, de
	jr	z, SlotIsClosed
	dec	hl
	call	ToString
	call	PrintString
	ld	(iy + X_POS), 5
GetVATPtr_SMC = $+1
	call	0
	ld	a, (hl)
	or	a, a
	sbc	hl, hl
	ld	l, a
	call	ToString
	call	PrintString
	ld	(iy + X_POS), 10
IsArchived_SMC = $+1
	call	0
	ld	a, l
	or	a, a
	jr	z, InRAM
	ld	a, '*'
	call	PrintChar
InRAM:
	ld	hl, TempStringData
	push	hl
GetName_SMC = $+1
	call	0
	pop	hl
	call	PrintString
	ld	(iy + X_POS), 20
	ld	a, '$'
	call	PrintChar
GetDataPtr_SMC = $+1
	call	0
	call	_SetAToHLU
	call	PrintByte
	ld	a, h
	call	PrintByte
	ld	a, l
	call	PrintByte
	ld	(iy + X_POS), 34
Tell_SMC = $+1
	call	0
	call	ToString
	call	PrintString
SlotIsClosed:
	pop	bc
	inc	c
	dec	b
	jp	nz, GetSlotLoop
AllSlotsClosed:
	call	GetKeyAnyFast
	jp	MainMenu
	
ViewScreen:
	ld	hl, 6
	add	hl, sp
	ld	de, (hl)
	ld	(mpLcdCtrl), de
	dec	hl
	dec	hl
	dec	hl
	ld	hl, (hl)
	ld	(mpLcdUpBase), hl
	call	GetKeyAnyFast
	jp	MainMenuSetLCDConfig

ViewBuffer:
	ld	hl, 6
	add	hl, sp
	ld	hl, (hl)
	ld	(mpLcdCtrl), hl
	ld	hl, (mpLcdLpBase)
	ld	(mpLcdUpBase), hl
	call	GetKeyAnyFast
	jp	MainMenuSetLCDConfig
	
Breakpoints:
	
JumpLabel:
	ld	hl, (iy + DBG_PROG_START)
	xor	a, a
	cpir
	inc	hl				; Skip FILEIOC functions pointer
	inc	hl
	inc	hl
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
	dec	(iy + X_POS)
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
	
PrintByte:
	ld	b, a
	rra
	rra
	rra
	rra
	and	a, 00Fh
	cp	a, 10
	jr	c, +_
	add	a, 'A' - '9' - 1
_:	add	a, '0'
	call	PrintChar
	ld	a, b
	and	a, 00Fh
	cp	a, 10
	jr	c, +_
	add	a, 'A' - '9' - 1
_:	add	a, '0'
	jp	PrintChar
	
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
	jr	PrintString
	
PrintChar:
	push	hl
	push	de
	push	bc
	ld	c, a
	ld	a, (iy + X_POS)
	cp	a, 40
	jr	z, DontDisplayChar
	or	a, a
	sbc	hl, hl
	ld	l, a
	inc	(iy + X_POS)
	ld	e, (iy + Y_POS)
	ld	d, lcdWidth / 8
	mlt	de
	add	hl, de
	ld	de, SCREEN_START
	add	hl, de
	ex	de, hl
	ld	hl, _DefaultTextData
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
DontDisplayChar:
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
ViewOpenedSlotsString:
	.db	"View opened slots", 0
ViewScreenString:
	.db	"View screen", 0
ViewBufferString:
	.db	"View buffer", 0
BreakpointsString:
	.db	"Add/remove breakpoints", 0
JumpToLabelString:
	.db	"Jump to label", 0
QuitString:
	.db	"Quit", 0
StepString:
	.db	"Step  StepOver   StepNext  StepOut  Quit", 0
	
SlotOptionsString:
	.db	"Slot Type Name      DataPtr Size  Offset", 0

_DefaultTextData:
; To get the font data, load font.pf into 8x8 ROM PixelFont Editor, export it as an assembly include file,
; and replace "0x(..)" with "0\1h" to make it spasm-compatible
#include "font.asm"
DebuggerCodeEnd:

.echo $ - DebuggerCode2