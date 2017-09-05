;==================================================================================
;
; INTERRUPT SECTION
;
; Interrupt Service Routine for the Am9511A-1
; 
; Initially called once the required operand pointers and commands are loaded
; Following calls generated by END signal whenever a single APU command is completed
; Sends a new command (with operands if needed) to the APU
;
; On interrupt exit APUStatus contains either
; __IO_APU_STATUS_BUSY = 1, and rest of APUStatus bits are invalid
; __IO_APU_STATUS_BUSY = 0, idle, and the status bits resulting from the final COMMAND

    INCLUDE "config_private.inc"

    SECTION code_driver

    PUBLIC asm_am9511a_isr

    EXTERN APUCMDOutPtr, APUPTROutPtr
    EXTERN APUCMDBufUsed, APUPTRBufUsed, APUStatus, APUError

    asm_am9511a_isr:
        push af                 ; store AF, etc, so we don't clobber them
        push bc
        push de
        push hl

        xor a                   ; set internal clock = crystal x 1 = 18.432MHz
                                ; that makes the PHI 9.216MHz
        out0 (CMR), a           ; CPU Clock Multiplier Reg (CMR)
                                ; Am9511A-1 needs TWCS 30ns. This provides 41.7ns.

    am9511a_isr_entry:
        ld a, (APUCMDBufUsed)   ; check whether we have a command to do
        or a                    ; zero?
        jr z, am9511a_isr_end   ; if so then clean up and END

        ld hl, APUStatus        ; set APUStatus to busy
        ld (hl), __IO_APU_STATUS_BUSY

        ld bc, __IO_APU_PORT_STATUS ; the address of the APU status port in BC
        in a, (c)               ; read the APU
        and __IO_APU_STATUS_ERROR   ; any errors?
        call nz, am9511a_isr_error  ; then capture error in APUError

        ld hl, (APUCMDOutPtr)   ; get the pointer to place where we pop the COMMAND
        ld a, (hl)              ; get the COMMAND byte
        push af                 ; save the COMMAND 

        inc l                   ; move the COMMAND pointer low byte along, 0xFF rollover
        ld (APUCMDOutPtr), hl   ; write where the next byte should be popped

        ld hl, APUCMDBufUsed
        dec (hl)                ; atomically decrement COMMAND count remaining

        and $F0                 ; mask only most significant nibble of COMMAND
        cp __IO_APU_OP_ENT      ; check whether it is OPERAND entry COMMAND
        jr z, am9511a_isr_op_ent    ; load an OPERAND

        cp __IO_APU_OP_REM      ; check whether it is OPERAND removal COMMAND
        jr z, am9511a_isr_op_rem    ; remove an OPERAND

        pop af                  ; recover the COMMAND 
        ld bc, __IO_APU_PORT_CONTROL    ; the address of the APU control port in BC
        out (c), a              ; load the COMMAND, and do it

    am9511a_isr_exit:
        ld a, CMR_X2            ; set internal clock = crystal x 2 = 36.864MHz
        out0 (CMR), a           ; CPU Clock Multiplier Reg (CMR)

        pop hl                  ; recover HL, etc
        pop de
        pop bc
        pop af
        retn

    am9511a_isr_end:            ; we've finished a COMMAND sequence
        ld bc, __IO_APU_PORT_STATUS ; the address of the APU status port in BC
        in a, (c)               ; read the APU
        ld (APUStatus), a       ; update status byte
        jr am9511a_isr_exit     ; we're done here

    am9511a_isr_op_ent:
        ld hl, (APUPTROutPtr)   ; get the pointer to where we pop OPERAND PTR
        ld e, (hl)              ; read the OPERAND PTR low byte from the APUPTROutPtr
        inc l                   ; move the POINTER low byte along, 0xFF rollover
        ld d, (hl)              ; read the OPERAND PTR high byte from the APUPTROutPtr
        inc l
        ld (APUPTROutPtr), hl   ; write where the next POINTER should be read

        ld hl, APUPTRBufUsed    ; decrement of POINTER count remaining
        dec (hl)
        dec (hl)

        ld bc, __IO_APU_PORT_DATA+$0300 ; the address of the APU data port (+3) in BC
        ex de, hl               ; move the base address of the OPERAND to HL

        outi                    ; output 16 bit OPERAND

        ex (sp), hl             ; delay for 38 cycles (5us) TWI @1.152MHz 3.472us
        ex (sp), hl
        outi

        pop af                  ; recover the COMMAND 
        cp __IO_APU_OP_ENT16    ; is it a 2 byte OPERAND
        jp z, am9511a_isr_entry ; yes? then go back to get another COMMAND

        ex (sp), hl             ; delay for 38 cycles (5us) TWI 1.280us
        ex (sp), hl
        outi                    ; output last two bytes of 32 bit OPERAND

        ex (sp), hl             ; delay for 38 cycles (5us) TWI @1.152MHz 3.472us
        ex (sp), hl
        outi

        jp am9511a_isr_entry    ; go back to get another COMMAND

    am9511a_isr_op_rem:
        ld hl, (APUPTROutPtr)   ; get the pointer to where we pop OPERAND PTR
        ld e, (hl)              ; read the OPERAND PTR low byte from the APUPTROutPtr
        inc l                   ; move the POINTER low byte along, 0xFF rollover
        ld d, (hl)              ; read the OPERAND PTR high byte from the APUPTROutPtr
        inc l
        ld (APUPTROutPtr), hl   ; write where the next POINTER should be read

        ld hl, APUPTRBufUsed    ; decrement of OPERAND POINTER count remaining
        dec (hl)
        dec (hl)

        ld bc, __IO_APU_PORT_DATA+$0300 ; the address of the APU data port (+3) in BC
        ex de, hl               ; move the base address of the OPERAND to HL

        inc hl                  ; reverse the OPERAND bytes to load

        pop af                  ; recover the COMMAND 
        cp __IO_APU_OP_REM16    ; is it a 2 byte OPERAND
        jr z, am9511a_isr_op_rem16  ; yes then skip over 32bit stuff

        inc hl                  ; increment two more bytes for 32bit OPERAND
        inc hl

        ind                     ; get the higher two bytes of 32bit OPERAND
        ind

    am9511a_isr_op_rem16:
        ind                     ; get 16 bit OPERAND
        ind

        jp am9511a_isr_entry    ; go back to get another COMMAND

    am9511a_isr_error:          ; we've an error to notify in A
        ld hl, APUError         ; collect any previous errors
        or (hl)                 ; and we add any new error types
        ld (hl), a              ; set the APUError status
        ret                     ; we're done here

