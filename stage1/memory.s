.attribute arch, "rv64im"

.include "object.h.s"

# The stage1 memory management provides allocation only for most sizes, and won't deallocate.
#
# A special exception is made for objects of LISP_OBJECT_SIZE with alignment of 8. These are stored
# in memory in bins, starting with a 32 byte allocation bitmap and then 255 allocation
# slots immediately following.
.set OBJECT_REGION_SIZE, 8192

.data

.global ALLOCATE
ALLOCATE: .quad builtin_allocate

.global DEALLOCATE
DEALLOCATE: .quad builtin_deallocate

.global BUILTIN_HEAP_PTR
BUILTIN_HEAP_PTR: .quad _heap_start

.global OBJECT_REGION_PTR
OBJECT_REGION_PTR: .quad _object_region_start

.section heap

.global _heap_start
_heap_start: .skip 0x80000 # 512 KiB
.equ _heap_end, .

.section object_region

.global _object_region_start
_object_region_start: .skip 0xc0000 # 768 KiB
.equ _object_region_end, .

.text

# args: a0 = bytes to allocate, a1 = alignment
# ret: a0 = pointer on success, zero on failure
.global allocate
allocate:
        ld t0, (ALLOCATE)
        jalr zero, (t0)

# args: a0 = pointer, a1 = number of bytes
# ret: a0 = 0
.global deallocate
deallocate:
        ld t0, (DEALLOCATE)
        jalr zero, (t0)

.global memory_init
memory_init:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        la s1, _object_region_start
.Lmemory_init_loop:
        la t1, _object_region_end
        bgeu s1, t1, .Lmemory_init_end
        # Zero the bitmap
        mv a0, s1
        li a1, 4
        mv a2, zero
        call mem_set_d
        li t1, OBJECT_REGION_SIZE
        add s1, s1, t1
        j .Lmemory_init_loop
.Lmemory_init_end:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        addi sp, sp, 0x10
        ret

.global builtin_allocate
builtin_allocate:
        # Check for object size/align
        li t0, LISP_OBJECT_SIZE
        bne a0, t0, 1f
        li t0, 8
        beq a1, t0, builtin_allocate_object # Allocate from object region
1:
        ld t0, (BUILTIN_HEAP_PTR)
        # align the pointer
        remu t1, t0, a1 # t1 = pointer % alignment
        beqz t1, .Lbuiltin_allocate_aligned # remainder zero, aligned already
        sub t1, a1, t1 # t1 = alignment - (pointer % alignment)
        add t0, t0, t1 # t0 = pointer + alignment - (pointer % alignment)
.Lbuiltin_allocate_aligned:
        # calculate the new value of BUILTIN_HEAP_PTR after allocation
        add t1, t0, a0
        # make sure that it won't be beyond the end of the heap
        la t2, _heap_end
        bgt t1, t2, .Lbuiltin_allocate_error
        # store the new BUILTIN_HEAP_PTR
        la t2, BUILTIN_HEAP_PTR
        sd t1, (t2)
        # return the allocated, aligned pointer
        mv a0, t0
        ret
.Lbuiltin_allocate_error:
        mv a0, zero
        ret

.global builtin_allocate_object
builtin_allocate_object:
        # Save OBJECT_REGION_PTR so we know if we've checked everything
        ld t0, (OBJECT_REGION_PTR) # bitmap ptr
        sd t0, -0x08(sp)
.Lbuiltin_allocate_object_region_loop:
        # Find free space in bitmap
        addi t1, t0, 32 # bitmap max address
        mv t2, zero # bit index
.Lbuiltin_allocate_object_bitmap_loop:
        bgeu t0, t1, .Lbuiltin_allocate_object_not_free
        li t3, 64 # bits
        ld t4, (t0) # dw bitmap
        beqz t2, 1f # the first bit is reserved for the bitmap, skip it
.Lbuiltin_allocate_object_bits_loop:
        beqz t3, .Lbuiltin_allocate_object_bits_end
        # check bit
        andi t5, t4, 1
        # if zero, it's free
        beqz t5, .Lbuiltin_allocate_object_free
1:
        # otherwise shift and increment/decrement counters
        srli t4, t4, 1
        addi t3, t3, -1
        addi t2, t2, 1
        j .Lbuiltin_allocate_object_bits_loop
.Lbuiltin_allocate_object_bits_end:
        # next 8-byte bitmap
        addi t0, t0, 8
        j .Lbuiltin_allocate_object_bitmap_loop
.Lbuiltin_allocate_object_free:
        # bit index that was free = t2
        # set the bit before proceeding
        andi t5, t2, 63 # t5 = bit offset within current map
        li t3, 1
        sll t3, t3, t5 # shift by offset to make that bit
        ld t4, (t0) # load
        or t4, t4, t3 # set the bit
        sd t4, (t0) # store
        # store the pointer to the object region that had free space in OBJECT_REGION_PTR
        # for next time
        andi t0, t0, -32 # realign to beginning
        la t1, OBJECT_REGION_PTR
        sd t0, (t1)
        # calculate address that was free
        slli t2, t2, 5 # multiply x 32
        add a0, t0, t2 # add offset
        ret
.Lbuiltin_allocate_object_not_free:
        # try next region
        srli t0, t0, 13 # divide by 8192
        addi t0, t0, 1  # add one
        slli t0, t0, 13 # mul by 8192
        # wrap to beginning if we reach end
        la t1, _object_region_end
        bltu t0, t1, 1f
        la t0, _object_region_start
1:
        # check to see if we are back where we started - if so return an error
        ld t1, -0x08(sp)
        beq t0, t1, .Lbuiltin_allocate_object_error
        # loop again
        j .Lbuiltin_allocate_object_region_loop
.Lbuiltin_allocate_object_error:
        mv a0, zero
        ret

.global builtin_deallocate
builtin_deallocate:
        # Check if ptr in object region
        la t0, _object_region_start
        bltu a0, t0, 1f
        la t0, _object_region_end
        bltu a0, t0, builtin_deallocate_object # Deallocate from object region
1:
        # do nothing
        mv a0, zero
        ret

.global builtin_deallocate_object
builtin_deallocate_object:
        # ensure ptr in range
        la t0, _object_region_start
        bltu a0, t0, .Lbuiltin_deallocate_object_ret
        la t0, _object_region_end
        bgeu a0, t0, .Lbuiltin_deallocate_object_ret
        # find bitmap base address
        li t0, -OBJECT_REGION_SIZE
        and t0, a0, t0
        # find bitmap bit offset
        li t1, OBJECT_REGION_SIZE - 1
        and t1, a0, t1
        srli t1, t1, 5 # 32 bytes
        beqz t1, .Lbuiltin_deallocate_object_ret # can't deallocate bitmap
        # which doubleword (64 bits) is that? 1 << 6 = 64
        srli t2, t1, 6 # doubleword offset
        slli t2, t2, 3 # times 8 bytes
        andi t1, t1, 63 # bit inside doubleword
        # calculate mask for clearing that bit
        li t3, 1
        sll t3, t3, t1 # 1 << (bit inside doubleword)
        xori t3, t3, -1 # invert
        # load, mask, store
        add t0, t0, t2 # add doubleword offset
        ld t4, (t0)
        and t4, t4, t3 # apply mask to clear bit
        sd t4, (t0)
        # bit has been cleared, now free
        # zero out the object header to make it more obvious if used after free
        sd zero, 0x00(a0)
.Lbuiltin_deallocate_object_ret:
        mv a0, zero
        ret

# increment refcount
.global acquire_object
acquire_object:
        beqz a0, 1f
        lw t0, LISP_OBJECT_REFCOUNT(a0)
        addi t0, t0, 1
        sw t0, LISP_OBJECT_REFCOUNT(a0)
1:
        ret

# decrement refcount and deallocate if <= 0
.global release_object
release_object:
        beqz a0, 1f
        lw t0, LISP_OBJECT_REFCOUNT(a0)
        addi t0, t0, -1
        sw t0, LISP_OBJECT_REFCOUNT(a0)
        bgtz t0, 1f
        j deallocate_object
1:
        mv a0, zero
        ret

# calls deallocate for an object as well as any of the memory it owns
.global deallocate_object
deallocate_object:
        addi sp, sp, -24
        sd ra, 0(sp)
        sd s1, 8(sp) # s1 = saved object address
        sd s2, 16(sp) # s2 = object type
        mv s1, a0
        lwu s2, LISP_OBJECT_TYPE(s1)
        beqz s2, .Ldeallocate_object_zero # most likely double free
.Ldeallocate_object_cons:
        # check for CONS
        li t0, LISP_OBJECT_TYPE_CONS
        bne s2, t0, .Ldeallocate_object_string
        # release head if not nil
        ld a0, LISP_CONS_HEAD(s1)
        beqz a0, 1f
        call release_object
        1:
        # release tail if not nil
        ld a0, LISP_CONS_TAIL(s1)
        beqz a0, 1f
        call release_object
        1:
        j .Ldeallocate_object_end
.Ldeallocate_object_string:
        # check for STRING
        li t0, LISP_OBJECT_TYPE_STRING
        bne s2, t0, .Ldeallocate_object_procedure
        # release the buffer x capacity
        ld a0, LISP_STRING_BUF(s1)
        ld a1, LISP_STRING_CAP(s1)
        call deallocate
        j .Ldeallocate_object_end
.Ldeallocate_object_procedure:
        # check for PROCEDURE
        li t0, LISP_OBJECT_TYPE_PROCEDURE
        bne s2, t0, .Ldeallocate_object_end
        # release data if not nil
        ld a0, LISP_PROCEDURE_DATA(s1)
        beqz a0, .Ldeallocate_object_end
        call release_object
        j .Ldeallocate_object_end
.Ldeallocate_object_symbol:
        # check for SYMBOL
        li t0, LISP_OBJECT_TYPE_SYMBOL
        bne s2, t0, .Ldeallocate_object_end
        # symbols should never be released
        mv a0, s1
        call acquire_object
        j 1f
.Ldeallocate_object_zero:
        # print z address and return without deallocating
        li a0, 'z'
        call putc
        mv a0, s1
        li a1, 16
        call put_hex
        li a0, '\n'
        call putc
        j 1f
.Ldeallocate_object_end:
        mv a0, s1
        li a1, LISP_OBJECT_SIZE
        call deallocate
1:
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24
        mv a0, zero
        ret

# a0 = length
# a1 = src pointer
# a2 = dest pointer
.global mem_copy
mem_copy:
        # round a0 to doublewords and put the remainder bytes in t1
        andi t1, a0, (1 << 3) - 1
        andi a0, a0, (-1 << 3)
.Lmem_copy_dw:
        beqz a0, .Lmem_copy_bytes
        ld t0, (a1)
        sd t0, (a2)
        addi a0, a0, -8
        addi a1, a1, 8
        addi a2, a2, 8
        j .Lmem_copy_dw
.Lmem_copy_bytes:
        beqz t1, .Lmem_copy_ret
        lb t0, (a1)
        sb t0, (a2)
        addi t1, t1, -1
        addi a1, a1, 1
        addi a2, a2, 1
        j .Lmem_copy_bytes
.Lmem_copy_ret:
        ret

# compare memory
# a0, a1 = buf, len of A
# a2, a3 = buf, len of B
# ret: a0 = -1 (A < B), 0 (A = B), 1 (A > B)
.global mem_compare
mem_compare:
        # determine minimum length for counter
        bgt a1, a3, 1f
        mv t1, a1
        j 2f
1:
        mv t1, a3
2:
.Lmem_compare_loop:
        beqz t1, .Lmem_compare_end
        # read the two bytes
        lb t2, (a0)
        lb t3, (a2)
        # compare
        sltu t4, t2, t3 # t4 = 1 if A < B
        sltu t5, t3, t2 # t5 = 1 if A > B
        sub t4, zero, t4 # t4 = -t4
        add t4, t4, t5 # t4 = -(A < B) + (A > B)
        bnez t4, .Lmem_compare_different # if t4 != 0, there's a difference
        # increment ptrs, decrement counter
        # note: don't decrement lengths because we may need to compare them before returning
        # and we don't use them anyway
        addi a0, a0, 1
        addi a2, a2, 1
        addi t1, t1, -1
        j .Lmem_compare_loop
.Lmem_compare_different:
        # there's a byte difference, so return t4 as our return value
        mv a0, t4
        ret
.Lmem_compare_end:
        # reached end of one or both strings, so the return value basically now is whichever length
        # is gt/lt
        sltu t1, a1, a3 # t1 = 1 if A < B
        sltu t2, a3, a1 # t2 = 1 if A > B
        sub t1, zero, t1 # t1 = -t1
        add a0, t1, t2 # return -(A < B) + (A > B)
        ret


# a0 = start address
# a1 = length in double-words
# a2 = value (double-word) to set
.global mem_set_d
mem_set_d:
        # determine max address
        add t1, a0, a1 # add length to addr
1:
        bge a0, t1, 2f
        sd zero, (a0)
        addi a0, a0, 8
        j 1b
2:
        ret

