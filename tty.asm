; --- TTY driver ------------------------------------------------------------

.data
.global drvtop
; This must point at the _last_ driver.
drvtop: .word drv_TTY

defdriver TTY, DRVID_TTY, drvstrat_TTY, drv_SCREEN

; TTY driver strategy routine.
; Y=TTY opcode.
.proc drvstrat_TTY
    jmpdispatch jmptable_lo, jmptable_hi

jmptable_lo:
    jmptablo tty_const
    jmptablo tty_conin
    jmptablo tty_conout
jmptable_hi:
    jmptabhi tty_const
    jmptabhi tty_conin
    jmptabhi tty_conout
.endproc

; Returns $ff if no key is pending, 0 if one is.

.proc tty_const
    dec const_counter
    zif mi
        lda #16
        sta const_counter
        jsr scan_keyboard
    zendif

    lda pending_key
   
    zif ne
        lda #$ff
    zendif

    clc
    rts
.endproc

; Blocks until a key is pressed; returns it in A.

.proc tty_conin
    zrepeat
        lda #$ff
        ldx #$ff
        jsr screen_getchar
        ; Filter out arrow keys
        cmp #$80
        zif cs
            lda #0
        zendif
    zuntil cc

    rts
.endproc

; Writes the character in A.

.proc tty_conout
    cmp #13
    zif eq
        lda #0
        sta cursorx
        rts
    zendif
    cmp #127
    zif eq
        dec cursorx
        zif mi
            lda #SCREEN_WIDTH-1
            sta cursorx

            dec cursory
            zif mi
                lda #0
                sta cursory
                jsr screen_scrolldown
            zendif
        zendif
        jsr calculate_cursor_address
        lda #' '
        sta (ptr), y
        rts
    zendif
    cmp #10
    beq write_nl

    tax
    lda cursorx
    pha
    txa
    jsr screen_putchar

    pla
    cmp #SCREEN_WIDTH-1
    beq write_nl
    rts
.endproc

.proc write_nl
    lda #0
    sta cursorx

    inc cursory
    lda cursory
    cmp #SCREEN_HEIGHT
    zif eq
        dec cursory
        jmp screen_scrollup
    zendif
    rts
.endproc

; --- SCREEN driver ---------------------------------------------------------

defdriver SCREEN, DRVID_SCREEN, drvstrat_SCREEN, 0

; SCREEN driver strategy routine.
; Y=SCREEN opcode.
.proc drvstrat_SCREEN
    jmpdispatch screen_jmptable_lo, screen_jmptable_hi

screen_jmptable_lo:
    jmptablo screen_version
    jmptablo screen_getsize
    jmptablo screen_clear
    jmptablo screen_setcursor
    jmptablo screen_getcursor
    jmptablo screen_putchar
    jmptablo screen_putstring
    jmptablo screen_getchar
    jmptablo fail
    jmptablo screen_scrollup
    jmptablo screen_scrolldown
    jmptablo screen_cleartoeol
    jmptablo screen_setstyle
screen_jmptable_hi:
    jmptabhi screen_version
    jmptabhi screen_getsize
    jmptabhi screen_clear
    jmptabhi screen_setcursor
    jmptabhi screen_getcursor
    jmptabhi screen_putchar
    jmptabhi screen_putstring
    jmptabhi screen_getchar
    jmptabhi fail
    jmptabhi screen_scrollup
    jmptabhi screen_scrolldown
    jmptabhi screen_cleartoeol
    jmptabhi screen_setstyle
.endproc

.proc screen_version
    lda #0
    rts
.endproc

.proc screen_getsize
    lda #SCREEN_WIDTH-1
    ldx #SCREEN_HEIGHT-1
    rts
.endproc

.proc screen_clear
    lda #0
    zrepeat
        pha
        jsr calculate_line_address

        ldy #SCREEN_WIDTH-1
        lda #' '
        zrepeat
            sta (ptr), y
            dey
        zuntil mi

        pla
        clc
        adc #1
        cmp #SCREEN_HEIGHT
    zuntil eq

    ; SCREEN doesn't specify where the cursor ends up, but this code is used by
    ; TTY and homing the cursor here simplifies things.

    lda #0
    sta cursorx
    sta cursory
    rts
.endproc

.proc screen_setcursor
    sta cursorx
    stx cursory
    rts
.endproc

.proc screen_getcursor
    lda cursorx
    ldx cursory
    rts
.endproc

.proc screen_putchar
    cmp #32
    zif cs
        pha
        jsr calculate_cursor_address
        pla
        ora screen_style
        sta (ptr), y
    zendif

    lda cursorx
    cmp #SCREEN_WIDTH-1
    zif ne
        inc cursorx
    zendif

    rts
.endproc

.proc screen_putstring
    sta 1f+1
    stx 1f+2

    jsr calculate_cursor_address
    ldx #0
    zloop
    1:
        lda $ffff, x
        zbreakif eq

        sta (ptr), y
        iny
        inx
    zendloop

    rts
.endproc

; Sets (ptr), y to the location of the cursor.
.proc calculate_cursor_address
    ldy cursorx
    lda cursory
    ; fall through
.endproc

; Sets ptr to the address of screen line A.
.proc calculate_line_address
    clc
    rol ptr+1           ; shift a zero bit into the bottom of ptr+1

    ; x*40 = x*8 + x*32.

    ; We have 28 lines. As 28*8 will fit in a byte, we can do this easily.

    asl a               ; a = y*2
    asl a               ; a = y*4
    asl a               ; a = y*8
    sta ptr+0           ; store y*8

    ; Anything more than this needs to be 16-bit arithmetic.

    asl a               ; = y*16
    rol ptr+1

    asl a               ; = y*13
    rol ptr+1

    ; Add.

    clc
    adc ptr+0
    sta ptr+0
    zif cs
        inc ptr+1
    zendif

    ; Add in the video address.

    clc
    lda ptr+0
    adc #<SCREEN_TEXT
    sta ptr+0
    lda ptr+1
    and #%00000111
    adc #>SCREEN_TEXT
    sta ptr+1

    rts
.endproc

.proc toggle_cursor
    jsr calculate_cursor_address
    lda (ptr), y
    eor #$80
    sta (ptr), y
    rts
.endproc

.proc screen_scrollup
    ldx #0              ; current line
    zrepeat
        txa
        jsr calculate_line_address
        lda ptr+0
        sta ptr1+0
        lda ptr+1
        sta ptr1+1      ; ptr1 is dest pointer

        inx
        txa
        jsr calculate_line_address ; ptr is source pointer

        ldy #SCREEN_WIDTH-1
        zrepeat
            lda (ptr), y
            sta (ptr1), y
            dey
        zuntil mi

        cpx #SCREEN_HEIGHT-1
    zuntil eq

    ldy #SCREEN_WIDTH-1
    lda #' '
    ora screen_style
    zrepeat
        sta (ptr), y
        dey
    zuntil mi
    rts
.endproc

.proc screen_scrolldown
    ldx #SCREEN_HEIGHT-1 ; current line
    zrepeat
        txa
        jsr calculate_line_address
        lda ptr+0
        sta ptr1+0
        lda ptr+1
        sta ptr1+1      ; ptr1 is dest pointer

        dex
        txa
        jsr calculate_line_address ; ptr is source pointer

        ldy #SCREEN_WIDTH-1
        zrepeat
            lda (ptr), y
            sta (ptr1), y
            dey
        zuntil mi

        cpx #0
    zuntil eq

    ldy #SCREEN_WIDTH-1
    lda #' '
    ora screen_style
    zrepeat
        sta (ptr), y
        dey
    zuntil mi
    rts
.endproc

.proc screen_cleartoeol
    jsr calculate_cursor_address

    lda #' '
    ora screen_style
    zrepeat
        sta (ptr), y
        iny
        cpy #SCREEN_WIDTH
    zuntil eq
    rts
.endproc

.proc screen_setstyle
    ldx #0
    and #STYLE_REVERSE
    zif ne
        ldx #$80
    zendif
    stx screen_style
    rts
.endproc

; --- Keyboard --------------------------------------------------------------

.proc screen_getchar
    jsr toggle_cursor
    zrepeat
        jsr scan_keyboard
        lda pending_key
    zuntil ne
    pha
    jsr toggle_cursor
    pla

    ldx #0
    stx pending_key

    clc
    rts
.endproc

; Does a single keyboard scan, processing any pressed keys. Last pressed key
; wins.

.proc scan_keyboard
    ldy #7                      ; row counter
    zrepeat
        sty VIA_PB

        ldx #7                      ; column counter
        zrepeat
            lda #$0e               ; AY column register
            sta VIA_PA
            lda #$ff               ; write to AY
            sta VIA_PCR
            lda #$dd               ; clear CB2
            sta VIA_PCR

            lda column_pa_values, x
            sta VIA_PA
            lda #$fd
            sta VIA_PCR
            lda #$dd
            sta VIA_PCR

            ; Bit 3 of PB is now set if a key is pressed.

            lda VIA_PB
            and #$08
            lsr a
            lsr a
            lsr a
            lsr a                   ; C is set if key is pressed
            zif cs
                lda column_store_values, x
            zendif
            eor keypress_bitfield, y
            and column_store_values, x ; has key changed state?
            zif ne
                ; Key has changed state.

                eor keypress_bitfield, y
                sta keypress_bitfield, y ; update bitfield

                txa
                pha
                tya
                pha

                jsr key_state_changed

                pla
                tay
                pla
                tax
            zendif

            dex
        zuntil mi

        dey
    zuntil mi
    rts

column_pa_values:
    .byte $7f, $bf, $df, $ef, $f7, $fb, $fd, $fe
column_store_values:
    .byte 1, 2, 4, 8, 16, 32, 64, 128
.endproc

.proc key_state_changed
    tya
    asl a
    asl a
    asl a
    sta ptr+0
    txa
    clc
    adc ptr+0
    tax

    cpx #$23
    beq shift_change
    cpx #$3b
    beq shift_change
    cpx #$13
    beq ctrl_change

    lda VIA_PB
    and #$08
    zif ne
        lda keyboard_decode_tab, x
        bit shift_pressed
        zif mi
            lda keyboard_shift_decode_tab, x
        zendif
        bit ctrl_pressed
        zif mi
            and #$1f
        zendif
        sta pending_key
    zendif
    rts

shift_change:
    lda keypress_bitfield+4
    ora keypress_bitfield+7
    asl a
    asl a
    asl a
    asl a
    sta shift_pressed
    rts

ctrl_change:
    lda keypress_bitfield+2
    asl a
    asl a
    asl a
    asl a
    sta ctrl_pressed
    rts

keyboard_decode_tab:
    .byte '3', 'x', '1', 0, 'v', '5', 'n', '7'
    .byte 'd', 'q', 27,  0, 'f', 'r', 't', 'j'
    .byte 'c', '2', 'z', 0, '4', 'b', '6', 'm'
    .byte '\'', '\\', 0, 0, '-', ';', '9', 'k'
    .byte 137, 138, 136, 0, 139, '.', ',', ' '
    .byte '[', ']', 127, 0, 'p', 'o', 'i', 'u'
    .byte 'w', 's', 'a', 0, 'e', 'g', 'h', 'y'
    .byte '=',  0,  13,  0, '/', '0', 'l', '8'

keyboard_shift_decode_tab:
    .byte '#', 'X', '!', 0, 'V', '%', 'N', '&'
    .byte 'D', 'Q', 27,  0, 'F', 'R', 'T', 'J'
    .byte 'C', '"', 'Z', 0, '$', 'B', '^', 'M' ; " lol
    .byte '\'', '\\', 0, 0, '_', ':', '(', 'K' 
    .byte 0,   0,   0,   0, 0,   '<', '>', ' '
    .byte '{', '}', 127, 0, 'P', 'O', 'I', 'U'
    .byte 'W', 'S', 'A', 0, 'E', 'G', 'H', 'Y'
    .byte '+',  0,  13,  0, '|', ')', 'L', '*'
zendproc


