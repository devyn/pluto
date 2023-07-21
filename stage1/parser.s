.attribute arch, "rv64im"

.include "parser.h.s"
.include "object.h.s"

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

# Parse a single token. a2-a4 are the same as returned from get_token, so you just need to switch
# the a0-a1 registers out
#
# a0 = parser state array (starts with index dw, length dw, then array of flag dw, cell dw)
# a2 = token type
# a3 = token slice ptr
# a4 = token slice length
#
# return:
#
# a0 = status (PARSER_STATUS_)
# a1 = produced value if n = 1
.global parse_token
parse_token:
        # free up some saved registers for our use
        addi sp, sp, -7*8
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # a0
        sd s2, 0x10(sp) # current state pointer
        sd s3, 0x18(sp) # a2
        sd s4, 0x20(sp) # a3
        sd s5, 0x28(sp) # a4
        sd s6, 0x30(sp) # produced object for placement
        # save all of the arguments so that we can call other procedures
        mv s1, a0
        mv s3, a2
        mv s4, a3
        mv s5, a4
        mv s6, zero
.Lparse_token_check_type:
        # these are in order of how common they probably are
        li t1, TOKEN_SYMBOL
        beq s3, t1, .Lparse_token_symbol
        li t1, TOKEN_WHITESPACE
        beq s3, t1, .Lparse_token_ignore
        li t1, TOKEN_INTEGER_DECIMAL
        beq s3, t1, .Lparse_token_decimal
        li t1, TOKEN_INTEGER_HEX
        beq s3, t1, .Lparse_token_hex
        li t1, TOKEN_LIST_BEGIN
        beq s3, t1, .Lparse_token_list_begin
        li t1, TOKEN_LIST_END
        beq s3, t1, .Lparse_token_list_end
        li t1, TOKEN_LIST_ASSOC
        beq s3, t1, .Lparse_token_list_assoc
        li t1, TOKEN_STRING
        beq s3, t1, .Lparse_token_string
        li t1, TOKEN_ADDRESS
        beq s3, t1, .Lparse_token_address
        li t1, TOKEN_COMMENT
        beq s3, t1, .Lparse_token_ignore
        # unrecognized = error
        j .Lparse_token_error
.Lparse_token_symbol:
        j .Lparse_token_error # WIP
.Lparse_token_decimal:
        j .Lparse_token_error # WIP
.Lparse_token_hex:
        # allocate object for the integer into s6
        call new_obj
        mv s6, a0
        beqz s6, .Lparse_token_error # allocation failed
        # convert the token to an integer
        mv a0, s4
        mv a1, s5
        li t1, 2
        bleu a1, t1, .Lparse_token_error # token too small, should be at least 3 (0x?)
        # skip the 0x
        addi a0, a0, 2
        addi a1, a1, -2
        call hex_str_to_int
        # set up the int object
        li t0, LISP_OBJECT_TYPE_INTEGER
        sw t0, LISP_OBJECT_TYPE(s6)
        sd a0, LISP_INTEGER_VALUE(s6)
        # place it
        j .Lparse_token_place_object
.Lparse_token_list_begin:
        # push state
        lw t0, PARSER_STATE_LENGTH(s1)
        lw s2, PARSER_STATE_INDEX(s1)
        addi s2, s2, 1
        bge s2, t0, .Lparse_token_overflow # check to make sure new index is in bounds
        # store the new index
        sw s2, PARSER_STATE_INDEX(s1)
        # calculate the pointer
        jal t0, .Lparse_token_get_state_pointer_s2
        # flag = PARSER_FLAG_LIST
        li t0, PARSER_FLAG_LIST
        sd t0, PARSER_STATE_E_FLAG(s2)
        # begin, current = zero
        sd zero, PARSER_STATE_E_BEGIN_NODE(s2)
        sd zero, PARSER_STATE_E_CURRENT_NODE(s2)
        j .Lparse_token_ret_ok
.Lparse_token_list_end:
        # check current state entry
        lw s2, PARSER_STATE_INDEX(s1)
        jal t0, .Lparse_token_get_state_pointer_s2
        ld t0, PARSER_STATE_E_FLAG(s2)
        beqz t0, .Lparse_token_error # no list to end
        # take begin node into s6 as object to place
        ld s6, PARSER_STATE_E_BEGIN_NODE(s2)
        # clear the entry
        sd zero, PARSER_STATE_E_FLAG(s2)
        sd zero, PARSER_STATE_E_BEGIN_NODE(s2)
        sd zero, PARSER_STATE_E_CURRENT_NODE(s2)
        # decrement index if over zero
        lw t0, PARSER_STATE_INDEX(s1)
        beqz t0, 1f
        addi t0, t0, -1
        sw t0, PARSER_STATE_INDEX(s1)
1:
        # place the object in s6
        j .Lparse_token_place_object
.Lparse_token_list_assoc:
        j .Lparse_token_error # WIP
.Lparse_token_string:
        j .Lparse_token_error # WIP
.Lparse_token_address:
        j .Lparse_token_error # WIP
.Lparse_token_place_object:
        # get the pointer to the current state into s2
        lw s2, PARSER_STATE_INDEX(s1)
        jal t0, .Lparse_token_get_state_pointer_s2
        # if flag = 0, we can just produce the object (we're not inside a list)
        ld t0, PARSER_STATE_E_FLAG(s2)
        beqz t0, .Lparse_token_produce_value
        # otherwise we need to add it to the list. if assoc we set tail, otherwise make new node,
        # set head, append.
        # first check to ensure we are in a cons that does not have tail set, or no cons yet
        # (empty list)
        ld t3, PARSER_STATE_E_CURRENT_NODE(s2)
        beqz t3, 1f # cons is not set yet
        lw t4, LISP_OBJECT_TYPE(t3)
        li t5, LISP_OBJECT_TYPE_CONS
        bne t4, t5, .Lparse_token_error # must assoc to a list
        ld t4, LISP_CONS_TAIL(t3)
        bnez t4, .Lparse_token_error # tail must not already be set
1:
        # determine whether this is assoc
        li t1, PARSER_FLAG_ASSOC
        and t1, t0, t1
        bnez t1, .Lparse_token_place_assoc
.Lparse_token_place_append:
        call new_obj
        beqz a0, .Lparse_token_error # alloc error
        li t1, LISP_OBJECT_TYPE_CONS
        sw t1, LISP_OBJECT_TYPE(a0) # new.type = LISP_OBJECT_TYPE_CONS
        sd s6, LISP_CONS_HEAD(a0) # new.head = s6
        mv s6, a0 # s6 = new
        beqz t3, 1f # if current = nil, need to set current & begin
        sd s6, LISP_CONS_TAIL(t3) # current.tail = new
        sd s6, PARSER_STATE_E_CURRENT_NODE(s2) # current = new
        j .Lparse_token_ret_ok
1:
        # current = nil, so just put s6 in begin & current
        sd s6, PARSER_STATE_E_BEGIN_NODE(s2)
        sd s6, PARSER_STATE_E_CURRENT_NODE(s2)
        j .Lparse_token_ret_ok
.Lparse_token_place_assoc:
        # error if current = nil (must assoc to existing cons)
        beqz t3, .Lparse_token_error
        # just set the s6 as tail
        sd s6, LISP_CONS_TAIL(t3) # current.tail = s6 object
        j .Lparse_token_ret_ok
.Lparse_token_overflow:
        li a0, PARSER_STATUS_OVERFLOW
        j 1f
.Lparse_token_error:
        li a0, PARSER_STATUS_ERR
1:
        # Check if there's an object in s6 that must be cleaned up
        beqz s6, .Lparse_token_ret
        mv a0, s6
        call release_object
        li a0, PARSER_STATUS_ERR
        j .Lparse_token_ret
.Lparse_token_produce_value:
        li a0, PARSER_STATUS_VALUE
        mv a1, s6
        j .Lparse_token_ret
.Lparse_token_ignore: # same, just return ok and continue
.Lparse_token_ret_ok:
        li a0, PARSER_STATUS_OK
.Lparse_token_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        ld s3, 0x18(sp)
        ld s4, 0x20(sp)
        ld s5, 0x28(sp)
        ld s6, 0x30(sp)
        addi sp, sp, 7*8
        ret
# utility subprocs
.Lparse_token_get_state_pointer_s2: # clobbers t1, returns to t0
        li t1, PARSER_STATE_ELEN
        mul s2, s2, t1
        addi s2, s2, PARSER_STATE_FIRST
        add s2, s2, s1
        jalr zero, (t0)
