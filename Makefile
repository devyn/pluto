CROSS_COMPILE = riscv64-elf-
GDB = $(CROSS_COMPILE)gdb
LD = $(CROSS_COMPILE)ld
AS = $(CROSS_COMPILE)as
OBJCOPY = $(CROSS_COMPILE)objcopy
QEMU = qemu-system-riscv64
QEMUFLAGS = -s -d guest_errors

all: stage0.elf stage1.hex stage2.lsp

clean: clean-stage0 clean-stage1 clean-stage2

include stage0/make.mk
include stage1/make.mk
include stage2/make.mk

qemu: stage0.elf
	$(QEMU) \
		-M virt \
		-m 64m \
		-smp 1 \
		-nographic \
		-kernel stage0.elf \
		$(QEMUFLAGS)

gdb:
	$(GDB) -ex 'file stage1.elf' -ex 'target remote localhost:1234'

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	xxd -p $< > $@

copy-all: stage1.hex stage2.lsp
	(cat stage1.hex; echo -n '.'; cat stage2.lsp) | ( \
		xclip -selection CLIPBOARD || \
		wl-copy || \
		pbcopy)

.PHONY: all clean qemu gdb copy-all
