/*
 * Simple Testbench for HFT Accelerator
 */

`timescale 1ns / 1ps

module hft_accelerator_tb;

    logic clk;
    logic rst;
    logic uart_rx;
    logic uart_tx;
    
    // Clock generation (50 MHz)
    initial clk = 0;
    always #10 clk = ~clk;  // 10ns = 50MHz
    
    // DUT instantiation
    hft_accelerator #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );
    
    // Helper: Convert price to Q16.16
    function [31:0] price_to_q16(real price);
        return $rtoi(price * 65536.0);
    endfunction
    
    // Helper: Send byte via UART RX
    task send_uart_byte(input [7:0] data);
        integer i;
        integer bit_time;
        begin
            bit_time = 1_000_000_000 / 9600;  // ns per bit
            
            // Start bit
            uart_rx = 0;
            #bit_time;
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #bit_time;
            end
            
            // Stop bit
            uart_rx = 1;
            #bit_time;
        end
    endtask
    
    // Helper: Send price (4 bytes)
    task send_price(input real price);
        logic [31:0] price_q16;
        begin
            price_q16 = price_to_q16(price);
            $display("Sending price: $%.2f (0x%08X)", price, price_q16);
            
            send_uart_byte(price_q16[31:24]);
            send_uart_byte(price_q16[23:16]);
            send_uart_byte(price_q16[15:8]);
            send_uart_byte(price_q16[7:0]);
        end
    endtask
    
    // Test stimulus
    initial begin
        $dumpfile("hft_accelerator.vcd");
        $dumpvars(0, hft_accelerator_tb);
        
        $display("===========================================");
        $display("HFT Accelerator Testbench");
        $display("===========================================\n");
        
        uart_rx = 1;  // Idle
        rst = 1;
        #100;
        rst = 0;
        #1000;
        
        $display("Test 1: Declining prices (should trigger BUY)");
        send_price(150.00);
        #500000;
        send_price(148.50);
        #500000;
        send_price(147.00);
        #500000;
        send_price(145.50);
        #500000;
        send_price(144.00);
        #500000;
        send_price(142.50);
        #500000;
        send_price(141.00);
        #500000;
        send_price(139.50);
        #500000;
        send_price(138.00);
        #500000;
        send_price(136.50);
        #500000;
        send_price(135.00);
        #500000;
        send_price(133.50);
        #500000;
        send_price(132.00);
        #500000;
        send_price(130.50);
        #500000;
        send_price(129.00);  // RSI should be low now
        #500000;
        
        $display("\nTest 2: Rising prices (should trigger SELL)");
        send_price(130.00);
        #500000;
        send_price(132.00);
        #500000;
        send_price(134.00);
        #500000;
        send_price(136.00);
        #500000;
        send_price(138.00);
        #500000;
        send_price(140.00);
        #500000;
        send_price(142.00);
        #500000;
        send_price(144.00);
        #500000;
        send_price(146.00);
        #500000;
        send_price(148.00);
        #500000;
        send_price(150.00);  // RSI should be high now
        #500000;
        
        $display("\n===========================================");
        $display("Test Complete");
        $display("===========================================");
        
        #1000000;
        $finish;
    end
    
    // Monitor UART TX output
    always @(negedge uart_tx) begin
        #100;  // Small delay
        if (!rst) begin
            $display("  UART TX activity detected at time %0t", $time);
        end
    end

endmodule
