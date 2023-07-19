.attribute arch, "rv64im"

.text

.global start
start:
        la a0, MSG
        mv s1, ra
        call puts
        mv ra, s1
        ret

.global getc
getc:
        # call opensbi sbi_console_getchar
        li a7, 0x02
        ecall
        ret

.global putc
putc:
        # call opensbi sbi_console_putchar
        li a7, 0x01
        ecall
        ret

# Accepts a zero-terminated string in a0
.global puts
puts:
        addi sp, sp, -24
        sd ra, 0(sp)
        sd s1, 8(sp)
        sd s2, 16(sp)
        mv s1, a0
.Lputs_loop:
        lb s2, (s1)
        mv a0, s2
        call putc
        addi s1, s1, 1
        bnez s2, .Lputs_loop
.Lputs_done:
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24
        ret

.section .rodata

MSG: .asciz "success."
