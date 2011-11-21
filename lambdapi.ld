heap_size      = 1024;
stack_fiq_size = 16;
stack_irq_size = 256;
stack_app_size = 1024;

ENTRY(__reset)
SECTIONS
{
	. = 0x0;
	.text : {
		*(.reset)
		*(.text)
	}
	
	/* .data section which is used for initialized data */
	. = ALIGN(4);
	_etext = . ;
	PROVIDE (etext = .);
	.data : AT (_etext)
	{
		_data = .;
		*(.data)
	}

	/* .bss section which is used for uninitialized data */
	. = ALIGN(4);
	_edata = . ;
	PROVIDE (edata = .);
	.bss (NOLOAD) :
	{
		__bss_start = . ;
		__bss_start__ = . ;
		*(.bss)
		*(COMMON)
		. = ALIGN(4);
	}

	. = ALIGN(4);
	__bss_end__ = . ;
	PROVIDE (__bss_end = .);
	.heap ALIGN(__bss_end__ , 4) (NOLOAD) :
	{
		__heap_start__ = .;
		*(.heap)
	}
	__heap_end__ = __heap_start__ + heap_size;


	.stack_bottom  ALIGN(__heap_end__ , 4) (NOLOAD) :
	{
		__stack__bottom__ = .;
		*(.stack)
	}

	__stack_bottom_end__ = __stack__bottom__  + stack_fiq_size ;
	.stack_fiq_bottom  ALIGN(__stack_bottom_end__ , 4) (NOLOAD) :
	{
		__stack__fiq_bottom__ = .;
		*(.stack)
	}

	__stack_fiq_bottom_end__ = __stack__fiq_bottom__  + stack_irq_size ;
	.stack_irq_bottom  ALIGN(__stack_fiq_bottom_end__ , 4) (NOLOAD) :
	{
		__stack_irq_bottom__ = .;
		*(.stack)
	}

	__stack_irq_bottom_end__ = __stack_irq_bottom__  + stack_app_size ;
	_end = . ;
	PROVIDE (end = .);
}