CROSS_COMPILE = riscv64-elf-
GDB = $(CROSS_COMPILE)gdb
LD = $(CROSS_COMPILE)ld
AS = $(CROSS_COMPILE)as
OBJCOPY = $(CROSS_COMPILE)objcopy
QEMU = qemu-system-riscv64
QEMUFLAGS = -s

all: stage0.elf stage1.hex

clean: clean-stage0 clean-stage1

include stage0/make.mk
include stage1/make.mk

qemu: stage0.elf
	$(QEMU) \
		-M virt \
		-m 64m \
		-smp 1 \
		-nographic \
		-kernel stage0.elf \
		$(QEMUFLAGS)

gdb:
	$(GDB) -ex 'file stage0.elf' -ex 'target remote localhost:1234'

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	xxd -p $< > $@

.PHONY: all clean qemu gdb
