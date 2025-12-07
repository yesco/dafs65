;;; TODO: I guess this is loading the residental
;;;   part of OS?
BIOS_SECTOR_COUNT= 4
BIOS_LOAD_ADDR= $400


; CP/M-65 Copyright © 2023 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.
;;; 
;;; 2025 Jonas S Karlsson, jsk@yesco.org
;;; File has been "minimized" and adopted to boot d'AtmOS



; #include "zif.inc"
; #include "cpm65.inc"
; #include "driver.inc"
; #include "jumptables.inc"

.feature c_comments
.feature labels_without_colons


/* Microdisc interface definitions */

.define MFDC_command_register    $0310
.define MFDC_status_register     $0310
.define MFDC_track_register      $0311
.define MFDC_sector_register     $0312
.define MFDC_data                $0313
.define MFDC_flags               $0314
.define MFDC_drq                 $0318

.define MFDC_Flag_Side0          %10000001
.define MFDC_Flag_Side1          %10010001

.define MFDC_ID                  0

.define MCMD_ReadSector          $80
.define MCMD_WriteSector         $a0
.define MCMD_Seek                $1f

/* Jasmin interface definitions */

.define JFDC_command_register    $03f4
.define JFDC_status_register     $03f4
.define JFDC_track_register      $03f5
.define JFDC_sector_register     $03f6
.define JFDC_data                $03f7
.define JFDC_flags               $03f8
.define JFDC_drq                 $03FC

.define JFDC_Flag_Side0          %00000000
.define JFDC_Flag_Side1          %00000001

.define JFDC_ovl_control         $03FA
.define JFDC_rom_control         $03FB

.define JFDC_ID                  1

.define JCMD_ReadSector          $8c
.define JCMD_WriteSector         $ac
.define JCMD_Seek                $1F

.define FLOPPY_DELAY            30

/* Other system definitions */

; 6522 VIA
VIA      = $0300
VIA_PB   = VIA + 0
VIA_PA   = VIA + 1
VIA_DDRB = VIA + 2
VIA_DDRA = VIA + 3
VIA_T1CL = VIA + 4
VIA_T1CH = VIA + 5
VIA_T1LL = VIA + 6
VIA_T1LH = VIA + 7
VIA_T2CL = VIA + 8
VIA_T2CH = VIA + 9
VIA_SR   = VIA + 10
VIA_ACR  = VIA + 11
VIA_PCR  = VIA + 12
VIA_IFR  = VIA + 13
VIA_IER  = VIA + 14
VIA_ORA  = VIA + 15

VIA_PB_NDAC_IN  = 1<<0
VIA_PB_NRFD_OUT = 1<<1
VIA_PB_ATN_OUT  = 1<<2
VIA_PB_NRFD_IN  = 1<<6
VIA_PB_DAV_IN   = 1<<7

/* Screen stuff */

.define SCREEN_WIDTH            40
.define SCREEN_HEIGHT           28

.define SCREEN_TEXT             $bb80

; --- Zero page -------------------------------------------------------------

.zeropage

ptr:              .res 2
ptr1:             .res 2

.code

; --- Bootloader code -------------------------------------------------------

/* The Oric boot process is a bit complicated due to there being two different
 * disk systems we need to support. */




;;; ==================================================
;;;                 J A S M I N 


; Jasmin will load this at $0400.


;.segment "sector1", "ax"

.org $0400

sector1:        


;;; Only for debug disk, cannot have when run/boot!
;
SHOWNAMES=1

.ifdef SHOWNAMES
.byte "JASMIN>>>"
.endif

    jmp jasmin_start

; Microdisc requires this literal data.

    .byte $00, $00, $00, $00, $00, $20, $20, $20 ; :.....   :
    .byte $20, $20, $20, $20, $20, $00, $00, $03 ; :     ...:
    .byte $00, $00, $00, $01, $00, $53, $45, $44 ; :.....SED:
    .byte $4F, $52, $49, $43, $20, $20, $20, $20 ; :ORIC    :
    .byte $20, $20, $20, $20, $20, $20, $20, $20 ; :        :
    .byte $20, $20, $20, $20, $20, $20, $20, $20 ; :        :
    .byte $20, $20, $20, $20, $20, $20, $20, $20 ; :        :
    .byte $20, $20, $20, $20, $20                   ; :    ....:

; Jasmin boot code starts here.

jasmin_start:
    /* Turn off the EPROM, exposing RAM. */

    sei
    lda #1
    sta JFDC_ovl_control        ; enable overlay RAM
    sta JFDC_rom_control        ; disable ROM

    /* Set up for reading the BIOS. */

    lda #<BIOS_LOAD_ADDR        ; set read pointer
    sta ptr+0
    lda #>BIOS_LOAD_ADDR
    sta ptr+1

    ldx #4                      ; sector to read
;    zrepeat
@nextsector:
        stx JFDC_sector_register    ; sector to read

        /* Do the read. */

        lda #JCMD_ReadSector
        sta JFDC_command_register

        ldy #FLOPPY_DELAY
;        zrepeat
@delay:
            nop
            nop
            dey
;        zuntil eq
         bne @delay

        ldy #0

;        zrepeat
@next:

;            zrepeat
@wait:        
                lda JFDC_drq
;            zuntil pl
             bmi @wait

            lda JFDC_data
            sta (ptr), y
            iny
;        zuntil eq
         bne @next

        /* Advance to next sector. */

        inx
        inc ptr+1
        cpx #4 + BIOS_SECTOR_COUNT
;    zuntil eq
     bne @nextsector

    /* Patch the BIOS floppy routines to use the Jasmin registers. */

.ifdef JASMINE
    lda #JFDC_Flag_Side0
    sta __fdc_side0_flag
    lda #JFDC_Flag_Side1
    sta __fdc_side1_flag
    lda #JCMD_ReadSector
    sta __fdc_readsector_cmd
    lda #JCMD_WriteSector
    sta __fdc_writesector_cmd
    lda #JCMD_Seek
    sta __fdc_seek_cmd
    lda #<JFDC_command_register
    sta __fdc_command_reg
    lda #<JFDC_drq
    sta __fdc_drq_reg_0
    sta __fdc_drq_reg_1
    lda #<JFDC_status_register
    sta __fdc_status_reg
    lda #<JFDC_flags
    sta __fdc_flags_reg
    lda #<JFDC_data
    sta __fdc_data_reg_0
    sta __fdc_data_reg_1
    sta __fdc_data_reg_2
    lda #<JFDC_track_register
    sta __fdc_track_reg
    lda #<JFDC_sector_register
    sta __fdc_sector_reg

.endif ; JASMINE

    lda #JFDC_ID
    jmp _start

.ifdef SHOWNAMES
.byte "<<<JASMIN"
.endif

.res $500-*


;;;                  J A S M I N 
;;; ==================================================
;;;               M I C R O D I S K




;.segment "sector2", "ax"
.org $0400
sector2:        

.ifdef SHOWNAMES
.byte "MICRODISK>>>"
.endif

;;; TODO:

; This is the Microdisc boot sector. It can load at a variety of
; addresses, for maximum inconvenience. After loading, we relocate to
; $9800, which is known to be unused (it's in the highres screen
; area).

; These literal bytes go before the code itself:

;;; TODO(jsk):  (what are they?)

    .byte $00, $00, $FF, $00, $D0, $9F, $D0, $9F
    .byte $02, $B9, $01, $00, $FF, $00, $00, $B9
    .byte $E4, $B9, $00, $00, $E6, $12, $00

;;; boot: somehow microcode loads us anywhere?

        ;; jsk
        lda #'A'
        sta SCREEN+0

    sei
;;; To figure out our dynamically loaded address
;;; we do an JSR and pick it off the stack after return!
    lda #$60                    ; RTS
    sta ptr                     ; place an RTS in zero page
    jsr ptr                     ; call it

;;; Lol: a dummy label (by cpm)
return:

    tsx
    dex
    clc
    lda $0100, x                ; get low byte
    sbc #(return - sector2 - 2) ; adjust to beginning of sector
    sta ptr+0

    lda $0101, x               ; get high byte
    sbc #0
    sta ptr+1                   ; ptr points to code

    ; Copy 256 bytes.
    ldy #0
:       
        lda (ptr), y
        sta sector2, y
        iny
    bne :-

        ;; Now wew jump to the code we just copied!
        ;; (.org made this address compile right, it's just
        ;;  in wrong place in memory - relocate!)
        jmp sector2_start


sector2_start:

        ;; JSK
        lda #'B'
        sta SCREEN+1


;;; TODO: make it load my main "program"!

.ifdef LOAD_BIOS

;;; TODO: I guess this is turning off ATMOS BASIC ROM?

    /* Turn off the EPROM, exposing RAM. */

    lda #MFDC_Flag_Side0        ; EPROM off, FDC interrupts off
    sta MFDC_flags

    /* Set up for reading the BIOS. */

    lda #<BIOS_LOAD_ADDR        ; set read pointer
    sta ptr+0
    lda #>BIOS_LOAD_ADDR
    sta ptr+1

    ldx #4                      ; sector to read
;    zrepeat
@nextsector:
        stx MFDC_sector_register    ; sector to read

        /* Do the read. */
        lda #MCMD_ReadSector
        sta MFDC_command_register

        ldy #FLOPPY_DELAY
@delay:
            nop
            nop
            dey
        bne @delay

        ldy #0
@next:
@wait:
        lda MFDC_drq
        bmi @wait

            lda MFDC_data
            sta (ptr), y
            iny
        bne @next

        /* Advance to next sector. */
        inx
        inc ptr+1
        cpx #4 + BIOS_SECTOR_COUNT

     bne @nextsector

.endif ; LOAD_BIOS

    lda #MFDC_ID

;;; START is whatever wwas loaded $501 ??? if TAP file basic!
    jmp _start


;;; TODO: move to OS "bios" ???
;;; jsk: dummy start and HALT

SCREEN= $bb80

_start: 
        lda #'C'
        sta SCREEN+2

halt:   
        lda #'H'
        sta SCREEN+3
        jmp halt

.ifdef SHOWNAMES
.byte "<<<MICRODISK"
.endif

.res $500-*




;;;               M I C R O D I S K
;;; ==================================================
;;;                  J A S M I N 





;;; TODO: 
;.segment "sector3", "ax"
sector3:        

; Sector 3 of a disk must contain this exact data, or the Microdisc ROM will
; refuse to boot it. (It's a minimal Microdisc filesystem.)

    .byte $00,$00,$02,$53,$59,$53,$54,$45,$4d,$44,$4f,$53,$01,$00,$02,$00  ; ...SYSTEMDOS....
    .byte $02,$00,$00,$42,$4f,$4f,$54,$55,$50,$43,$4f,$4d,$00,$00,$00,$00  ; ...BOOTUPCOM....
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; ................









; --- Initialisation code ---------------------------------------------------

/* This is run once on startup and then discarded. */

.ifdef START

.proc _start
    pha                     ; store xFDC_ID
    jsr init_hardware
    jsr screen_clear

    ldy #banner_end - banner

;    zrepeat
@printbanner:

        tya
        pha
        lda banner-1, y
        jsr tty_conout
        pla
        tay
        dey

;    zuntil eq
     bne @printbanner

    pla                     ; get xFDC_ID back

;    zif ne
    beq @notjasmine

      ldy #msg_jasmin_end - msg_jasmin

;      zrepeat
@printbanner2:

          tya
          pha
          lda msg_jasmin-1, y
          jsr tty_conout
          pla
          tay
          dey

;      zuntil eq
       bne @printbanner2

      beq msg_crlf

;    zendif
@notjasmine:


    ldy #msg_microdisc_end - msg_microdisc

;    zrepeat
@printbanner3:
        tya
        pha
        lda msg_microdisc-1, y
        jsr tty_conout
        pla
        tay
        dey
;    zuntil eq
     bne @printbanner3


msg_crlf:
    lda #10
    jsr tty_conout
    lda #13
    jsr tty_conout

    ; Miscellaneous initialisation.

    ldx #bss_top - bss_bottom
    lda #0
;zrepeat
:       
        sta bss_bottom-1, x
        dex
;    zuntil eq
     bne :-

    ldx #$ff
    stx buffered_host_sector
    stx buffered_track
    jsr initdrivers

    ; Read the BDOS.

    lda #<bdos_filename
    ldx #>bdos_filename
    ldy #>__TPA1_START__
    jsr loadfile

    ; Relocate it.

    lda #>__TPA1_START__
    ldx #__ZEROPAGE_START__
    jsr bios_RELOCATE

    ; Go!

;    lda #<biosentry
;    ldx #>biosentry

;;; TODO: 
;;; GO where?
;    jmp __TPA1_START__ + COMHDR_ENTRY
        
bdos_filename:
    .byte "BDOS    SYS"

msg_jasmin:
    .byte "nimsaJ"
msg_jasmin_end:

msg_microdisc:
    .byte "csidorciM"
msg_microdisc_end:

banner: ; reversed!
    .byte "/cirO eht rof 56-M/PC"
banner_end:

.endproc ; _start

.endif ; START






.ifdef INIT_HARDWARE

; Initializes VIA and AY-3-8912 defaults (iss)
.proc init_hardware

    lda   #$ff
    sta   VIA_PA
    sta   VIA_ORA
    sta   VIA_DDRA
    lda   #$b7
    sta   VIA_PB
    lda   #$f7
    sta   VIA_DDRB
    lda   #$dd
    sta   VIA_PCR
    lda   #$7f
    sta   VIA_IER
    lda   #$40
    sta   VIA_ACR

    lda   #<50000           ; 50 msec
    ldx   #>50000
    sta   VIA_T1LL
    sta   VIA_T1CL
    stx   VIA_T1LH
    stx   VIA_T1CH

    lda   #$c0             ; enable T1 interrupt
    sta   VIA_IER

    lda   #$07             ; set i/o port on 8912 to output
    ldx   #$3f             ; and disable mixer
    jsr   psg_x2a

    lda   #$08             ; mute all channels
    ldx   #$00
    jsr   psg_x2a
    lda   #$09
    ldx   #$00
    jsr   psg_x2a
    lda   #$0a
    ldx   #$00
    jsr   psg_x2a

    lda   #$00
    ldx   #$7f
    jsr   psg_x2a

    lda   #$01
    ldx   #$00
;   jmp   psg_x2a           ; fall trough
.endproc ; init_hardware


; Writes X to port A
.proc psg_x2a
    sta   VIA_PA
    tay
    txa
    cpy   #$07
;    zif eq
    bne :+
      ora   #$40
;    zendif
:       

    pha
    lda   VIA_PCR
    ora   #$ee
    sta   VIA_PCR
    and   #$11
    ora   #$cc
    sta   VIA_PCR
    tax
    pla
    sta   VIA_PA
    txa
    ora   #$ec
    sta   VIA_PCR
    and   #$11
    ora   #$cc
    sta   VIA_PCR
    rts
zendproc

.endif ; INIT_HARDWARE      


.ifdef BIOS

; --- BIOS entrypoints ------------------------------------------------------

.proc bios_GETTPA
    ldy current_bank
    lda mem_base, y
    ldx mem_end, y
    clc
    rts
.endproc

.proc bios_SETTPA
    ldy current_bank
    sta mem_base, y
    txa                 ; BUG: stx mem_end, y - invalid 6502 instruction
    sta mem_end, y
    clc
    rts
.endproc

.proc bios_GETZP
    lda zp_base
    ldx zp_end
    clc
    rts
.endproc

.proc bios_SETZP
    sta zp_base
    stx zp_end
    clc
    rts
.endproc

.proc bios_SETBANK
    sta current_bank
    rts
.endproc

.proc fail
    sec
    rts
.endproc

; Sets the current DMA address.

.proc bios_SETDMA
    sta dma+0
    stx dma+1
    rts
.endproc

; Select a disk.
; A is the disk number.
; Returns the DPH in XA.
; Sets carry on error.

.proc bios_SELDSK
    cmp #0
    bne fail                ; invalid drive

    lda #<dph
    ldx #>dph
    clc
    rts
.endproc

; Set the current absolute sector number.
; XA is a pointer to a three-byte number.

.proc bios_SETSEC
    sta ptr+0
    stx ptr+1

    ; Copy bottom 16 of sector number to temporary (the top byte must be 0).

    ldy #0
    lda (ptr), y
    sta ptr1+0
    iny
    lda (ptr), y
    sta ptr1+1

    ; There are 34 CP/M sectors per host track. Do a 16-bit divide.

    lda #0
    sta requested_cpm_sector

    ldx #16
    lda #0
;    zrepeat
@next:
        asl ptr1+0
        rol ptr1+1
        rol a
        cmp #34

;        zif cs
        bcc :+
            sbc #34
            inc ptr1+0
;        zendif
:       

        dex
;    zuntil eq
     bne @next

    sta requested_cpm_sector
    lda ptr1+0
    sta requested_track

    rts
.endproc

.proc bios_READ
    jsr change_sector

;    zif cc
    bcs @noneed

        lda requested_cpm_sector
        ror a
        lda #0
        ror a               ; $00 or $80
        tax

        ldy #0
;        zrepeat
:       
            lda DISK_BUFFER, x
            sta (dma), y
            inx
            iny
            cpy #$80
;        zuntil eq
         bne :-
        clc
;    zendif
@noneed:        

    rts
.endproc

.proc bios_WRITE
    pha
    jsr change_sector
    pla
;    zif cc
    bcs @noneed
        pha

        lda requested_cpm_sector
        ror a
        lda #0
        ror a               ; $00 or $80
        tax

        ldy #0

;        zrepeat
:       
            lda (dma), y
            sta DISK_BUFFER, x
            inx
            iny
            cpy #$80
;        zuntil eq
        bne :-

        lda #$80
        sta buffer_dirty

        clc
        pla

;        zif ne
         beq :+
            jsr flush_buffer

;        zendif
:       

;    zendif
@noneed:        

    rts
.endproc

.endif ; BIOS


.ifdef DISK_ACCESS

; --- Disk access -----------------------------------------------------------

.proc change_sector
    lda requested_cpm_sector
    lsr a
    cmp buffered_host_sector
    zif eq
        lda requested_track
        cmp buffered_track
        zif eq
            ; Buffered track/sector not changing, so do no work.

            clc
            rts
        zendif
    zendif

    bit buffer_dirty
    zif mi
        jsr flush_buffer
        zif cs
            rts
        zendif
    zendif

    lda requested_cpm_sector
    lsr a
    sta buffered_host_sector

    lda requested_track
    sta buffered_track

    jsr prepare_read_fdc_command

    ldy #0
    zrepeat
        zrepeat
__fdc_drq_reg_0 = . + 1
            lda MFDC_drq
        zuntil pl
__fdc_data_reg_0 = . + 1
        lda MFDC_data
        sta DISK_BUFFER, y
        iny
    zuntil eq

    jsr wait_for_fdc_completion
    clc
    and #$1c
    zif ne
        ; Some kind of read error. The data in the buffer is corrupt.

        lda #$ff
        sta buffered_track

        sec
    zendif
    rts
.endproc

.proc flush_buffer
    jsr prepare_write_fdc_command

    ldy #0
    zrepeat
        zrepeat
__fdc_drq_reg_1 = . + 1
            lda MFDC_drq
        zuntil pl
        lda DISK_BUFFER, y
__fdc_data_reg_1 = . + 1
        sta MFDC_data
        iny
    zuntil eq

    jsr wait_for_fdc_completion
    sec
    and #$1c
    zif eq
        ; A successful write, so mark the buffer as clean.

        lda #0
        sta buffer_dirty
        clc
    zendif
    rts
.endproc

; Seek to the appropriate track and prepare for a read or write transfer.

.proc prepare_fdc
    ; Seek to track.

    lda buffered_track
    lsr a                           ; bottom bit is the side
__fdc_track_reg = . + 1
    cmp MFDC_track_register
    zif ne
__fdc_data_reg_2 = . + 1
        sta MFDC_data               ; computed track
__fdc_seek_cmd = . + 1
        lda #MCMD_Seek
        jsr write_fdc_command

        jsr wait_for_fdc_completion
    zendif

    ; Set sector.

    ldx buffered_host_sector
    inx                             ; FDC wants 1-based sectors
__fdc_sector_reg = . + 1
    stx MFDC_sector_register

    ; Set head.

__fdc_side0_flag = . + 1
    ldx #MFDC_Flag_Side0
    lda buffered_track
    ror a
    zif cs
__fdc_side1_flag = . + 1
        ldx #MFDC_Flag_Side1
    zendif
__fdc_flags_reg = . + 1
    stx MFDC_flags

    rts
.endproc

.proc wait_for_fdc_completion
    ; Short delay before checking the register.

    ldy #4
    zrepeat
        dey
    zuntil eq

    zloop
__fdc_status_reg = . + 1
        lda MFDC_status_register
        lsr a
    zuntil cc
    asl a
    rts
.endproc

.proc prepare_read_fdc_command
    jsr prepare_fdc
__fdc_readsector_cmd = . + 1
    lda #MCMD_ReadSector
.endproc
    ; fall through
.proc write_fdc_command
__fdc_command_reg = . + 1
    sta MFDC_command_register

    ldy #4
    zrepeat
        nop
        nop
        dey
    zuntil eq
    rts
.endproc

.proc prepare_write_fdc_command
    jsr prepare_fdc
__fdc_writesector_cmd = . + 1
    lda #MCMD_WriteSector
    jmp write_fdc_command
.endproc

.endif ; DISK_ACCESS

.ifdef VECTORS
; --- Vectors ---------------------------------------------------------------

.proc brk_handler
    pla             ; discard flags

    ldy #brk_message_end - brk_message
    zrepeat
        tya
        pha
        lda brk_message-1, y
        jsr tty_conout
        pla
        tay
        dey
    zuntil eq

    pla
    tay             ; low byte of fault address
    pla
    tax             ; high byte of fault address
    tya
    jsr print_hex16_number

    lda #10
    jsr tty_conout
    lda #13
    jsr tty_conout

    lda #<biosentry
    ldx #>biosentry
    jmp __TPA1_START__ + COMHDR_ENTRY

brk_message: ; reversed!
    .byte " KRB"
    .byte 13, 10, 13, 10
brk_message_end:
.endproc

.proc nmi_handler
    ldy #nmi_message_end - nmi_message
    zrepeat
        tya
        pha
        lda nmi_message-1, y
        jsr tty_conout
        pla
        tay
        dey
    zuntil eq

    lda #<biosentry
    ldx #>biosentry
    jmp __TPA1_START__ + COMHDR_ENTRY

nmi_message: ; reversed!
    .byte 13, 10
    .byte "IMN"
    .byte 13, 10, 13, 10
nmi_message_end:
.endproc

; Prints a 16-bit hex number in XA.
.proc print_hex16_number
    pha
    txa
    jsr print_hex_number
    pla
    jmp print_hex_number
.endproc

; Prints an 8-bit hex number in A.
.proc print_hex_number
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr print_hex4_number
    pla
print_hex4_number:
    and #$0f
    ora #'0'
    cmp #'9'+1
    zif cs
        adc #6
    zendif
    pha
    jsr tty_conout
    pla
    rts
.endproc

.segment "tail", "ax"

    .word nmi_handler
    .word 0
    .word brk_handler

.endif ; VECTOR

; --- Data ------------------------------------------------------------------

.data

;zp_base:    .byte __ZEROPAGE_START__
;zp_end:     .byte __ZEROPAGE_END__
;mem_base:   .byte __TPA0_START__@mos16hi, __TPA1_START__@mos16hi
;mem_end:    .byte __TPA0_END__@mos16hi,   __TPA1_END__@mos16hi

; DPH for drive 0 (our only drive)

;define_dpb dpb, 2844, 2048, 64, 34
;define_dph dph, dpb

.data

;bss_bottom:
;current_bank:           .res 1     ; which memory bank is selected
;requested_cpm_sector:   .res 1     ; CP/M sector requested by user
;requested_track:        .res 1     ; track requested by user
;buffered_host_sector:   .res 1     ; host sector in buffer
;buffered_track:         .res 1     ; track in buffer
;buffer_dirty:           .res 1     ; top bit set if the buffer was modified
;directory_buffer:       .res 128   ; used by the BDOS
bss_top:

;.global directory_buffer

