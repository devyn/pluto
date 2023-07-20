.attribute arch, "rv64im"

.set PARSER_FLAG, 0
.set PARSER_CELL, 8

.set PARSER_FLAG_LIST, 1
.set PARSER_FLAG_ASSOC, 2

.set TOKEN_ERROR, 0x0
.set TOKEN_WHITESPACE, 0x1
.set TOKEN_COMMENT, 0x2
.set TOKEN_LIST_BEGIN, 0x10
.set TOKEN_LIST_END, 0x11
.set TOKEN_LIST_ASSOC, 0x12
.set TOKEN_SYMBOL, 0x20
.set TOKEN_STRING, 0x21
.set TOKEN_INTEGER_DECIMAL, 0x30
.set TOKEN_INTEGER_HEX, 0x31
.set TOKEN_ADDRESS, 0x40

.text

# a0 = buffer
# a1 = length
# return:
# a0 = next buffer
# a1 = next length
# a2 = token type
# a3 = token slice ptr
# a4 = token slice length
.global get_token
get_token:
        li a4, 0
        # just ensure the length is not zero
        bnez a1, 1f
        li a2, TOKEN_ERROR
        mv a3, zero
        ret
1:
        # token generally will start at a0
        mv a3, a0
        # detect the type based on the first character
        lb t0, (a0)
        # whitespace
        jal t6, .Lget_token_check_whitespace
        bnez t5, .Lget_token_whitespace
        # list begin
        li t1, '('
        li a2, TOKEN_LIST_BEGIN
        beq t0, t1, .Lget_token_single_char
        # list end
        li t1, ')'
        li a2, TOKEN_LIST_END
        beq t0, t1, .Lget_token_single_char
        # list assoc
        li t1, '.'
        li a2, TOKEN_LIST_ASSOC
        beq t0, t1, .Lget_token_single_char
        # comment
        li t1, ';'
        beq t0, t1, .Lget_token_comment
        # string
        li t1, 0x22 # double quote (")
        beq t0, t1, .Lget_token_string
        # integer (but not sure which type)
        li t1, '0'
        bltu t0, t1, 1f # ch < '0'
        li t1, '9'
        bleu t0, t1, .Lget_token_integer # ch <= '9'
1:
        # this can be an address but need to lookahead to check for a digit
        li t1, '<'
        li t2, 1
        bleu a1, t2, 1f # skip if length <= 1
        lb t2, 1(a0)
        li t1, '0'
        bltu t2, t1, 1f # ch < '0'
        li t1, '9'
        bleu t2, t1, .Lget_token_address
1:
.Lget_token_symbol:
        # anything else gets parsed as a symbol
        # consume until we reach parens or whitespace
        li a2, TOKEN_SYMBOL
2:
        beqz a1, 3f # eof
        lb t0, (a0)
        jal t6, .Lget_token_check_whitespace
        bnez t5, 3f
        li t1, '('
        beq t0, t1, 3f
        li t1, ')'
        beq t0, t1, 3f
        # increment token length and buffer ptr, decrement buffer length
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        j 2b
3:
        ret
.Lget_token_single_char:
        # any single character token - just return the type (already put in a2)
        # token starts at a0, length 1
        li a4, 1
        # advance buffer by one char
        addi a0, a0, 1
        addi a1, a1, -1
        ret
.Lget_token_whitespace:
        # increment while whitespace
        li a2, TOKEN_WHITESPACE
2:
        beqz a1, 3f # eof
        lb t0, (a0)
        jal t6, .Lget_token_check_whitespace
        beqz t5, 3f
        # increment token length and buffer ptr, decrement buffer length
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        j 2b
3:
        ret
.Lget_token_comment:
        # increment until newline
        li a2, TOKEN_COMMENT
        li t1, '\n'
2:
        beqz a1, 3f # eof
        lb t0, (a0)
        beq t0, t1, 3f
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        j 2b
3:
        ret
.Lget_token_string:
        # consume first character, increment until matching ".
        # pairs of double quotes are escape
        li a2, TOKEN_STRING
        li a4, 1
        addi a0, a0, 1
        addi a1, a1, -1
        li t1, 0x22 # double quote (")
2:
        beqz a1, 3f # eof
        lb t0, (a0)
        # consume, even if this is the last quote
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        # if it's not a double quote, loop
        bne t0, t1, 2b
        # it's a double quote, so peek ahead to see if the next one is also
        beqz a1, 4f # eof so can't peek ahead but we got the double quote so it's ok
        lb t0, (a0)
        bne t0, t1, 4f # it's not a quote so we can just end
        # consume
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        # loop
        j 2b
3:
        # eof is an error
        li a2, TOKEN_ERROR
        mv a3, zero
        mv a4, zero
4:
        ret
.Lget_token_integer:
        li a2, TOKEN_INTEGER_DECIMAL
        # detect 0x = hex, otherwise decimal
        li t4, 0 # t4 = 0 (decimal), 1 (hex)
        li t0, 1
        bleu a1, t0, .Lget_token_integer_decimal # can't lookahead = decimal for sure
        lb t0, 0(a0)
        li t1, '0'
        bne t0, t1, .Lget_token_integer_decimal
        lb t0, 1(a0)
        li t1, 'x'
        bne t0, t1, .Lget_token_integer_decimal
.Lget_token_integer_hex:
        li t4, 1
        # always keep two chars
        addi a0, a0, 2
        addi a4, a4, 2
        addi a1, a1, -2
.Lget_token_integer_decimal:
        # change to hex if flag set (TOKEN_INTEGER_DECIMAL + 1 = TOKEN_INTEGER_HEX)
        add a2, a2, t4
        # look for digits in range
.Lget_token_integer_loop:
        beqz a1, .Lget_token_integer_end # eof
        lb t0, (a0)
        # '0' <= ch <= '9'
        li t1, '0'
        bltu t0, t1, 1f
        li t1, '9'
        bleu t0, t1, .Lget_token_integer_ok
1:
        # only check hex digits if t4 = 1
        beqz t4, .Lget_token_integer_end
        # 'a' <= ch <= 'f'
        li t1, 'a'
        bltu t0, t1, 1f
        li t1, 'f'
        bleu t0, t1, .Lget_token_integer_ok
1:
        # 'A' <= ch <= 'F'
        li t1, 'A'
        bltu t0, t1, .Lget_token_integer_end
        li t1, 'F'
        bgtu t0, t1, .Lget_token_integer_end
.Lget_token_integer_ok:
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        j .Lget_token_integer_loop
.Lget_token_integer_end:
        ret
.Lget_token_address:
        li a2, TOKEN_ADDRESS
        # consume first char
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        # consume until and including matching angle bracket
2:
        beqz a1, 3f # eof
        lb t0, (a0)
        li t1, '>'
        addi a0, a0, 1
        addi a4, a4, 1
        addi a1, a1, -1
        beq t0, t1, 3f
        j 2b
3:
        ret
.Lget_token_check_whitespace:
        # microprocedure, return address t6, t5 = 1 if whitespace in t0
        li t1, ' '
        beq t0, t1, 1f
        li t1, '\t'
        beq t0, t1, 1f
        li t1, '\r'
        beq t0, t1, 1f
        li t1, '\n'
        beq t0, t1, 1f
        li t5, 0
        jalr zero, (t6)
1:
        li t5, 1
        jalr zero, (t6)
