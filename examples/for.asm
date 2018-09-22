; Disassembly of FOR.8xp:

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
D1A89A: 11D9A8D1      ld        de, D1A8D9
D1A89E: CDD8A8D1      call      D1A8D8
D1A8A2: FD218000D0    ld        iy, flags
D1A8A7: D8            ret       c
D1A8A8: 21020000      ld        hl, 000002			; 2->A
D1A8AC: DD2F80        ld        (ix - 80), hl
D1A8AF: 2B            dec       hl				; For(A,1,5,3
D1A8B0: DD2F80        ld        (ix - 80), hl
D1A8B3: C3C7A8D1      jp        D1A8C7
D1A8B7: DD2783        ld        hl, (ix - 7D)			; B+1->B
D1A8BA: 23            inc       hl
D1A8BB: DD2F83        ld        (ix - 7D), hl
D1A8BE: DD2780        ld        hl, (ix - 80)			; End
D1A8C1: 23            inc       hl
D1A8C2: 23            inc       hl
D1A8C3: 23            inc       hl
D1A8C4: DD2F80        ld        (ix - 80), hl
D1A8C7: 11060000      ld        de, 000006
D1A8CB: B7            or        a, a
D1A8CC: ED52          sbc       hl, de
D1A8CE: 38E7          jr        c, D1A8B7
								; dbd(0
D1A8D0: 21050000      ld        hl, 000005			; 5->A
D1A8D4: DD2F80        ld        (ix - 80), hl
D1A8D7: C9            ret       
D1A8D8: E9            jp        (hl)
D1A8D9: 15            dec       d
D1A8DA: 46            ld        b, (hl)
D1A8DB: 4F            ld        c, a
D1A8DC: 5244          ld.sil    b, h
D1A8DE: 42            ld        b, d
D1A8DF: 47            ld        b, a
D1A8E0: 00            nop       



DEBUGAPPVAR:
	.db	"A", 0			; Name + zero byte
	.db	2			; Amount of variables
	.db	"A", 0			; Variables
	.db	"B", 0
	.db	7			; Amount of lines
	.dl	$D1A8A8, 0		; [i]B
	.dl	$D1A8A8, 0		; 2->A
	.dl	$D1A8AF, $D1A8C7	; For(A,1,5,3
	.dl	$D1A8B7, 0		; B+1->B
	.dl	$D1A8BE, $D1A8B7	; End
	.dl	$D1A8D0, 0		; dbd(1
	.dl	$D1A8D0, 0		; 5->A
	.db	1			; Amount of startup breakpoints
	.dl	7			; Startup breakpoints
	.db	0			; Amount of labels
