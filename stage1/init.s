.attribute arch, "rv64im"

.text

.global start
start:
        mv s1, ra
        la a0, INIT_MSG
        call puts
.Lstart_repl:
        la a0, PROMPT
        call puts
        la a0, LINE_BUF
        li a1, 4096
        call get_line
        beqz a0, .Lstart_end
        la a0, LINE_BUF
        call puts
        la a0, OK_MSG
        call puts
        j .Lstart_repl
.Lstart_end:
        mv ra, s1
        ret

.section .rodata

INIT_MSG: .asciz "\nstage1 initializing.\n"
PROMPT: .asciz "> "
OK_MSG: .asciz "ok\n"

.bss

LINE_BUF: .skip 4096
