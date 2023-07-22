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
