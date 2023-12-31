.attribute arch, "rv64im"

# read hex values from string and construct integer
# a0 = string ptr, a1 = length
.global hex_str_to_int
hex_str_to_int:
        # construct number in t1
        mv t1, zero
        beqz a1, .Lhex_str_to_int_ret # empty string
.Lhex_str_to_int_loop:
        # read byte in
        lb t2, (a0)
        # check range
        li t3, '9'
        bgtu t2, t3, 1f
        li t3, '0'
        bltu t2, t3, 1f
        # it's a 0-9 digit
        sub t2, t2, t3 # t2 = ch - '0'
        j .Lhex_str_to_int_next
1:
        li t3, 'F'
        bgtu t2, t3, 1f
        li t3, 'A'
        bltu t2, t3, 1f
        # it's A-F
        j 2f
1:
        li t3, 'f'
        bgtu t2, t3, 1f
        li t3, 'a'
        bltu t2, t3, 1f
        # it's a-f
2:
        sub t2, t2, t3 # t2 = ch - 'A' or 'a'
        addi t2, t2, 0xA # t2 += 0xA
        j .Lhex_str_to_int_next
1:
        # this is an error, just return -1 early
        li a0, -1
        ret
.Lhex_str_to_int_next:
        # add the digit in t2 to t1
        or t1, t1, t2
        # move ptr forward, length backward
        addi a0, a0, 1
        addi a1, a1, -1
        # end of string (don't shift)
        beqz a1, .Lhex_str_to_int_ret
        # shift left one hex digit
        slli t1, t1, 4
        j .Lhex_str_to_int_loop
.Lhex_str_to_int_ret:
        mv a0, t1
        ret

# read decimal value from str and construct integer
# negative numbers supported with leading minus sign (-)
# a0 = string ptr, a1 = length
.global dec_str_to_int
dec_str_to_int:
        # construct number in t1
        mv t1, zero
        beqz a1, .Lhex_str_to_int_ret # empty string
        # check for negative sign
        lb t2, (a0)
        li t3, '-'
        li t4, 0
        bne t2, t3, .Ldec_str_to_int_loop
        # has negative sign, consume and set t4=1
        li t4, 1
        addi a0, a0, 1
        addi a1, a1, -1
        beqz a1, .Lhex_str_to_int_ret # no digits
.Ldec_str_to_int_loop:
        # read byte in
        lb t2, (a0)
        # check range
        li t3, '9'
        bgtu t2, t3, 1f
        li t3, '0'
        bltu t2, t3, 1f
        # it's a 0-9 digit
        sub t2, t2, t3 # t2 = ch - '0'
        j .Ldec_str_to_int_next
1:
        # this is an error, just return -1 early
        li a0, -1
        ret
.Ldec_str_to_int_next:
        # add the digit in t2 to t1
        add t1, t1, t2
        # move ptr forward, length backward
        addi a0, a0, 1
        addi a1, a1, -1
        # end of string (don't multiply)
        beqz a1, .Ldec_str_to_int_ret
        # multiply x 10
        li t2, 10
        mul t1, t1, t2
        j .Ldec_str_to_int_loop
.Ldec_str_to_int_ret:
        # check if we should negate
        bnez t4, 1f
        mv a0, t1
        ret
1:
        sub a0, zero, t1 # negate
        ret
