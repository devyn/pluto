.attribute arch, "rv64imzicsr"

.set _program_area, 0x82000000
.set _program_area_end, 0x82200000

.text

.global start
start:
        # preserve a0, a1 (args from firmware)
        mv s1, a0
        mv s2, a1
        # clear interrupts
        csrrw zero, sie, zero # disable all interrupts
        # set up stack
        la sp, _stack_end
        # zero the program area
        call zero_program_area
        # receive data
        la a0, INIT_MSG
        call puts
        call recv_hex
        # restore args and call
        li t0, _program_area
        mv a0, s1
        mv a1, s2
        jalr ra, (t0)
        # on return, shut down
        j shutdown

# Fill the program area with zeroes
.global zero_program_area
zero_program_area:
        li t0, _program_area
        li t1, _program_area_end
1:
        sd zero, (t0)
        addi t0, t0, 8
        blt t0, t1, 1b
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

# Reads hex bytes into _program_area until the dot character is received
.global recv_hex
recv_hex:
        addi sp, sp, -16
        sd ra, 0(sp)
        sd s1, 8(sp)
        # current program offset in s1
        li s1, _program_area
.Lrecv_hex_loop:
        # get_hex returns -1 if dot is received
        call get_hex
        bltz a0, .Lrecv_hex_end
        sb a0, (s1)
        addi s1, s1, 1
        j .Lrecv_hex_loop
.Lrecv_hex_end:
        ld ra, 0(sp)
        ld s1, 8(sp)
        addi sp, sp, 16
        ret

# Reads two hex characters and constructs a byte from console into a0. Returns -1 on failure
.global get_hex
get_hex:
        addi sp, sp, -16
        sd ra, 0(sp)
        sd s2, 8(sp) # byte
.Lget_hex_first:
        call getc
        li t0, '.'
        beq a0, t0, .Lget_hex_dot_received
        call from_hex_digit
        bltz a0, .Lget_hex_first
        slli s2, a0, 4
        # now digit << 4 is in s2
.Lget_hex_second:
        call getc
        li t0, '.'
        beq a0, t0, .Lget_hex_dot_received
        call from_hex_digit
        bltz a0, .Lget_hex_second
        or s2, s2, a0
        li a0, '#'
        call putc # echo for each byte
        j .Lget_hex_done
.Lget_hex_dot_received:
        li s2, -1
.Lget_hex_done:
        mv a0, s2
        ld ra, 0(sp)
        ld s2, 8(sp)
        addi sp, sp, 16
        ret

# Converts a single hex character in a0 to its digit value. Returns -1 if out of range
.global from_hex_digit
from_hex_digit:
        li t0, '0'
        blt a0, t0, .Lfrom_hex_digit_lower
        li t0, '9'
        bgt a0, t0, .Lfrom_hex_digit_lower
        addi a0, a0, -'0'
        ret
.Lfrom_hex_digit_lower:
        li t0, 'a'
        blt a0, t0, .Lfrom_hex_digit_upper
        li t0, 'f'
        bgt a0, t0, .Lfrom_hex_digit_upper
        addi a0, a0, 10 - 'a'
        ret
.Lfrom_hex_digit_upper:
        li t0, 'A'
        blt a0, t0, .Lfrom_hex_digit_invalid
        li t1, 'F'
        blt a0, t0, .Lfrom_hex_digit_invalid
        addi a0, a0, 10 - 'A'
        ret
.Lfrom_hex_digit_invalid:
        li a0, -1
        ret

.global shutdown
shutdown:
        # call opensbi sbi_shutdown
        li a7, 0x08
        ecall
        1: j 1b

.section .rodata

INIT_MSG:
        .ascii "\n\npluto. <stage0>\n\n"
        .ascii "Ready to receive hex bytes on console.\n"
        .asciz "End with dot (.), other characters ignored.\n"

.bss

.align 4

.global _stack
_stack: .skip 0x2000

.global _stack_end
.equ _stack_end, .
