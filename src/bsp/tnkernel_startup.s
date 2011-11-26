/*	  Copyright (c) 20011, Simon Stapleton (simon.stapleton@gmail.com)	  */
/*										  */
/*				All rights reserved.				  */
/*										  */
/* Redistribution  and	use   in  source  and  binary  forms,	with  or  without */
/* modification, are permitted provided that the following conditions are met:	  */
/*										  */
/* Redistributions of  source code must	 retain the above copyright  notice, this */
/* list of conditions and the following disclaimer.				  */
/*										  */
/* Redistributions in binary form must reproduce the above copyright notice, this */
/* list of conditions and the following disclaimer in the documentation and/or	  */
/* other materials provided with the distribution.				  */
/*										  */
/* Neither the name of	the developer nor the names of	other contributors may be */
/* used	 to  endorse or	 promote  products  derived  from this	software  without */
/* specific prior written permission.						  */
/*										  */
/* THIS SOFTWARE  IS PROVIDED BY THE  COPYRIGHT HOLDERS AND CONTRIBUTORS  "AS IS" */
/* AND ANY  EXPRESS OR	IMPLIED WARRANTIES,  INCLUDING, BUT  NOT LIMITED  TO, THE */
/* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE */
/* DISCLAIMED. IN NO  EVENT SHALL THE COPYRIGHT HOLDER OR  CONTRIBUTORS BE LIABLE */
/* FOR	ANY DIRECT,  INDIRECT, INCIDENTAL,  SPECIAL, EXEMPLARY,	 OR CONSEQUENTIAL */
/* DAMAGES (INCLUDING,	BUT NOT	 LIMITED TO, PROCUREMENT  OF SUBSTITUTE	 GOODS OR */
/* SERVICES; LOSS  OF USE,  DATA, OR PROFITS;  OR BUSINESS  INTERRUPTION) HOWEVER */
/* CAUSED AND ON ANY THEORY OF	LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, */
/* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING	IN ANY WAY OUT OF THE USE */
/* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.		  */

.include "../lib/macros.inc"

.equ MODE_BITS,   0x1F		 /* Bit mask for mode bits in CPSR */
.equ USR_MODE,    0x10		 /* User mode */
.equ FIQ_MODE,    0x11		 /* Fast Interrupt Request mode */
.equ IRQ_MODE,    0x12		 /* Interrupt Request mode */
.equ SVC_MODE,    0x13		 /* Supervisor mode */
.equ ABT_MODE,    0x17		 /* Abort mode */
.equ UND_MODE,    0x1B		 /* Undefined Instruction mode */
.equ SYS_MODE,    0x1F		 /* System mode */

 /*--- Start */

FUNC	_reset
	/* Do any hardware intialisation that absolutely must be done first */
	/* No stack set up at this point - be careful */
	bl	tn_startup_hardware_init

	/* Assume that at this point, __memtop and __system_ram are populated
	/* Let's get on with initialising our stacks */
	
	/* For the moment we'll work with the TNKernel/ARM assumption that */
	/* we only ever use SVC, IRQ and maybe FIQ */

	mrs	r0, cpsr			/* Original PSR value */
	ldr	r1, __memtop			/* Top of memory */
	
	bic	r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr	r0, r0, #IRQ_MODE		/* Set IRQ mode bits */
	msr	cpsr_c, r0			/* Change the mode */
	mov	sp, r1				/* End of IRQ_STACK */
	
	/* Subtract IRQ stack size */
	ldr	r2, __irq_stack_size
	sbc	r1, r1, r2

	bic    r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr    r0, r0, #FIQ_MODE		/* Set FIQ mode bits */
	msr    cpsr_c, r0			/* Change the mode   */
	mov    sp, r1				/* End of FIQ_STACK  */
	
	/* Subtract IRQ stack size */
	ldr	r2, __fiq_stack_size
	sbc	r1, r1, r2

	bic    r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr    r0, r0, #SVC_MODE		/* Set Supervisor mode bits */
	msr    cpsr_c, r0			/* Change the mode */
	mov    sp, r2				/* End of stack */
	
	/* And finally subtract Kernel stack size to get final __memtop */
	ldr	r2, __kern_stack_size
	sbc	r1, r1, r2
	str	r1, __memtop
	
	/*-- Leave core in SVC mode ! */
	
	/* Zero the memory in the .bss section.  */
	mov 	a2, #0			/* Second arg: fill value */
	mov	fp, a2			/* Null frame pointer */
	
	ldr	a1, .Lbss_start		/* First arg: start of memory block */
	ldr	a3, .Lbss_end	
	sub	a3, a3, a1		/* Third arg: length of block */
	bl	memset

	mov r0, #0
	mov r1, #0
	ldr r2, .Lmain
        mov     lr, pc
        bx      r2

	/*--- Return from main - reset. */
	/* We should never get here */
	b	_reset

/* This tries to work out how much memory we have available 	 */
FUNC	tn_startup_hardware_init

	/* patch in temporary fault handler */
	ldr	r3, =.Ldaha
	ldr	r3, [r3]
	ldr	r4, [r3]
	ldr	r5, =temp_abort_handler
	str	r5, [r3] 
	DMB	r12

	/* Try and work out how much memory we have */
	ldr	r0, __memtop
	ldr	r1, __mem_page_size
.Lmem_check:
	add	r0, r0, #0x04
	str	r0, [r0]		/* Try and store a value above current __memtop */
	DMB	r12			/* Data memory barrier, in case */
	ldr	r2, [r0]		/* Test if it stored */
	cmp	r0, r2			/* Did it work? */
	bne	.Lmem_done
	ldr	r0, __memtop
	add	r0, r0, r1		/* Add block size onto __memtop and try again */
	str	r0, __memtop
	b	.Lmem_check
.Lmem_done:
	ldr	r0, __memtop		/* get final memory size */
	lsr	r0, #0x14		/* Get number of megabytes */
	str	r0, __system_ram	/* And store it */
	
	/* unpatch handlers */
	str	r4, [r3]
	DMB	r12

	bx	lr
.Ldaha:
.word	data_abort_handler_address

/* temporary data abort handler that sets r2 to zero */
/* this will force the "normal" check to work in the */
/* case (as, I believe, on RasPi) where access 'out  */
/* of bounds' causes a page fault                    */

temp_abort_handler:
	mov	r2, #0x00000000
	sub	lr, lr, #0x08
	movs	pc, lr
	
/* Variables (hopefully) provided by the linker */

.Lbss_start:		.word	__bss_start__
.Lbss_end:		.word	__bss_end__
.Lmain:			.word	main

/* Defaulted variables */

/* These ones are exposed to C */
.global	__memtop
__memtop:		.word	0x00400000		/* Start checking memory from 4MB */
.global	__system_ram
__system_ram:		.word	0x00000000		/* System memory in MB */
.global	__heap_start
__heap_start:		.word	__bss_end__		/* Start of the dynamic heap */

/* These ones are global but not exposed in header files */
.global	__mem_page_size
__mem_page_size:	.word	0x00100000		/* Scan 1MB blocks */
.global __irq_stack_size
__irq_stack_size:	.word	0x000000ff		/* Stack size for IRQ in bytes */
.global __fiq_stack_size
__fiq_stack_size:	.word	0x000000ff		/* Stack size for FIQ in bytes */
.global __kern_stack_size
__kern_stack_size:	.word	0x000000ff		/* Stack size for Kernel in bytes */

