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
		
	//signals for statistics
	wire [31:0]
		d_read_hit,
		d_read_miss,
		d_reads,
		d_write_hit,
		d_write_miss,
		d_writes,
		i_hit,	
		i_miss,
		i_reads;
	
	DATA_CACHE d_cache(
		.clk(clk),
		.command(command),
		.address(address),
		.mode(mode),
		.DC_Read_Hit(d_read_hit),
		.DC_Read_Miss(d_read_miss),
		.DC_Reads(d_reads),
		.DC_Write_Hit(d_write_hit),
		.DC_Write_Miss(d_write_miss),
		.DC_Writes(d_writes)
		);
	
	INSTRUCTION_CACHE i_cache(
		.clk(clk),
		.command(command),
		.address(address),
		.mode(mode),
		.IC_Read_Hit(i_hit),
		.IC_Read_Miss(i_miss),
		.IC_Reads(i_reads)
		);
		
	STATISTICS stats(
		.done(done),
		.DC_Read_Hit(d_read_hit),
		.DC_Read_Miss(d_read_miss),
		.DC_Reads(d_reads),
		.DC_Write_Hit(d_write_hit),
		.DC_Write_Miss(d_write_miss),
		.DC_Writes(d_writes),
		.IC_Read_Hit(i_hit),
		.IC_Read_Miss(i_miss),
		.IC_Reads(i_reads)
		);

endmodule