#!/usr/bin/env python3
"""
HFT Accelerator - PC Side Controller
Fetches stock data and communicates with FPGA via UART
"""

import struct
import time
import requests
import serial
import argparse

API_KEY = '5nMOblcaLluhVKAoAKTBbrrhLzx2D774'  # Your API key

def price_to_q16_16(price):
    """Convert float price to Q16.16 fixed-point format"""
    return int(price * 65536)

def q16_16_to_price(q16_16):
    """Convert Q16.16 fixed-point to float price"""
    return q16_16 / 65536.0

def get_stock_price(ticker):
    """Fetch latest stock price from Polygon.io"""
    url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/prev?adjusted=true&apiKey={API_KEY}"
    
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            price = data['results'][0]['c']
            return price
        else:
            print(f"API Error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error fetching price: {e}")
        return None

def send_price_to_fpga(ser, price):
    """Send price to FPGA via UART (4 bytes, big-endian)"""
    price_q16 = price_to_q16_16(price)
    data = struct.pack('>I', price_q16)  # Big-endian 32-bit unsigned
    ser.write(data)
    print(f"Sent: ${price:.2f} (0x{price_q16:08X})")

def receive_decision_from_fpga(ser):
    """Receive trading decision from FPGA (3 bytes: action, rsi_low, rsi_high)"""
    if ser.in_waiting >= 3:
        data = ser.read(3)
        action = data[0] & 0x03
        rsi = (data[2] << 8) | data[1]
        
        action_str = {0: "HOLD", 1: "BUY", 2: "SELL"}.get(action, "UNKNOWN")
        rsi_value = rsi / 100.0
        
        print(f"Decision: {action_str} | RSI: {rsi_value:.1f}")
        return action_str, rsi_value
    return None, None

def main():
    parser = argparse.ArgumentParser(description='HFT Accelerator Controller')
    parser.add_argument('--port', default='/dev/ttyUSB0', help='Serial port (default: /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=9600, help='Baud rate (default: 9600)')
    parser.add_argument('--ticker', default='AAPL', help='Stock ticker (default: AAPL)')
    parser.add_argument('--interval', type=float, default=5.0, help='Poll interval in seconds (default: 5)')
    parser.add_argument('--test', action='store_true', help='Test mode without serial port')
    
    args = parser.parse_args()
    
    # Open serial port (skip in test mode)
    ser = None
    if not args.test:
        try:
            ser = serial.Serial(args.port, args.baud, timeout=1)
            print(f"Connected to {args.port} at {args.baud} baud")
            time.sleep(2)  # Wait for FPGA reset
        except Exception as e:
            print(f"Error opening serial port: {e}")
            print("Running in test mode (no FPGA communication)")
            args.test = True
    
    print(f"Trading {args.ticker} with {args.interval}s interval")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            # Fetch current price
            price = get_stock_price(args.ticker)
            
            if price is not None:
                print(f"\n[{time.strftime('%H:%M:%S')}] {args.ticker}: ${price:.2f}")
                
                if not args.test:
                    # Send to FPGA
                    send_price_to_fpga(ser, price)
                    
                    # Wait a bit for processing
                    time.sleep(0.5)
                    
                    # Receive decision
                    action, rsi = receive_decision_from_fpga(ser)
                    
                    if action == "BUY":
                        print("  ✅ BUY SIGNAL - Would execute buy order")
                    elif action == "SELL":
                        print("  🔴 SELL SIGNAL - Would execute sell order")
                else:
                    print("  (Test mode - no FPGA communication)")
            
            # Wait for next interval
            time.sleep(args.interval)
            
    except KeyboardInterrupt:
        print("\n\nStopped by user")
    finally:
        if ser:
            ser.close()
            print("Serial port closed")

if __name__ == '__main__':
    main()
