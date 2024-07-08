; ---------------------------------------------
;
;	DELAY ROUTINES
;
; ---------------------------------------------

; routine waits a fixed time, then returns

multiPurposeDelay:	            		
	push bc 

				; arrive with A =  the delay byte. One bit to be set only.
	ld b, a 
	MOSCALL $08             ; get IX pointer to sysvars

waitLoop:

	ld a, (ix + 0)          ; ix+0h is lowest byte of clock timer

				; need to check if bit set is same as last time we checked.
				;   bit 0 - changes 128 times per second
				;   bit 1 - changes 64 times per second
				;   bit 2 - changes 32 times per second
				;   bit 3 - changes 16 times per second

				;   bit 4 - changes 8 times per second
				;   bit 5 - changes 4 times per second
				;   bit 6 - changes 2 times per second
				;   bit 7 - changes 1 times per second
				; eg. and 00000010b           ; check 1 bit only
	and b 
	ld c,a 
   	ld a, (oldTimeStamp)
  	cp c                    ; is A same as last value?
	jr z, waitLoop   	; loop here if it is
 	ld a, c 
 	ld (oldTimeStamp), a    ; set new value

 	pop bc
 	ret

oldTimeStamp:   .db 00h

; ---------------------------------------------

miniDelay:
	push bc  
	ld bc, 0
	ld b,10
miniLoop:

	djnz miniLoop
	pop bc
	ret


