RISCV_PREFIX ?= /Users/garygao/riscv-tools/xpack-riscv-none-elf-gcc-14.2.0-2/bin/riscv-none-elf-
CC      = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

CFLAGS  = -march=rv32i_zifencei -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
INCLUDES = -Ienv -I../riscv-tests/isa/macros/scalar
LDFLAGS = -Tenv/link.ld

SRC_DIR = ../riscv-tests/isa/rv32ui
BIN_DIR = bin

TESTS = add addi and andi auipc beq bge bgeu blt bltu bne fence_i \
        jal jalr lb lbu lh lhu lui lw or ori sb sh simple \
        sll slli slt slti sltiu sltu sra srai srl srli sub sw xor xori

BINS = $(addprefix $(BIN_DIR)/rv32ui-p-, $(addsuffix .bin, $(TESTS)))

.PHONY: all clean

all: $(BIN_DIR) $(BINS)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/rv32ui-p-%.bin: $(SRC_DIR)/%.S $(BIN_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $< -o $(BIN_DIR)/rv32ui-p-$*.elf
	$(OBJCOPY) -O binary $(BIN_DIR)/rv32ui-p-$*.elf $@
	$(OBJDUMP) -D $(BIN_DIR)/rv32ui-p-$*.elf > $(BIN_DIR)/rv32ui-p-$*.dump
	rm -f $(BIN_DIR)/rv32ui-p-$*.elf

clean:
	rm -rf $(BIN_DIR)
