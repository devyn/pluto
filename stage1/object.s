.attribute arch, "rv64im"

.include "object.h.s"

# Lisp object in a0. Returns value of head in a0. Returns nil if not cons
.global car
car:
        jal t0, check_cons
        ld a0, LISP_CONS_HEAD(a0)
        ret

# Lisp object in a0. Returns value of tail in a0. Returns nil if not cons
.global cdr
cdr:
        jal t0, check_cons
        ld a0, LISP_CONS_TAIL(a0)
        ret

# microprocedure, uses t0 return address, modifies t1, t2
.local check_cons
check_cons:
        beqz a0, return_nil
        li t1, LISP_OBJECT_TYPE_CONS
        lwu t2, LISP_OBJECT_TYPE(a0)
        bne t1, t2, return_nil
        jalr zero, (t0)

.local return_nil
return_nil:
        mv a0, zero
        ret

# make cons from a0 (head), a1 (tail)
.global cons
cons:
        mv a3, zero
        mv a2, a1
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_CONS
        j make_obj

# make integer object from int in a0
.global box_integer
box_integer:
        mv a3, zero
        mv a2, zero
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_INTEGER
        j make_obj

# make procedure object from a0 (ptr), a1 (data)
# set data to zero (nil) if not used
.global box_procedure
box_procedure:
        mv a3, zero
        mv a2, a1
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_PROCEDURE
        j make_obj

# sets up a new object and initializes refcount ONLY.
# returns a0=zero on allocation error, otherwise a0=object.
.global new_obj
new_obj:
        # keep sp so we can do allocate
        addi sp, sp, -8
        sd ra, 0(sp)
        # allocate lisp object
        li a0, LISP_OBJECT_SIZE
        li a1, LISP_OBJECT_ALIGN
        call allocate
        beqz a0, .Lnew_obj_ret # allocation error
        # initialize to all zero
        sd zero, 0x00(a0)
        sd zero, 0x08(a0)
        sd zero, 0x10(a0)
        sd zero, 0x18(a0)
        # set refcount = 1
        li t1, 1
        sw t1, LISP_OBJECT_REFCOUNT(a0)
.Lnew_obj_ret:
        # clean up stack
        ld ra, 0(sp)
        addi sp, sp, 8
        ret

# make an object from type (a0), field0 (a1), field2 (a2), field3 (a3)
# objects are 32 bytes but this assumes that the remainder after type and refcount
# are all double-words
.global make_obj
make_obj:
        addi sp, sp, -0x28
        sd ra, 0x00(sp)
        sd a0, 0x08(sp)
        sd a1, 0x10(sp)
        sd a2, 0x18(sp)
        sd a3, 0x20(sp)
        call new_obj
        beqz a0, .Lmake_obj_ret
        ld t1, 0x08(sp)
        sw t1, LISP_OBJECT_TYPE(a0)
        ld t2, 0x10(sp) # original a1
        ld t3, 0x18(sp) # original a2
        ld t4, 0x20(sp) # original a3
        sd t2, 0x08(a0) # field0
        sd t3, 0x10(a0) # field1
        sd t4, 0x18(a0) # field2
.Lmake_obj_ret:
        ld ra, 0x00(sp)
        addi sp, sp, 0x28
        ret

# object to print in a0
.global print_obj
print_obj:
        # reserve stack and save arg in s1
        addi sp, sp, -16
        sd ra, 0(sp)
        sd s1, 8(sp)
        mv s1, a0
        beqz s1, .Lprint_obj_cons # since nil = (), handle with cons
        # check object type
        lwu t0, LISP_OBJECT_TYPE(s1)
        li t1, LISP_OBJECT_TYPE_CONS
        beq t0, t1, .Lprint_obj_cons
        li t1, LISP_OBJECT_TYPE_INTEGER
        beq t0, t1, .Lprint_obj_integer
        li t1, LISP_OBJECT_TYPE_SYMBOL
        beq t0, t1, .Lprint_obj_symbol
        li t1, LISP_OBJECT_TYPE_PROCEDURE
        beq t0, t1, .Lprint_obj_procedure
        # print <??> if unrecognized
        la a0, PRINT_UNRECOGNIZED_MSG
        ld a1, (PRINT_UNRECOGNIZED_MSG_LENGTH)
        call put_buf
        j .Lprint_obj_ret
.Lprint_obj_cons:
        li a0, '('
        call putc
        beqz s1, .Lprint_obj_cons_end # handle nil case here
.Lprint_obj_cons_loop:
        # print head
        ld a0, LISP_CONS_HEAD(s1)
        call print_obj
        # prepare to loop on tail
        ld s1, LISP_CONS_TAIL(s1)
        # if it's nil, just end
        beqz s1, .Lprint_obj_cons_end
        # print a space since we need it in either case
        li a0, ' '
        call putc
        # check if the type is CONS and loop if so
        lwu t0, LISP_OBJECT_TYPE(s1)
        li t1, LISP_OBJECT_TYPE_CONS
        beq t0, t1, .Lprint_obj_cons_loop
        # this is an assoc so put the dot and space
        li a0, '.'
        call putc
        li a0, ' '
        call putc
        # then print the object and end without looping
        mv a0, s1
        call print_obj
.Lprint_obj_cons_end:
        li a0, ')'
        call putc
        j .Lprint_obj_ret
.Lprint_obj_integer:
        # todo: print variable width, probably usually decimal
        li a0, '0'
        call putc
        li a0, 'x'
        call putc
        ld a0, LISP_INTEGER_VALUE(s1)
        li a1, 16
        call put_hex
        j .Lprint_obj_ret
.Lprint_obj_symbol:
        # just print the string
        ld a0, LISP_SYMBOL_BUF(s1)
        ld a1, LISP_SYMBOL_LEN(s1)
        call put_buf
        j .Lprint_obj_ret
.Lprint_obj_procedure:
        # print address in angle brackets
        li a0, '<'
        call putc
        li a0, '0'
        call putc
        li a0, 'x'
        call putc
        ld a0, LISP_PROCEDURE_PTR(s1)
        li a1, 16
        call put_hex
        li a0, '>'
        call putc
        j .Lprint_obj_ret
.Lprint_obj_ret:
        ld ra, 0(sp)
        ld s1, 8(sp)
        addi sp, sp, 16
        ret

.section .rodata

PRINT_UNRECOGNIZED_MSG: .ascii "<??>"
PRINT_UNRECOGNIZED_MSG_LENGTH: .quad . - PRINT_UNRECOGNIZED_MSG
