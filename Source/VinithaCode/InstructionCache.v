`define InstructionCacheWay 4  //InstructionCacheWay
`define InstructionCacheSet 16*1024  //InstructionCacheset
`define CacheLineSize 64  //linelength
`define AddressBits 32  //AddressBits

module INSTRUCTION_CACHE(
	input clk,
	input [3:0] command,
	input [`AddressBits-1:0] address,
	input mode,
	output reg [31:0] IC_Read_Hit = 32'b0,
	output reg [31:0] IC_Read_Miss = 32'b0,
	output reg [31:0] IC_Reads = 32'b0
	);

	
	
	//MESI protocal
	parameter 
		Invalid = 2'b00,
		Exclusive = 2'b01,  
		Shared = 2'b10,
		Modified = 2'b11;

	//valid commands from trace file
	parameter 
		//READ = 4'd0,
		//WRITE = 4'd1,
		INSTRUCTION_FETCH = 4'd2,
		INVALIDATE = 4'd3,
		//SNOOP = 4'd4,
		RESET = 4'd8,
		PRINT = 4'd9;
	  
	parameter   
		IC_IndexBits = $clog2(`InstructionCacheSet),
		IC_OffsetBits = $clog2(`CacheLineSize),
		IC_TagBits = `AddressBits -(IC_OffsetBits+IC_IndexBits),
		IC_LRUBits = $clog2(`InstructionCacheWay),
		MESI_Size = 2;	

	reg [IC_TagBits + IC_LRUBits + MESI_Size-1:0] InstructionCache[0:`InstructionCacheWay-1][0:`InstructionCacheSet-1]; //InstructionCache
	reg [IC_TagBits + IC_LRUBits + MESI_Size-1:0] InstructionLine; //Cache Instruction Line

	reg [1:0] MESI_Bits;	
	reg [IC_OffsetBits-1:0] Offset;
	reg [IC_IndexBits-1:0] Index;
	reg [IC_TagBits-1:0] Tag;

	//for instruction cache
	reg [IC_OffsetBits-1:0] IC_Offset;
	reg [IC_IndexBits-1:0] IC_Index;
	reg [IC_TagBits-1:0] IC_Tag;
	reg [IC_LRUBits-1:0] IC_LRU;

	reg [IC_TagBits-1:0] print_Tag [0:`InstructionCacheWay];
	reg [IC_LRUBits-1:0] print_LRU [0:`InstructionCacheWay];
	reg [1:0] print_MESI [0:`InstructionCacheWay];

	parameter TRUE = 1'b1;
	parameter FALSE = 1'b0;

	integer way, found, replaced, w, s, temp;	
	reg print;

	always @(posedge clk)
	begin
	
		Offset = address[IC_OffsetBits-1:0];
		Index = address[IC_OffsetBits+IC_IndexBits-1:IC_OffsetBits];
		Tag = address[`AddressBits-1:`AddressBits-IC_TagBits];
		
		//$display("command %d address %h Index %h, Tag %h", command, address, Index, Tag);
		found=0;
		replaced=0;

		case(command)
		//2 instruction fetch (a read request to L1 instruction cache)
		INSTRUCTION_FETCH:
		begin
			IC_Reads=IC_Reads+1;
			
			for(way=0;way<`InstructionCacheWay;way=way+1)
			begin			
				InstructionLine=InstructionCache[way][Index];
				MESI_Bits = InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
				IC_Tag = InstructionLine[IC_TagBits-1:0];
			
				if((MESI_Bits != Invalid) && (IC_Tag == Tag)) //if valid and tag match
				begin
					IC_Read_Hit=IC_Read_Hit+1;
					found=1;	//data in cache found!
					
					IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
					InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits] = Shared;
					InstructionCache[way][Index]=InstructionLine;				
				end			
			end
			
			if(found==0)
			begin
				IC_Read_Miss=IC_Read_Miss+1;
				
				if(mode == 1)
					$display("Read from L2 %h", address); //add lru and write

				//find an invalid way in set and put tag bits and set lru 111 and decreament lru for other ways by 1
				
				for(way=0;way<`InstructionCacheWay;way=way+1)
				begin
					InstructionLine=InstructionCache[way][Index];
					MESI_Bits=InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
					
					if ((MESI_Bits == Invalid) && (found!=1))
					begin
						found=1; // invalid way found
						
						IC_LRU=InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
						InstructionLine[IC_TagBits-1:0] = Tag;
						InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits] = Exclusive;
						InstructionCache[way][Index] = InstructionLine;
					end
				end	

				// if no invalid way, look for LRU=000 and check mesi bits
				if(found!=1)
				begin
					for(way=0;way<`InstructionCacheWay;way=way+1)
					begin
						InstructionLine=InstructionCache[way][Index];
						MESI_Bits=InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
						IC_LRU=InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
					
						if (IC_LRU == 0 && replaced == 0)
						begin
							replaced = 1;
						// if mesi bit modified write to L2 and replace,ie, put tag bits there 
							if(MESI_Bits == Modified)
							begin
								Offset = 0;
								if(mode == 1)
									$display("Write to L2 %h", {InstructionLine[IC_TagBits-1:0], Index, Offset});
							end
							
							IC_LRU=InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
							InstructionLine[IC_TagBits-1:0] = Tag;
							InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits] = Exclusive;
							InstructionCache[way][Index] = InstructionLine;
						end
					end
					IC_LRU = 0;
				end
			end
							
			temp = UpdateInstruction_LRU(IC_LRU, Index);	// update lru
		end

		//3 invalidate command from L2
		INVALIDATE:
		begin
		// look up for line by going to set n comparing tags in ways
			for(way=0;way<`InstructionCacheWay;way=way+1)
			begin				
				InstructionLine = InstructionCache[way][Index];
				MESI_Bits = InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
				IC_Tag = InstructionLine[IC_TagBits-1:0];
				//$display("mesi %b tag %h", MESI_Bits, tagbits);
				if(Tag == IC_Tag) //if tag match
				begin
					MESI_Bits = Invalid; //if line found then set MESI_Bits as invalid
					IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
					InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits] = MESI_Bits;
					InstructionCache[way][Index] = InstructionLine;
				end
			end

			temp = UpdateInstruction_LRU(IC_LRU, Index);	// update lru
		end
		
		//8 clear the cache and reset all state (and statistics)
		RESET:
		begin
			for (s=0; s<`InstructionCacheSet; s=s+1)
			begin	
				for (w=0; w<`InstructionCacheWay; w=w+1)
				begin
					InstructionLine=InstructionCache[w][s];
					InstructionLine[IC_TagBits + IC_LRUBits + MESI_Size-1 : IC_TagBits + IC_LRUBits] = Invalid;
					InstructionLine[IC_TagBits + IC_LRUBits-1 : IC_TagBits] = w;
					InstructionCache[w][s] = InstructionLine;
				end
			end

			IC_Read_Hit = 32'b0;
			IC_Read_Miss = 32'b0;
			IC_Reads = 32'b0;
		end

		//9 print contents and state of the cache (allow subsequent trace activity)
		PRINT:
		begin
			$display("____________________________________");	
			$display("                                    ");			
			$display("    INSTRUCTION CACHE CONTENTS      ");
			$display("____________________________________");
			
			for (s=0;s<`InstructionCacheSet;s=s+1)
			begin
				print = FALSE;
				for (w=0;w<`InstructionCacheWay;w=w+1)
				begin
					InstructionLine = InstructionCache[w][s];
					MESI_Bits = InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
					IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
					IC_Tag = InstructionLine[IC_TagBits-1:0];
	
					if(print == TRUE || MESI_Bits != Invalid || IC_Tag != "x")
					begin
						if(print == FALSE)
						begin
							print = TRUE;
							w = -1;
						end
						else
						begin
							print_MESI[w] = MESI_Bits;
							print_LRU[w] = IC_LRU;
							print_Tag[w] = IC_Tag;
						end	

					end
				end
				if(print == TRUE)
				begin
					$display("Set Index : %h", s);	
					$display("Way:	 1	 2	 3	 4");
					$display("Tag:	%h	%h	%h	%h", print_Tag[0], print_Tag[1], print_Tag[2], print_Tag[3]);
					$display("LRU:	%b	%b	%b	%b", print_LRU[0], print_LRU[1], print_LRU[2], print_LRU[3]);
					$display("MESI:	%s	%s	%s	%s", Get_MESI_ID(print_MESI[0]), Get_MESI_ID(print_MESI[1]), Get_MESI_ID(print_MESI[2]), Get_MESI_ID(print_MESI[3]));
					$display("        ** END OF SET **          ");
					$display("------------------------------------");
				end
			end
			$display("Instruction Cache Usage Statistics:");
			$display("Number of cache reads		: %d", IC_Reads);
			$display("Number of cache hits		: %d", IC_Read_Hit);
			$display("Number of cache misses	: %d", IC_Read_Miss);
			$display("Cache	hit ratio		: %.2f%% \n", IC_Reads != 0 ? 100.00*(IC_Read_Hit)/(IC_Reads) : 0);
			$display("  END OF INSTRUCTION CACHE CONTENTS ");
			$display("____________________________________");		
		end
		
		endcase	
	end

	function UpdateInstruction_LRU;
		input [IC_LRUBits-1:0] LRU;
		input [IC_IndexBits-1:0] index;
		
		integer w;

		begin 
			for (w=0; w<`InstructionCacheWay; w=w+1)
			begin
				InstructionLine = InstructionCache[w][index];
				IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
				if(IC_LRU == LRU)
				begin
					InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits] = `InstructionCacheWay-1;
					InstructionCache[w][index] = InstructionLine;
				end
				else if(IC_LRU > LRU)
				begin
					InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits] = IC_LRU-1;
					InstructionCache[w][index] = InstructionLine;
				end
			end
		end
	endfunction

	function [8:0] Get_MESI_ID;
		input [1:0] MESI;
		
		begin
			case(MESI)
			2'b00: Get_MESI_ID = "I";
			2'b01: Get_MESI_ID = "E";
			2'b10: Get_MESI_ID = "S";
			2'b11: Get_MESI_ID = "M";
			endcase
		end
	endfunction 

endmodule
