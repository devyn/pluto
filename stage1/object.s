.attribute arch, "rv64im"

.include "object.h.s"

# make cons from a0 (head), a1 (tail)
.global cons
cons:
        mv a3, zero
        mv a2, a1
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_CONS
        j make_obj

# destructure cons in a0
# return a0 = 1 on success, a1 = head, a2 = tail
# maintains refcount on head and tail, but releases the cons
.global uncons
uncons:
        addi sp, sp, -0x28
        sd ra, 0x00(sp)
        sd a0, 0x08(sp)
        sd zero, 0x10(sp)
        sd zero, 0x18(sp)
        sd zero, 0x20(sp)
        beqz a0, .Luncons_ret # nil
        li t1, LISP_OBJECT_TYPE_CONS
        lw t2, LISP_OBJECT_TYPE(a0)
        bne t2, t1, .Luncons_ret # not cons
        # success - get value
        li t1, 1
        ld t2, LISP_CONS_HEAD(a0)
        ld t3, LISP_CONS_TAIL(a0)
        sd t1, 0x10(sp)
        sd t2, 0x18(sp)
        sd t3, 0x20(sp)
        # acquire HEAD
        mv a0, t2
        call acquire_object
        # acquire TAIL
        ld a0, 0x20(sp)
        call acquire_object
.Luncons_ret:
        # always release
        ld a0, 0x08(sp)
        call release_object
        ld ra, 0x00(sp)
        ld a0, 0x10(sp)
        ld a1, 0x18(sp)
        ld a2, 0x20(sp)
        addi sp, sp, 0x28
        ret

# make integer object from int in a0
.global box_integer
box_integer:
        mv a3, zero
        mv a2, zero
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_INTEGER
        j make_obj

# make string from buf (a0), len (a1)
# object takes ownership of the buf and will deallocate it on drop
.global box_string
box_string:
        mv a3, zero
        mv a2, a1
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_STRING
        j make_obj

# Return only head from cons in a0
# Takes ownership of reference, so make sure to acquire first if you don't want to lose the cons
# Returns nil if not cons
.global car
car:
        add sp, sp, -0x10
        sd ra, 0x00(sp)
        sd zero, 0x08(sp) # head
        call uncons
        beqz a0, .Lcar_ret # not cons
        # save head
        sd a1, 0x08(sp)
        # release tail
        mv a0, a2
        call release_object
.Lcar_ret:
        ld ra, 0x00(sp)
        ld a0, 0x08(sp)
        addi sp, sp, 0x10
        ret

# Return only tail from cons in a0
# Takes ownership of reference, so make sure to acquire first if you don't want to lose the cons
# Returns nil if not cons
.global cdr
cdr:
        add sp, sp, -0x10
        sd ra, 0x00(sp)
        sd zero, 0x08(sp) # tail
        call uncons
        beqz a0, .Lcdr_ret # not cons
        # save tail
        sd a2, 0x08(sp)
        # release head
        mv a0, a1
        call release_object
.Lcdr_ret:
        ld ra, 0x00(sp)
        ld a0, 0x08(sp)
        addi sp, sp, 0x10
        ret

# load integer from boxed int (a0) and release it
# return 1 on success in a0, int value in a1
.global unbox_integer
unbox_integer:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd zero, 0x08(sp)
        sd zero, 0x10(sp)
        beqz a0, .Lunbox_integer_ret # nil
        li t1, LISP_OBJECT_TYPE_INTEGER
        lw t2, LISP_OBJECT_TYPE(a0)
        bne t2, t1, .Lunbox_integer_ret # not integer
        # success - get value
        li t1, 1
        ld t2, LISP_INTEGER_VALUE(a0)
        sd t1, 0x08(sp)
        sd t2, 0x10(sp)
.Lunbox_integer_ret:
        # always release
        call release_object
        ld ra, 0x00(sp)
        ld a0, 0x08(sp)
        ld a1, 0x10(sp)
        addi sp, sp, 0x18
        ret

# make procedure object from a0 (ptr), a1 (data)
# set data to zero (nil) if not used
.global box_procedure
box_procedure:
        mv a3, zero
        mv a2, a1
        mv a1, a0
        li a0, LISP_OBJECT_TYPE_PROCEDURE
        j make_obj

# unbox and release procedure object (a0), incrementing data refcount first
# a0 = 1 if success
# a1 = ptr
# a2 = data
.global unbox_procedure
unbox_procedure:
        addi sp, sp, -0x28
        sd ra, 0x00(sp)
        sd zero, 0x08(sp)
        sd zero, 0x10(sp)
        sd zero, 0x18(sp)
        sd a0, 0x20(sp)
        beqz a0, .Lunbox_procedure_ret # nil
        li t1, LISP_OBJECT_TYPE_PROCEDURE
        lw t2, LISP_OBJECT_TYPE(a0)
        bne t2, t1, .Lunbox_procedure_ret # not procedure
        # success - get value
        li t1, 1
        ld t2, LISP_PROCEDURE_PTR(a0)
        ld t3, LISP_PROCEDURE_DATA(a1)
        sd t1, 0x08(sp)
        sd t2, 0x10(sp)
        sd t3, 0x18(sp)
        # acquire DATA
        mv a0, t3
        call acquire_object
.Lunbox_procedure_ret:
        # always release
        ld a0, 0x20(sp)
        call release_object
        ld ra, 0x00(sp)
        ld a0, 0x08(sp)
        ld a1, 0x10(sp)
        ld a2, 0x18(sp)
        addi sp, sp, 0x28
        ret

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
# preserves a0, does not touch refcount
.global print_obj
print_obj:
        # reserve stack and save arg in s1
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd a0, 0x10(sp) # so we can preserve it
        mv s1, a0
        beqz s1, .Lprint_obj_cons # since nil = (), handle with cons
        # check object type
        lw t0, LISP_OBJECT_TYPE(s1)
        li t1, LISP_OBJECT_TYPE_CONS
        beq t0, t1, .Lprint_obj_cons
        li t1, LISP_OBJECT_TYPE_INTEGER
        beq t0, t1, .Lprint_obj_integer
        li t1, LISP_OBJECT_TYPE_SYMBOL
        beq t0, t1, .Lprint_obj_symbol
        li t1, LISP_OBJECT_TYPE_STRING
        beq t0, t1, .Lprint_obj_string
        # for anything else, print the raw fields
        li a0, '<'
        call putc
        ld a0, 0x00(s1)
        li a1, 16
        call put_hex
        li a0, ' '
        call putc
        ld a0, 0x08(s1)
        li a1, 16
        call put_hex
        li a0, ' '
        call putc
        ld a0, 0x10(s1)
        li a1, 16
        call put_hex
        li a0, ' '
        call putc
        ld a0, 0x18(s1)
        li a1, 16
        call put_hex
        li a0, '>'
        call putc
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
        lw t0, LISP_OBJECT_TYPE(s1)
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
        # TODO: it would be nice to flag integers that should be presented as hex?
        ld a0, LISP_INTEGER_VALUE(s1)
        call put_dec
        j .Lprint_obj_ret
.Lprint_obj_symbol:
        # just print the string
        ld a0, LISP_SYMBOL_BUF(s1)
        ld a1, LISP_SYMBOL_LEN(s1)
        call put_buf
        j .Lprint_obj_ret
.Lprint_obj_string:
        # get string buf, len
        addi sp, sp, -0x10
        sd s2, 0x00(sp)
        sd s3, 0x08(sp)
        ld s2, LISP_STRING_BUF(s1)
        ld s3, LISP_STRING_LEN(s1)
        # put quote
        li a0, 0x22
        call putc
        # loop through chars, print double quote if quote
1:
        beqz s3, 2f
        lb a0, (s2)
        call putc
        lb a0, (s2)
        li t0, 0x22
        addi s2, s2, 1
        addi s3, s3, -1
        bne a0, t0, 1b # not a quote
        call putc # print extra quote
        j 1b
2:
        # closing quote
        li a0, 0x22
        call putc
        ld s2, 0x00(sp)
        ld s3, 0x08(sp)
        addi sp, sp, 0x10
        j .Lprint_obj_ret
.Lprint_obj_zero_x:
        li a0, '0'
        call putc
        li a0, 'x'
        call putc
        jr t0
.Lprint_obj_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld a0, 0x10(sp)
        addi sp, sp, 0x18
        ret
