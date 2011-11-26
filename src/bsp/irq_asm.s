/*                                                                                */
/*                              All rights reserved.                              */
/*                                                                                */
/* Redistribution  and  use   in  source  and  binary  forms,   with  or  without */
/* modification, are permitted provided that the following conditions are met:    */
/*                                                                                */
/* Redistributions of  source code must  retain the above copyright  notice, this */
/* list of conditions and the following disclaimer.                               */
/*                                                                                */
/* Redistributions in binary form must reproduce the above copyright notice, this */
/* list of conditions and the following disclaimer in the documentation and/or    */
/* other materials provided with the distribution.                                */
/*                                                                                */
/* Neither the name of  the developer nor the names of  other contributors may be */
/* used  to  endorse or  promote  products  derived  from this  software  without */
/* specific prior written permission.                                             */
/*                                                                                */
/* THIS SOFTWARE  IS PROVIDED BY THE  COPYRIGHT HOLDERS AND CONTRIBUTORS  "AS IS" */
/* AND ANY  EXPRESS OR  IMPLIED WARRANTIES,  INCLUDING, BUT  NOT LIMITED  TO, THE */
/* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE */
/* DISCLAIMED. IN NO  EVENT SHALL THE COPYRIGHT HOLDER OR  CONTRIBUTORS BE LIABLE */
/* FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,  SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL */
/* DAMAGES (INCLUDING,  BUT NOT  LIMITED TO, PROCUREMENT  OF SUBSTITUTE  GOODS OR */
/* SERVICES; LOSS  OF USE,  DATA, OR PROFITS;  OR BUSINESS  INTERRUPTION) HOWEVER */
/* CAUSED AND ON ANY THEORY OF  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, */
/* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING  IN ANY WAY OUT OF THE USE */
/* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.           */

.include "macros.inc"

.equ	IRQ_BASE,	0x7e00b000

.equ	IRQ0_PENDING,	0x00000200
.equ	IRQ1_PENDING,	0x00000204
.equ	IRQ2_PENDING,	0x00000208

.equ	IRQ_BANK1,	0x00000100
.equ	IRQ_BANK2,	0x00000200

.equ	IRQ_BANK1_DUP1,	0x000c0000	/* bitmask of IRQs already handled in bank 0 */
.equ	IRQ_BANK1_DUP2,	0x00000680	/* Twice becase they don't fit into one BIC  */
.equ	IRQ_BANK2_DUP1,	0x43000000	/* which can clear 8 contiguous bits with a  */
.equ	IRQ_BANK2_DUP2,	0x00e00000	/* 4 bit rotation                            */


/********************************************************/
/* Identify and acknowledge interrupt			*/
/* In 	: nada 						*/
/* Out	: r0 - address of interrupt handler or null 	*/
/* Clob	: r1-r6						*/
/********************************************************/
FUNC	tn_cpu_identify_and_clear_irq
	ldr	r4, =.Lirq_base
	ldr	r4, [r4]
	
	/* Load the IRQ0 pending register */
	ldr	r0, [r4, #IRQ0_PENDING]
	
	/* Look into the banked bits */
	bics	r5, r0, #IRQ_BANK1
	
	/* If we're in bank 1 */
	streq	r0, [r4, #IRQ0_PENDING]		/* Clear bank 0 IRQ pending flag */
	ldreq	r0, [r4, #IRQ1_PENDING]
	biceq	r0, #IRQ_BANK1_DUP1		/* Clear any bank 1 duplicates */
	biceq	r0, #IRQ_BANK1_DUP2
	ldreq	r5, =irq_bank1_handlers
	addeq	r4, r4, #IRQ1_PENDING
	beq	.Lid_done			/* And handle the interrupt */
	
	/* Got here because we're not in Bank 1 */
	bics	r5, r0, #IRQ_BANK2

	/* If we're in bank 2 */
	streq	r0, [r4, #IRQ0_PENDING]		/* Clear bank 0 IRQ pending flag */
	ldreq	r0, [r4, #IRQ2_PENDING]
	biceq	r0, #IRQ_BANK2_DUP1		/* Clear any bank 2 duplicates */
	biceq	r0, #IRQ_BANK2_DUP2
	ldreq	r5, =irq_bank2_handlers
	addeq	r4, r4, #IRQ2_PENDING
	beq	.Lid_done

	/* If we get to here, we're still in bank 0 */
	ldr	r5, =irq_bank0_handlers
	addeq	r4, r4, #IRQ0_PENDING
.Lid_done:
	/* At this point : 								*/
	/* - r0 is the remaining pending interrupt flags (may be zero due to duplicates)*/
	/* - r4 is pointing to pending register						*/
	/* - r5 is pointing at the handler table					*/
	/* - if we're not in bank 0, bank 0 pending flags are already cleared		*/

	mov	r6, r0				/* save flags */
	bl	ffs_asm				/* find first set bit */
	
	movne	r1, #1				/* make a mask */
	lslne	r1, r1, r0			
	bicne	r6, r6, r1			/* clear flag */
	strne	r6, [r4]			/* And save it back */
	
	ldrne	r0, [r2, r0]			/* load handler address */
	moveq	r0, #0				/* or null */
.Lret:	bx	lr				/* exit */
	

.Lirq_base:
	.word	IRQ_BASE
.bss
.global irq_bank0_handlers
irq_bank0_handlers:	.skip	32 * 4
.global irq_bank1_handlers
irq_bank1_handlers:	.skip	32 * 4
.global irq_bank2_handlers
irq_bank2_handlers:	.skip	32 * 4
