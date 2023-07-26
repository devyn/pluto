# pluto
Bootstrapping from nothing

First, make the bootstrap files and copy their contents to your clipboard

    $ make copy-all

Then run the emulator and you should be able to paste in the file

    $ make qemu

Press dot (`.`) to run it and you should currently see a prompt. This can execute some variant of
Lisp.

## Rationale

I have some hardware that can run RV64GC but isn't incredibly powerful, so I want to have some fun
with it. An advantage of RISC-V is that the ISA is quite straightforward and the number of different
instruction formats is small, so it shouldn't be hard to write an assembler from within the Lisp
environment and continue extending it that way, which just sounds like the exact kind of masochistic
software fun I'm into.

## Current state

There are several builtin procedures defined, from which further procedures are created within Lisp
in `stage2.lsp`.

Example of what stage2 is capable of:

    00> ; (+ <num1> <num2>)
    00> (define +$ (allocate 0x8 0x4))
    ==> (0x0000000000000000 0x0000000000000008)

    00> (poke.w +$
    01>   0x00b50533 ; add a0, a0, a1
    01>   0x00008067 ; ret
    01> )
    ==> 0x0000000082025740

    00> (define + (proc args scope
    02>   (car ; a0
    03>     (call-native +$
    04>       ; a0, a1
    04>       (eval scope (car args))
    04>       (eval scope (cadr args))))))
    ==> (0x0000000000000000 0x0000000000000008)

    00> (+ 0x1 0x2)
    ==> 0x0000000000000003

Tail recursion is supported but I haven't yet implemented any flow control or comparison. That
should all be possible from within stage2, by using the above technique to dump machine code into
memory.

## Previous examples

Basic `ref` and `deref` for integer pointers, and `quote`:

    00> (ref hello)
    ==> 0x0000000082021c48

    00> (deref 0x0000000082021c48)
    ==> <0x0000000082020fac>

    00> (deref (ref hello))
    ==> <0x0000000082020fac>

    00> (deref (ref (quote foobar)))
    ==> foobar

Can call into assembler routines using `call-native`, which accepts an address and up to 8 args into
the `a0` to `a7` registers and returns the `(a0 a1)` return values as per the RISC-V ABI.

`(hello)` will print "Hello, world!" and return nil.

Calling hello using the internal ABI:

    00> hello
    ==> <0x0000000082020fac>

    > (call-native 0x0000000082020fac 0x0 0x0)
    Hello, world!
    ==> (0x0000000000000000 0x0000000000000000)

Read/write `peek` and `poke` are supported, with different lengths:

    00> (peek.w (ref (quote foo)))
    ==> 0x0000000000000001

    00> (poke.b 0x820215d8 0x42 0x79 0x65 0x62 0x79 0x65)
    ==> 0x00000000820215d8

    00> (hello)
    Byebye world!
    ==> ()
