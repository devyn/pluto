clean-stage1:
	rm -f stage1.{elf,bin,hex}
	rm -f stage1/*.o

STAGE1_OBJECTS = \
	init.o \
	io.o \
	number.o \
	object.o \
	memory.o \
	symbol.o \
	parser.o \
	eval.o \
	words.o \
	proc_builtin.o

stage1.elf: stage1/link.ld $(addprefix stage1/,$(STAGE1_OBJECTS))
	$(LD) -T $< -o $@ $(filter %.o,$^)

stage1/%.o: stage1/%.s
	cd stage1 && $(AS) -g -o $(patsubst stage1/%,%,$@) $(patsubst stage1/%,%,$<)

copy-stage1: stage1.hex
	xclip -selection CLIPBOARD < $< || \
		wl-copy < $< || \
		pbcopy < $<

.PHONY: clean-stage1 copy-stage1
