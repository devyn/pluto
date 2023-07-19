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
