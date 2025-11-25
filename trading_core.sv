/*
 * Simplified HFT Trading Core - RSI Mean Reversion
 * 
 * Strategy: Buy when RSI < 30, Sell when RSI > 70
 * Uses Q16.16 fixed-point arithmetic for speed
 */

module trading_core #(
    parameter RSI_PERIOD = 14
)(
    input  logic        clk,
    input  logic        rst,
    
    // Price input (Q16.16 format: $150.50 = 0x00960800)
    input  logic [31:0] price_in,
    input  logic        price_valid,
    
    // Trading decision output
    output logic [1:0]  action,        // 00=HOLD, 01=BUY, 10=SELL
    output logic        action_valid,
    output logic [15:0] rsi_value      // Current RSI (0-10000 = 0.00-100.00)
);

    // Price history buffer (circular)
    logic [31:0] prices [0:15];  // Store last 16 prices
    logic [3:0]  write_ptr;
    logic [4:0]  num_samples;    // Count of valid samples
    
    // RSI calculation
    logic [31:0] gains_sum;
    logic [31:0] losses_sum;
    logic [31:0] avg_gain;
    logic [31:0] avg_loss;
    logic [15:0] rsi;
    
    // Position tracking
    logic        holding;
    logic [31:0] entry_price;
    
    // State machine
    typedef enum logic [2:0] {
        IDLE,
        CALC_RSI,
        DECIDE,
        OUTPUT
    } state_t;
    
    state_t state;
    logic [3:0] calc_step;

    // Actions
    localparam HOLD = 2'b00;
    localparam BUY  = 2'b01;
    localparam SELL = 2'b10;

    //===========================================
    // Main State Machine
    //===========================================
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            write_ptr <= 4'd0;
            num_samples <= 5'd0;
            holding <= 1'b0;
            action <= HOLD;
            action_valid <= 1'b0;
            rsi <= 16'd5000;  // 50.00
            calc_step <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    action_valid <= 1'b0;
                    if (price_valid) begin
                        // Store new price
                        prices[write_ptr] <= price_in;
                        write_ptr <= write_ptr + 4'd1;
                        if (num_samples < 5'd16)
                            num_samples <= num_samples + 5'd1;
                        
                        // Start calculation if we have enough data
                        if (num_samples >= RSI_PERIOD) begin
                            state <= CALC_RSI;
                            calc_step <= 4'd0;
                            gains_sum <= 32'd0;
                            losses_sum <= 32'd0;
                        end
                    end
                end
                
                CALC_RSI: begin
                    // Calculate gains and losses over last 14 samples
                    if (calc_step < RSI_PERIOD - 1) begin
                        logic [3:0] idx_curr, idx_prev;
                        logic signed [31:0] change;
                        
                        idx_curr = write_ptr - calc_step - 4'd1;
                        idx_prev = write_ptr - calc_step - 4'd2;
                        
                        change = $signed(prices[idx_curr]) - $signed(prices[idx_prev]);
                        
                        if (change > 0)
                            gains_sum <= gains_sum + change;
                        else if (change < 0)
                            losses_sum <= losses_sum + (-change);
                        
                        calc_step <= calc_step + 4'd1;
                    end else begin
                        // Calculate averages (divide by 14 ≈ shift by 4)
                        avg_gain <= gains_sum >> 4;
                        avg_loss <= losses_sum >> 4;
                        state <= DECIDE;
                    end
                end
                
                DECIDE: begin
                    // Calculate RSI
                    if (avg_loss == 32'd0) begin
                        rsi <= 16'd10000;  // 100.00
                    end else if (avg_gain == 32'd0) begin
                        rsi <= 16'd0;
                    end else begin
                        logic [47:0] num, den;
                        logic [31:0] ratio;
                        
                        num = avg_gain << 16;
                        den = avg_gain + avg_loss;
                        ratio = num / den;
                        rsi <= (ratio * 100) >> 16;
                    end
                    
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Trading decision
                    if (!holding && rsi < 16'd3000) begin  // RSI < 30
                        action <= BUY;
                        holding <= 1'b1;
                        entry_price <= prices[write_ptr - 4'd1];
                    end else if (holding && rsi > 16'd7000) begin  // RSI > 70
                        action <= SELL;
                        holding <= 1'b0;
                    end else begin
                        action <= HOLD;
                    end
                    
                    action_valid <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
    
    assign rsi_value = rsi;

endmodule
