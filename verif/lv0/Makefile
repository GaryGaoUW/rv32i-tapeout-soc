TOP_MODULE = core_top
RTL_DIR    = ../../rtl
# RTL is split by function (see ROADMAP Appendix B); Verilator searches
# every directory below for module definitions.
RTL_SUBDIRS = core mem bus
SIM_SRC    = sim_main.cpp
BIN        = obj_dir/V$(TOP_MODULE)

VFLAGS = --cc --exe --build --trace \
         --top-module $(TOP_MODULE) \
         -Wno-fatal \
         $(addprefix -I$(RTL_DIR)/,$(RTL_SUBDIRS))

.PHONY: all build run wave clean

all: build

build:
	verilator $(VFLAGS) $(RTL_DIR)/core/$(TOP_MODULE).v $(SIM_SRC)

run: build
	./$(BIN)

wave:
	surfer $(CURDIR)/wave.vcd

clean:
	rm -rf obj_dir *.vcd
