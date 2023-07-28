.attribute arch, "rv64im"

.include "object.h.s"

.bss

.set SYMBOL_HASH_BITS, 6
.set SYMBOLS_LEN, (1 << SYMBOL_HASH_BITS)

# array of pointers to lisp lists of symbols, indexed by lower bits of hash of symbol value
#
# these are unique values that are interned once, and it should always be possible to check
# equality by pointer
.global SYMBOLS
SYMBOLS: .skip SYMBOLS_LEN * 8

.text

# initialize the symbol array with all zeroes
.global symbol_init
symbol_init:
        la a0, SYMBOLS
        li a1, SYMBOLS_LEN
        j mem_set_d

# hash a string for the symbol table
# a0 = buf, a1 = len
# returns byte in a0
.global symbol_hash
symbol_hash:
        li t1, 0xe2 # hash value, start with initial seed
1:
        beqz a1, 2f
        lb t0, (a0)
        xor t1, t0, t1 # hash ^= byte
        # now rotate left by one bit
        andi t2, t1, (1 << 7) # take the top bit
        srli t2, t2, 7 # shift it all the way to the end
        slli t1, t1, 1 # shift the result to the left one bit
        andi t1, t1, 0xff # keep it in range
        or t1, t1, t2 # add the new bit to the end
        addi a1, a1, -1 # decrement counter
        j 1b
2:
        mv a0, t1
        ret

# intern a symbol
#
# tries to find a matching symbol in the symbol table. if it can't, creates a new one and adds it
#
# a0 = buf, a1 = len
# returns symbol address in a0 unless there was an error (in which case zero)
# increments refcount of the symbol.
.global symbol_intern
symbol_intern:
        addi sp, sp, -0x28
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # s1 = a0/buf
        sd s2, 0x10(sp) # s2 = a1/len
        sd s3, 0x18(sp) # s3 = symbol table entry address
        sd s4, 0x18(sp) # s4 = current list entry address, or temp ptr while constructing symbol
        mv s1, a0
        mv s2, a1
        # calculate hash
        call symbol_hash
        # strip upper bits to make it an index
        andi a0, a0, (1 << SYMBOL_HASH_BITS) - 1
        # multiply by 8
        slli a0, a0, 3
        # add to pointer
        la s3, SYMBOLS
        add s3, s3, a0
        # get the first node address
        ld s4, (s3)
.Lsymbol_intern_search_loop:
        # search the symbol table for a matching symbol
        beqz s4, .Lsymbol_intern_insert # current node nil, not found
        # get the current node head
        ld t1, LISP_CONS_HEAD(s4)
        beqz t1, .Lsymbol_intern_error # head should not be nil
        # get the symbol buf, len in a0, a1
        ld a0, LISP_SYMBOL_BUF(t1)
        ld a1, LISP_SYMBOL_LEN(t1)
        # move the query string into a2, a3
        mv a2, s1
        mv a3, s2
        call mem_compare
        beqz a0, .Lsymbol_intern_search_found
        # we didn't find it here, so deref tail and move on
        ld s4, LISP_CONS_TAIL(s4)
        j .Lsymbol_intern_search_loop
.Lsymbol_intern_search_found:
        # found at head of list: get that object addr and increment refcount
        ld a0, LISP_CONS_HEAD(s4)
        j .Lsymbol_intern_found_ret
.Lsymbol_intern_insert:
        # create a new symbol. first copy the string
        mv a0, s2
        li a1, 1
        call allocate
        beqz a0, .Lsymbol_intern_error # allocation error
        # copy bytes into the new allocation
        mv s4, a0
        mv a0, s2
        mv a1, s1
        mv a2, s4
        call mem_copy
        # create a new object for the symbol
        mv a3, zero
        mv a2, s2 # LISP_SYMBOL_LEN
        mv a1, s4 # LISP_SYMBOL_BUF
        li a0, LISP_OBJECT_TYPE_SYMBOL
        call make_obj
        beqz a0, .Lsymbol_intern_error # allocation error
        # move new symbol to s4
        mv s4, a0
        # create a new object for the new cons to insert
        mv a0, s4 # new.head = new symbol
        ld a1, (s3) # new.tail = current address in symbol table entry
        call cons
        beqz a0, .Lsymbol_intern_error # allocation error
        # put the new cons as the symbol table entry
        sd a0, (s3)
        # return the new symbol
        mv a0, s4
        j .Lsymbol_intern_found_ret
.Lsymbol_intern_error:
        mv a0, zero
        j .Lsymbol_intern_ret
.Lsymbol_intern_found_ret:
        # increment refcount before returning
        call acquire_object
.Lsymbol_intern_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        ld s3, 0x18(sp)
        ld s4, 0x20(sp)
        addi sp, sp, 0x28
        ret
