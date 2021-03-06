/*        Copyright (c) 20011, Simon Stapleton (simon.stapleton@gmail.com)        */
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

#include "irq.h"
#include <kernel/tn.h>
#include <lib/sysmacros.h>

// Defined in assembly
extern irq_handler_t irq_bank0_handlers[];

//----------------------------------------------------------------------------
// Enable our interrupt vectors then enable IRQ int in ARM core
//----------------------------------------------------------------------------
void tn_cpu_int_enable()
{
	// And enable interrupts
	tn_arm_enable_interrupts();
}

void irq_enable(uint32_t interrupt, irq_handler_t handler) {
	int bank = interrupt_bank(interrupt);
	uint32_t * reg = (uint32_t *)((bank == 0) ? ARM_IRQ_ENBL3 : (bank == 1) ? ARM_IRQ_ENBL1 : ARM_IRQ_ENBL2);
	*reg |= interrupt_mask(interrupt);
	irq_bank0_handlers[handler_index(interrupt)] = handler;
}

void irq_disable(uint32_t interrupt) {
	int bank = interrupt_bank(interrupt);
	uint32_t * reg = (uint32_t *)((bank == 0) ? ARM_IRQ_DIBL3 : (bank == 1) ? ARM_IRQ_DIBL1 : ARM_IRQ_DIBL2);
	*reg |= interrupt_mask(interrupt);
	irq_bank0_handlers[handler_index(interrupt)] = 0L;
}