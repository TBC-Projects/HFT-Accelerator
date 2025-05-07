module tx_rx(clk, rst,rx,rx_clear,rx_ready,rx_data);
	input logic clk, rst, rx,rx_clear;
	output logic rx_ready;
	output logic rx_data[7:0];
	
	parameter baud_rate = 115200;
	parameter clk_frq_hz = 50000000;
	
	enum {IDLE,START,DATA,STOP,DONE} ps, ns;
	
	always_comb begin
		ns = ps;
		rx_done = 0;
		
		case(ps)
			
			IDLE : 	if(~rx) ns = START;
					else if ((rx & DONE) | ~START) ns = IDLE;
			
		
			START : 	if (~IDLE & ~rx) ns = START;
					else ns = IDLE;
			
			DATA : if (START & ~STOP) ns = DATA;
					else ns = STOP;
				
			
			STOP : if (~DATA) ns = STOP;
			
			DONE : if (STOP) ns = DONE; 
			
		
		
		
		
		
	