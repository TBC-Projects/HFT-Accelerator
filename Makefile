# Makefile for HFT Accelerator

# Source files
SOURCES = trading_core.sv uart_txrx.sv hft_accelerator.sv hft_accelerator_tb.sv

# Output
SIM = sim
VCD = hft_accelerator.vcd

# Default target
all: sim

# Compile and run simulation
sim: $(SOURCES)
	@echo "Compiling..."
	iverilog -g2012 -o $(SIM) $(SOURCES)
	@echo "Running simulation..."
	vvp $(SIM)

# View waveforms
view: $(VCD)
	gtkwave $(VCD) &

# Clean generated files
clean:
	rm -f $(SIM) $(VCD)

# Run Python controller in test mode
test-py:
	python3 hft_controller.py --test --ticker AAPL --interval 2

# Help
help:
	@echo "HFT Accelerator Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make sim      - Compile and run simulation"
	@echo "  make view     - View waveforms in GTKWave"
	@echo "  make test-py  - Test Python controller (no FPGA)"
	@echo "  make clean    - Remove generated files"

.PHONY: all sim view clean test-py help
