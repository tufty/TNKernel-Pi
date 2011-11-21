ARCH = arm-none-eabi
CC = ${ARCH}-gcc
AS = ${ARCH}-as
LD = ${ARCH}-ld
AR = ${ARCH}-ar
OBJCOPY = ${ARCH}-objcopy

CFLAGS = -Os -std=c99 -Werror -g -DTNKERNEL_PORT_ARM
CFLAGS_FOR_TARGET = -mcpu=arm1176jzf-s
ASFLAGS = -g
ASFLAGS_FOR_TARGET = -mcpu=arm1176jzf-s
LDFLAGS = -nostdlib -static --error-unresolved-symbols

SYSLIBS = 

MODULES := kernel bsp lambda
SRC_DIR := $(addprefix src/,$(MODULES))
OBJ_DIR := obj

ASRC     := $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.s))
AOBJ     := $(addprefix obj/, $(notdir $(ASRC:.s=.o)))
CSRC     := $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.c))
COBJ     := $(addprefix obj/, $(notdir $(CSRC:.c=.o)))

INCLUDES  := -Isrc $(addprefix -I,$(SRC_DIR))

vpath %.c $(SRC_DIR)
vpath %.s $(SRC_DIR)

$(OBJ_DIR)/%.o: %.c
	$(CC) $(CFLAGS_FOR_TARGET) $(INCLUDES) $(CFLAGS) -c -o $(OBJ_DIR)/$*.o $<

$(OBJ_DIR)/%.o: %.s
	$(AS) $(ASFLAGS_FOR_TARGET) $(INCLUDES) $(ASFLAGS) -o $(OBJ_DIR)/$*.o $<

OBJ = $(AOBJ) $(COBJ)

bin/kernel.img: bin/kernel.elf
	${OBJCOPY} -O binary $< $@

bin/kernel.elf: lambdapi.ld $(OBJ)
	${LD} ${LDFLAGS} -T lambdapi.ld $(OBJ) ${SYSLIBS} -o $@


clean:
	rm -f bin/*.elf bin/*.img obj/*.o

