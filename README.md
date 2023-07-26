# pluto
Bootstrapping from nothing

First, make the stage1.hex file and copy its contents to your clipboard

    $ make copy-stage1

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

Currently five procedures defined.

Basic `ref` and `deref` for integer pointers, and `quote`:

    > (ref hello)
    ==> 0x0000000082021c48
    ok
    > (deref 0x0000000082021c48)
    ==> <0x0000000082020fac>
    ok
    > (deref (ref hello))
    ==> <0x0000000082020fac>
    ok
    > (deref (ref (quote foobar)))
    ==> foobar
    ok

Can call into assembler routines using `call-native`, which accepts an address and up to 8 args into
the `a0` to `a7` registers and returns the `(a0 a1)` return values as per the RISC-V ABI.

`(hello)` will print "Hello, world!" and return nil.

Calling hello using the internal ABI:

    > hello
    ==> <0x0000000082020fac>
    ok
    > (call-native 0x0000000082020fac 0x0 0x0)
    Hello, world!
    ==> (0x0000000000000000 0x0000000000000000)
    ok

Read/write `peek` and `poke` are supported, with different lengths:

    > (peek.w (ref (quote foo)))
    ==> 0x0000000000000001
    ok
    > (poke.b 0x820215d8 0x42 0x79 0x65 0x62 0x79 0x65)
    ==> ()
    ok
    > (hello)
    Byebye world!
    ==> ()
    ok