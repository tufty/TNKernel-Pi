ENTRY(_reset)
SECTIONS
{
	. = 0x0;
	.text : {
		*(.reset)
		*(.text)
	}
	
	.data : {
		_data = .;
		*(.data)
	}

	.bss : {
		__bss_start = . ;
		__bss_start__ = . ;
		*(.bss)
		*(COMMON)
		. = ALIGN(4);
	}

	. = ALIGN(4);
	__bss_end__ = . ;
	PROVIDE (__bss_end = .);
	.heap : {
		__heap_start__ = .;
		*(.heap)
	}
}