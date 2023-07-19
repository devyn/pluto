# pluto
Bootstrapping from nothing

First, make the stage1.hex file and copy its contents to your clipboard

    $ make stage1.hex
    # on linux/xorg
    $ xclip -selection PRIMARY < stage1.hex
    # on macOS
    $ pbcopy < stage1.hex

Then run the emulator and you should be able to paste in the file

    $ make qemu

Press dot (`.`) to run it and you should see a success message and qemu should quit.