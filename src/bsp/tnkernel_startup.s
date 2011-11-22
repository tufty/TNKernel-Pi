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

.include "macros.inc"

    .equ MODE_BITS,   0x1F		 /* Bit mask for mode bits in CPSR */
    .equ USR_MODE,    0x10		 /* User mode */
    .equ FIQ_MODE,    0x11		 /* Fast Interrupt Request mode */
    .equ IRQ_MODE,    0x12		 /* Interrupt Request mode */
    .equ SVC_MODE,    0x13		 /* Supervisor mode */
    .equ ABT_MODE,    0x17		 /* Abort mode */
    .equ UND_MODE,    0x1B		 /* Undefined Instruction mode */
    .equ SYS_MODE,    0x1F		 /* System mode */


    .section	.reset, "ax"
    .global  __reset
    .code 32
__reset:
	b	_reset
	b	.				/* undef_handler not defined */
	b	.				/* swi_handler */
	b	.				/* pabort_handler */
	b	.				/* dabort_handler */
	b	.
	b	tn_cpu_irq_isr
	b 	tn_cpu_fiq_isr

	.ascii "©2011 Simon Stapleton <simon.stapleton@gmail.com>"
	.align
	.ascii "Kernel derived from TNKernel (http://www.tnkernel.com)"
	.align
	.ascii "Contains elements derived from the FreeBSD project (http://www.freebsd.org)"
	.align
	.ascii "In memory of John McCarthy, Sep 4, 1927 - Oct 24, 2011."
	.align

 /*--- Start */

FUNC	_reset
	/* Do any hardware intialisation that absolutely must be done first */
	/* No stack set up at this point - be careful */ 
	ldr	r0, tn_startup_hardware_init	/* vital hardware init */
	mov	lr, pc
	bx	r0

	/* Assume that at this point, __memtop and __system_ram are populated
	
	
    /*---- init stacks */

	mrs	r0, cpsr			/* Original PSR value */

	bic	r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr	r0, r0, #IRQ_MODE		/* Set IRQ mode bits */
	msr	cpsr_c, r0			/* Change the mode */
	ldr    sp, __memtop		/* End of IRQ_STACK */

	bic    r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr    r0, r0, #FIQ_MODE		/* Set FIQ mode bits */
	msr    cpsr_c, r0			/* Change the mode   */
	ldr    sp, __memtop		/* End of FIQ_STACK  */

	bic    r0, r0, #MODE_BITS		/* Clear the mode bits */
	orr    r0, r0, #SVC_MODE		/* Set Supervisor mode bits */
	msr    cpsr_c, r0			/* Change the mode */
	ldr    sp, __memtop			/* End of stack */

	/*-- Leave core in SVC mode ! */


 .extern     __bss_start
 .extern     __bss_end__

     /* ----- Clear BSS (zero init) */

	mov   r0,#0
	ldr   r1,=__bss_start
	ldr   r2,=__bss_end__
2:	cmp   r1,r2
	strlo r0,[r1],#4
	blo   2b


   /*----  */

	.extern	  main


    /*	goto main() */

	mov r0, #0
	mov r1, #0
	ldr r2, =main
	mov	lr, pc
	bx	r2

/*--- Return from main - reset. */

b	_reset

FUNC	tn_startup_hardware_init

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
	lsr	r0, #14			/* Get number of megabytes */
	str	r0, __system_ram	/* And store it */

	bx	lr



/*--------------------------  */

/* Variables (hopefully) provided by the linker */

/* Defaulted variables */

.global	__memtop
__memtop:
	.word	0x08000000		/* Assume memory top at 128MB - valid? */
.global	__mem_page_size
__mem_page_size:
	.word	0x00100000		/* Scan in 1MB blocks */
.global	__system_ram
__system_ram:
	.word	0x00000000		/* System memory in MB */



