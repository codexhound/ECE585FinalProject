/*
// ECE 485/585: Microprocessor System Design
// Final Project
// Fall 2018
// File : InstructionCache.v
// Authors : Vinitha Baddam, Michael Bourquin and Hima Ethakota
// Description : This module is for all the instruction cache operations
*/

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
	
	//Instruction cache index, offset, tag and LRU bits  
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

	//These are used to print the cache content
	reg [IC_TagBits-1:0] print_Tag [0:`InstructionCacheWay];
	reg [IC_LRUBits-1:0] print_LRU [0:`InstructionCacheWay];
	reg [1:0] print_MESI [0:`InstructionCacheWay];

	parameter TRUE = 1'b1;
	parameter FALSE = 1'b0;

	integer way, found, replaced, w, s, temp;	
	reg print;
	
	//Execute below on clock positive edge
	always @(posedge clk)
	begin
		//Parsing address to get offset, index and tag bits
		Offset = address[IC_OffsetBits-1:0];
		Index = address[IC_OffsetBits+IC_IndexBits-1:IC_OffsetBits];
		Tag = address[`AddressBits-1:`AddressBits-IC_TagBits];
		
		//Initially found and replaced values will be false
		found=0;
		replaced=0;

		case(command)
		//2 instruction fetch (a read request to L1 instruction cache)
		INSTRUCTION_FETCH:
		begin
			IC_Reads=IC_Reads+1;  //reads counter
			//see if the tag of the fetch address matches any tag in those set lines
			for(way=0;way<`InstructionCacheWay;way=way+1)
			begin			
				InstructionLine=InstructionCache[way][Index];
				MESI_Bits = InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits];
				IC_Tag = InstructionLine[IC_TagBits-1:0];
			
				if((MESI_Bits != Invalid) && (IC_Tag == Tag)) //if valid and tag match
				begin
					IC_Read_Hit=IC_Read_Hit+1;  //read hit counter
					found=1;	//data in cache found!
					
					IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
					InstructionLine[IC_TagBits+IC_LRUBits+MESI_Size-1:IC_TagBits+IC_LRUBits] = Shared;
					InstructionCache[way][Index]=InstructionLine;				
				end			
			end
			// If tag is not found in the cache set from above
			if(found==0)
			begin
				IC_Read_Miss=IC_Read_Miss+1;  //write miss counter
				
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
					IC_LRU = 0;  ////To replace '0'th LRU element
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
					InstructionLine[IC_TagBits-1:0] = 12'bx;
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
					//set all the cache MESI bits to Invalid
					InstructionLine[IC_TagBits + IC_LRUBits + MESI_Size-1 : IC_TagBits + IC_LRUBits] = Invalid;
					//Initially assign LRU bits to each cache line in a set to line number 
					InstructionLine[IC_TagBits + IC_LRUBits-1 : IC_TagBits] = w;
					//set tag bits to x
					InstructionLine[IC_TagBits-1:0] = 12'bx;
					InstructionCache[w][s] = InstructionLine;
				end
			end

			//set all summary paramentes to '0' on reset
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
			$display("  END OF INSTRUCTION CACHE CONTENTS ");
			$display("____________________________________");		
		end
		
		endcase	
	end

	//function to update LRU values of each line in a set based on line reference
	function UpdateInstruction_LRU;
		input [IC_LRUBits-1:0] LRU;
		input [IC_IndexBits-1:0] index;
		
		integer w;

		begin 
			//update the LRU bits of each cache line in a set
			for (w=0; w<`InstructionCacheWay; w=w+1)
			begin
				InstructionLine = InstructionCache[w][index];
				IC_LRU = InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits];
				//if it is a most recently used/refered cache line then set the LRU bits to 111
				if(IC_LRU == LRU)
				begin
					InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits] = `InstructionCacheWay-1;
					InstructionCache[w][index] = InstructionLine;
				end
				//LRU bits higher than the most recently used bits are decremented by 1 
				else if(IC_LRU > LRU)
				begin
					InstructionLine[IC_TagBits+IC_LRUBits-1:IC_TagBits] = IC_LRU-1;
					InstructionCache[w][index] = InstructionLine;
				end
			end
		end
	endfunction

	//function to get MESI ids for a given 2 bit MESI value
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
