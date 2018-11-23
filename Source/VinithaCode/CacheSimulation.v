`define AddressBits 32  //Addressbits

module CACHE_SIMULATION(
	input clk,
	input [3:0] command,
	//input address,
	input [`AddressBits-1:0] address,
	input mode,
	input done
	);
	
	//valid commands from trace file
	parameter READ = 4'd0;
	parameter WRITE = 4'd1;
	parameter INSTRUCTION_FETCH = 4'd2;
	parameter INVALIDATE = 4'd3;
	parameter SNOOP = 4'd4;
	parameter RESET = 4'd8;
	parameter PRINT = 4'd9;
	
	DATA_CACHE d_cache(
		.clk(clk),
		.command(command),
		.address(address),
		.mode(mode)
		);
	
	INSTRUCTION_CACHE i_cache(
		.clk(clk),
		.command(command),
		.address(address),
		.mode(mode)
		);

endmodule