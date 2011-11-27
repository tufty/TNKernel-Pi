#!/bin/bash
make || exit

# Start up qemu in the background
qemu-system-arm -nographic -M versatilepb -cpu arm1136-r2 -m 128 -device sp804 -device pl011 -kernel ./bin/kernel.elf -s -S &

# And fire up the debugger
arm-none-eabi-gdb -nx -x "./gdbinit" --tui ./bin/kernel.elf
#arm-none-eabi-gdb -nx ./bin/kernel.elf 
