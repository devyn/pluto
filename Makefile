CROSS_COMPILE = riscv64-elf-
GDB = $(CROSS_COMPILE)gdb
LD = $(CROSS_COMPILE)ld
AS = $(CROSS_COMPILE)as
OBJCOPY = $(CROSS_COMPILE)objcopy
QEMU = qemu-system-riscv64
QEMUFLAGS = -s

all: stage0.elf stage1.hex

clean:
	rm -f stage0.{elf,bin,hex}
	rm -f stage0/*.o
	rm -f stage1.{elf,bin,hex}
	rm -f stage1/*.o

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

stage0.elf: stage0/link.ld stage0/loader.o
	$(LD) -T $< -o $@ $(filter %.o,$^)

stage0/%.o: stage0/%.s
	$(AS) -o $@ $<

stage1.elf: stage1/link.ld stage1/init.o
	$(LD) -T $< -o $@ $(filter %.o,$^)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	xxd -p $< > $@

stage1/%.o: stage1/%.s
	$(AS) -o $@ $<

.PHONY: all clean qemu gdb
