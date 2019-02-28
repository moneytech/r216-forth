;; r2asm("/Users/siraben/Documents/Playground/R216/forth.asm", 0xDEAD, "/Users/siraben/Documents/Playground/R216/r2asm.log")

;; Register allocations
;; r0: Top of stack (TOS)
;; r1: Forth instruction pointer (IP)
;; r2: Return stack pointer (RSP)
;; r3: User pointer (HERE)

;; r10: Terminal port
;; sp: Parameter stack pointer (PSP)

;; r4 - r9: unassigned
;; r11 - r13: unassigned

;; word header:
;; 0: previous entry
;; 1: length + flags
;; 2: null-terminated name

start:
        mov sp, 0
        mov r2, 0x1f00
        mov r10, 0
        bump r10
        send r10, 0x1000
        send r10, 0x200F
        
        mov r1, main
        jmp next

main:
        dw lit, 9, here, store
main_loop:
        dw here, fetch, zjump, main_end
        dw here, fetch, lit, '0', plus, emit
        dw lit, 1, here, minus_store
        dw jump, main_loop

main_end:
        dw lit, you_typed_msg, puts
        dw drop, halt
        
        dw lit, 5, lit, 5, minus, zjump, wow
        dw lit, you_typed_msg, puts, halt
wow:
        dw lit, wow_msg, puts, halt
        
        dw lit, inputdata_prompt, puts
        dw lit, str_buf
        dw lit, 14, lit, 0x1012, getline
        
        dw lit, 0x1020, term_send
        dw lit, you_typed_msg, puts
        
        dw lit, 0x1030, term_send
        dw lit, str_buf, puts
        dw halt

        
allot:
        add r3, r0
        pop r0
        jmp next
        
here:
        push r0
        mov r0, r3
        jmp next

fetch:
        mov r4, [r0]
        mov r0, r4
        jmp next

store:
        pop r4
        mov [r0], r4
        pop r0
        jmp next

plus_store:
        pop r4
        add [r0], r4
        pop r0
        jmp next
        

minus_store:
        pop r4
        sub [r0], r4
        pop r0
        jmp next
        
dup:
        push r0
        jmp next

drop:
        pop r0
        jmp next

swap:
        pop r5
        push r0
        mov r0, r5
        jmp next

plus:
        pop r4
        add r0, r4
        jmp next


minus:
        pop r4
        sub r0, r4
        jmp next

one_minus:
        sub r0, 1
        jmp next

one_plus:
        add r0, 1
        jmp next

branch:
        mov r4, [r1]
        add r1, r4
        jmp next

zbranch:
        cmp r0, 0
        je zbranch_succ
        pop r0
        add r1, 1
        jmp next
        
zbranch_succ:
        pop r0
        mov r4, [r1]
        add r1, r4
        jmp next


div:
        

jump:
        mov r4, [r1]
        mov r1, r4
        jmp next

zjump:
        cmp r0, 0
        je zjump_succ
        pop r0
        add r1, 1
        jmp next
        
zjump_succ:
        pop r0
        mov r4, [r1]
        add r1, 1
        mov r1, r4
        jmp next


;; ( addr count cursor -- )
getline:
        mov r11, r0
        mov r6, r1
        pop r1
        mov r7, 0x200F
        pop r0
        ;; Save r1
        push r6
        call read_string
        ;; Restore r1
        pop r1
        
        ;; New TOS
        pop r0
        jmp next


divmod:
        pop r5
        mov r6, 0
        mov r6, 16
        
        jmp next
;; Print a character.
;; ( c -- )
emit:
        send r10, r0
        pop r0
        jmp next

;; Send a message to the terminal.
;; ( n -- )
term_send:
        send r10, r0
        pop r0
        jmp next


;; (IP) -> W
;; IP + 1 -> IP
;; JP (W)
next:
        mov r4, [r1]
        add r1, 1
        jmp r4

;; Since we do a call to docol, we
;; assume we have the return address
;; on the top of the stack.

;; PUSH_IP_RS
;; POP IP
;; JP NEXT
docol:
        sub r2, 1
        mov [r2], r1
        pop r1
        jmp next

;; POP_IP_RS
;; JP NEXT
exit:
        mov r1, [r2]
        add r2, 1
        jmp next
        
you_typed_msg:
        dw 0x200F, "You typed: ", 0
wow_msg:
        dw 0x200F, "wow", 0

inputdata_prompt:
        dw 0x1010, 0x200F, "> ", 0
        dw 0

puts:
        call write_string
        pop r0
        jmp next
        

lit:
        push r0
        mov r0, [r1]
        add r1, 1
        jmp next

halt:
        hlt

; * Writes zero-terminated strings to the terminal.
; * r0 points to buffer to write from.
; * r10 is terminal port address.
; * r11 is incremented by the number of characters sent to the terminal (which
;   doesn't help at all if the string contains colour or cursor codes).
write_string:
        push r0
        push r1
        mov r5, r0
.loop:
        mov r1, [r0]
        jz .exit
        add r0, 1
        send r10, r1
        jmp .loop
.exit:
        add r11, r0
        sub r11, r5
        pop r1
        pop r0
        ret

; * Sends spaces to the terminal.
; * r10 holds the number of spaces to send.
clear_continuous:
.loop:
    send r10, 32
    sub r0, 1
    jnz .loop
    ret


; * Reads a single character from the terminal.
; * Character code is returned in r0.
; * r10 is terminal port address.
read_character:
.wait_loop:
    wait r3                   ; * Wait for a bump. r3 should be checked but
                              ;   as in this demo there's no other peripheral,
                              ;   it's fine this way.
    js .wait_loop
    bump r10                  ; * Ask for character code.
.recv_loop:
    recv r0, r10              ; * Receive character code.
    jnc .recv_loop            ; * The carry bit it set if something is received.
    ret

; * Sends spaces to the terminal.
; * r10 holds the number of spaces to send.
clear_continuous:
.loop:
    send r10, 32
    sub r0, 1
    jnz .loop
    ret

; * Reads a single character from the terminal while blinking a cursor.
; * r6 is cursor colour.
; * r10 is terminal port address.
; * r11 is cursor position.
; * Character read is returned in r8.
read_character_blink:
    mov r12, 0x7F             ; * r12 holds the current cursor character.
    mov r9, 8                 ; * r9 is the counter for the blink loop.
    send r10, r6
    send r10, r11
    send r10, r12              ; * Display cursor.
.wait_loop:
    wait r8                   ; * Wait for a bump. r3 should be checked but
                              ;   as in this demo there's no other peripheral,
                              ;   it's fine this way.
    jns .got_bump             ; * The sign flag is cleared if a bump arrives.
    sub r9, 1
    jnz .wait_loop            ; * Back to waiting if it's not time to blink yet.
    xor r12, 0x5F              ; * Turn a 0x20 into a 0x7F or vice versa.
    send r10, r6              ;   Those are ' ' and a box, respectively.
    send r10, r11
    send r10, r12              ; * Display cursor.
    mov r9, 8
    jmp .wait_loop            ; * Back to waiting, unconditionally this time.
.got_bump:
    bump r10                  ; * Ask for character code.
.recv_loop:
    recv r8, r10              ; * Receive character code.
    jnc .recv_loop            ; * The carry bit it set if something is received.
    ret




; * Reads zero-terminated strings from the terminal.
; * r0 points to buffer to read into and r1 is the size of the buffer,
;   including the zero that terminates the string. If you have a 15 cell
;   buffer, do pass 15 in r1, but expect only 14 characters to be read at most.
; * r7 is the default cursor colour (the one used when the buffer is not about
;   to overflow; when it is, the cursor changes to yellow, 0x200E).
; * r10 is terminal port address.
; * r11 is cursor position.
read_string:
    bump r10                  ; * Drop whatever is in the input buffer.
    mov r5, r1
    sub r5, 1                 ; * The size of the buffer includes the
                              ;   terminating zero, so the character limit
                              ;   should be one less than this size.
    mov r6, r7                ; * Reset the default cursor colour.
    mov r1, 0                 ; * r1 holds the number of characters read.
.read_character:
    call read_character_blink
    cmp r8, 13                ; * Check for thr Return key.
    je .got_return
    cmp r8, 8                 ; * Check for the Backspace key.
    je .got_backspace
    cmp r5, r1                ; * Check if whatever else we got fits the buffer.
    je .read_character
    send r10, r11             ; * If it does, display it and add it to the
    send r10, r8              ;   buffer.
    add r11, 1
    mov [r0+r1], r8
    add r1, 1
    cmp r5, r1
    ja .read_character        ; * Change cursor colour to yellow if the buffer
    mov r6, 0x200E            ;   is full.
    jmp .read_character       ; * Back to waiting.
.got_backspace:
    cmp r1, 0                 ; * Only delete a character if there is at least
    je .read_character        ;   one to delete.
    mov r6, r7                ; * Reset the default cursor colour.
    send r10, r11
    send r10, 0x20            ; * Clear the previous position of the cursor.
    sub r11, 1
    sub r1, 1
    jmp .read_character       ; * Back to waiting.
.got_return:
    send r10, r11
    send r10, 0x20            ; * Clear the previous position of the cursor.
    mov [r0+r1], 0            ; * Terminate string explicitly.
    ret

str_buf:
    dw "              "       ; * Global string buffer for use with functions
                              ;   that operate on strings. 14 cells. Don't
                              ;   worry, it's thread-safe.

