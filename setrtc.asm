; 
; Title:        setrtc
; Author:       Richard Turnnidge 2024
; A MOSlet to set the time of a RTC module
;
; Usage:
;         *setrtc seconds minutes hours day date month year
;
;   eg.    *setrtc 0 23 18 2 21 9 24
;
;   this version is more compact and efficient at sending i2c data
;

    include "myMacros.inc"

    .assume adl=1   ; We start up in full 24bit mode, allowing full memory access and 24-bit wide registers
    .org $0B0000    ; This program assembles to MOSlet RAm area


    jp start        ; skip headers

; Quark MOS header 
    .align 64       ; Quark MOS expects programs that it LOADs,to have a specific signature
                    ; Starting from decimal 64 onwards
    .db "MOS"       ; MOS header 'magic' characters
    .db 00h         ; MOS header version 0 - the only in existence currently afaik
    .db 01h         ; Flag for run mode (0: Z80, 1: ADL) - We start up in ADL mode here

_exec_name:     .DB  "setrtc.bin", 0      ; The executable name, only used in argv
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

    cp 1                    ; if only 1 param then no arguments were sent in, so nothing to set
    jp z, _noParams

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
    call close_i2c

    ld hl, okMSG
    call PRSTR              ; print OK message

now_exit:
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
    MOSCALL $1F                 ; open i2c               
   
   ret

; ---------------------------------------------

writeAllData:

    ld c, $68               ; i2c address ($68)
    ld b, 8                 ; number of bytes to send
    ld hl, PARAMS           ; location of data

    MOSCALL $21

    ret  

; ---------------------------------------------

close_i2c:

    MOSCALL $20

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
