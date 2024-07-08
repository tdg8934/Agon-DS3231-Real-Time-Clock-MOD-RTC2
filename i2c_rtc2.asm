;   MOD-RTC2 I2C-Compatible Real Time Clock using DS3231SN
;   eZ80 Assembly program for Agon Light 2 used to create: 
;
;   Agon Light - MOD-RTC2
;   Written by Tim Gilmore July 2024 in 100% eZ80 Assembly Language
;   This is made possibly by the coordination of Learn Agon (Luis)
;   with his dedication and persistance to keep learning on the Agon Light 2
;   through his videos (https://www.youtube.com/@LearnAgon).
;
;   Special thanks also goes out to Richard Turnnidge who's Agon Light
;   eZ80 Assembly Language videos (https://www.youtube.com/@AgonBits) 
;   has trained me to create this eZ80 Assembly Language program.
  


    .assume adl=1       ; ez80 ADL memory mode
    .org $40000         ; load code here
    include "myMacros.inc"

    jp start_here       ; jump to start of code

    .align 64           ; MOS header
    .db "MOS",0,1     

    include "debug_routines.asm"
    include "delay_routines.asm"
    include "math_routines.asm"    

start_here:
            
    push af             ; store all the registers
    push bc
    push de
    push ix
    push iy

; ------------------
; This is our actual code in ez80 assembly

      
    CLS


    ld hl, VDUdata
    ld bc, endVDUdata - VDUdata
    rst.lil $18

   
    call hidecursor     ; hide the cursor

; need to setup i2c port

    call open_i2c



    
LOOP_HERE:
    MOSCALL $1E          ; get IX pointer to keyvals, currently pressed keys
    ld a, (ix + $0E)    
    bit 0, a    
    jp nz, EXIT_HERE            ; ESC key to exit


    ld a, 00000100b		; changes ? times a second
    call multiPurposeDelay      ; wait a bit
    
   
    call read_i2c	

    jr LOOP_HERE
    

; ------------------

EXIT_HERE:

; need to close i2c port
    call close_i2c
    CLS			; Clear the screen when exiting
    call showcursor

    pop iy              ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0             ; Load the MOS API return code (0) for no errors.   
    
    ret                 ; Return to MOS


; ------------------

open_i2c:

    ld c, 3                     ; making assumption based on Jeroen's code
    MOSCALL $1F                 ; open i2c     			 
   

; write to Address Pointer register and data buffer
    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $00		; 1st byte ($00) points to SECONDS address reg
    inc hl   
    ld (hl), 01000111b		; 2nd byte represents 47 seconds in BCD format 
    ld hl, i2c_write_buffer
    MOSCALL $21


    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $01		; 1st byte ($01) points to MINUTES address reg
    inc hl   
    ld (hl), 01011001b		; 2nd byte represents 59 minutes in BCD format 
    ld hl, i2c_write_buffer
    MOSCALL $21


    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $02		; 1st byte ($02) points to HOURS address reg
    inc hl   
    ld (hl), 00010010b		; 2nd byte represents 12 hours in BCD format 
    ld hl, i2c_write_buffer     
    MOSCALL $21



    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $03		; 1st byte ($03) points to DAY address reg
    inc hl   
    ld (hl), 00000010b		; 2nd byte represents the 2nd day/week in BCD format 
    ld hl, i2c_write_buffer     
    MOSCALL $21

    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $04		; 1st byte ($04) points to DATE address reg
    inc hl   
    ld (hl), 00100111b		; 2nd byte represents the 27th day/month in BCD format 
    ld hl, i2c_write_buffer     
    MOSCALL $21

    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $05		; 1st byte ($05) points to MONTH address reg
    inc hl   
    ld (hl), 00010000b		; 2nd byte represents the 10th month in BCD format 
    ld hl, i2c_write_buffer     
    MOSCALL $21

    ld a, 00000010b
    call multiPurposeDelay

    ld c, $68   		; i2c address ($68)
    ld b, 2			; number of bytes to send
    ld hl, i2c_write_buffer

    ld (hl), $06		; 1st byte ($06) points to YEAR address reg
    inc hl   
    ld (hl), 00100100b		; 2nd byte represents the 24th year in BCD format 
    ld hl, i2c_write_buffer     
    MOSCALL $21



    ret 

read_i2c:

    ; ask for data

    ld c, $68   		; i2c address ($68)
    ld b,1			; number of bytes to send
    ld hl, i2c_write_buffer
    ld (hl), $00
    MOSCALL $21
   
    ld a, 00000100b
    call multiPurposeDelay
    
    ld c, $68
    ld b, 7
    ld hl, i2c_read_buffer
    MOSCALL $22

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

    




    ld b, 23
    ld c, 1
    ld a, (SECONDS)
    call debugA

    ld b, 20
    ld c, 1
    ld a, (MINUTES)
    call debugA

    ld b, 17
    ld c, 1
    ld a, (HOURS)
    call debugA


    ld b, 30
    ld c, 1
    ld a, (DAY)
    call debugA
   
    ld b, 36
    ld c, 1
    ld a, (DATE)
    call debugA

    ld b, 33
    ld c, 1
    ld a, (MONTH)
    call debugA

    ld b, 39
    ld c, 1
    ld a, (YEAR)
    call debugA
    
    

    ret 



close_i2c:

    MOSCALL $20

    ret 

 ; ------------------


hidecursor:
    push af
    ld a, 23
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,0
    rst.lil $10                 ; VDU 23,1,0
    pop af
    ret


showcursor:
    push af
    ld a, 23
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,1
    rst.lil $10                 ; VDU 23,1,1
    pop af
    ret

 ; ------------------

VDUdata:

    .db 31, 15,27, "Press Esc to exit"
    .db 31, 19,1, ":"
    .db 31, 22,1, ":"
    .db 31, 35,1, "/"
    .db 31, 38,1, "/"
endVDUdata:



i2c_read_buffer:		;i2c useage - keep
    .ds 32,0

i2c_write_buffer:
    .ds 32,0

SECONDS:  	.db     0	;store RTC values
MINUTES:        .db     0
HOURS:		.db	0
HOURSMODE:	.db	0
DAY:		.db	0
DATE:		.db	0
MONTH:		.db	0
YEAR:		.db	0
