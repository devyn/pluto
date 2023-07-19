# pluto
Bootstrapping from nothing

First, make the stage1.hex file and copy its contents to your clipboard

    $ make copy-stage1

Then run the emulator and you should be able to paste in the file

    $ make qemu

Press dot (`.`) to run it and you should currently see a prompt. Typing a line will cause the line
to be read back to you, followed by "ok", in a loop.

This is currently all this does but I want to make it basically a very bootstrapped RISC-V Lisp
interpreter. Basically support an entire system being built up from text sent over a serial port.

## Rationale

I have some hardware that can run RV64GC but isn't incredibly powerful, so I want to have some fun
with it. An advantage of RISC-V is that the ISA is quite straightforward and the number of different
instruction formats is small, so it shouldn't be hard to write an assembler from within the Lisp
environment and continue extending it that way, which just sounds like the exact kind of masochistic
software fun I'm into.