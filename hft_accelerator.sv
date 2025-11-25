/*
 * HFT Accelerator Top Module
 * 
 * Integrates UART communication with trading core
 * Receives price data via UART, makes trading decisions, sends back via UART
 */

module hft_accelerator #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic clk,
    input  logic rst,
    input  logic uart_rx,
    output logic uart_tx
);

    // UART signals
    logic [7:0] rx_data;
    logic       rx_ready;
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_busy;
    
    // Price reception state machine
    typedef enum logic [2:0] {
        WAIT_PRICE,
        RCV_BYTE0,
        RCV_BYTE1,
        RCV_BYTE2,
        RCV_BYTE3,
        PROCESS
    } rx_state_t;
    
    rx_state_t rx_state;
    logic [31:0] price_buffer;
    logic [1:0]  byte_count;
    
    // Trading signals
    logic [31:0] current_price;
    logic        price_valid;
    logic [1:0]  action;
    logic        action_valid;
    logic [15:0] rsi_value;
    
    // Response transmission state
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_ACTION,
        TX_RSI_LOW,
        TX_RSI_HIGH
    } tx_state_t;
    
    tx_state_t tx_state;

    //===========================================
    // UART Module
    //===========================================
    uart_txrx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .tx(uart_tx),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );

    //===========================================
    // Trading Core
    //===========================================
    trading_core trading (
        .clk(clk),
        .rst(rst),
        .price_in(current_price),
        .price_valid(price_valid),
        .action(action),
        .action_valid(action_valid),
        .rsi_value(rsi_value)
    );

    //===========================================
    // Price Reception State Machine
    //===========================================
    always_ff @(posedge clk) begin
        if (rst) begin
            rx_state <= WAIT_PRICE;
            byte_count <= 2'd0;
            price_valid <= 1'b0;
            current_price <= 32'd0;
        end else begin
            price_valid <= 1'b0;  // Pulse
            
            case (rx_state)
                WAIT_PRICE: begin
                    if (rx_ready) begin
                        price_buffer[31:24] <= rx_data;
                        rx_state <= RCV_BYTE1;
                    end
                end
                
                RCV_BYTE1: begin
                    if (rx_ready) begin
                        price_buffer[23:16] <= rx_data;
                        rx_state <= RCV_BYTE2;
                    end
                end
                
                RCV_BYTE2: begin
                    if (rx_ready) begin
                        price_buffer[15:8] <= rx_data;
                        rx_state <= RCV_BYTE3;
                    end
                end
                
                RCV_BYTE3: begin
                    if (rx_ready) begin
                        price_buffer[7:0] <= rx_data;
                        rx_state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    current_price <= price_buffer;
                    price_valid <= 1'b1;
                    rx_state <= WAIT_PRICE;
                end
            endcase
        end
    end

    //===========================================
    // Response Transmission State Machine
    //===========================================
    always_ff @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
        end else begin
            tx_start <= 1'b0;  // Default
            
            case (tx_state)
                TX_IDLE: begin
                    if (action_valid) begin
                        tx_data <= {6'd0, action};  // Send action (HOLD/BUY/SELL)
                        tx_start <= 1'b1;
                        tx_state <= TX_ACTION;
                    end
                end
                
                TX_ACTION: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= rsi_value[7:0];  // RSI low byte
                        tx_start <= 1'b1;
                        tx_state <= TX_RSI_LOW;
                    end
                end
                
                TX_RSI_LOW: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= rsi_value[15:8];  // RSI high byte
                        tx_start <= 1'b1;
                        tx_state <= TX_RSI_HIGH;
                    end
                end
                
                TX_RSI_HIGH: begin
                    if (!tx_busy && !tx_start) begin
                        tx_state <= TX_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
