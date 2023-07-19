.attribute arch, "rv64im"

.text

.set LINE_BUF_LENGTH, 1024

.global start
start:
        mv s1, ra
        la a0, INIT_MSG
        ld a1, (INIT_MSG_LENGTH)
        call put_buf
        # allocate line buffer into s2
        li a0, LINE_BUF_LENGTH
        li a1, 1
        call allocate
        beqz a0, .Lstart_end
        mv s2, a0
.Lstart_repl:
        la a0, PROMPT
        ld a1, (PROMPT_LENGTH)
        call put_buf
        mv a0, s2
        li a1, LINE_BUF_LENGTH
        call get_line
        beqz a0, .Lstart_end
        mv a1, a0
        mv a0, s2
        call put_buf
        la a0, OK_MSG
        ld a1, (OK_MSG_LENGTH)
        call put_buf
        j .Lstart_repl
.Lstart_end:
        mv ra, s1
        ret

.section .rodata

INIT_MSG: .ascii "\nstage1 initializing.\n"
INIT_MSG_LENGTH: .quad . - INIT_MSG

PROMPT: .ascii "> "
PROMPT_LENGTH: .quad . - PROMPT

OK_MSG: .ascii "ok\n"
OK_MSG_LENGTH: .quad . - OK_MSG
