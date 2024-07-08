; ---------------------------------------------
;
;	A SET OF MATHS ROUTINES TO INCLUDE
;
; ---------------------------------------------


get_ABS_a:	; returns A as ABS(A)
	or a
	ret p
	neg
	ret

; ---------------------------------------------

C_Div_D:
;Inputs
;   C is the numerator
;   D is the denominator
;Outputs
;   A is the remainder
;   B is 0
;   C is the result of C/D
;   D,E,H,L are not changed
;
    ld b, 8
    xor a
    sla c
    rla
    cp d
    jr c,$+4
    inc c
    sub d
    djnz $-8
    ret

; ---------------------------------------------

