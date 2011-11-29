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

/* This Driver adapted from the PL011 driver provided as part of the "PREX" RTOS  */ 
#include "pl011.h"

#define PL011_STACK_SIZE	256
#define PL011_PRIORITY		1
#define PL011_QUEUE_SIZE	80

#define UART_BASE	UART0_BASE
#define UART_IRQ	INTERRUPT_UART0
#define UART_CLK	14745600
#define BAUD_RATE	115200

/* UART Registers */
#define UART_DR		(UART_BASE + 0x00)
#define UART_RSR	(UART_BASE + 0x04)
#define UART_ECR	(UART_BASE + 0x04)
#define UART_FR		(UART_BASE + 0x18)
#define UART_IBRD	(UART_BASE + 0x24)
#define UART_FBRD	(UART_BASE + 0x28)
#define UART_LCRH	(UART_BASE + 0x2c)
#define UART_CR		(UART_BASE + 0x30)
#define UART_IMSC	(UART_BASE + 0x38)
#define UART_MIS	(UART_BASE + 0x40)
#define UART_ICR	(UART_BASE + 0x44)


/* Flag register */
#define FR_RXFE		0x10	/* Receive FIFO empty */
#define FR_TXFF		0x20	/* Transmit FIFO full */

/* Masked interrupt status register */
#define MIS_RX		0x10	/* Receive interrupt */
#define MIS_TX		0x20	/* Transmit interrupt */

/* Interrupt clear register */
#define ICR_RX		0x10	/* Clear receive interrupt */
#define ICR_TX		0x20	/* Clear transmit interrupt */

/* Line control register (High) */
#define LCRH_WLEN8	0x60	/* 8 bits */
#define LCRH_FEN	0x10	/* Enable FIFO */

/* Control register */
#define CR_UARTEN	0x0001	/* UART enable */
#define CR_TXE		0x0100	/* Transmit enable */
#define CR_RXE		0x0200	/* Receive enable */

/* Interrupt mask set/clear register */
#define IMSC_RX		0x10	/* Receive interrupt mask */
#define IMSC_TX		0x20	/* Transmit interrupt mask */


driver_t _pl011;
TN_TCB _pl011_task;
unsigned int _pl011_task_stack[PL011_STACK_SIZE];
TN_DQUE _pl011_queue_in;
TN_DQUE _pl011_queue_out;
void * _pl011_fifo_in[PL011_QUEUE_SIZE];
void * _pl011_fifo_out[PL011_QUEUE_SIZE];

pl011_config_t _pl011_default_config = {19200,8,0,1};

void pl011_task_loop(void *);
void pl011_irq(void);

driver_t * pl011_init() {
	// Set up the task
	tn_task_create(&_pl011_task, &pl011_task_loop, PL011_PRIORITY, 
								 &_pl011_task_stack[PL011_STACK_SIZE - 1], PL011_STACK_SIZE, 0, 0);

	// And the queues
	_pl011_queue_in.id_dque = 0;
	tn_queue_create(&_pl011_queue_in, _pl011_fifo_in, PL011_QUEUE_SIZE);
	_pl011_queue_out.id_dque = 0;
	tn_queue_create(&_pl011_queue_out, _pl011_fifo_in, PL011_QUEUE_SIZE);

	// Set up the driver structure
	_pl011._opaque = 0L;
	_pl011._queue_in = &_pl011_queue_in;
	_pl011._queue_out = &_pl011_queue_out;
	_pl011._sieze = &pl011_sieze;
	_pl011._release = &pl011_release;
	_pl011._pause = &pl011_pause;
	_pl011._resume = &pl011_resume;
	_pl011._configure = &pl011_configure;
	
	tn_task_activate(&_pl011_task);
	
	pl011_configure(&_pl011_task, &_pl011_default_config);
	
	irq_enable(INTERRUPT_UART0, &pl011_irq);
	
	return &_pl011;
}

uint32_t pl011_sieze(TN_TCB * task, void * cf) {
	if (task == &_pl011_task) {
		return EINVAL;
	} else if (_pl011._opaque == 0) {
		_pl011._opaque = task;
		return 0;
	} else if (_pl011._opaque == task) {
		return EEXIST;
	}
	return EBUSY;
}

uint32_t pl011_release(TN_TCB * task, void * cf) {
	if (task != _pl011._opaque) {
		return EINVAL;
	}
	_pl011._opaque = 0L;
	return 0;
}

uint32_t pl011_pause(TN_TCB * task, void * cf) {
	if (task != _pl011._opaque) {
		return EINVAL;
	}
	write32(UART_CR, 0L);
	write32(UART_ICR, 0x07ff);
	return 0;
}

uint32_t pl011_resume(TN_TCB * task, void * cf) {
	if (task != _pl011._opaque) {
		return EINVAL;
	}
	write32(UART_CR, (CR_RXE | CR_TXE | CR_UARTEN));
	write32(UART_IMSC, (IMSC_RX | IMSC_TX));
	return 0;
}

uint32_t pl011_configure(TN_TCB * task, void * cf) {
	if (task && cf) {
		pl011_config_t * config = (pl011_config_t*)cf;
		
		// Stop the uart itself
		write32(UART_CR, 0L);
		write32(UART_ICR, 0x07ff);
		
		// Set up the baud rate
		uint32_t divider, remainder, fraction;
		divider = UART_CLK / (16 * config->_baud);
		remainder = UART_CLK % (16 * config->_baud);
		fraction = (8 * remainder / config->_baud) >> 1;
		fraction += (8 * remainder / config->_baud) & 1;
		write32(UART_IBRD, divider);
		write32(UART_FBRD, fraction);
		
		// Data bits
		uint32_t format_config = LCRH_FEN;
		switch (config->_data_bits) {
			case 5:
			break;
			case 6:
			format_config |= (0x01 << 5);
			break;
			case 7:
			format_config |= (0x02 << 5);
			break;
			case 8:
			format_config |= (0x03 << 5);
			break;
			default:
			return EINVAL;
		}
		
		// Parity
		switch (config->_parity) {
			case 0:	// No parity checking
			break;
			case 1:	// Even parity
			format_config |= (0x03 << 1);
			break;
			case 255:	// Odd parity
			format_config |= (0x01 << 1);
			break;
			default:
			return EINVAL;
		}
		
		// Stop bits
		switch(config->_stop_bits) {
			case 1:
			break;
			case 2:
			format_config |= (0x01 << 3);
			break;
			default:
			return EINVAL;
		}
		// Finalise the configuration
		write32(UART_LCRH, format_config);
		// Enable UART
		write32(UART_CR, (CR_RXE | CR_TXE | CR_UARTEN));
		/* Enable TX/RX interrupt */
		write32(UART_IMSC, (IMSC_RX | IMSC_TX));
		return 0;
	}
	return EPERM;
}

void pl011_task_loop(void * unused) {
	void * data;
	while(1) {
		// Check if we have data to send
		if (tn_queue_receive(_pl011._queue_in, &data, TN_WAIT_INFINITE) == TERR_NO_ERR) {
			while (read32(UART_FR) & FR_TXFF)
				DMB;
			write32(UART_DR, (uint32_t)data);
		}
	}
}

void pl011_irq(void) {
	uint32_t c;
	uint32_t mis;

	mis = read32(UART_MIS);

	if (mis & MIS_RX) {
		/* Clear interrupt status */
		write32(UART_ICR, ICR_RX);

		tn_arm_enable_interrupts();
		
		while (read32(UART_FR) & FR_RXFE)
			DMB;
		do {
			c = read32(UART_DR);
			tn_queue_isend_polling(_pl011._queue_out, &c);
		} while ((read32(UART_FR) & FR_RXFE) == 0);
		
		tn_arm_disable_interrupts();
	}
	if (mis & MIS_TX) {
		write32(UART_ICR, ICR_TX);
	}	
}

