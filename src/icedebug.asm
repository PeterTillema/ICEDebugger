;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'ICEDEBUG', 4

;-------------------------------------------------------------------------------
include_library '../include/fileioc.asm'
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; v1 functions
;-------------------------------------------------------------------------------
	export icedbg_setup
	export icedbg_open
	
SCREEN_START       := (usbArea and 0FFFFF8h) + 8			; Note: mask to 8 bytes!
ICE_VARIABLES      := 0D13F56h						; See src/main.h
AMOUNT_OF_OPTIONS  := 11

BREAKPOINT_SIZE    := 11
BREAKPOINT_TYPE    := 0
BREAKPOINT_TYPE_FIXED  := 0
BREAKPOINT_TYPE_TEMP   := 1
BREAKPOINT_LINE    := 1
BREAKPOINT_ADDRESS := 4
BREAKPOINT_CODE    := 7
	
; DE = compiled program name
; Return C if failure
icedbg_setup:
	di
	ld	iy, iy_base
	ex	de, hl				; Input is DBG file
	call	_Mov9ToOP1
	call	_ChkFindSym			; Find program, must exists
	ret	c
	call	_ChkInRAM
	ex	de, hl
	jr	nc, DbgVarInRAM
	ld	bc, 9
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
DbgVarInRAM:
	inc	hl
	inc	hl
	ld	(DBG_PROG_START), hl	; HL points to the source program now
	dec	hl
	call	_Mov9ToOP1
	ld	a, ProgObj
	ld	(OP1), a
	call	_ChkFindSym			; Find debug program, must exists
	ret	c
	call	_ChkInRAM
	ex	de, hl
	ld	bc, -1
	ld	(RESTORE_BREAKPOINT_LINE), bc
	inc	bc
	jr	nc, SrcVarInRAM
	ld	c, 9
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
SrcVarInRAM:
	ld	c, (hl)				; Get size
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	(PROG_SIZE), bc			; Store pointers
	ld	(PROG_START), hl
	ld	hl, (DBG_PROG_START)
	xor	a, a
	ld	(AMOUNT_OF_BREAKPOINTS), a
	ld	c, a
	ld	b, a
	cpir
	ld	(VARIABLE_START), hl
	ld	b, (hl)				; Amount of variables
	inc	hl
	inc	b
	dec	b
	jr	z, NoVariablesSkip
SkipVariableLoop0:
	ld	c, 255				; Prevent decrementing B; a variable name won't be longer than 255 bytes
	cpir
	djnz	SkipVariableLoop0
NoVariablesSkip:
	ld	(STEP_MODE), b
	ld	(LINES_START), hl
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
	ld	(STARTUP_BREAKPOINTS), hl
	ld	c, (hl)
	ld	b, 3
	mlt	bc
	inc	hl
	add	hl, bc
	ld	(LABELS_START), hl
	ld	hl, (STARTUP_BREAKPOINTS)
	ld	a, (hl)
	or	a, a
	ret	z
	inc	hl
	push	ix
InsertBreakpointLoop:
	push	hl
	ex	af, af'
	ld	hl, (hl)
	call	InsertFixedBreakpointAtLine
	ex	af, af'
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	dec	a
	jr	nz, InsertBreakpointLoop
	pop	ix
	ret
	
icedbg_open:
; This is the breakpoint handler
; See breakpoints.txt for some more information

; Backup registers and variables
	di
	ld	(tempSP), sp
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
	
	ld	iy, iy_base
	call	SetICEPalette
	
; Remove temp breakpoints
	ld	a, (AMOUNT_OF_TEMP_BREAKPOINTS)
	or	a, a
	jr	z, DontRemoveTempBreakpoints
	ld	c, (AMOUNT_OF_BREAKPOINTS)
	ld	b, BREAKPOINT_SIZE
	mlt	bc
	ld	ix, BreakpointsStart
	add	ix, bc
.loop:	lea	ix, ix - BREAKPOINT_SIZE
	ld	a, 1
	call	RemoveBreakpoint
	dec	(AMOUNT_OF_TEMP_BREAKPOINTS)
	jr	nz, .loop
DontRemoveTempBreakpoints:
	ld	hl, (RESTORE_BREAKPOINT_LINE)
	inc	hl
	add	hl, de
	or	a, a
	sbc	hl, de
	dec	hl
	call	nz, InsertFixedBreakpointAtLine
	scf
	sbc	hl, hl
	ld	(RESTORE_BREAKPOINT_LINE), hl
	ld	a, (STEP_MODE)
	ld	(STEP_MODE), 0
	dec	a
	jp	z, BASICDebuggerStepContinue
	dec	a
	jp	z, BASICDebuggerStepOutContinue
	dec	a
	jp	z, BASICDebuggerStepNextContinue
	dec	a
	jp	z, BASICDebuggerStepOverContinue
	
MainMenuSetLCDConfig:
	call	SetLCDConfig
MainMenu:
	call	ClearScreen
	ld	c, 0
	ld	b, AMOUNT_OF_OPTIONS
	ld	e, b
	ld	hl, MainOptionsString
	ld	(Y_POS), 1
	
PrintOptionsLoop:
	ld	(X_POS), 1
	call	PrintString
	call	AdvanceLine
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
	jp	z, ViewStrings
	dec	a
	jp	z, ViewLists
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
BASICDebuggerStepContinue:
	call	ClearScreen
	call	SetLCDConfig
StepCode:
	ld	hl, (tempSP)
	ld	de, (hl)
	dec	de
	dec	de
	dec	de
	dec	de					; DE = call pointer
	call	GetLineFromAddress
	ld	(DEBUG_CURRENT_LINE), hl
	ex	de, hl					; DE = line_numer
	ld	hl, (LINES_START)
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
; first_line_offset = 0
	ld	de, 0
; highlight_line = current_line
	ld	ixl, a
	jr	DoDisplayLines
	
CheckClipBottom:
; Else If amount_of_lines - current_line <= 13
	sbc	hl, de				; HL = amount_of_lines - current_line
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
	ld	ixl, a
; first_line_offset = 25 - amount_of_lines
	ex	de, hl
	push	bc
	pop	hl
	sbc	hl, de
	ex	de, hl
	jr	DoDisplayLines
DisplayLinesNormal:
; Else
; highlight_line = 12
; first_line_offset = 12 - current_line
	ld	hl, 12
	ld	a, l
	ld	ixl, a
	sbc	hl, de
	ex	de, hl
	
DoDisplayLines:
; BC = program length
; DE = current line relative to the first displayed line
; IXL = amount of lines before active line
	or	a, a
	sbc	hl, hl
	sbc	hl, de
	ld	(DEBUG_LINE_START), hl
	ld	a, 1
	ld	hl, (PROG_START)
	ld	bc, (PROG_SIZE)
GetBASICTokenLoopDispColon:
	ld	(Y_POS), a
	ld	(X_POS), 1
	bit	7, d
	jr	nz, GetBASICTokenLoop
	push	ix					; Line is visible; check whether a breakpoint is placed on this line
	push	hl
	push	de
	ld	hl, (DEBUG_LINE_START)
	add	hl, de
	call	IsBreakpointAtLine
	pop	de
	pop	hl
	jr	z, .nobreakpoint
	dec	(X_POS)
	ld	a, 0F8h
	call	PrintChar
.nobreakpoint:
	pop	ix					; We pop ix here to make sure the debug dot isn't highlighted: BreakpointsStart and 0xFF != 1
	ld	a, ':'
	call	PrintChar
GetBASICTokenLoop:
	ld	a, b					; Program's done!
	or	a, c
	jr	z, BASICProgramDone
	ld	a, (hl)
	cp	a, tEnter
	jr	z, AdvanceBASICLine
	bit	7, d					; Out of screen
	jr	nz, DontDisplayToken
	ld	a, (X_POS)
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
	jr	nz, GetBASICTokenLoop
	inc	hl
	dec	bc
	jr	GetBASICTokenLoop
AdvanceBASICLine:
	ld	a, (Y_POS)
	bit	7, d
	jr	nz, .cont
	dec	ixl
	add	a, 9
.cont:	inc	de
	inc	hl
	dec	bc
	cp	a, 229 - 7
	jr	c, GetBASICTokenLoopDispColon
BASICProgramDone:
	ld	ixl, 1
	ld	hl, SCREEN_START + (228 * lcdWidth / 8)
	ld	de, 0FFFFFFh
	ld	b, 5
FillBlackRowLoop:
	ld	(hl), de
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
	djnz	FillBlackRowLoop
	ld	(Y_POS), 231
	ld	(X_POS), 0
	ld	hl, StepString
	call	PrintString
BASICDebuggerKeyWait:
	call	GetKeyAnyFast
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
	jr	BASICDebuggerKeyWait
	
BASICDebuggerStep:
	scf
	sbc	hl, hl
	ld	(RESTORE_BREAKPOINT_LINE), hl
	ld	hl, (DEBUG_CURRENT_LINE)
	call	IsBreakpointAtLine
	jr	z, .nobreakpoint
	ld	(RESTORE_BREAKPOINT_LINE), hl
	call	RemoveBreakpointFromLine
.nobreakpoint:
; Insert temp breakpoint at the line after this line
	ld	hl, (DEBUG_CURRENT_LINE)
	inc	hl
	call	InsertTempBreakpointAtLine
	ld	hl, (LINES_START)
	ld	de, (DEBUG_CURRENT_LINE)
	inc	de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	ld	hl, (hl)
	add	hl, de
	or	a, a
	sbc	hl, de
	jr	z, .return
	inc	hl
	add	hl, de
	or	a, a
	sbc	hl, de
	jr	nz, .insertjump
; Insert temp breakpoint at the return address
	ld	hl, (tempSP)
	inc	hl
	inc	hl
	inc	hl
	ld	de, (hl)
	call	GetLineFromAddress
	call	InsertTempBreakpointAtLine
	jr	.return
.insertjump:
; Insert temp breakpiont at the jump address
	dec	hl
	ex	de, hl
	call	GetLineFromAddress
	call	InsertTempBreakpointAtLine
.return:
	ld	a, 1
	ld	(STEP_MODE), a
	call	DecreaseCallReturnAddress
	jp	Quit
BASICDebuggerStepOut:
BASICDebuggerStepOutContinue:
BASICDebuggerStepNext:
BASICDebuggerStepNextContinue:
BASICDebuggerStepOver:
BASICDebuggerStepOverContinue:
BASICDebuggerSwitchBreakpoint:
BASICDebuggerQuit:
	jp	MainMenu
	
; =======================================================================================
ViewVariables:
; B = amount of variables to display
; C = currently selected variable
; D = start offset
; E = amount of variables
	ld	hl, (VARIABLE_START)
	xor	a, a
	cp	a, (hl)
	jr	nz, FoundVariables
	call	GetKeyAnyFast
	jp	MainMenu
FoundVariables:
	ld	d, a
	ld	c, a
	jr	DontClearVariablesScreen
PrintAllVariables:
	exx
	call	ClearScreen
	exx
DontClearVariablesScreen:
	ld	hl, (VARIABLE_START)
	ld	e, (hl)
	inc	hl
	ld	b, 26				; Get amount of variables to display
	ld	a, b
	cp	a, e
	jr	c, MoreThan26Variables
	ld	b, e
MoreThan26Variables:
	ld	(Y_POS), 1
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
.loop:
	ld	c, 255				; Every variable name < 255 characters, so B won't get overwritten with cpir
	cpir
	djnz	.loop
	pop	bc
PrintVariableLoop:
	ld	(X_POS), 1
	call	PrintString
	ld	a, ':'
	call	PrintChar
	ld	(X_POS), 25
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
	jp	nz, MainMenu
; Edit the variable
	exx					; Save BC and DE for later
	ld	(X_POS), 25
	ld	b, 8
.loop:
	xor	a, a
	call	PrintChar
	djnz	.loop
	ld	(X_POS), 25
	ld	de, TempStringData
	ld	b, 8
	ld	c, 255 - 4
DisplayEmptyCursor:
	ld	a, 0E4h				; _
	call	PrintChar
GetVariableNumberLoop:
	call	GetKeyAnyFast
	ld	l, 01Ch
	bit	0, (hl)
	jr	nz, GetVariableNewNumber
	ld	l, 016h
	ld	a, (hl)
	and	a, 000001111b
	jr	z, Check258
	sub	a, 4				; A = A-(A!=4)
	add	a, 255
	sbc	a, c
	jr	GotVariableChar
Check258:
	ld	l, 018h
	ld	a, (hl)
	and	a, 000001110b
	jr	z, Check359
	add	a, c				; A = A+(A=4)
	sub	a, 255
	sbc	a, c
	jr	GotVariableChar
Check359:
	ld	l, 01Ah
	ld	a, (hl)
	and	a, 000001110b
	jr	z, GetVariableNumberLoop
	add	a, c				; A = A+1+(A!=4)
	sub	a, 254
	sbc	a, c
GotVariableChar:
	dec	(X_POS)
	add	a, '0'
	ld	(de), a
	inc	de
	call	PrintChar
	djnz	DisplayEmptyCursor
GetVariableNewNumber:
	xor	a, a
	ld	(de), a
	ld	de, TempStringData
	sbc	hl, hl
GetNumberCharLoop:
	ld	a, (de)
	or	a, a
	jr	z, OverwriteVariable
	sub	a, '0'
	add	hl, hl				; Num * 10 + new num
	push	hl
	pop	bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	bc, 0
	ld	c, a
	add	hl, bc
	inc	de
	jr	GetNumberCharLoop
OverwriteVariable:
	push	hl
	exx					; Restore BC and DE
	pop	hl
	ld	a, d				; Get current variable offset
	add	a, c
	ld	b, a
	add	a, a
	add	a, b
	sub	a, 080h
	ld	(VariableOffset2), a
	ld	ix, ICE_VARIABLES
VariableOffset2 = $+2
	ld	(ix - 080h), hl
	jp	PrintAllVariables
	
; =======================================================================================
ViewMemory:
	ld	hl, ramStart
	ld	c, 24
	ld	(Y_POS), 0
MemoryDrawLine:
	ld	a, (Y_POS)
	add	a, 10
	ld	(Y_POS), a
	ld	(X_POS), 0
	ld	a, 0F2h				; $
	call	PrintChar
	call	PrintHexInt
	inc	(X_POS)
	ld	b, 8
MemoryDrawLineOfBytes:
	ld	a, (hl)
	inc	hl
	call	PrintByte
	inc	(X_POS)
	djnz	MemoryDrawLineOfBytes
	ld	de, -8
	add	hl, de
	ld	b, 8
MemoryDrawLineOfChars:
	ld	a, (hl)
	inc	hl
	or	a, a
	jr	nz, .charnonzero
	ld	a, '.'
.charnonzero:
	cp	a, 0F4h
	jr	c, .chartoolarge
	ld	a, '.'
.chartoolarge:
	call	PrintChar
	djnz	MemoryDrawLineOfChars
	dec	c
	jr	nz, MemoryDrawLine
	call	GetKeyAnyFast
	jp	MainMenu
	
; =======================================================================================
ViewStrings:
	jp	MainMenu

; =======================================================================================
ViewLists:
	jp	MainMenu
	
; =======================================================================================
ViewSlots:
	ld	(X_POS), 0
	ld	(Y_POS), 0
	ld	hl, SlotOptionsString
	call	PrintString
	ld	b, 5
	ld	c, 1
	inc	(Y_POS)
GetSlotLoop:
	push	bc
	call	AdvanceLine
	ld	(X_POS), 0
	ld	a, c
	add	a, '0'
	call	PrintChar
	ld	a, ':'
	call	PrintChar
	ld	(X_POS), 28
	call	ti_GetSize
	ld	d, h
	ld	e, l
	add	hl, hl
	jr	c, SlotIsClosed
	ex.s	de, hl
	call	PrintInt
	ld	(X_POS), 5
	call	ti_GetVATPtr
	ld	a, (hl)
	or	a, a
	sbc	hl, hl
	ld	l, a
	call	PrintInt
	ld	(X_POS), 10
	call	ti_IsArchived
	ld	a, l
	or	a, a
	jr	z, .notarchived
	ld	a, '*'
	call	PrintChar
.notarchived:
	ld	hl, TempStringData
	push	hl
	call	ti_GetName
	pop	hl
	call	PrintString
	ld	(X_POS), 20
	ld	a, 0F2h
	call	PrintChar
	call	ti_GetDataPtr
	call	PrintHexInt
	ld	(X_POS), 34
	call	ti_Tell
	call	PrintInt
SlotIsClosed:
	pop	bc
	inc	c
	dec	b
	jp	nz, GetSlotLoop
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
	call	RestorePalette
	call	GetKeyAnyFast
	call	SetICEPalette
	jp	MainMenuSetLCDConfig
	
; =======================================================================================
ViewBuffer:
	ld	hl, 6
	add	hl, sp
	ld	hl, (hl)
	ld	(mpLcdCtrl), hl
	ld	hl, (mpLcdLpBase)
	ld	(mpLcdUpBase), hl
	call	RestorePalette
	call	GetKeyAnyFast
	call	SetICEPalette
	jp	MainMenuSetLCDConfig
	
; =======================================================================================
SafeExit:
	ld	sp, (tempSP)
.pop:
	pop	hl
	ld	de, ramStart
	or	a, a
	sbc	hl, de
	jr	nc, .pop
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
	ld	hl, (LABELS_START)
	xor	a, a
	cp	a, (hl)
	jr	z, NoLabelsFound
	ld	d, a
	ld	c, a
PrintAllLabels:
	exx
	call	ClearScreen
	exx
	ld	hl, (LABELS_START)
	ld	e, (hl)
	inc	hl
	ld	b, 26
	ld	a, b
	cp	a, e
	jr	c, MoreThan26Labels
	ld	b, e
MoreThan26Labels:
	ld	(Y_POS), 1
	xor	a, a
	cp	a, d
	jr	z, PrintLabelLoop
	push	bc
	ld	b, d
.skip:
	ld	c, 255
	cpir
	inc	hl
	inc	hl
	inc	hl
	djnz	.skip
	pop	bc
PrintLabelLoop:
	ld	(X_POS), 1
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
	ld	hl, (LABELS_START)
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
	ld	hl, (tempSP)
	ld	(hl), de
	jp	Quit
NoLabelsFound:
	call	GetKeyAnyFast
	jp	MainMenu
	
; =======================================================================================
; ============================== Routines are starting here =============================
; =======================================================================================

InsertTempBreakpointAtLine:
	inc	(AMOUNT_OF_TEMP_BREAKPOINTS)
	ld	a, BREAKPOINT_TYPE_TEMP
	db	006h					; ld b, *
InsertFixedBreakpointAtLine:
	assert	BREAKPOINT_TYPE_FIXED = 0
	xor	a, a
InsertBreakpointAtLine:
	ld	b, a
	call	IsBreakpointAtLine
	ld	a, b
	jr	z, DoInsertBreakpoint
	or	a, a
	ret	z
DoInsertBreakpoint:
	ex	de, hl
	ld	hl, (LINES_START)
	ld	hl, (hl)				; HL = amount_of_lines
	or	a, a
	sbc	hl, de
	ret	z
	ld	ix, BreakpointsStart
	ld	c, (AMOUNT_OF_BREAKPOINTS)
	inc	(AMOUNT_OF_BREAKPOINTS)
	ld	b, BREAKPOINT_SIZE
	mlt	bc
	add	ix, bc
	ld	(ix + BREAKPOINT_TYPE), a
	ld	(ix + BREAKPOINT_LINE), de
	ld	hl, (LINES_START)
	inc	hl
	inc	hl
	inc	hl
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	add	hl, de
	ld	hl, (hl)
	ld	(ix + BREAKPOINT_ADDRESS), hl	; Program pointer
	lea	de, ix + BREAKPOINT_CODE
	ld	bc, 4
	ldir
	dec	hl
	dec	hl
	dec	hl
	ld	de, icedbg_open
	ld	(hl), de
	dec	hl
	ld	(hl), 0CDh			; CALL icedbg_open
	ret

RemoveBreakpointFromLine:
	call	IsBreakpointAtLine
	ret	z
RemoveBreakpoint:
	ld	de, (ix + BREAKPOINT_ADDRESS)
	lea	hl, ix + BREAKPOINT_CODE
	ld	bc, 4
	ldir
	dec	(AMOUNT_OF_BREAKPOINTS)
	dec	a				; A = 1 at last breakpoint
	ret	z
	ld	c, a
	ld	b, BREAKPOINT_SIZE
	mlt	bc
	add	ix, bc
	lea	de, ix - BREAKPOINT_SIZE
	lea	hl, ix
	ldir
	ret

GetLineFromAddress:
; Inputs:
;   DE = address
; Returns:
;   HL = line number

	ld	hl, (STARTUP_BREAKPOINTS)
	ld	bc, -6
	exx
	ld	hl, (LINES_START)
	ld	hl, (hl)
.loop:	exx
	add	hl, bc
	push	hl
	ld	hl, (hl)
	scf
	sbc	hl, de
	pop	hl
	exx
	dec	hl
	jr	nc, .loop
	ret

IsBreakpointAtLine:
; Inputs:
;   HL = line number
; Outputs:
;   Z if not found
;   NZ if found
;   A = index of found breakpoint (starting at the end)

	ld	a, (AMOUNT_OF_BREAKPOINTS)
	or	a, a
	ret	z
	ld	ix, BreakpointsStart
.loop:	ld	de, (ix + BREAKPOINT_LINE)
	or	a, a
	sbc	hl, de
	add	hl, de
	jr	z, .found
	lea	ix, ix + BREAKPOINT_SIZE
	dec	a
	jr	nz, .loop
	ret
.found:	dec	a
	inc	a
	ret
	
RestorePaletteUSB:
; Restore palette, usb area, variables and registers
	ld	hl, usbArea
	ld	(hl), 0
	push	hl
	pop	de
	inc	de
	ld	bc, 14305
	ldir
RestorePalette:
	ld	de, mpLcdPalette
	lea	hl, PALETTE_ENTRIES_BACKUP
	ld	bc, 4
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
	ld	(Y_POS), a
	ld	(X_POS), 0
	ld	a, '>'
	call	PrintChar
	dec	(X_POS)
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
	scf
	ret
PressedUp:
	dec	d
	ret
PressedDown:
	inc	d
	ret
	
TempStringData:
	rb	9
	
ClearScreen:
	ld	hl, SCREEN_START
	ld	(hl), 0
	push	hl
	pop	de
	inc	de
	ld	bc, lcdWidth * lcdHeight / 8 - 1
	ldir
	ret
	
SetLCDConfig:
	ld	a, lcdBpp1
	ld	hl, mpLcdCtrl
	ld	(hl), a
	inc	hl
	set	2, (hl)
	ld	hl, SCREEN_START
	ld	(mpLcdUpbase), hl
	ret
	
SetICEPalette:
	ld	hl, mpLcdPalette
	lea	de, PALETTE_ENTRIES_BACKUP
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
	ret
	
DecreaseCallReturnAddress:
	ld	hl, (tempSP)
	ld	de, (hl)
	dec	de
	dec	de
	dec	de
	dec	de					; DE = call pointer
	ld	(hl), de
	ret
	
GetKeyAnyFast:
	ld	hl, mpKeyRange + (keyModeAny shl 8)
	ld	(hl), h
	ld	l, keyIntStat
	xor	a, a
	ld	(hl), keyIntKeyPress
.wait1:
	bit	bKeyIntKeyPress, (hl)
	jr	z, .wait1
	ld	l, a
	ld	(hl), keyModeScanOnce
.wait2:
	cp	a, (hl)
	jr	nz, .wait2
	ld	a, 20
	jp	_DelayTenTimesAms
	
AdvanceLine:
	ld	a, (Y_POS)
	add	a, 9
	ld	(Y_POS), a
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
	jr	c, .charisnum1
	add	a, 'A' - '9' - 1
.charisnum1:
	add	a, '0'
	call	PrintChar
	ld	a, d
	and	a, 00Fh
	cp	a, 10
	jr	c, .charisnum2
	add	a, 'A' - '9' - 1
.charisnum2:
	add	a, '0'
	
PrintChar:
	push	hl
	push	de
	push	bc
	ld	c, a
	ld	a, (X_POS)
	cp	a, 40
	jr	z, DontDisplayChar
	or	a, a
	sbc	hl, hl
	ld	l, a
	inc	(X_POS)
	ld	e, (Y_POS)
	ld	d, lcdWidth / 8
	mlt	de
	add	hl, de
	ld	de, SCREEN_START
	add	hl, de
	ex	de, hl
	ld	hl, _DefaultTIFontData
	ld	b, 8
	ld	ixh, b
	mlt	bc
	add	hl, bc
	ld	bc, (lcdWidth / 8) - 1
PutCharLoop:
	ld	a, ixl
	or	a, a
	ld	a, (hl)
	jr	nz, .notinvert
	cpl
.notinvert:
	ld	(de), a
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
	db	"Step through code", 0
	db	"View/edit variables", 0
	db	"View/edit memory", 0
	db	"View OS strings", 0
	db	"View OS lists", 0
	db	"View opened slots", 0
	db	"View screen", 0
	db	"View buffer", 0
	db	"Jump to label", 0
	db	"Save exit program", 0
	db	"Quit", 0
StepString:
	db	"Step  StepOver   StepNext  StepOut  Quit", 0
SlotOptionsString:
	db	"Slot Type Name      DataPtr Size  Offset", 0

_DefaultTIFontData:
; To get the font data, load font.pf into 8x8 ROM PixelFont Editor, export it as an assembly include file,
; and replace the regex "0x(..)" with "0\1h" to make it spasm-compatible
include 'font.asm'

virtual at iy
	PROG_SIZE:			dl 0
	PROG_START:			dl 0
	DBG_PROG_SIZE:			dl 0
	DBG_PROG_START:			dl 0
	PALETTE_ENTRIES_BACKUP:		rb 4
	INPUT_LINE:			dl 0
	X_POS:				db 0
	Y_POS:				db 0
	VARIABLE_START:			dl 0
	LINES_START:			dl 0
	STARTUP_BREAKPOINTS:		dl 0
	LABELS_START:			dl 0
	AMOUNT_OF_BREAKPOINTS:		db 0
	DEBUG_CURRENT_LINE:		dl 0
	DEBUG_LINE_START:		dl 0
	STEP_MODE:			db 0
	AMOUNT_OF_TEMP_BREAKPOINTS:	db 0
	RESTORE_BREAKPOINT_LINE:	dl 0
	load iy_data: $ - $$ from $$
end virtual
iy_base db iy_data

BreakpointsStart:
	rb	BREAKPOINT_SIZE * 100