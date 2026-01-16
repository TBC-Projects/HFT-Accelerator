`timescale 1ns/1ps

module testbench;
    logic clk = 0;
    logic rst = 1;
    logic [7:0] rx_byte;
    logic rx_valid = 0;
    
    packet_receiver fpga (.clk(clk), .rst(rst), .rx_byte(rx_byte), .rx_valid(rx_valid));
    
    always #10 clk = ~clk;  // 50 MHz
    
    task send_packet(input [143:0] pkt);
        integer i;
        begin
            $display("Sent packet %h to FPGA", pkt);
            for (i = 0; i < 18; i = i + 1) begin
                @(negedge clk);
                rx_byte = pkt[(17-i)*8 +: 8];
                rx_valid = 1;
                @(negedge clk);
                rx_valid = 0;
            end
        end
    endtask
    
    initial begin
        #100 rst = 0;
        #5_000_000; 
        
        send_packet(144'haa4141504c696871ba006b69006a400000fe);
        #5_000_000;

        send_packet(144'haa4141504c696871bb006b69006a400000ff);
        #5_000_000;

        send_packet(144'haa4141504c696871bd006b69006a400000f9);
        #5_000_000;

        send_packet(144'haa4141504c696871be006b69006a400000fa);
        #5_000_000;

        send_packet(144'haa4141504c696871c0006b69006a40000084);
        #5_000_000;

        send_packet(144'haa4141504c696871c1006b69006a40000085);
        #5_000_000;

        send_packet(144'haa4141504c696871c3006b69006a40000087);
        #5_000_000;

        send_packet(144'haa4141504c696871c5006b69006a40000081);
        #5_000_000;

        send_packet(144'haa4141504c696871c6006b69006a40000082);
        #5_000_000;

        send_packet(144'haa4141504c696871c8006b69006a4000008c);
        #5_000_000;

        send_packet(144'haa4141504c696871c9006b69006a4000008d);
        #5_000_000;

        send_packet(144'haa4141504c696871cb006b69006a4000008f);
        #5_000_000;

        send_packet(144'haa4141504c696871cc006b69006a40000088);
        #5_000_000;

        send_packet(144'haa4141504c696871ce006b69006a4000008a);
        #5_000_000;

        send_packet(144'haa4141504c696871d0006b69006a40000094);
        #5_000_000;

        send_packet(144'haa4141504c696871d1006b69006a40000095);
        #5_000_000;

        send_packet(144'haa4141504c696871d3006b69006a40000097);
        #5_000_000;

        send_packet(144'haa4141504c696871d4006b69006a40000090);
        #5_000_000;
        $finish;
    end
endmodule
