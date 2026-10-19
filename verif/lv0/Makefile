TOP_MODULE = core_top
RTL_DIR    = ../../rtl
SIM_SRC    = sim_main.cpp
BIN        = obj_dir/V$(TOP_MODULE)

VFLAGS = --cc --exe --build --trace \
         --top-module $(TOP_MODULE) \
         -Wno-fatal \
         -I$(RTL_DIR)

.PHONY: all build run wave clean

all: build

build:
	verilator $(VFLAGS) $(RTL_DIR)/$(TOP_MODULE).v $(SIM_SRC)

run: build
	./$(BIN)

wave:
	surfer wave.vcd

clean:
	rm -rf obj_dir *.vcd

