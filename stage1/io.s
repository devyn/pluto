.attribute arch, "rv64im"

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

# Accepts pointer to buffer in a0, size in a1
.global put_buf
put_buf:
        addi sp, sp, -24
        sd ra, 0(sp)
        sd s1, 8(sp)  # s1: current char pointer
        sd s2, 16(sp) # s2: max pointer (buffer + size)
        mv s1, a0
        add s2, a0, a1
.Lput_buf_loop:
        lb a0, (s1)
        call putc
        addi s1, s1, 1
        bltu s1, s2, .Lput_buf_loop
.Lput_buf_done:
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24
        ret

# Puts unsigned number in a0 as hex, a1 = number of digits
.global put_hex
put_hex:
        addi sp, sp, -24
        sd ra, 0(sp)
        sd s1, 8(sp) # s1: current number value
        sd s2, 16(sp) # s2: counter
        mv s1, a0
        mv s2, a1
        # shift over to truncate digits
        li t0, 16
        sub t0, t0, s2 # 16 - digits
        slli t0, t0, 2 # (16 - digits) * 4
        sll s1, s1, t0
.Lput_hex_loop:
        # take the first digit
        li t1, (-1 << 60)
        and a0, s1, t1
        srli a0, a0, 60
        # check if it's > 9 (A-F)
        li t1, 9
        bgt a0, t1, .Lput_hex_af
.Lput_hex_09:
        addi a0, a0, '0'
        j .Lput_hex_putc
.Lput_hex_af:
        addi a0, a0, ('a' - 0xA)
.Lput_hex_putc:
        call putc
        # subtract from counter
        addi s2, s2, -1
        beqz s2, .Lput_hex_end
        # shift to the left by one digit
        slli s1, s1, 4
        j .Lput_hex_loop
.Lput_hex_end:
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24
        ret

.section .rodata

# a 64-bit signed integer can have 18 decimal digits
.align 8
PUT_DEC_DIVISOR: .quad (1000000000000000000)

.text

# Put signed number in a0 as decimal
.global put_dec
put_dec:
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # s1: current number value
        sd s2, 0x10(sp) # s2: current divisor
        sd s3, 0x18(sp) # s3: first digit found?
        mv s1, a0
        ld s2, (PUT_DEC_DIVISOR)
        li s3, 0
        # check sign
        srli t0, s1, 63
        bnez t0, 1f
        j .Lput_dec_loop
1:
        # put sign and negate
        li a0, '-'
        call putc
        sub s1, zero, s1
.Lput_dec_loop:
        beqz s2, .Lput_dec_end # end if divisor is zero
        # div/rem divisor
        div t0, s1, s2 # digit = number / divisor
        rem s1, s1, s2 # number %= divisor
        li t1, 10
        div s2, s2, t1 # divisor /= 10
        # check if digit is zero and first digit not found
        or t1, t0, s3
        beqz t1, .Lput_dec_loop
        # digit found for sure, set s3
        li s3, 1
        # convert to char and putc
        addi a0, t0, '0'
        call putc
        j .Lput_dec_loop
.Lput_dec_end:
        # add a zero if digit not found
        beqz s3, 1f
        j 2f
1:
        # digit not found, so this number is zero
        li a0, '0'
        call putc
2:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        ld s3, 0x18(sp)
        addi sp, sp, 0x20
        ret

# Puts line from console in buffer a0, size a1. Returns length of final string
.global get_line
get_line:
        addi sp, sp, -40
        sd ra, 0(sp)
        sd s1, 8(sp) # s1: number of chars read
        sd s2, 16(sp) # s2: current buffer pointer
        sd s3, 24(sp) # s3: buffer size limit
        sd s4, 32(sp) # s4: current read character
        mv s1, zero
        mv s2, a0
        mv s3, a1
.Lget_line_loop:
        # check limit
        bge s1, s3, .Lget_line_done
        call getc
        mv s4, a0
        # check for error, retry
        bltz a0, .Lget_line_loop
        # check for backspace
        li t0, '\b'
        beq s4, t0, .Lget_line_backspace
        li t0, 0x7f
        beq s4, t0, .Lget_line_backspace
        # check for newline
        li t0, '\r'
        beq s4, t0, .Lget_line_newline
        li t0, '\n'
        beq s4, t0, .Lget_line_newline
        # write the char and increment the indexes
        sb s4, (s2)
        addi s2, s2, 1
        addi s1, s1, 1
        # echo the character (note: clobbers a0)
        call putc
        # otherwise just loop again
        j .Lget_line_loop
.Lget_line_backspace:
        # do not subtract past zero
        beqz s1, .Lget_line_loop
        addi s1, s1, -1
        addi s2, s2, -1
        # echo backspace character
        li a0, '\b'
        call putc
        j .Lget_line_loop
.Lget_line_newline:
        # echo newline
        li s4, '\n'
        mv a0, s4
        call putc
        # put newline at end of line
        sb s4, (s2)
        addi s1, s1, 1
        addi s2, s2, 1
.Lget_line_done:
        mv a0, s1
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        ld s3, 24(sp)
        ld s4, 32(sp)
        addi sp, sp, 40
        ret
