REPO   = ../../..
PYTHON = $(REPO)/.venv/bin/python

.PHONY: all test wave clean

all: test

# Build RTL with Verilator and run every @cocotb.test in test_axi_d_bus.py
test:
	$(PYTHON) -m pytest -v -s test_axi_d_bus.py

# Open the waveform from the last run
wave:
	surfer dump.vcd

clean:
	rm -rf sim_build dump.vcd *.result.xml results.xml __pycache__ .pytest_cache
