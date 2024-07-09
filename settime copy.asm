; 
; Title:        LLIST to print to thermal printer
; Author:       Richard Turnnidge 2024
;               working version
;               added 16bit support
;               added baud options

    include "myMacros.inc"

    .assume adl=1   ; We start up in full 24bit mode, allowing full memory access and 24-bit wide registers
    .org $0B0000    ; This program assembles to MOSlet RAm area
;    .org $040000    ; This program assembles to the first mapped RAM location, start for user programs

    jp start        ; skip headers

; Quark MOS header 
    .align 64       ; Quark MOS expects programs that it LOADs,to have a specific signature
                    ; Starting from decimal 64 onwards
    .db "MOS"       ; MOS header 'magic' characters
    .db 00h         ; MOS header version 0 - the only in existence currently afaik
    .db 01h         ; Flag for run mode (0: Z80, 1: ADL) - We start up in ADL mode here

_exec_name:     .DB  "settime.bin", 0      ; The executable name, only used in argv
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
    LD B, C                ; B: # of arguments
    ld a, b 
    ld (numParams),a

    cp 1
    jp z, noParams

; now set the params
    ld iy, PARAMS                   ; set IY to the address of first param
    dec a
    ld b, a

    LD IX, argv_ptrs       ; The argv array pointer address
    inc ix
    inc ix
    inc ix

paramLoop:
    push bc

    ; get param #B
    ld de, (ix)           ; address of first arg, is a 0 terminated string for the file


    ; for debugging, just print each param in turn
    ld hl, (ix)           ; address of first arg, is a 0 terminated string for the file
    call PRSTR
    ld hl, LFCR           ; address of first arg, is a 0 terminated string for the file
    call PRSTR



    call string2int         ;convert string to an int. HL is result, we only need L as will be less than 256
    ld a, l
    ld (iy), a              ; store the byte
    inc iy                  ; increase destination location

    inc ix
    inc ix
    inc ix                  ; increase three address bytes, as three used for each pointer

    pop bc
    djnz paramLoop          ; go round B times for data we want to store,
                            ; in the order of: hours minutes seconds day month year



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


noParams:
    ld hl, errMSG
    call PRSTR

    jp now_exit
; ---------------------------------------------

string2int:

; takes pointer to a string of ascii representing an integer and converts to 3 byte integer
; hl = result
; de = pointer to ASCII number

  Ld hl,0
T1: 
  ld a,(de)
  Sub 48
  Jr c,T2
  Cp 10
  Jr nc,T2
  Push hl
  Pop bc
  Add hl,hl   ; x2
  Add hl,hl   ; x4
  Add hl,bc   ; x5
  Add hl,hl   ; x10
  Ld bc,0
  Ld c,a
  Add hl,bc   ; Add digit
  Inc de      ; go to next number
  Jr T1
T2:
  ret 

; ---------------------------------------------

printError:
    ld hl, errMSG
    call PRSTR

    jp now_exit


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



; ---------------------------------------------
;
;   UART CODE
;
; ---------------------------------------------

errMSG:             .db "Sorry, wrong number of arguments.\r\nUse: settime hours minutes seconds day month year\r\n",0
LFCR:               .db "\r\n",0
argv_ptrs:          .ds    48, 255        ; max 16 x 3 bytes each
numParams:          .db 0


i2c_read_buffer:        ;i2c useage - keep
    .ds 32,0

i2c_write_buffer:
    .ds 32,0

;   store RTC values. receive data in this order
PARAMS:

HOURS:          .db     0
MINUTES:        .db     0
SECONDS:        .db     0   

DATE:           .db     0
MONTH:          .db     0
YEAR:           .db     0

;   optional

HOURSMODE:  .db 0
DAY:        .db 0

overrun:
    .ds 32,0
