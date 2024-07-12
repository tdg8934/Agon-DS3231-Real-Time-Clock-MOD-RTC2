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

_exec_name:     .DB  "Rclock.bin", 0      ; The executable name, only used in argv
argv_ptrs_max:      EQU 16          ; Maximum number of arguments allowed in argv



; ---------------------------------------------
;
;   INITIAL SETUP CODE HERE
;
; ---------------------------------------------

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
 

    ld a, mb                ; grab current MB to restore when exiting
    push af 
    xor a 
    ld mb, a                ; put 0 into MB


    LD IX, argv_ptrs       ; The argv array pointer address
    PUSH IX
    CALL _parse_params     ; Parse the parameters
    POP IX                 ; IX: argv  
    LD B, 0                ;  C: argc
    LD B, C                ;  B: number of arguments
    ld a, b 

   ; cp 1                    ; if only 1 param then no arguments were sent in, so nothing to set
   ; jp z, _noParams         ; comment this out if no arguments are sent

    dec b                   ; arguments is always 1 more than we need as first is app name

; now set the params
    ld iy, SECONDS          ; set IY to the address of first byte to store (SECONDS)



    LD IX, argv_ptrs       ; The argv array pointer address
    inc ix
    inc ix
    inc ix

_paramLoop:                 ; loop round each argument and store value
    push bc

    ld de, (ix)             ; get param #B address
    call string2bytePair    ; convert to BCD value needed, returned in A
    ld (iy), a              ; store the byte

    inc iy                  ; increase destination location

    inc ix
    inc ix
    inc ix                  ; increase three source address bytes, as three used for each pointer

    pop bc
    inc c
    djnz _paramLoop          ; go round B times for data we want to store,
                             ; in the order of: hours minutes seconds day month year

i2cSection:

    call open_i2c
    call writeAllData

    call read_i2c	     ; Read and display the time and date	

    call close_i2c

   ; ld hl, okMSG	     ; No need to display any messages - comment out
    ld hl, LFCR

    call PRSTR              ; print OK message

now_exit:

    ld a, 4		    ; write text at text cursor
    rst.lil $10

                            ; Cleanup stack, prepare for return to MOS
    pop af 
    ld mb, a                ; restore MB
    pop iy                  ; Pop all registers back from the stack
    pop ix
    pop de
    pop bc
    pop af
    ld hl,0                 ; Load the MOS API return code (0) for no errors.
 
    ret                     ; Return to MOS


_noParams:                   ; no arguments received, so can't set anything
    ld hl, errMSG
    call PRSTR              ; print error message

    jp now_exit

; ---------------------------------------------

open_i2c:

    ld c, 3                     ; making assumption based on Jeroen's code
    ld a, $1F                   ; open i2c               
    rst.lil $08		        ; MOSCALL 	
   ret

; ---------------------------------------------

writeAllData:

    ld c, $68               ; i2c address ($68)
   
   ;ld b, 8                 ; number of bytes to send (1+7)
    ld b, 1                 ; 1 argument sent for executable name

    ld hl, PARAMS           ; location of data

    ld a, $21                   
    rst.lil $08	            ; MOSCALL 	
    
    ret  

; ---------------------------------------------

close_i2c:

    ld a, $20                                 
    rst.lil $08	            ; MOSCALL 	
    
    ret 

; ---------------------------------------------

string2bytePair:

; takes pointer to a string (0-99) and converts to a BCD single byte of two nibble values

; de = pointer to ASCII number
; a = result
; b and c are used for the two chars

    push bc  

    ld a, (de)      ; get first char
    ld b, a         ; put it into B
    inc de          ; inc de to next pos
    ld a, (de)      ; get the char
    ld c, a         ; put it into c

    cp 0            ; check if second char for a zero termination
    jr nz, _c1      ; jp if not, ie we got pair of chars

    ld c, b         ; put first char into second char
    ld b, '0'       ; and put a leading 0 into first char

_c1:
    ld a, c         ; get second char
    sub 48          ; convert from char to value
    ld c, a         ; store it back into C

    ld a, b         ; get first char
    sub 48          ; convert from char to value

    or a            ; clear any flags

    sla a
    sla a
    sla a
    sla a           ; move left 4 bits

    or c            ; add the second nibble to it, ie. B + C

    pop bc

    ret

; ---------------------------------------------

PRSTR:                              ; Print a zero-terminated string
    LD A,(HL)
    OR A
    RET Z
    RST.LIL 10h
    INC HL
    JR PRSTR

; ---------------------------------------------
; Parse the parameter string into a C array
; Parameters
; - HL: Address of parameter string
; - IX: Address for array pointer storage
; Returns:
; -  C: Number of parameters parsed

_parse_params:      
    LD  BC, _exec_name
    LD  (IX+0), BC                  ; ARGV[0] = the executable name
    INC IX
    INC IX
    INC IX
    CALL _skip_spaces               ; Skip HL past any leading spaces

    LD  BC, 1                       ; C: ARGC = 1 - also clears out top 16 bits of BCU
    LD  B, argv_ptrs_max - 1        ; B: Maximum number of argv_ptrs

_parse_params_1:    
    PUSH BC                         ; Stack ARGC    
    PUSH HL                         ; Stack start address of token
    CALL _get_token                 ; Get the next token
    LD A, C                         ; A: Length of the token in characters
    POP DE                          ; Start address of token (was in HL)
    POP BC                          ; ARGC
    OR A                            ; Check for A=0 (no token found) OR at end of string
    RET Z

    LD  (IX+0), DE                  ; Store the pointer to the token
    PUSH HL                         ; DE=HL
    POP DE
    CALL    _skip_spaces            ; And skip HL past any spaces onto the next character
    XOR A
    LD (DE), A                      ; Zero-terminate the token
    INC IX
    INC IX
    INC IX                          ; Advance to next pointer position
    INC C                           ; Increment ARGC
    LD  A, C                        ; Check for C >= A
    CP  B
    JR  C, _parse_params_1          ; And loop
    RET


; ---------------------------------------------

; Skip spaces in the parameter string
; Parameters:
; - HL: Address of parameter string
; Returns:
; - HL: Address of next none-space character
;    F: Z if at end of string, otherwise NZ if there are more tokens to be parsed

_skip_spaces:       
        LD  A, (HL)                 ; Get the character from the parameter string   
            CP  ' '                 ; Exit if not space
            RET NZ
            INC HL                  ; Advance to next character
            JR  _skip_spaces        ; Increment length

        
; ---------------------------------------------

; Get the next token
; Parameters:
; - HL: Address of parameter string
; Returns:
; - HL: Address of first character after token
; -  C: Length of token (in characters)

_get_token:     
    LD C, 0                         ; Initialise length
nt:         
    LD A, (HL)                      ; Get the character from the parameter string
    OR A                            ; Exit if 0 (end of parameter string in MOS)
    RET Z
    CP 13                           ; Exit if CR (end of parameter string in BBC BASIC)
    RET Z
    CP ' '                          ; Exit if space (end of token)
    RET Z
    INC HL                          ; Advance to next character
    INC C                           ; Increment length
    JR  nt

; ---------------------------------------------

CLS:
    ld a, 12
    rst.lil $10                     ; CLS
    ret


 ; ------------------


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


    ld b, TimePos +6
    ld c, 1
    ld a, (SECONDS)
    call debugA

    ld b, TimePos +3
    ld c, 1
    ld a, (MINUTES)
    call debugA

    ld b, TimePos
    ld c, 1
    ld a, (HOURS)
    call debugA


   ; ld b, 30
   ; ld c, 1
   ; ld a, (DAY)
   ; call debugA
   
    ld b, DatePos +3
    ld c, 1
    ld a, (DATE)
    call debugA

    ld b, DatePos
    ld c, 1
    ld a, (MONTH)
    call debugA

    ld b, DatePos +6
    ld c, 1
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

errMSG:             .db "Sorry, wrong number of arguments.\r\nUse: settime seconds minutes hours day date month year\r\n",0
okMSG:              .db "RTC set\r\n",0
LFCR:               .db "\r\n",0
argv_ptrs:          .ds    48, 255        ; max 16 x 3 bytes each

;   store RTC values. Send data in THIS ORDER

PARAMS:         .db     0   ; this first 0 sets initial memory address to write to when sending data, always 0

SECONDS:        .db     0  
MINUTES:        .db     0  
HOURS:          .db     0  

DAY:            .db     0  

DATE:           .db     0  
MONTH:          .db     0  
YEAR:           .db     0


overrun:
    .ds 32,0                   ; not used yet

 ; ------------------

VDUdata:
    .db 31, TimePos +2,1, ":"
    .db 31, TimePos +5,1, ":"
    .db 31, DatePos +2,1, "/"
    .db 31, DatePos +5,1, "/"
endVDUdata:

i2c_read_buffer:		;i2c useage
    .ds 32,0

i2c_write_buffer:
    .ds 32,0

TimePos:	equ	58
DatePos:	equ	70


