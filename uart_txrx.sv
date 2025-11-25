/*
 * UART Transmitter and Receiver
 * 
 * Baud rate: 9600 (configurable)
 * Data bits: 8
 * Stop bits: 1
 * Parity: None
 */

module uart_txrx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       rst,
    
    // UART physical pins
    input  logic       rx,
    output logic       tx,
    
    // Transmit interface
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx_busy,
    
    // Receive interface
    output logic [7:0] rx_data,
    output logic       rx_ready
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    //===========================================
    // UART Transmitter
    //===========================================
    typedef enum logic [2:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP,
        TX_DONE
    } tx_state_t;
    
    tx_state_t tx_state;
    logic [31:0] tx_clk_count;
    logic [2:0]  tx_bit_index;
    logic [7:0]  tx_data_reg;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_clk_count <= 32'd0;
            tx_bit_index <= 3'd0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    tx_clk_count <= 32'd0;
                    tx_bit_index <= 3'd0;
                    
                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        tx_busy <= 1'b1;
                        tx_state <= TX_START;
                    end
                end
                
                TX_START: begin
                    tx <= 1'b0;  // Start bit
                    
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 32'd0;
                        tx_state <= TX_DATA;
                    end
                end
                
                TX_DATA: begin
                    tx <= tx_data_reg[tx_bit_index];
                    
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 32'd0;
                        
                        if (tx_bit_index < 7) begin
                            tx_bit_index <= tx_bit_index + 1;
                        end else begin
                            tx_bit_index <= 3'd0;
                            tx_state <= TX_STOP;
                        end
                    end
                end
                
                TX_STOP: begin
                    tx <= 1'b1;  // Stop bit
                    
                    if (tx_clk_count < CLKS_PER_BIT - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 32'd0;
                        tx_state <= TX_DONE;
                    end
                end
                
                TX_DONE: begin
                    tx_busy <= 1'b0;
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    //===========================================
    // UART Receiver
    //===========================================
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP,
        RX_DONE
    } rx_state_t;
    
    rx_state_t rx_state;
    logic [31:0] rx_clk_count;
    logic [2:0]  rx_bit_index;
    logic [7:0]  rx_data_reg;
    logic        rx_sync1, rx_sync2;  // For metastability
    
    // Synchronize RX input (avoid metastability)
    always_ff @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_ready <= 1'b0;
            rx_clk_count <= 32'd0;
            rx_bit_index <= 3'd0;
            rx_data <= 8'd0;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    rx_ready <= 1'b0;
                    rx_clk_count <= 32'd0;
                    rx_bit_index <= 3'd0;
                    
                    if (rx_sync2 == 1'b0) begin  // Start bit detected
                        rx_state <= RX_START;
                    end
                end
                
                RX_START: begin
                    // Wait for middle of start bit
                    if (rx_clk_count < (CLKS_PER_BIT / 2) - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        if (rx_sync2 == 1'b0) begin  // Verify start bit
                            rx_clk_count <= 32'd0;
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;  // False start
                        end
                    end
                end
                
                RX_DATA: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 32'd0;
                        rx_data_reg[rx_bit_index] <= rx_sync2;
                        
                        if (rx_bit_index < 7) begin
                            rx_bit_index <= rx_bit_index + 1;
                        end else begin
                            rx_bit_index <= 3'd0;
                            rx_state <= RX_STOP;
                        end
                    end
                end
                
                RX_STOP: begin
                    if (rx_clk_count < CLKS_PER_BIT - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 32'd0;
                        rx_data <= rx_data_reg;
                        rx_ready <= 1'b1;
                        rx_state <= RX_DONE;
                    end
                end
                
                RX_DONE: begin
                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end

endmodule
