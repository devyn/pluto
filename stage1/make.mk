clean-stage1:
	rm -f stage1.{elf,bin,hex}
	rm -f stage1/*.o

stage1.elf: stage1/link.ld stage1/init.o
	$(LD) -T $< -o $@ $(filter %.o,$^)

stage1/%.o: stage1/%.s
	$(AS) -o $@ $<

.PHONY: clean-stage1
