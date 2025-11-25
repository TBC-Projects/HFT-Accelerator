module project(clk,ticker,rst,ask,bid,buyOutput);
input logic [63:0] data_frame
logic [4:0] ticker 
logic [27:0] ask
logic [27:0] bid
output logic buyOutput;
input clk; 
input logic rst;


assign ticker = data_frame [4:0];
assign ask = data_frame [32:5];
assign bid = data_frame [62:33];
assign buyOutput = data_frame[63];

always_ff @(posedge clk) begin
    if (rst) begin
        buyOutput <= 0;
    else 
        buyOutput <= (ask > bid);
end
