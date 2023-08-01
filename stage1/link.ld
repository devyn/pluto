MEMORY {
	RAM (rwx) : ORIGIN = 0x82000000, LENGTH = 0x200000
}

SECTIONS {
	. = 0x82000000;
	.text : { *(.text) }
	.rodata : { *(.rodata) }
	.data : { *(.data) }
	.bss : { *(.bss) }

	. = ALIGN(8);
	heap : { *(heap) }

	. = ALIGN(8192);
	object_region : { *(object_region) }
}
