; 
; Title:        Rclock
; Author:       Richard Turnnidge 2024 / Tim Gilmore
; A MOSlet to display the time and date of a RTC module
;

    .assume adl=1   ; We start up in full 24bit mode, allowing full memory access and 24-bit wide registers
    .org $0B0000    ; This program assembles to MOSlet RAm area

    jp start        ; skip headers

; Quark MOS header 
    .align 64       ; Quark MOS expects programs that it LOADs,to have a specific signature
                    ; Starting from decimal 64 onwards
    .db "MOS"       ; MOS header 'magic' characters
    .db 00h         ; MOS header version 0 - the only in existence currently afaik
    .db 01h         ; Flag for run mode (0: Z80, 1: ADL) - We start up in ADL mode here


; ---------------------------------------------
;
;   INITIAL SETUP CODE HERE
;
; ---------------------------------------------

TimePosX:	equ	60
TimePosY:	equ	1

DatePosX:	equ	70
DatePosY:	equ	1


start:                      ; Start code here
    push af                 ; Push all registers to the stack
    push bc
    push de
    push ix
    push iy

    ld a, 12		    ; CLS
    rst.lil $10

    ld hl, VDUdata
    ld bc, endVDUdata - VDUdata
    rst.lil $18   
 

i2cSection:

    call open_i2c

    call read_i2c	    ; Read and display the time and date	

    call close_i2c

    ld hl, LFCR		    ; line feed & carriage return here
    call PRSTR             


    pop iy                  ; Cleanup stack, prepare for return to MOS
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                 ; Load the MOS API return code (0) for no errors.
 
    ret                     ; Return to MOS


; ---------------------------------------------

open_i2c:

    ld c, 3                 ; making assumption based on Jeroen's code
    ld a, $1F               ; open i2c               
    rst.lil $08	            ; MOSCALL 	
   ret

; ---------------------------------------------

close_i2c:

    ld a, $20                                 
    rst.lil $08	            ; MOSCALL 	
    
    ret 

; ---------------------------------------------

PRSTR:                      ; Print a zero-terminated string
    LD A,(HL)
    OR A
    RET Z
    RST.LIL 10h
    INC HL
    JR PRSTR

; ---------------------------------------------

read_i2c:

    ; ask for data

    ld c, $68   		    ; i2c address ($68)
    ld b,1		            ; number of bytes to send
    ld hl, i2c_write_buffer
    ld (hl), $00
   
    ld a, $21                                  
    rst.lil $08		            ; MOSCALL 	
    
   
    ld a, 00000100b
    call multiPurposeDelay
    
    ld c, $68
    ld b, 7
    ld hl, i2c_read_buffer
    
    ld a, $22                                  
    rst.lil $08		            ; MOSCALL 	

    ld a, 00000010b
    call multiPurposeDelay
    
    ;display the data

    ld hl, i2c_read_buffer

    ld a, (hl)
    ld (SECONDS), a
    inc hl

    ld a, (hl)
    ld (MINUTES), a
    inc hl

    ld a, (hl)
    ld (HOURS), a
    inc hl

     ld a, (hl)
     ld (DAY), a
     inc hl

    ld a, (hl)
    ld (DATE), a
    inc hl

    ld a, (hl)
    ld (MONTH), a
    inc hl

    ld a, (hl)
    ld (YEAR), a
    inc hl


    ld b, TimePosX +6
    ld c, TimePosY
    ld a, (SECONDS)
    call debugA

    ld b, TimePosX +3
    ld c, TimePosY
    ld a, (MINUTES)
    call debugA

    ld b, TimePosX
    ld c, TimePosY
    ld a, (HOURS)
    call debugA


   ; ld b, 30
   ; ld c, 1
   ; ld a, (DAY)
   ; call debugA
   
    ld b, DatePosX +3
    ld c, DatePosY
    ld a, (DATE)
    call debugA

    ld b, DatePosX
    ld c, DatePosY
    ld a, (MONTH)
    call debugA

    ld b, DatePosX +6
    ld c, DatePosY
    ld a, (YEAR)
    call debugA
       
    ret 


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
	                        
        ld a, $08               ; get IX pointer to sysvars                   
        rst.lil $08	        ; MOSCALL 	
        
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



; ---------------------------------------------
;
;	DEBUG ROUTINES
;
; ---------------------------------------------

debugA:				; debug A to screen as HEX byte pair at pos BC
	push af 
	ld (debug_char), a	; store A
				; first, print 'A=' at TAB 36,0
	ld a, 31		; TAB at x,y
	rst.lil $10
	ld a, b			; x=b
	rst.lil $10
	ld a, c			; y=c
	rst.lil $10		; put tab at BC position

	ld a, (debug_char)	; get A from store, then split into two nibbles
	and 11110000b		; get higher nibble
	rra
	rra
	rra
	rra			; move across to lower nibble
	add a,48		; increase to ascii code range 0-9
	cp 58			; is A less than 10? (58+)
	jr c, nextbd1		; carry on if less
	add a, 7		; add to get 'A' char if larger than 10
nextbd1:	
	rst.lil $10		; print the A char

	ld a, (debug_char)	; get A back again
	and 00001111b		; now just get lower nibble
	add a,48		; increase to ascii code range 0-9
	cp 58			; is A less than 10 (58+)
	jp c, nextbd2		; carry on if less
	add a, 7		; add to get 'A' char if larger than 10	
nextbd2:	
	rst.lil $10		; print the A char
	
	ld a, (debug_char)
	pop af 
	ret			; head back

debug_char: 	.db 0



; ---------------------------------------------
;
;   DATA
;
; ---------------------------------------------

LFCR:           .db "\r\n",0

;   store RTC values. Send data in THIS ORDER

PARAMS:         .db     0   ; this first 0 sets initial memory address to write to when sending data, always 0

SECONDS:        .db     0  
MINUTES:        .db     0  
HOURS:          .db     0  

DAY:            .db     0  

DATE:           .db     0  
MONTH:          .db     0  
YEAR:           .db     0


; ------------------

VDUdata:
    .db 31, TimePosX +2,TimePosY, ":"
    .db 31, TimePosX +5,TimePosY, ":"
    .db 31, DatePosX +2,DatePosY, "/"
    .db 31, DatePosX +5,DatePosY, "/"
endVDUdata:

i2c_read_buffer:		;i2c useage
    .ds 32,0

i2c_write_buffer:
    .ds 32,0


