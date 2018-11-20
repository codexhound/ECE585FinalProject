
module STATISTICS(
	input done,
	input [31:0] DC_Read_Hit,
	input [31:0] DC_Read_Miss,
	input [31:0] DC_Reads,
	input [31:0] DC_Write_Hit,
	input [31:0] DC_Write_Miss,
	input [31:0] DC_Writes,
	input [31:0] IC_Read_Hit,
	input [31:0] IC_Read_Miss,
	input [31:0] IC_Reads
	);
	
	always @(posedge done)
	begin
		$display("Data Cache Usage Statistics:");
		$display("Number of cache reads		: %d", DC_Reads);
		$display("Number of cache writes	: %d", DC_Writes);
		$display("Number of cache hits		: %d", DC_Read_Hit + DC_Write_Hit);
		$display("Number of cache misses	: %d", DC_Read_Miss + DC_Write_Miss);
		$display("Cache	hit ratio		: %.2f%% \n", (DC_Reads + DC_Writes) != 0 ? 100.00 * (DC_Read_Hit + DC_Write_Hit)/(DC_Reads + DC_Writes) : 0);
		
		$display("Instruction Cache Usage Statistics:");
		$display("Number of cache reads		: %d", IC_Reads);
		$display("Number of cache hits		: %d", IC_Read_Hit);
		$display("Number of cache misses	: %d", IC_Read_Miss);
		$display("Cache	hit ratio		: %.2f%% \n", IC_Reads != 0 ? 100.00*(IC_Read_Hit)/(IC_Reads) : 0);
	end
	
endmodule