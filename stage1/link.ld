MEMORY {
	RAM (rwx) : ORIGIN = 0x82020000, LENGTH = 0x200000
}

SECTIONS {
	. = 0x82020000;
	.text : { *(.text) }
	.rodata : { *(.rodata) }
	.data : { *(.data) }
	.bss : { *(.bss) }
}
