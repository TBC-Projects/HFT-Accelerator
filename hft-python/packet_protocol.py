import struct

# ============================================
# OUTBOUND PACKET (Python → FPGA): 20 bytes
# ============================================

def encode_market_data(ticker, ask_price, bid_price, position, timestamp):
    """
    Encode 18-byte market data packet to send to FPGA.
    
    Packet structure: 
    - Byte 0:      Start marker (0xAA)
    - Bytes 1-4:   Stock ticker (4 ASCII chars)
    - Bytes 5-8:   Unix timestamp (32-bit)
    - Bytes 9-11:  Ask price in cents (24-bit)
    - Bytes 12-14: Bid price in cents (24-bit)
    - Bytes 15-16: Current position (16-bit signed)
    - Byte 17:     Checksum (XOR of bytes 1-16)
    """

    ask_cents = int(ask_price * 100) & 0xFFFFFF
    bid_cents = int(bid_price * 100) & 0xFFFFFF
    position_int = int(position)
    unix_time = int(timestamp) & 0xFFFFFFFF
    
    packet = bytearray()
    packet.append(0xAA)                                          # 1 byte
    packet.extend(ticker.encode('ascii')[:4].ljust(4, b' '))    # 4 bytes
    packet.extend(struct.pack('>I', unix_time))                  # 4 bytes
    packet.extend(ask_cents.to_bytes(3, byteorder='big'))       # 3 bytes
    packet.extend(bid_cents.to_bytes(3, byteorder='big'))       # 3 bytes
    packet.extend(struct.pack('>h', position_int))               # 2 bytes
    

    checksum = 0
    for byte in packet[1:]:
        checksum ^= byte
    packet.append(checksum)                                      # 1 byte
    
    return bytes(packet)  # Total: 18 bytes


# ============================================
# INBOUND PACKET (FPGA → Python): 16 bytes
# ============================================

def decode_trade_decision(response):
    """
    Decode 16-byte trade decision from FPGA
    
    Structure:
    - Byte 0:      Start marker (0xBB)
    - Bytes 1-4:   Ticker (4 ASCII chars)
    - Byte 5:      Action (0=HOLD, 1=BUY, 2=SELL)
    - Bytes 6-7:   Quantity (16-bit shares)
    - Byte 8:      Order type (0=MARKET, 1=LIMIT)
    - Bytes 9-11:  Limit price in cents (24-bit)
    - Bytes 12-15: Timestamp (32-bit Unix time)
    
    Returns dict with trade details or None if invalid
    """
    if len(response) < 16:
        return None
    
    # Check start marker
    if response[0] != 0xBB:
        return None
    
    # Decode fields
    ticker = response[1:5].decode('ascii').strip()
    action = response[5]
    quantity = struct.unpack('>H', response[6:8])[0]
    order_type = response[8]
    limit_price_cents = int.from_bytes(response[9:12], byteorder='big')
    timestamp = struct.unpack('>I', response[12:16])[0]
    
    # Map action codes
    action_map = {0: "HOLD", 1: "BUY", 2: "SELL"}
    order_type_map = {0: "MARKET", 1: "LIMIT"}
    
    return {
        "ticker": ticker,
        "action": action_map.get(action, "UNKNOWN"),
        "quantity": quantity,
        "order_type": order_type_map.get(order_type, "MARKET"),
        "limit_price": limit_price_cents / 100.0,
        "timestamp": timestamp
    }


def format_packet_hex(packet):
    """Format packet as hex string with spaces"""
    return ' '.join(f'{byte:02x}' for byte in packet)


def format_packet_binary(packet):
    """Format packet as binary string with spaces"""
    return ' '.join(format(byte, '08b') for byte in packet)