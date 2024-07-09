; ---------------------------------------------
;
;	SOME USEFUL MACROS
;
; ---------------------------------------------

	macro CLS
	ld a, 12
        rst.lil $10
	endmacro

	macro CLG
	ld a, 16
	rst.lil $10
	endmacro

	macro SET_COLOUR value
        ld a, 17
        rst.lil $10
        ld a, value
        rst.lil $10
	endmacro

	macro SET_BG_COLOUR value
        ld a, 17
	rst.lil $10
        ld a, value
        add a, 128
        rst.lil $10
	endmacro

	macro TAB_TO x,y
        ld a, 31
        rst.lil $10
        ld a, x
        rst.lil $10
        ld a, y
        rst.lil $10
	endmacro

	macro SET_MODE mode
        ld a, 22
        rst.lil $10
        ld a, mode
        rst.lil $10
        ld a, mode
        rst.lil $10
	endmacro

	macro MOSCALL arg1
        ld a, arg1
        rst.lil $08
	endmacro

        macro SET_MODE_GCOL mode,gcolour
        ld a, 18
        rst.lil $10
        ld a, mode
        rst.lil $10
        ld a, gcolour
        rst.lil $10
        endmacro

        macro NON_SCALED_GRAPHICS
        ld a, 0
        rst.lil $10
        ld a, 192
        rst.lil $10
        ld a, 0
        rst.lil $10
        endmacro

