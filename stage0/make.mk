clean-stage0:
	rm -f stage0.{elf,bin,hex}
	rm -f stage0/*.o

stage0.elf: stage0/link.ld stage0/loader.o
	$(LD) -T $< -o $@ $(filter %.o,$^)

stage0/%.o: stage0/%.s
	$(AS) -o $@ $<

.PHONY: clean-stage0
