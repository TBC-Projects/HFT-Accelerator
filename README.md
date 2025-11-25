# HFT-Accelerator

FPGA-accelerated high-frequency trading system using RSI (Relative Strength Index) mean reversion strategy.

## Strategy

- **Buy** when RSI < 30 (oversold)
- **Sell** when RSI > 70 (overbought)
- Uses 14-period RSI calculation
- Q16.16 fixed-point arithmetic for speed

## Architecture

```
PC (Python) <--UART--> FPGA (SystemVerilog)
     |                      |
   Polygon.io API      Trading Core
   Stock Data          RSI Calculation
                       Buy/Sell Decision
```

## Files

### SystemVerilog (FPGA)
- `trading_core.sv` - RSI calculation and trading logic
- `uart_txrx.sv` - UART communication module
- `hft_accelerator.sv` - Top-level integration
- `hft_accelerator_tb.sv` - Testbench

### Python (PC)
- `hft_controller.py` - Fetches stock data and communicates with FPGA

## Quick Start

### 1. Simulation

```bash
# Compile with Icarus Verilog
iverilog -g2012 -o sim trading_core.sv uart_txrx.sv hft_accelerator.sv hft_accelerator_tb.sv

# Run simulation
vvp sim

# View waveforms (optional)
gtkwave hft_accelerator.vcd
```

### 2. Python Controller

```bash
# Install dependencies
pip install pyserial requests

# Test mode (no FPGA)
python3 hft_controller.py --ticker AAPL --interval 5 --test

# With FPGA connected
python3 hft_controller.py --port /dev/ttyUSB0 --ticker AAPL
```

## Communication Protocol

### PC → FPGA (Price Data)
- 4 bytes: Price in Q16.16 format
- Example: $150.50 = 0x00960800

### FPGA → PC (Trading Decision)
- Byte 0: Action (0=HOLD, 1=BUY, 2=SELL)
- Byte 1-2: RSI value (0-10000 representing 0.00-100.00)

## Q16.16 Fixed-Point Format

```
Price = Integer_Part × 65536 + Fractional_Part × 65536
Example: $150.50 = (150 << 16) + (0.50 × 65536) = 9,863,168
```

## FPGA Resource Usage
- LUTs: ~500
- Flip-Flops: ~300
- Block RAM: 1KB
- Clock: 50 MHz recommended

## Performance

- Decision latency: ~10-20 clock cycles
- At 50 MHz: 200-400 nanoseconds
- UART bottleneck: ~4ms per transaction at 9600 baud

## Configuration

Edit parameters in `hft_accelerator.sv`:
```systemverilog
parameter CLK_FREQ = 50_000_000;  // Your FPGA clock
parameter BAUD_RATE = 9600;       // UART speed
```

Edit parameters in `trading_core.sv`:
```systemverilog
parameter RSI_PERIOD = 14;  // RSI calculation period
```
