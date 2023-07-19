SECTIONS {
	. = 0x82000000;
	.text : { *(.text) }
	.data : { *(.data) }
	.bss : { *(.bss) }
}

ENTRY(start)
