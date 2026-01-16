import yfinance as yf
import time
import serial
import csv
from datetime import datetime
from packet_protocol import (
    encode_market_data, 
    decode_trade_decision,
    format_packet_hex,
    format_packet_binary
)

# ============================================
# CONFIGURATION
# ============================================

SERIAL_PORT = '/dev/tty.usbserial-210319BD755F1'
BAUD_RATE = 115200
TICKER_SYMBOL = "AAPL"
UPDATE_INTERVAL = 1.5
LOG_FILE = "packets.csv"

# Display options
PRINT_BINARY = False
PRINT_HEX = False
PRINT_TESTBENCH_FORMAT = False  # outputs SystemVerilog format

# ============================================
# GLOBAL STATE
# ============================================

ser = None
current_position = 0
csv_file = None
csv_writer = None


def init_serial():
    """Initialize serial connection to FPGA"""
    global ser
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"✓ Connected to FPGA on {SERIAL_PORT} at {BAUD_RATE} baud\n")
        time.sleep(2)
        return True
    except Exception as e:
        print(f"✗ Serial connection error: {e}")
        print("Running in simulation mode (no FPGA)\n")
        return False


def init_csv():
    """Initialize CSV logging"""
    global csv_file, csv_writer
    csv_file = open(LOG_FILE, 'w', newline='')
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(['Timestamp', 'Ticker', 'Ask', 'Bid', 'Position', 'Unix Time', 'Hex Packet'])
    print(f"✓ Logging packets to {LOG_FILE}\n")


def log_packet(ticker, ask, bid, pos, timestamp, packet):
    """Write packet to CSV"""
    if csv_writer:
        csv_writer.writerow([
            datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            ticker,
            f"${ask:.2f}",
            f"${bid:.2f}",
            pos,
            timestamp,
            format_packet_hex(packet)
        ])
        csv_file.flush()


def format_packet_testbench(packet):
    """Format packet for SystemVerilog testbench"""
    hex_str = ''.join(f'{byte:02x}' for byte in packet)
    return f"send_packet(144'h{hex_str});\n#5_000_000;"


def get_market_data(ticker_symbol):
    """Fetch real-time market data from Yahoo Finance"""
    try:
        ticker = yf.Ticker(ticker_symbol)
        info = ticker.info
        
        bid_price = info.get('bid', None)
        ask_price = info.get('ask', None)
        
        if bid_price is None or ask_price is None or bid_price == 0 or ask_price == 0:
            return None
        
        return (ask_price, bid_price)
    
    except Exception as e:
        print(f"Error fetching market data: {e}")
        return None


def execute_trade(decision):
    """Execute trade based on FPGA decision"""
    global current_position
    
    action = decision['action']
    quantity = decision['quantity']
    order_type = decision['order_type']
    limit_price = decision['limit_price']
    ticker = decision['ticker']
    
    if action == "HOLD":
        return
    
    if action == "BUY":
        current_position += quantity
    elif action == "SELL":
        current_position -= quantity
    
    print(f"\n{'='*60}")
    print(f"  TRADE EXECUTED")
    print(f"{'='*60}")
    print(f"  Action:      {action}")
    print(f"  Ticker:      {ticker}")
    print(f"  Quantity:    {quantity} shares")
    print(f"  Order Type:  {order_type}")
    if order_type == "LIMIT":
        print(f"  Limit Price: ${limit_price:.2f}")
    print(f"  New Position: {current_position} shares")
    print(f"{'='*60}\n")


def trading_loop_iteration():
    """Single iteration of the trading loop"""
    global current_position
    
    market_data = get_market_data(TICKER_SYMBOL)
    
    if market_data is None:
        print("No valid market data available, skipping...")
        return
    
    ask_price, bid_price = market_data
    
    packet = encode_market_data(
        TICKER_SYMBOL,
        ask_price,
        bid_price,
        current_position,
        time.time()
    )
    
    # Log to CSV
    log_packet(TICKER_SYMBOL, ask_price, bid_price, current_position, int(time.time()), packet)
    
    timestamp = datetime.now().strftime('%H:%M:%S')
    print(f"[{timestamp}] {TICKER_SYMBOL} | Ask: ${ask_price:.2f} | Bid: ${bid_price:.2f} | Pos: {current_position}")
    
    if PRINT_BINARY:
        print(format_packet_binary(packet))
    
    if PRINT_HEX:
        print(format_packet_hex(packet))
    
    if PRINT_TESTBENCH_FORMAT:
        print(format_packet_testbench(packet))
    
    if ser and ser.is_open:
        ser.write(packet)
        time.sleep(0.1)
        
        if ser.in_waiting >= 16:
            response = ser.read(16)
            print(f"← FPGA Response: {format_packet_hex(response)}")
            
            decision = decode_trade_decision(response)
            
            if decision:
                print(f"  Decision: {decision['action']} {decision['quantity']} @ {decision['order_type']}", end="")
                if decision['order_type'] == "LIMIT":
                    print(f" ${decision['limit_price']:.2f}")
                else:
                    print()
                
                if decision['action'] != "HOLD":
                    execute_trade(decision)
            else:
                print("  ✗ Invalid response packet")
    
    print()


def main():
    """Main trading system"""
    print("="*60)
    print(f"  Ticker:   {TICKER_SYMBOL}")
    print(f"  Position: {current_position} shares")
    print(f"  Interval: {UPDATE_INTERVAL}s")
    print("="*60 + "\n")
    
    init_serial()
    init_csv()
    
    print("Starting trading loop (Press Ctrl+C to stop)\n")
    
    try:
        while True:
            trading_loop_iteration()
            time.sleep(UPDATE_INTERVAL)
    
    except KeyboardInterrupt:
        print("\n" + "="*60)
        print(f"  Final Position: {current_position} shares")
        print(f"  Packets logged to: {LOG_FILE}")
        print("="*60 + "\n")
        
        if csv_file:
            csv_file.close()
        
        if ser and ser.is_open:
            ser.close()
            print("✓ Serial connection closed\n")


if __name__ == "__main__":
    main()