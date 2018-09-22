; Disassembly of WHILE.8xp:

                    userMem:
D1A881: 7F            ld        a, a
D1A882: DD21563FD1    ld        ix, D13F56
								; [i]B
								; <open debugger>
D1A887: 2AE425D0      ld        hl, (windowHookPtr)
D1A88B: ED17          ld        de, (hl)
D1A88D: EB            ex        de, hl
D1A88E: 0183BFC9      ld        bc, C9BF83
D1A892: B7            or        a, a
D1A893: ED42          sbc       hl, bc
D1A895: C0            ret       nz
D1A896: EB            ex        de, hl
D1A897: 23            inc       hl
D1A898: 23            inc       hl
D1A899: 23            inc       hl
D1A89A: 11D0A8D1      ld        de, D1A8D0
D1A89E: CDCFA8D1      call      D1A8CF
D1A8A2: FD218000D0    ld        iy, flags
D1A8A7: D8            ret       c
D1A8A8: 21020000      ld        hl, 000002			; 2->A
D1A8AC: DD2F80        ld        (ix - 80), hl
D1A8AF: C3BAA8D1      jp        D1A8BA				; While A!=3
D1A8B3: DD2780        ld        hl, (ix - 80)			; A+1->A
D1A8B6: 23            inc       hl
D1A8B7: DD2F80        ld        (ix - 80), hl
D1A8BA: DD2780        ld        hl, (ix - 80)			; End
D1A8BD: 2B            dec       hl
D1A8BE: 2B            dec       hl
D1A8BF: 2B            dec       hl
D1A8C0: 11FFFFFF      ld        de, FFFFFF
D1A8C4: 19            add       hl, de
D1A8C5: 38EC          jr        c, D1A8B3
								; dbd(0
D1A8C7: 21050000      ld        hl, 000005			; 5->A
D1A8CB: DD2F80        ld        (ix - 80), hl
D1A8CE: C9            ret       
D1A8CF: E9            jp        (hl)
D1A8D0: 15            dec       d
D1A8D1: 57            ld        d, a
D1A8D2: 48            ld        c, b
D1A8D3: 494C          ld.lis    c, h
D1A8D5: 45            ld        b, l
D1A8D6: 44            ld        b, h
D1A8D7: 42            ld        b, d
D1A8D8: 47            ld        b, a
D1A8D9: 00            nop       



DEBUGAPPVAR:
	.db	"A", 0			; Name + zero byte
	.db	1			; Amount of variables
	.db	"A", 0			; Variables
	.db	7			; Amount of lines
	.dl	$D1A8A8, 0		; [i]B
	.dl	$D1A8A8, 0		; 2->A
	.dl	$D1A8AF, $D1A8BA	; While A!=3
	.dl	$D1A8B3, 0		; A+1->A
	.dl	$D1A8BA, $D1A8B3	; End
	.dl	$D1A8C7, 0		; dbd(1
	.dl	$D1A8C7, 0		; 5->A
	.db	1			; Amount of startup breakpoints
	.dl	7			; Startup breakpoints
	.db	0			; Amount of labels
