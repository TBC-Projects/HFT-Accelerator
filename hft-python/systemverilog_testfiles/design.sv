`timescale 1ns/1ps

module packet_receiver (
    input  logic clk,
    input  logic rst,
    input  logic [7:0] rx_byte,
    input  logic rx_valid
);
    // ========================================
    // DEBUG FLAG - Set to 1 to see breakdown
    // ========================================
    parameter SHOW_BREAKDOWN = 1;
    
    // ========================================
    // Decoded packet fields
    // NOTE: These update on the NEXT clock cycle after packet received
    // If you need them immediately, use the raw packet[] array
    // ========================================
    logic [31:0] ticker;
    logic [31:0] timestamp;
    logic [23:0] ask_cents;
    logic [23:0] bid_cents;
    logic signed [15:0] position;
    logic packet_ready = 0;  // Pulses when new packet decoded
    
    // Packet reception
    logic [7:0] packet [0:17];
    logic [4:0] count = 0;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
            packet_ready <= 0;
        end else begin
            packet_ready <= 0;
            
            if (rx_valid) begin
                packet[count] <= rx_byte;
                
                if (count == 17) begin
                    // Decode into registers
                    ticker <= {packet[1], packet[2], packet[3], packet[4]};
                    timestamp <= {packet[5], packet[6], packet[7], packet[8]};
                    ask_cents <= {packet[9], packet[10], packet[11]};
                    bid_cents <= {packet[12], packet[13], packet[14]};
                    position <= {packet[15], rx_byte};
                    packet_ready <= 1;
                    
                    // Display breakdown if flag enabled
                    if (SHOW_BREAKDOWN) begin
                        $display("\n--- Packet Breakdown ---");
                        $display("Ticker:    %c%c%c%c", 
                                 packet[1], packet[2], packet[3], packet[4]);
                        $display("Timestamp: %0d", {packet[5], packet[6], packet[7], packet[8]});
                        $display("Ask:       $%0.2f", {packet[9], packet[10], packet[11]} / 100.0);
                        $display("Bid:       $%0.2f", {packet[12], packet[13], packet[14]} / 100.0);
                        $display("Position:  %0d shares", $signed({packet[15], rx_byte}));
                        $display("------------------------\n");
                    end
                    
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
        end
    end
    
    // ========================================
    // YOUR TRADING ALGORITHM GOES HERE
    // ========================================
    
    // Use packet_ready to know when new data arrived
    // Use ask_cents, bid_cents, position (they're valid when packet_ready = 1)
    
    // Example: Simple print says "i can see the ask price is x"
    always_ff @(posedge clk) begin
        if (packet_ready) begin
          // $display("I can see that ask price is = $%0.2f", ask_cents / 100.0);
        end
    end

endmodule