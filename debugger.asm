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
#define SLOT_FUNCTIONS_POINTER 21
#define VARIABLE_START         24
#define LINES_START            27
#define STARTUP_BREAKPOINTS    30
#define LABELS_START           33
#define AMOUNT_OF_BREAKPOINTS  36
#define DEBUG_CURRENT_LINE     39
#define DEBUG_LINE_START       40

#define SCREEN_START           (usbArea & 0FFFFF8h) + 8	; Note: mask to 8 bytes!
#define BREAKPOINTS_START SCREEN_START + (lcdWidth * lcdHeight / 8)
#define DEBUGGER_START         saveSScreen + 21945 - 260 - 4000		; See src/main.h
#define ICE_VARIABLES          0D13F56h		; See src/main.h
#define AMOUNT_OF_OPTIONS      9

	.db	083h
	cp	a, a				; Signify start of ICE Debugger
	ret
	
; Here we actually start; the ICE program can check for these 3 bytes to make sure the debugger is loaded
; DE = compiled program name
; Return C if failure
	di
	ld	iy, VARIABLES
	ex	de, hl				; Input is DBG file
	call	_Mov9ToOP1
	call	_ChkFindSym			; Find program, must exists
	ret	c
	call	_ChkInRAM
	ex	de, hl
	jr	nc, +_
	ld	bc, 9
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
_:	inc	hl
	inc	hl
	ld	(iy + DBG_PROG_START), hl	; HL points to the source program now
	dec	hl
	call	_Mov9ToOP1
	ld	a, ProgObj
	ld	(OP1), a
	call	_ChkFindSym			; Find debug program, must exists
	ret	c
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
	ld	hl, (iy + DBG_PROG_START)
	xor	a, a
	ld	(iy + AMOUNT_OF_BREAKPOINTS), a
	ld	c, a
	ld	b, a
	cpir
	ld	(iy + SLOT_FUNCTIONS_POINTER), hl
	inc	hl
	inc	hl
	inc	hl
	ld	(iy + VARIABLE_START), hl
	ld	b, (hl)				; Amount of variables
	inc	hl
	inc	b
	dec	b
	jr	z, +_
SkipVariableLoop0:
	ld	c, 255				; Prevent decrementing B; a variable name won't be longer than 255 bytes
	cpir
	djnz	SkipVariableLoop0
_:	ld	(iy + LINES_START), hl
	ld	de, (hl)
	inc	hl
	inc	hl
	inc	hl
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	inc	hl				; Skip ending $FF byte
	ld	(iy + STARTUP_BREAKPOINTS), hl
	ld	c, (hl)
	ld	b, 3
	mlt	bc
	inc	hl
	add	hl, bc
	ld	(iy + LABELS_START), hl
	ld	hl, (windowHookPtr)		; Copy to safeRAM
	ld	de, DebuggerCode1
	add	hl, de
	ld	de, DebuggerCode2
	ld	bc, DebuggerCodeEnd - DebuggerCode2
	ldir
	ld	hl, (iy + STARTUP_BREAKPOINTS)
	ld	a, (hl)
	or	a, a
	ret	z
	inc	hl
	push	ix
InsertBreakpointLoop:
	push	hl
	ex	af, af'
	ld	hl, (hl)
	call	InsertBreakpoint
	ex	af, af'
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	dec	a
	jr	nz, InsertBreakpointLoop
	pop	ix
	ret

DebuggerCode1:
.org DEBUGGER_START
DebuggerCode2:
; This is the breakpoint handler
; See breakpoints.txt for some more information

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
	ld	e, b
	ld	hl, MainOptionsString
	
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
	ld	d, b
	ld	c, b
	call	SelectOption
	jr	nz, Quit

	ld	a, c
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
	jp	z, JumpLabel
	dec	a
	jp	z, SafeExit
	
Quit:
	call	RestorePaletteUSB
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
	
; =======================================================================================
StepCode:
	ld	hl, 24
	add	hl, sp
	ld	de, (hl)
	dec	de
	dec	de
	dec	de
	dec	de					; DE = call pointer
	
	ld	hl, (iy + STARTUP_BREAKPOINTS)
	dec	hl
	ld	bc, -6
	exx
	ld	hl, (iy + LINES_START)
	ld	hl, (hl)
CheckLineLoop:
	exx
	add	hl, bc
	push	hl
	ld	hl, (hl)
	scf
	sbc	hl, de
	pop	hl
	exx
	dec	hl
	jr	nc, CheckLineLoop
	ld	(iy + DEBUG_CURRENT_LINE), hl
	ex	de, hl					; DE = line_numer
	ld	hl, (iy + LINES_START)
	ld	hl, (hl)				; HL = amount_of_lines
	
; If current_line <= 13 or amount_of_lines <= 25
	ld	bc, 14
	ld	a, d
	or	a, a
	jr	nz, CheckClipBottom
	ld	a, e
	cp	a, c
	jr	c, ClipAtTop
CheckAmountOfLines:
	ld	c, 26
	sbc	hl, bc
	add	hl, bc
	jr	nc, CheckClipBottom
ClipAtTop:
; lines_to_skip = 0
	ld	de, 0
; highlight_line = current_line
	ld	ixl, a
	jr	DoDisplayLines
	
CheckClipBottom:
; Else If amount_of_lines - current_line <= 13
	sbc	hl, de
	ld	c, 14
	sbc	hl, bc
	add	hl, bc
	jr	nc, DisplayLinesNormal
	add	hl, de
; highlight_line = 25 - (amount_of_lines - current_line) = 25 + current_line - amount_of_lines
	ld	a, 25
	ld	c, a
	add	a, e
	sub	a, l
; lines_to_skip = amount_of_lines - 25
	sbc	hl, bc
	ex	de, hl
	add	a, e
	ld	ixl, a
	jr	DoDisplayLines
DisplayLinesNormal:
; Else
; lines_to_skip = current_line - 13
	ex	de, hl
	ld	de, 12
; highlight_line = 13
	ld	a, e
	sbc	hl, de
	ex	de, hl
	add	a, e
	ld	ixl, a
DoDisplayLines:
; BC = program length
; DE = amount of lines to skip
; IXL = amount of lines before active line
	ld	a, 1
	ld	hl, (iy + PROG_START)
	ld	bc, (iy + PROG_SIZE)
GetBASICTokenLoopDispColon:
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 1
	ld	a, d
	or	a, e
	jr	nz, GetBASICTokenLoop
	ld	a, ':'
	call	PrintChar
GetBASICTokenLoop:
	ld	a, b					; Program's done!
	or	a, c
	jr	z, BASICProgramDone
	ld	a, (hl)
	cp	a, tEnter
	jr	z, AdvanceBASICLine
	ld	a, d					; Out of screen
	or	a, e
	jr	nz, DontDisplayToken
	ld	a, (iy + X_POS)
	cp	a, 40
	jr	z, DontDisplayToken
	push	bc
	push	de
	push	hl
	call	_Get_Tok_Strng
	ld	hl, OP3
	call	PrintString
	pop	hl
	pop	de
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
AdvanceBASICLine:
	dec	ixl
	ld	a, d
	or	a, e
	ld	a, (iy + Y_POS)
	jr	nz, +_
	add	a, 9
	inc	de
_:	dec	de
	inc	hl
	dec	bc
	cp	a, 229 - 7
	jr	c, GetBASICTokenLoopDispColon
BASICProgramDone:
	ld	ixl, 1
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
_:	call	GetKeyAnyFast
	ld	l, 012h
	ld	a, (hl)
	rra
	jr	c, BASICDebuggerQuit
	rra
	jr	c, BASICDebuggerStepOut
	rra
	jr	c, BASICDebuggerStepNext
	rra
	jr	c, BASICDebuggerStepOver
	rra
	jr	c, BASICDebuggerStep
	ld	l, 01Ch
	bit	0, (hl)
	jr	nz, BASICDebuggerSwitchBreakpoint
	bit	6, (hl)
	jr	nz, BASICDebuggerQuit
	jr	-_
	
BASICDebuggerStepOut:
BASICDebuggerStepNext:
BASICDebuggerStepOver:
BASICDebuggerStep:
BASICDebuggerSwitchBreakpoint:
	
BASICDebuggerQuit:
	jp	MainMenu
	
; =======================================================================================
ViewVariables:
; B = amount of variables to display
; C = currently selected variable
; D = start offset
; E = amount of variables
	ld	hl, (iy + VARIABLE_START)
	xor	a, a
	cp	a, (hl)
	jr	z, NoVariablesFound
	ld	d, a
	ld	c, a
PrintAllVariables:
	exx
	call	ClearScreen
	exx
	ld	hl, (iy + VARIABLE_START)
	ld	e, (hl)
	inc	hl
	ld	b, 26				; Get amount of variables to display
	ld	a, b
	cp	a, e
	jr	c, +_
	ld	b, e
_:	ld	(iy + Y_POS), 1
	ld	a, d
	add	a, a
	add	a, d
	sub	a, 3 + 080h
	ld	(VariableOffset), a
	xor	a, a
	cp	a, d
	jr	z, PrintVariableLoop
	push	bc
	ld	b, d
_:	ld	c, 255
	cpir
	djnz	-_
	pop	bc
PrintVariableLoop:
	ld	(iy + X_POS), 1
	call	PrintString
	ld	a, ':'
	call	PrintChar
	ld	(iy + X_POS), 25
	push	hl
	ld	a, (VariableOffset)
	add	a, 3
	ld	(VariableOffset), a
	ld	ix, ICE_VARIABLES
VariableOffset = $+2
	ld	hl, (ix - 080h)
	call	PrintInt
	pop	hl
	call	AdvanceLine
	djnz	PrintVariableLoop
	call	SelectOption
	jr	nc, PrintAllVariables
NoVariablesFound:
	call	z, GetKeyAnyFast
	jp	MainMenu
	
; =======================================================================================
ViewMemory:
	ld	hl, ramStart
	ld	c, 24
	ld	(iy + Y_POS), 0
MemoryDrawLine:
	ld	a, (iy + Y_POS)
	add	a, 10
	ld	(iy + Y_POS), a
	ld	(iy + X_POS), 0
	ld	a, 0F2h				; $
	call	PrintChar
	call	PrintHexInt
	inc	(iy + X_POS)
	ld	b, 8
MemoryDrawLineOfBytes:
	ld	a, (hl)
	inc	hl
	call	PrintByte
	inc	(iy + X_POS)
	djnz	MemoryDrawLineOfBytes
	ld	de, -8
	add	hl, de
	ld	b, 8
MemoryDrawLineOfChars:
	ld	a, (hl)
	inc	hl
	or	a, a
	jr	nz, +_
	ld	a, '.'
_:	cp	a, 0F4h
	jr	c, +_
	ld	a, '.'
_:	call	PrintChar
	djnz	MemoryDrawLineOfChars
	dec	c
	jr	nz, MemoryDrawLine
	call	GetKeyAnyFast
	jp	MainMenu
	
; =======================================================================================
ViewSlots:
	ld	hl, (iy + SLOT_FUNCTIONS_POINTER)
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
	inc	(iy + Y_POS)
GetSlotLoop:
	push	bc
	call	AdvanceLine
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
	call	PrintInt
	ld	(iy + X_POS), 5
GetVATPtr_SMC = $+1
	call	0
	ld	a, (hl)
	or	a, a
	sbc	hl, hl
	ld	l, a
	call	PrintInt
	ld	(iy + X_POS), 10
IsArchived_SMC = $+1
	call	0
	ld	a, l
	or	a, a
	jr	z, +_
	ld	a, '*'
	call	PrintChar
_:	ld	hl, TempStringData
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
	call	PrintHexInt
	ld	(iy + X_POS), 34
Tell_SMC = $+1
	call	0
	call	PrintInt
SlotIsClosed:
	pop	bc
	inc	c
	dec	b
	jp	nz, GetSlotLoop
AllSlotsClosed:
	call	GetKeyAnyFast
	jp	MainMenu
	
; =======================================================================================
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
	
; =======================================================================================
ViewBuffer:
	ld	hl, 6
	add	hl, sp
	ld	hl, (hl)
	ld	(mpLcdCtrl), hl
	ld	hl, (mpLcdLpBase)
	ld	(mpLcdUpBase), hl
	call	GetKeyAnyFast
	jp	MainMenuSetLCDConfig
	
; =======================================================================================
SafeExit:
	ld	hl, 24
	add	hl, sp
	ld	sp, hl
_:	pop	hl
	ld	de, ramStart
	or	a, a
	sbc	hl, de
	jr	nc, -_
	add	hl, de
	push	hl
	ld	a, lcdBpp16
	ld	hl, mpLcdCtrl
	ld	(hl), a
	ld	hl, vRAM
	ld	(mpLcdUpbase), hl
	call	RestorePaletteUSB
	ld	iy, flags
	jp	_DrawStatusBar
	
; =======================================================================================
JumpLabel:
; B = amount of labels to display
; C = currently selected label
; D = start offset
; E = amount of variables
	ld	hl, (iy + LABELS_START)
	xor	a, a
	cp	a, (hl)
	jr	z, NoLabelsFound
	ld	d, a
	ld	c, a
PrintAllLabels:
	exx
	call	ClearScreen
	exx
	ld	hl, (iy + LABELS_START)
	ld	e, (hl)
	inc	hl
	ld	b, 26
	ld	a, b
	cp	a, e
	jr	c, +_
	ld	b, e
_:	ld	(iy + Y_POS), 1
	xor	a, a
	cp	a, d
	jr	z, PrintLabelLoop
	push	bc
	ld	b, d
_:	ld	c, 255
	cpir
	inc	hl
	inc	hl
	inc	hl
	djnz	-_
	pop	bc
PrintLabelLoop:
	ld	(iy + X_POS), 1
	call	PrintString
	inc	hl				; Skip label address
	inc	hl
	inc	hl
	call	AdvanceLine
	djnz	PrintLabelLoop
	call	SelectOption
	jr	nc, PrintAllLabels
	jp	nz, MainMenu
; Get label address
	ld	hl, (iy + LABELS_START)
	inc	hl
	ld	a, d
	add	a, c
	jr	z, GetLabelAddress
	ld	e, a
	xor	a, a
	ld	b, a
	ld	c, b
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

InsertBreakpoint:
; HL = line number
	ld	c, (iy + AMOUNT_OF_BREAKPOINTS)
	ld	b, 10
	mlt	bc
	ld	ix, BREAKPOINTS_START
	add	ix, bc
	ld	(ix), hl			; Line number
	ld	de, (iy + LINES_START)
	inc	de
	inc	de
	inc	de
	ex	de, hl
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	ld	hl, (hl)
	ld	(ix + 3), hl			; Program pointer
	lea	de, ix + 6
	ld	bc, 4
	ldir
	dec	hl
	dec	hl
	dec	hl
	ld	de, DEBUGGER_START
	ld	(hl), de
	dec	hl
	ld	(hl), 0CDh			; CALL DEBUGGER_START
	ret
	
RestorePaletteUSB:
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
	ret

SelectOption:
; Inputs:
;   E = amount of options
;   D = start offset
;   C = currently selected option
; Returns:
;   Carry flag set:
;     Zero flag set = [ENTER]
;     Zero flag reset = [CLEAR]
;   Carry flag reset:
;     Pressed either [UP] or [DOWN]
	dec	e
PrintCursor:
	ld	a, c
	add	a, a
	add	a, a
	add	a, a
	add	a, c
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
	jr	nz, PressedEnter
	bit	6, (hl)
	jr	nz, PressedClear
	ld	l, 01Eh
	bit	0, (hl)
	jr	nz, MoveCursorDown
	bit	3, (hl)
	jr	z, CheckKeyLoop
MoveCursorUp:
	ld	a, c
	add	a, d
	jr	z, CheckKeyLoop
	sub	a, d
	jr	z, PressedUp
	dec	c
	jr	EraseCursor
MoveCursorDown:
	ld	a, c
	add	a, d
	cp	a, e
	jr	z, CheckKeyLoop
	ld	a, c
	cp	a, 25
	jr	z, PressedDown
	inc	c
EraseCursor:
	xor	a, a
	call	PrintChar
	jr	PrintCursor
PressedEnter:
	cp	a, a
	scf
	ret
PressedClear:
	or	a, 1
	scf
	ret
PressedUp:
	dec	d
	ret
PressedDown:
	inc	d
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
	
AdvanceLine:
	ld	a, (iy + Y_POS)
	add	a, 9
	ld	(iy + Y_POS), a
	ret
	
PrintInt:
	push	de
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
	pop	de
	
PrintString:
	ld	a, (hl)
	or	a, a
	inc	hl
	ret	z
	call	PrintChar
	jr	PrintString
	
PrintHexInt:
	call	_SetAToHLU
	call	PrintByte
	ld	a, h
	call	PrintByte
	ld	a, l
	
PrintByte:
	ld	d, a
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
	ld	a, d
	and	a, 00Fh
	cp	a, 10
	jr	c, +_
	add	a, 'A' - '9' - 1
_:	add	a, '0'
	
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
	ld	ixh, b
	mlt	bc
	add	hl, bc
	ld	bc, (lcdWidth / 8) - 1
PutCharLoop:
	ld	a, ixl
	or	a, a
	ld	a, (hl)
	jr	nz, +_
	cpl
_:	ld	(de), a
	inc	de
	inc	hl
	ex	de, hl
	add	hl, bc
	ex	de, hl
	dec	ixh
	jr	nz, PutCharLoop
DontDisplayChar:
	pop	bc
	pop	de
	pop	hl
	ret
	
MainOptionsString:
	.db	"Step through code", 0
	.db	"View/edit variables", 0
	.db	"View/edit memory", 0
	.db	"View opened slots", 0
	.db	"View screen", 0
	.db	"View buffer", 0
	.db	"Jump to label", 0
	.db	"Save exit program", 0
	.db	"Quit", 0
StepString:
	.db	"Step  StepOver   StepNext  StepOut  Quit", 0
SlotOptionsString:
	.db	"Slot Type Name      DataPtr Size  Offset", 0

_DefaultTextData:
; To get the font data, load font.pf into 8x8 ROM PixelFont Editor, export it as an assembly include file,
; and replace the regex "0x(..)" with "0\1h" to make it spasm-compatible
#include "font.asm"
DebuggerCodeEnd:

.echo $ - DebuggerCode2