;-------------------------------------------------------------------------------
include '../include/library.inc'
include '../include/include_library.inc'
;-------------------------------------------------------------------------------

library 'ICEDEBUG', 1

;-------------------------------------------------------------------------------
include_library '../include/fileioc.asm'
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; v1 functions
;-------------------------------------------------------------------------------
	export icedbg_setup
	export icedbg_open
	
VERSION_MAJOR      := 0
VERSION_MINOR      := 1
	
ICE_VARIABLES      := 0D13F56h				; See src/main.h
AMOUNT_OF_OPTIONS  := 11

BREAKPOINT_SIZE    := 11
BREAKPOINT_TYPE    := 0
BREAKPOINT_LINE    := 1
BREAKPOINT_ADDRESS := 4
BREAKPOINT_CODE    := 7

BREAKPOINT_TYPE_FIXED  := 0
BREAKPOINT_TYPE_TEMP   := 1

SUBPROGRAM_SIZE    := 14
SUBPROGRAM_NAME    := 0
SUBPROGRAM_START   := 8
SUBPROGRAM_END     := 10
SUBPROGRAM_CRC     := 12

LINE_SIZE          := 7
LINE_PROG_INDEX    := 0
LINE_ADDR_OFFSET   := 1
LINE_LOCAL_LINE    := 3
LINE_JUMP_OFFSET   := 5

STEP_RETURN        := 1
STEP               := 2
STEP_OVER          := 3
STEP_NEXT          := 4
STEP_OUT           := 5
	
icedbg_setup:
	push	de
	call	_HomeUp
	call	_ClrLCDFull
	pop	de
	ex	de, hl					; Input is DBG file
	call	_Mov9ToOP1
	call	_ChkFindSym				; Find program, must exists
	jq	c, NoDBGAppvar
	call	_ChkInRAM
	ex	de, hl
	jq	nc, DbgVarInRAM
	ld	bc, 9					; Get data pointer from flash
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
DbgVarInRAM:
	inc	hl
	inc	hl
	ld	(DBGProgStart), hl
	ld	a, (hl)
	cp	a, VERSION_MAJOR
	jq	nz, WrongVersion
	inc	hl
	ld	a, (hl)
	cp	a, VERSION_MINOR
	jq	nz, WrongVersion
	inc	hl
	ld	(SUBPROGRAMS_START - iy + iy_base), hl		; Sorry, I can't use iy!
	ld	b, (hl)
	inc	hl
	ld	iy, ProgramsPointers
.findloop:
	push	bc
	push	hl
	dec	hl
	call	_Mov9ToOP1
	ex	de, hl
	ld	(hl), 0
	call	_FindProgSym
	jq	c, NoSRCProgram
	call	_ChkInRAM
	ex	de, hl
	ld	bc, 0
	jq	nc, .inram
	ld	c, 9
	add	hl, bc
	ld	c, (hl)
	add	hl, bc
	inc	hl
.inram:
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	(iy), hl
	ld	(iy + 3), bc
	lea	iy, iy + 6
	ex	de, hl
	call	GetCRC
	ex	de, hl
	pop	hl
	ld	c, SUBPROGRAM_CRC
	add	hl, bc
	ld	a, (hl)
	cp	a, e
	jq	nz, CRCNotMatch
	inc	hl
	ld	a, (hl)
	cp	a, d
	jq	nz, CRCNotMatch
	inc	hl
	pop	bc
	djnz	.findloop
	ld	iy, iy_base
	ld	c, b
	dec	bc
	ld	(RESTORE_BREAKPOINT_LINE), bc		; -1 if no restore
	ld	(VARIABLE_START), hl
	xor	a, a
	ld	b, (hl)					; Amount of variables
	inc	hl
	cp	a, b
	jq	z, NoVariablesSkip
SkipVariableLoop0:
	ld	c, 255					; Prevent decrementing B; a variable name won't be longer than 255 bytes
	cpir						; Skip variable name
	djnz	SkipVariableLoop0
NoVariablesSkip:
	ld	(STEP_MODE), b				; No stepping mode currently
	ld	(LINES_START), hl			; Start of lines data
	ld	de, (hl)				; Amount of lines
	inc	hl
	inc	hl
	inc	hl
repeat LINE_SIZE
	add	hl, de
end repeat
	ld	(STARTUP_BREAKPOINTS), hl		; Start of startup breakpoints
	ld	c, (hl)					; Amount of startup breakpoints
	ld	b, 3
	mlt	bc
	inc	hl
	add	hl, bc
	ld	(LABELS_START), hl			; Start of labels
	call	ti_CloseAll				; Close all FILEIOC slots
	ld	hl, ramStart
	ld	(MEMORY_START_ADDR), hl
	ld	hl, (STARTUP_BREAKPOINTS)
	ld	a, (hl)
	or	a, a
	ret	z					; No startup breakpoints found
	inc	hl
	push	ix
InsertBreakpointLoop:
	push	hl
	ex	af, af'
	ld	hl, (hl)				; Get startup breakpoint line number
	call	InsertFixedBreakpointAtLine		; And insert it
	ex	af, af'
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	dec	a
	jq	nz, InsertBreakpointLoop		; Loop through all startup breakpoints
	pop	ix
	ret

NoSRCProgram:
	ld	hl, NoSRCProgramString
	pop	bc
DispStringOP1:
	pop	bc
	call	_PutS
	ld	hl, OP1 + 1
	call	_PutS
	call	_GetKey
	scf
	ret
CRCNotMatch:
	ld	hl, CRCNotMatchString
	jq	DispStringOP1
WrongVersion:
	ld	hl, WrongVersionString
DispStringReturn:
	call	_PutS
	call	_NewLine
	ld	hl, RecompileString
	call	_PutS
	call	_GetKey
	scf
	ret
NoDBGAppvar:
	ld	hl, NoDBGAppvarString
	jq	DispStringReturn
	
icedbg_open:
; This is the breakpoint handler
; See breakpoints.txt for some more information

	di						; Backup all registers and LCD control data
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
	call	SetICEPalette				; Setup the palette
	call	RemoveTempBreakpoints
	ld	hl, (RESTORE_BREAKPOINT_LINE)		; Check if we need to restore a breakpoint (line != -1)
	inc	hl
	add	hl, de
	or	a, a
	sbc	hl, de
	dec	hl
	call	nz, InsertFixedBreakpointAtLine		; If so, restore it
	scf						; And clear it as well
	sbc	hl, hl
	ld	(RESTORE_BREAKPOINT_LINE), hl
	ld	a, (STEP_MODE)				; Check if we were stepping through code
	or	a, a
	jq	z, MainMenuSetLCDConfig
assert STEP_RETURN = 1
	dec	a
	ld	(STEP_MODE), 0				; Clear the step mode
	call	z, DecreaseCallReturnAddress
	jq	z, Quit
	jq	StepCodeSetup				; And continue with debugging
	
MainMenuSetLCDConfig:
	call	SetLCDConfig
MainMenu:
	call	ClearScreen
	ld	b, AMOUNT_OF_OPTIONS			; Display all the main menu options
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
	call	SelectOption				; And select one of them
	jq	nz, Quit				; If pressed Quit, quit the debugger

	ld	a, c
	call	ClearScreen
	or	a, a					; Jump to the selected option
	jq	z, StepCode
	dec	a
	jq	z, ViewVariables
	dec	a
	jq	z, ViewMemory
	dec	a
	jq	z, ViewStrings
	dec	a
	jq	z, ViewLists
	dec	a
	jq	z, ViewSlots
	dec	a
	jq	z, ViewScreen
	dec	a
	jq	z, ViewBuffer
	dec	a
	jq	z, JumpLabel
	dec	a
	jq	z, SafeExit
	
Quit:
	ld	a, (STEP_MODE)				; If we were stepping, we need to decrease the returning address, because it 
							; was called from a (temp) breakpoint, where the code is temporarily replaced 
							; with a "call <debugger>", but we do need to run the underlying code.
	or	a, a
	call	nz, DecreaseCallReturnAddress
	call	RestorePalette			; Restore palette, USB area, LCD control and registers, and return
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
StepCodeSetup:
	call	ClearScreen				; Setup things - this isn't done by the breakpoint handler
	call	SetLCDConfig
StepCode:
	call	RemoveTempBreakpoints
	ld	hl, (tempSP)				; Get the call return address
	ld	de, (hl)
	dec	de
	dec	de
	dec	de
	dec	de					; DE = call address
	call	GetLineFromAddress			; Get the line number
	ld	(DEBUG_CURRENT_LINE), hl
	inc	hl
	ex	de, hl					; DE = input line number
	
; See docs/subprograms algorithm.c for the algorithm

	ld	ix, ProgramsPointers
	ld	iy, (SUBPROGRAMS_START)
	ld	c, (iy)
	ld	a, c
	ld	b, 6
	mlt	bc
	add	ix, bc
	ld	c, a
	ld	b, SUBPROGRAM_SIZE
	mlt	bc
	inc	bc
	add	iy, bc
	ld	c, a
.loop1:
	lea	ix, ix - 6
	lea	iy, iy - SUBPROGRAM_SIZE
	dec	a
	jq	z, .found
	ld	hl, (iy + SUBPROGRAM_START)
	scf
	sbc.s	hl, de
	jq	nc, .loop1
	ld	hl, (iy + SUBPROGRAM_END)
	or	a, a
	sbc.s	hl, de
	jq	c, .loop1
.found:
	ld	(SubprogramIndex1), a
	ld	(SubprogramIndex2), a
	ld	hl, (ix)
	ld	(PROG_START - iy + iy_base), hl
	ld	hl, (ix + 3)
	ld	(PROG_SIZE - iy + iy_base), hl
	push	iy
	call	_ZeroOP1
	lea	hl, iy + SUBPROGRAM_NAME - 1
	call	_Mov9ToOP1
	ld	iy, iy_base
	ld	hl, ProgramString
	call	PrintString
	ld	hl, OP1 + 1
	call	PrintString
	pop	iy
	ld	de, (iy + SUBPROGRAM_START)
	ex.s	de, hl
	call	GlobalToLocalLineDec
	push	hl
	ld	de, (iy + SUBPROGRAM_END)
	ex.s	de, hl
	call	GlobalToLocalLineDec
	pop	de
	or	a, a
	sbc	hl, de
	inc	hl
	push	hl
	ld	iy, iy_base
	ld	(DEBUG_AMOUNT_OF_LINES), hl
	ld	hl, (DEBUG_CURRENT_LINE)
	call	GlobalToLocalLine
	ex	de, hl
	pop	hl
	ld	bc, 14					; If current line <= 13 or amount of lines <= 24
	ld	a, d					;    current line <= 13
	or	a, a
	jq	nz, CheckClipBottom
	ld	a, e
	cp	a, c
	jq	c, ClipAtTop
CheckAmountOfLines:
	ld	c, 25					;    amount of lines <= 24
	sbc	hl, bc
	add	hl, bc
	jq	nc, CheckClipBottom
ClipAtTop:
	ld	de, 0					;       first line offset = 0
	ld	ixl, a					;       highlight_line = current line
	jq	DoDisplayLines				;       Display them code!
	
CheckClipBottom:
	sbc	hl, de					; Else If amount of lines - current line <= 13
							;    HL = amount of lines - current line
	ld	c, 14
	sbc	hl, bc
	add	hl, bc
	jq	nc, DisplayLinesNormal
	add	hl, de
	ld	a, 24					;    highlight_line = 24 - (amount of lines - current line)
							;                   = 24 + current line - amount of lines
	add	a, e
	sub	a, l
	ld	ixl, a
	ex	de, hl					;    first line offset = 24 - amount of lines
	ld	hl, 24
	sbc	hl, de
	ex	de, hl
	jq	DoDisplayLines
DisplayLinesNormal:
	ld	hl, 12					; Else
	ld	a, l					;    highlight line = 12
	ld	ixl, a
	sbc	hl, de					;    first line offset = 12 - current line
	ex	de, hl
	
DoDisplayLines:						; IXL = amount of lines before highlighted line
	or	a, a
	sbc	hl, hl
	sbc	hl, de					; DE = offset to first displayed line
	ld	(DEBUG_LINE_START), hl			; ~DE = first displayed line number
	ld	a, 10					; Starting Y position
	ld	hl, (PROG_START)			; HL = pointer to source program data
	ld	bc, (PROG_SIZE)				; BC = length of program data
GetBASICTokenLoopDispColon:
	ld	(Y_POS), a
	ld	(X_POS), 1				; Always reset X position
	bit	7, d					; If DE < 0, don't display anything
	jq	nz, GetBASICTokenLoop
	push	ix					; Line is visible; check whether a breakpoint is placed on this line
	push	hl
	push	de
	ld	hl, (DEBUG_LINE_START)			; Line = offset + start
	add	hl, de
SubprogramIndex1 = $+1
	ld	a, 0
	call	LocalToGlobalLine
	call	IsBreakpointAtLine			; Check if there's a breakpoint placed at this global line
	pop	de
	pop	hl
	ld	a, ':'
	jq	z, .nobreakpoint
	ld	a, 0F8h					; If so, display a dot instead of the colon
.nobreakpoint:
	ld	ixl, a
	call	PrintChar
	pop	ix					; We pop ix here to make sure the debug dot isn't highlighted: BreakpointsStart and 0xFF != 1
GetBASICTokenLoop:
	ld	a, b					; Program's done!
	or	a, c
	jq	z, BASICProgramDone
	ld	a, (hl)					; Check if it's an enter, if so, we need to advance a line
	cp	a, tEnter
	jq	z, AdvanceBASICLine
	bit	7, d					; Out of screen, no need to be displayed
	jq	nz, DontDisplayToken
	ld	a, (X_POS)				; Out of screen as well, stop displaying the tokens left on this line
	cp	a, 40
	jq	z, DontDisplayToken
	push	bc					; If the token is visible, convert to characters and display it
	push	de
	push	hl
	push	iy
	ld	iy, flags
	call	_Get_Tok_Strng
	pop	iy
	ld	hl, OP3
	call	PrintString
	pop	hl
	pop	de
	pop	bc
DontDisplayToken:
	ld	a, (hl)					; Advance a BASIC token
	call	_IsA2ByteTok
	inc	hl
	dec	bc
	jq	nz, GetBASICTokenLoop
	inc	hl
	dec	bc
	jq	GetBASICTokenLoop
AdvanceBASICLine:
	ld	a, (Y_POS)				; If DE < 0, Y_POS + 9 -> Y_POS
	bit	7, d
	jq	nz, .cont
	dec	ixl
	add	a, 9
.cont:	inc	de					; Always increase DE
	inc	hl
	dec	bc
	cp	a, 229 - 7				; Display until the 25th row
	jq	c, GetBASICTokenLoopDispColon
BASICProgramDone:
	ld	ixl, 1					; Prevent anything else to be displayed inverted
	ld	hl, SCREEN_START - 1			; Location to draw a black line
	ld	a, l
	or	a, 7
	ld	l, a
	inc	hl
	ld	de, 228 * lcdWidth / 8
	add	hl, de
	ld	de, 0FFFFFFh				; FF color
	ld	b, 5
FillBlackRowLoop:					; Fill a horizontal line with black
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
	ld	(Y_POS), 231				; And display the "Step..." text
	ld	(X_POS), 0
	ld	hl, StepString
	call	PrintString
	ld	c, 1
BASICDebuggerDisplayCursor:
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
BASICDebuggerKeyWait:
	call	GetKeyAnyFast				; Wait until any key is pressed
	cp	a, skUp
	jq	z, BASICDebuggerKeyUp
	cp	a, skDown
	jq	z, BASICDebuggerKeyDown
	cp	a, skEnter
	jq	z, BASICDebuggerSwitchBreakpoint
	cp	a, skClear
	jq	z, BASICDebuggerRun
	sub	a, skGraph
	jq	z, BASICDebuggerRun
	dec	a
	jq	z, BASICDebuggerStepOut
	dec	a
	jq	z, BASICDebuggerStepNext
	dec	a
	jq	z, BASICDebuggerStepOver
	dec	a
	jq	z, BASICDebuggerStep
	jq	BASICDebuggerKeyWait
	
BASICDebuggerKeyUp:
	ld	a, c
	dec	a
	jq	z, BASICDebuggerKeyWait
	dec	c
	jq	BASICDebuggerMoveCursor
BASICDebuggerKeyDown:
	ld	b, 25
	ld	hl, (DEBUG_AMOUNT_OF_LINES)
	inc	hl					; Remember the "PROGRAM:.." text at the bottom row
	ld	a, h
	or	a, a
	jq	nz, .docheck
	ld	a, b
	cp	a, l
	jq	c, .docheck
	ld	b, l
.docheck:
	ld	a, b
	cp	a, c
	jq	z, BASICDebuggerKeyWait
	inc	c
BASICDebuggerMoveCursor:
	dec	(X_POS)
	xor	a, a
	call	PrintChar
	jq	BASICDebuggerDisplayCursor
	
BASICDebuggerSwitchBreakpoint:
	push	bc
	ld	hl, (DEBUG_LINE_START)
	dec	c
	ld	b, 1
	mlt	bc
	add	hl, bc
SubprogramIndex2 = $+1
	ld	a, 0
	call	LocalToGlobalLine
	ld	de, (LINES_START)
	ex	de, hl
repeat LINE_SIZE
	add	hl, de
end repeat
	ld	de, LINE_ADDR_OFFSET + 3
	add	hl, de
	ld	hl, (hl)
	ex.s	hl, de
	ld	hl, userMem + 1
	add	hl, de
	ex	de, hl
	call	GetLineFromAddress
	push	hl
	call	GlobalToLocalLine
	ld	de, (DEBUG_LINE_START)
	or	a, a
	sbc	hl, de
	inc	l
	ld	b, a
	ld	a, l
	add	a, a
	add	a, a
	add	a, a
	add	a, l
	inc	a
	ld	(Y_POS), a
	pop	hl
	call	IsBreakpointAtLine
	jq	z, .insert
	call	RemoveBreakpointFromLine
	ld	a, ':'
	jq	.dispchar
.insert:
	call	InsertFixedBreakpointAtLine
	ld	a, 0F8h
.dispchar:
	ld	(X_POS), 1
	call	PrintChar
	dec	(X_POS)
	pop	bc
	jq	BASICDebuggerDisplayCursor
	
BASICDebuggerRun:
	ld	a, STEP_RETURN
	jq	InsertStepMode
BASICDebuggerStepOut:
	ld	a, STEP_OUT
	jq	InsertStepMode
BASICDebuggerStepNext:
	ld	a, STEP_NEXT
	jq	InsertStepMode
BASICDebuggerStepOver:
	ld	a, STEP_OVER
	jq	InsertStepMode
BASICDebuggerStep:
	ld	a, STEP
InsertStepMode:
	ld	(STEP_MODE), a				; Set step mode
	scf						; Empty restore breakpoint line
	sbc	hl, hl
	ld	(RESTORE_BREAKPOINT_LINE), hl
	ld	hl, (DEBUG_CURRENT_LINE)
	call	IsBreakpointAtLine			; If a breakpoint is placed at this line, we need to temporarily remove it
	jq	z, .nobreakpoint
	ld	(RESTORE_BREAKPOINT_LINE), hl
	call	RemoveBreakpointFromLine
.nobreakpoint:

; Here we need to check which step mode uses which temp breakpoints:
;              | Next line | Jump address  | Return address |
; -------------|-----------|---------------|----------------|
; Step return: |     0     |        X      |       -1       |
; Step:        |     0     |        X      |       -1       |
; Step over:   |     0     | X if not call |       -1       |
; Step next:   |     0     |               |                |
; Step out:    |           |               |     Always     |
; 
; Jump address options:
;   0:  line without jump, call or return
;   -1: return
;   X:  jump address

	ld	a, (STEP_MODE)
	cp	a, STEP_OUT
	jq	z, .insertreturnaddr
	ld	hl, (DEBUG_CURRENT_LINE)		; Insert temp breakpoint at the line after this one
	inc	hl
	call	InsertTempBreakpointAtLine
	ld	hl, (LINES_START)			; Get the jump address of the line
	ld	de, (DEBUG_CURRENT_LINE)
repeat LINE_SIZE
	add	hl, de
end repeat
	ld	de, LINE_JUMP_OFFSET + 3
	add	hl, de
	ld	de, (hl)
	ex.s	de, hl
	ld	a, h					; If it's zero, don't do anything with it
	or	a, l
	jq	z, .return
	inc	hl					; If it's not a -1, it's a real jump
	ld	a, h
	and	a, l
	inc	a
	jq	nz, .insertjump
	ld	a, (STEP_MODE)
	cp	a, STEP_NEXT
	jq	z, .return
.insertreturnaddr:
	ld	hl, (tempSP)				; It's -1, so the line is a Return -> place temp breakpoint at return address
	inc	hl
	inc	hl
	inc	hl
	ld	de, (hl)				; Return address
	call	GetLineFromAddress
	call	InsertTempBreakpointAtLine
	jq	.return
.insertjump:
	ld	a, (STEP_MODE)
assert STEP < STEP_NEXT & STEP_OVER < STEP_NEXT
	cp	a, STEP_NEXT
	jq	nc, .return
	dec	hl					; Place temp breakpoint at the jump address
	ld	de, userMem + 1
	add	hl, de
	ex	de, hl
	call	GetLineFromAddress
	call	InsertTempBreakpointAtLine
.return:
	ld	a, (STEP_MODE)
	dec	a
	jq	z, MainMenu
	jq	Quit
	
; =======================================================================================
ViewVariables:
	ld	hl, (VARIABLE_START)			; Get amount of variables
	xor	a, a
	cp	a, (hl)
	jq	nz, FoundVariables
	call	GetKeyAnyFast				; If none found, wait and return
	jq	MainMenu
FoundVariables:
	ld	d, a					; D = start offset of selected item in list
	ld	c, a					; C = currently selected variable
	jq	DontClearVariablesScreen
PrintAllVariables:
	exx						; Clear the screen to display all variables again
	call	ClearScreen
	exx
DontClearVariablesScreen:
	ld	hl, (VARIABLE_START)			; Get the amount of variables
	ld	e, (hl)					; E = amount of variables
	inc	hl
	ld	b, 26					; B = amount of variables to display
	ld	a, b					; Check if we have more than 26 variables
	cp	a, e
	jq	c, MoreThan26Variables
	ld	b, e					; If not, display E variables max
MoreThan26Variables:
	ld	(Y_POS), 1				; We start displaying at the top of the screen
	ld	a, d					; Get variable IX offset
	add	a, a
	add	a, d
	sub	a, 3 + 080h				; The variable offset is increased by 3 before getting the value, so 3 + <max variable offset>
	ld	(VariableOffset), a
	xor	a, a					; Check if we need to skip any variables after scrolling down
	cp	a, d
	jq	z, PrintVariableLoop
	push	bc
	ld	b, d					; B = amount of variables to skip
.loop:	ld	c, 255					; Every variable name < 255 characters, so B won't get overwritten with cpir
	cpir
	djnz	.loop
	pop	bc
PrintVariableLoop:					; Print the on-screen variables
	ld	(X_POS), 1				; Of course we display at the left of the screen
	call	PrintString				; HL points to the variable name
	ld	a, ':'
	call	PrintChar
	ld	(X_POS), 32
	ld	a, 0F2h					; $
	call	PrintChar
	push	hl
	ld	a, (VariableOffset)			; Advance the variable offset
	add	a, 3
	ld	(VariableOffset), a
	ld	ix, ICE_VARIABLES
VariableOffset = $+2
	ld	hl, (ix - 080h)
	push	de
	call	PrintHexInt				; Print the hex value
	pop	de
	ld	(X_POS), 22
	call	PrintInt				; And print the value!
	pop	hl
	call	AdvanceLine
	djnz	PrintVariableLoop
	call	SelectOption				; Select a variable from the list
	jq	nc, PrintAllVariables			; If we need to scroll, display it all over again
	jq	nz, MainMenu				; We pressed Clear, so return
							; Now we can say the user pressed Enter, so edit the variable
	push	bc					; Save BC and DE for later
	push	de
	ld	(X_POS), 22
	ld	b, 8
.loop:							; Clear the displayed value
	xor	a, a
	call	PrintChar
	djnz	.loop
	ld	(X_POS), 22
	ld	de, TempStringData
	ld	b, 8
	ld	c, 255 - 4
DisplayEmptyCursor:					; Display underscore as a "cursor"
	ld	a, 0E4h					; _
	call	PrintChar
GetVariableNumberLoop:					; Wait for a number/Enter to be pressed
	push	bc
	call	GetKeyAnyFast
	cp	a, skEnter				; We pressed Enter so get the value and replace it
	jq	z, GetVariableNewNumber
	ld	hl, NumbersKeyPresses + 6
	ld	bc, 10
	cpir
	jq	nz, GetVariableNumberLoop
	dec	(X_POS)					; If a number is pressed, display it and the cursor again
	ld	a, c
	add	a, '0'
	ld	(de), a
	inc	de
	call	PrintChar
	pop	bc
	djnz	DisplayEmptyCursor			; Max 8 numbers -> FFFFFFh = 8 chars
GetVariableNewNumber:
	pop	bc
	xor	a, a					; Zero terminate the string
	ld	(de), a
	ld	de, TempStringData
	sbc	hl, hl
GetNumberCharLoop:
	ld	a, (de)
	or	a, a
	jq	z, OverwriteVariable			; We got the number, so actually replace the variable
	sub	a, '0'
	add	hl, hl					; Num * 10
	push	hl
	pop	bc
	add	hl, hl
	add	hl, hl
	add	hl, bc
	ld	bc, 0					; Num = num + new char
	ld	c, a
	add	hl, bc
	inc	de
	jq	GetNumberCharLoop
OverwriteVariable:
	pop	de					; Restore BC and DE
	pop	bc
	ld	a, d					; Get current variable offset
	add	a, c
	ld	b, a
	add	a, a
	add	a, b
	sub	a, 080h
	ld	(VariableOffset2), a
	ld	ix, ICE_VARIABLES
VariableOffset2 = $+2
	ld	(ix - 080h), hl				; And store it!
	jq	PrintAllVariables			; Display all the variables again
	
; =======================================================================================
ViewMemory:
	ld	hl, (MEMORY_START_ADDR)
	ld	b, 0
	ld	c, 0
ViewMemoryPartClearScreen:
	exx
	call	ClearScreen
	exx
	push	hl
	push	bc
	ld	c, 23
	ld	(Y_POS), 5
MemoryDrawLine:
	ld	(X_POS), 0
	ld	a, 0F2h					; $
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
	jq	nz, .charnonzero
	ld	a, '.'
.charnonzero:
	cp	a, 0F4h
	jq	c, .chartoolarge
	ld	a, '.'
.chartoolarge:
	call	PrintChar
	djnz	MemoryDrawLineOfChars
	ld	a, (Y_POS)
	add	a, 10
	ld	(Y_POS), a
	dec	c
	jq	nz, MemoryDrawLine
	pop	bc
MemoryDisplayCursor:
	ld	hl, SCREEN_START - 1
	ld	a, l
	or	a, 7
	ld	l, a
	inc	hl
	ld	a, c
	add	a, a
	ld	e, a
	add	a, a
	add	a, a
	add	a, e
	add	a, 8 + 5
	ld	e, a
	ld	d, lcdWidth / 8
	mlt	de
	add	hl, de
	ld	a, b
	add	a, a
	add	a, b
	add	a, 8
	ld	e, a
	ld	d, 0
	add	hl, de
	ld	(hl), 0FFh
.wait:
	call	GetKeyAnyFast
	exx
	ld	hl, NumbersKeyPresses
	ld	bc, 16
	cpir
	jq	z, MemoryHexadecimalPressed
	exx
	cp	a, skClear
	jq	z, .return
	cp	a, skUp
	jq	z, .up
	cp	a, skDown
	jq	z, .down
	cp	a, skLeft
	jq	z, .left
	cp	a, skRight
	jq	nz, .wait
.right:
	ld	a, b
	cp	a, 7
	jq	z, .rightadvance
	inc	b
	jq	.cont
.rightadvance:
	ld	b, 0
.down:
	ld	a, c
	cp	a, 22
	jq	z, .downadvance
	inc	c
	jq	.cont
.downadvance:
	pop	hl
	ld	de, 8
	add	hl, de
	jq	ViewMemoryPartClearScreen
.left:
	ld	a, b
	or	a, a
	jq	z, .leftadvance
	dec	b
	jq	.cont
.leftadvance:
	ld	b, 7
.up:
	ld	a, c
	or	a, a
	jq	z, .upadvance
	dec	c
	jq	.cont
.upadvance:
	pop	hl
	ld	de, -8
	add	hl, de
	jq	ViewMemoryPartClearScreen
.cont:
	ld	(hl), 0
	jq	MemoryDisplayCursor
.return:
	pop	hl
	ld	(MEMORY_START_ADDR), hl
	jq	MainMenu
MemoryHexadecimalPressed:
	pop	hl
	push	hl
	ld	e, c
	exx
	push	bc
	exx
	pop	bc
	ld	a, b
	ld	b, 8
	mlt	bc
	add	hl, bc
	ld	c, a
	add	hl, bc
	call	_SetAToHLU
	and	a, 0F0h
	cp	a, 0D0h
	ld	a, e
	exx
	jq	nz, MemoryDisplayCursor.wait
	ld	(hl), 0
	inc	hl
	ld	(hl), 0FFh
	ld	e, a
	ld	a, b
	add	a, a
	add	a, b
	add	a, 8
	ld	(X_POS), a
	ld	a, c
	add	a, a
	ld	d, a
	add	a, a
	add	a, a
	add	a, d
	add	a, 5
	ld	(Y_POS), a
	push	de
	ld	a, e
	call	PrintByte.convert
.wait2:
	call	GetKeyAnyFast
	exx
	push	hl
	ld	hl, NumbersKeyPresses
	ld	bc, 16
	cpir
	pop	hl
	ld	a, c
	exx
	jq	nz, .wait2
	push	af
	ld	(hl), 0
	call	PrintByte.convert
	exx
	pop	af
	ld	c, a
	pop	de
	ld	a, e
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	add	a, c
	ld	(hl), a
	exx
	jq	MemoryDisplayCursor.right
	
; =======================================================================================
ViewStrings:
	jq	MainMenu

; =======================================================================================
ViewLists:
	jq	MainMenu
	
; =======================================================================================
ViewSlots:
	ld	(X_POS), 0				; Display the slot options at the top of the screen
	ld	(Y_POS), 0
	ld	hl, SlotOptionsString
	call	PrintString
	ld	b, 5					; Loop through all slots
	ld	c, 1
	inc	(Y_POS)
GetSlotLoop:
	push	bc					; Both backup BC and this is needed by the FILEIOC functions
	call	AdvanceLine
	ld	(X_POS), 0
	ld	a, c					; Display the slot number
	add	a, '0'
	call	PrintChar
	ld	a, ':'
	call	PrintChar
	ld	(X_POS), 28				; Get the size
	call	ti_GetSize
	ld	d, h					; If the size = -1, the slot is closed, so don't display anything
	ld	e, l
	add	hl, hl
	jq	c, SlotIsClosed
	ex.s	de, hl
	call	PrintInt				; Otherwise, display it
	ld	(X_POS), 5				; Get the variable type and display it
	call	ti_GetVATPtr
	ld	a, (hl)
	or	a, a
	sbc	hl, hl
	ld	l, a
	call	PrintInt
	ld	(X_POS), 10				; Check if the program is archived
	call	ti_IsArchived
	ld	a, l
	or	a, a
	jq	z, .notarchived
	ld	a, '*'					; If so, display a * in front of it
	call	PrintChar
.notarchived:
	ld	hl, TempStringData			; Get the name and display it
	push	hl
	call	ti_GetName
	pop	hl
	call	PrintString
	ld	(X_POS), 20
	ld	a, 0F2h					; $
	call	PrintChar
	call	ti_GetDataPtr				; Get the data pointer and display it
	call	PrintHexInt
	ld	(X_POS), 34				; And finally get the offset and display it
	call	ti_Tell
	call	PrintInt
SlotIsClosed:						; Loop through all slots
	pop	bc
	inc	c
	dec	b
	jq	nz, GetSlotLoop
	call	GetKeyAnyFast				; Wait for any key to be pressed and return to main menu
	jq	MainMenu
	
; =======================================================================================
ViewScreen:
	ld	hl, 6					; Restore the LCD control
	add	hl, sp
	ld	de, (hl)
	ld	(mpLcdCtrl), de
	dec	hl
	dec	hl
	dec	hl
	ld	hl, (hl)				; And restore the LCD UpBase
	ld	(mpLcdUpBase), hl
	call	RestorePalette				; Don't forget to restore the palette as well
	call	GetKeyAnyFast				; Wait for any key to be pressed
	call	SetICEPalette				; Restore palette and return to main menu while setting the right LCD config
	jq	MainMenuSetLCDConfig
	
; =======================================================================================
ViewBuffer:
	ld	hl, 6					; Restore the LCD control
	add	hl, sp
	ld	hl, (hl)
	ld	(mpLcdCtrl), hl
	ld	hl, (mpLcdLpBase)			; Take the LpBase and store it into UpBase
	ld	(mpLcdUpBase), hl
	call	RestorePalette				; Restore palette
	call	GetKeyAnyFast				; Wait for any key to be pressed
	call	SetICEPalette				; Restore palette and return to main menu while setting the right LCD config
	jq	MainMenuSetLCDConfig
	
; =======================================================================================
SafeExit:
	ld	sp, (tempSP)				; Starting SP to check from
.pop:
	pop	hl					; Pop until the value < ramStart
	ld	de, ramStart
	or	a, a
	sbc	hl, de
	jq	nc, .pop
	add	hl, de					; Don't forget to return to that address
	push	hl
	ld	a, lcdBpp16				; Set right LCD control
	ld	hl, mpLcdCtrl
	ld	(hl), a
	ld	hl, vRAM
	ld	(mpLcdUpbase), hl
	call	RestorePalette			; Restore palette and USB area
	ld	iy, flags				; And display a fancy status bar
	jq	_DrawStatusBar
	
; =======================================================================================
JumpLabel:
; B = amount of labels to display
; C = currently selected label
; D = start offset
; E = amount of labels
	ld	hl, (LABELS_START)			; Get amount of labels
	xor	a, a
	cp	a, (hl)
	jq	z, NoLabelsFound			; If no labels found, return to main menu
	ld	d, a					; D = start offset of selected item in list
	ld	c, a					; C = currently selected label
PrintAllLabels:						; Clear the screen to display all label again
	exx
	call	ClearScreen
	exx
	ld	hl, (LABELS_START)			; Get amount of labels
	ld	e, (hl)					; E = amount of labels
	inc	hl
	ld	b, 26					; B = amount of labels to be displayed
	ld	a, b					; Display no more than 26 labels
	cp	a, e
	jq	c, MoreThan26Labels
	ld	b, e
MoreThan26Labels:
	ld	(Y_POS), 1
	xor	a, a					; Check if we need to skip any label
	cp	a, d
	jq	z, PrintLabelLoop
	push	bc
	ld	b, d
.skip:
	ld	c, 255					; The length of a label name < 255, so B won't get overwritten
	cpir						; Skip label name + address
	inc	hl
	inc	hl
	inc	hl
	djnz	.skip
	pop	bc
PrintLabelLoop:
	ld	(X_POS), 1
	call	PrintString				; HL points to the label name, so display it
	inc	hl					; Skip label address
	inc	hl
	inc	hl
	call	AdvanceLine
	djnz	PrintLabelLoop
	call	SelectOption				; Select a label from the menu
	jq	nc, PrintAllLabels			; We need to scroll, so display it over again
	jq	nz, MainMenu				; The user pressed Clear, so return to main menu
	ld	hl, (LABELS_START)			; Here the user pressed Enter, so immediately jump to that label
	inc	hl
	ld	a, d					; Get selected label
	add	a, c
	jq	z, GetLabelAddress
	ld	e, a					; How much labels do we need to skip?
	xor	a, a
	ld	b, a
	ld	c, b
SkipLabelsLoop:
	cpir						; Skip label name + address
	inc	hl
	inc	hl
	inc	hl
	dec	e
	jq	nz, SkipLabelsLoop
GetLabelAddress:
	cpir						; Skip over the current label name
	ld	de, (hl)				; Get the address
	ld	hl, (tempSP)				; And write it to the return addresss
	ld	(hl), de
	jq	Quit
NoLabelsFound:
	call	GetKeyAnyFast
	jq	MainMenu
	
; =======================================================================================
; ============================== Routines are starting here =============================
; =======================================================================================

RemoveTempBreakpoints:
	ld	a, (AMOUNT_OF_TEMP_BREAKPOINTS)		; If there are temp breakpoints present, remove them
	or	a, a
	ret	z
	ld	c, (AMOUNT_OF_BREAKPOINTS)		; We can safely assume the temp breakpoints are placed at the top of the breakpoints stack
	ld	b, BREAKPOINT_SIZE
	mlt	bc
	ld	ix, BreakpointsStart
	add	ix, bc
.loop:	lea	ix, ix - BREAKPOINT_SIZE		; Go back 1 breakpoint
	ld	a, 1
	call	RemoveBreakpoint			; And remove it
	dec	(AMOUNT_OF_TEMP_BREAKPOINTS)
	jq	nz, .loop
	ret

InsertTempBreakpointAtLine:
	ld	a, BREAKPOINT_TYPE_TEMP
	db	006h					; ld b, *
InsertFixedBreakpointAtLine:
assert	BREAKPOINT_TYPE_FIXED = 0
	xor	a, a
InsertBreakpointAtLine:
	ld	b, a
	call	IsBreakpointAtLine
	ld	a, b
	jq	z, DoInsertBreakpoint
	or	a, a
	ret	z
DoInsertBreakpoint:
	ex	de, hl
	ld	hl, (LINES_START)
	ld	hl, (hl)				; HL = amount of lines
	scf
	sbc	hl, de
	ret	c
	dec	a
	jq	nz, .fixed
	inc	(AMOUNT_OF_TEMP_BREAKPOINTS)
.fixed:
	inc	a
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
repeat LINE_SIZE
	add	hl, de
end repeat
assert LINE_ADDR_OFFSET = 1
	inc	hl
	ld	de, (hl)
	ex.s	de, hl
	ld	de, userMem + 1
	add	hl, de
	ld	(ix + BREAKPOINT_ADDRESS), hl		; Program pointer
	lea	de, ix + BREAKPOINT_CODE
	ld	bc, 4
	ldir
	dec	hl
	dec	hl
	dec	hl
	ld	de, icedbg_open
	ld	(hl), de
	dec	hl
	ld	(hl), 0CDh				; CALL icedbg_open
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
	dec	a					; A = 1 at last breakpoint
	ret	z
	ld	c, a
	ld	b, BREAKPOINT_SIZE
	mlt	bc
	lea	de, ix
	lea	hl, ix + BREAKPOINT_SIZE
	ldir
	ret

GetLineFromAddress:
; Inputs:
;   DE = address
; Returns:
;   HL = line number

	ld	hl, (STARTUP_BREAKPOINTS)
assert LINE_ADDR_OFFSET = 1
	inc	hl
	ld	bc, -LINE_SIZE
	exx
	ld	hl, (LINES_START)
	ld	hl, (hl)
	ld	bc, -1
.loop:
	add	hl, bc
	ret	nc
	exx
	add	hl, bc
	push	hl
	push	de
	ld	de, (hl)
	ex.s	de, hl
	ld	de, userMem + 1
	add	hl, de
	pop	de
	scf
	sbc	hl, de
	pop	hl
	exx
	jq	nc, .loop
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
.loop:	
	ld	de, (ix + BREAKPOINT_LINE)
	or	a, a
	sbc	hl, de
	add	hl, de
	jq	z, .found
	lea	ix, ix + BREAKPOINT_SIZE
	dec	a
	jq	nz, .loop
	ret
.found:	
	dec	a
	inc	a
	ret
	
GlobalToLocalLineDec:
; Inputs: HL = global line
; Outputs: HL = local line
	dec	hl
GlobalToLocalLine:
	ex	de, hl
	ld	hl, (LINES_START - iy + iy_base)
repeat LINE_SIZE
	add	hl, de
end repeat
	ld	de, LINE_LOCAL_LINE + 3
	add	hl, de
	ld	de, (hl)
	ex.s	de, hl
	ret
	
LocalToGlobalLine:
; Inputs:
;   -  A = program index
;   - HL = local line
; Outputs:
;   - HL = global line
	ex	de, hl
	push	iy
	push	bc
	ld	iy, (LINES_START)
	ld	bc, (iy)
	lea	iy, iy + 3 - LINE_SIZE
	scf
	sbc	hl, hl
.loop:
	lea	iy, iy + LINE_SIZE
	inc	hl
	ex	af, af'
	ld	a, b
	or	a, c
	jq	z, .return
	dec	bc
	ex	af, af'
	cp	a, (iy + LINE_PROG_INDEX)
	jq	nz, .loop
	push	hl
	ld	hl, (iy + LINE_LOCAL_LINE)
	or	a, a
	sbc.s	hl, de
	pop	hl
	jq	nz, .loop
.return:
	pop	bc
	pop	iy
	ret
	
	
RestorePalette:
	ld	de, mpLcdPalette
	lea	hl, PALETTE_ENTRIES_BACKUP
	ld	bc, 4
	ldir
	ret
	
GetCRC:
	ld	hl, 000FFFFh
Read:	
	ld	a, b
	or	a, c
	ret	z
	push	bc
	ld	a, (de)
	inc	de
	xor	a, h
	ld	h, a
	ld	b, 8
.loop:
	add.s	hl, hl
	jq	nc, .next
	ld	a, h
	xor	a, 010h
	ld	h, a
	ld	a, l
	xor	a, 021h
	ld	l, a
.next:	
	djnz	.loop
	pop	bc
	dec	bc
	jq	Read

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
.wait:
	call	GetKeyAnyFast
	cp	a, skEnter
	jq	z, .enter
	cp	a, skClear
	jq	z, .clear
	cp	a, skDown
	jq	z, .down
	cp	a, skUp
	jq	nz, .wait
	ld	a, c
	add	a, d
	jq	z, .wait
	sub	a, d
	jq	z, .pressedup
	dec	c
	jq	.erase
.down:
	ld	a, c
	add	a, d
	cp	a, e
	jq	z, .wait
	ld	a, c
	cp	a, 25
	jq	z, .presseddown
	inc	c
.erase:
	xor	a, a
	call	PrintChar
	jq	PrintCursor
.enter:
	scf
	ret
.clear:
	or	a, 1
	scf
	ret
.pressedup:
	dec	d
	ret
.presseddown:
	inc	d
	ret
	
TempStringData:
	rb	9
	
ClearScreen:
	ld	hl, SCREEN_START - 1
	set	0, l
	set	1, l
	set	2, l
	inc	hl
	ld	(hl), 0
	push	hl
	pop	de
	inc	de
	ld	bc, lcdWidth * lcdHeight / 8 - 1
	ldir
	ld	iy, iy_base
	ld	(X_POS), 0
	ld	(Y_POS), 0
	ret
	
SetLCDConfig:
	ld	a, lcdBpp1
	ld	hl, mpLcdCtrl
	ld	(hl), a
	inc	hl
	set	2, (hl)
	ld	hl, SCREEN_START - 1
	ld	a, l
	or	a, 7
	ld	l, a
	inc	hl
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
	push	ix
	push	iy
	push	hl
	ld	iy, flags
.loop:
	call	_GetCSC
	or	a, a
	jq	z, .loop
	pop	hl
	pop	iy
	pop	ix
	di
	ret
	
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
	jq	nz, DivideLoop
	ex	de, hl
	pop	de
	
PrintString:
	ld	a, (hl)
	or	a, a
	inc	hl
	ret	z
	call	PrintChar
	jq	PrintString
	
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
	call	.convert
	ld	a, d
.convert:
	and	a, 00Fh
	add	a, 090h
	daa
	adc	a, 040h
	daa
	
PrintChar:
	push	hl
	push	de
	push	bc
	ld	c, a
	ld	a, (X_POS)
	cp	a, 40
	jq	z, DontDisplayChar
	or	a, a
	sbc	hl, hl
	ld	l, a
	inc	(X_POS)
	ld	e, (Y_POS)
	ld	d, lcdWidth / 8
	mlt	de
	add	hl, de
	ld	de, SCREEN_START - 1
	ld	a, e
	or	a, 7
	ld	e, a
	inc	de
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
	jq	nz, .notinvert
	cpl
.notinvert:
	ld	(de), a
	inc	de
	inc	hl
	ex	de, hl
	add	hl, bc
	ex	de, hl
	dec	ixh
	jq	nz, PutCharLoop
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
ProgramString:
	db	"Program: ", 0
NoDBGAppvarString:
	db	"Can't find debug appvar", 0
WrongVersionString:
	db	"Wrong debug appvar version", 0
CRCNotMatchString:
	db	"Source prog doesn't match:", 0
NoSRCProgramString:
	db	"Source program not found: ", 0
RecompileString:
	db	"Please recompile!", 0
	
NumbersKeyPresses:
	db	skCos, skSin, skRecip, skPrgm, skMatrix, skMath, sk9, sk8, sk7, sk6, sk5, sk4, sk3, sk2, sk1, sk0
	
DBGProgStart:
	dl	0
Temp:
	dl	0

_DefaultTIFontData:
; To get the font data, load font.pf into 8x8 ROM PixelFont Editor, export it as an assembly include file,
; and replace the regex "0x(..)" with "0\1h" to make it fasmg-compatible
include 'font.asm'

iy_base: org iy
; Pointers in debug appvar
	SUBPROGRAMS_START:              dl 0
	VARIABLE_START:			dl 0
	LINES_START:			dl 0
	STARTUP_BREAKPOINTS:		dl 0
	LABELS_START:			dl 0
	
; Breakpoints stuff
	AMOUNT_OF_BREAKPOINTS:		db 0
	AMOUNT_OF_TEMP_BREAKPOINTS:	db 0
	
; Stepping through code
	PROG_SIZE:			dl 0
	PROG_START:			dl 0
	DEBUG_CURRENT_LINE:		dl 0
	DEBUG_LINE_START:		dl 0
	DEBUG_AMOUNT_OF_LINES:		dl 0
	
; Temp variables
	PALETTE_ENTRIES_BACKUP:		rb 4
	X_POS:				db 0
	Y_POS:				db 0
	
; Other variables
	STEP_MODE:			db 0
	RESTORE_BREAKPOINT_LINE:	dl 0
	MEMORY_START_ADDR:		dl 0
org iy_base + $ - $$

BreakpointsStart:
	rb	BREAKPOINT_SIZE * 100
	
ProgramsPointers:
	rb	50 * (3 + 3)				; 3 for data pointer, 3 for size
	
SCREEN_START:
	rb	lcdWidth * lcdHeight / 8 + 7
libraryEnd:
