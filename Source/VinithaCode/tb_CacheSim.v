`define AddressBits 32  //Addressbits

//+TRACE=latest.txt +MODE=0

module tb_CacheSim();
	
	parameter CLOCK_CYCLE = 20;
	parameter CLOCK_WIDTH = CLOCK_CYCLE/2;
	parameter TRUE = 1'b1;
	parameter FALSE = 1'b0;
	parameter RESET = 4'd8;
	
	reg clk; //clock
	integer fptr; // the file handle
	reg done;  // trace fle processing status
	reg [3:0] command; // command n from trace file
	reg [`AddressBits-1:0] address; // address from trace file
	reg  [8*100:0] filename; //string trace file name
	reg mode; //output  mode
	integer result; 

	CACHE_SIMULATION cache_sim(
		.clk(clk),
		.command(command),
		.address(address),
		.mode(mode),
		.done(done)
		);
		
	initial
	begin
		clk = FALSE;
		done = FALSE;

		// Check to make sure that a TRACE file was provided
		if($value$plusargs("TRACE=%s", filename) == FALSE)
		begin
			$display("Please enter a valid trace file name on plusargs");
			$finish;
		end
		
		// If it was , open the file
		fptr = $fopen(filename , "r");	
		
		if($value$plusargs("MODE=%d",  mode) == FALSE)
		begin        
			$display("Please enter a valid mode on plusargs!");        
			$finish;
		end
		
		// simulate initial reset
		#CLOCK_WIDTH clk = FALSE;
		command = RESET; //for reset
		address = 32'b0;
		#CLOCK_WIDTH clk = TRUE;
		
		// While there are lines left to be read :
		while(!$feof(fptr))
		begin
			// Parse the line
			#CLOCK_WIDTH clk = FALSE;
			result = $fscanf(fptr,"%d", command);

			if(command != 8 && command != 9)
			begin
				result = $fscanf(fptr,"%h", address);
			end
			#CLOCK_WIDTH clk = TRUE;
		end

		// Close the file , and finish up
		$fclose(fptr);
		
		#CLOCK_WIDTH clk = FALSE;
		done = TRUE;
		#CLOCK_WIDTH clk = TRUE;
		$stop;
	end
endmodule