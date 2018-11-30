/*
// ECE 485/585: Microprocessor System Design
// Final Project
// Fall 2018
// File : DataCache.v
// Authors : Vinitha Baddam, Michael Bourquin and Hima Ethakota
// Description : This module is for all the data cache operations
*/

`define DataCacheWay 8  //DataCacheway
`define DataCacheSet 16*1024  //DataCacheset
`define CacheLineSize 64  //linelength
`define AddressBits 32  //AddressBits

module DATA_CACHE(
	input clk,
	input [3:0] command,
	input [`AddressBits-1:0] address,
	input mode,
	output reg [31:0] DC_Read_Hit = 32'b0,
	output reg [31:0] DC_Read_Miss = 32'b0,
	output reg [31:0] DC_Reads = 32'b0,
	output reg [31:0] DC_Write_Hit = 32'b0,
	output reg [31:0] DC_Write_Miss = 32'b0,
	output reg [31:0] DC_Writes = 32'b0
	);
	
	//MESI protocal
	parameter 
		Invalid = 2'b00,
		Exclusive = 2'b01,  
		Shared = 2'b10,
		Modified = 2'b11;

	//valid commands from trace file
	parameter 
		READ = 4'd0,
		WRITE = 4'd1,
		//INSTRUCTION_FETCH = 4'd2,
		INVALIDATE = 4'd3,
		SNOOP = 4'd4,
		RESET = 4'd8,
		PRINT = 4'd9;
	  
	//Data cache index, offset, tag and LRU bits
	parameter 
		DC_IndexBits = $clog2(`DataCacheSet),
		DC_OffsetBits = $clog2(`CacheLineSize),
		DC_TagBits = `AddressBits -(DC_OffsetBits+DC_IndexBits),
		DC_LRUBits = $clog2(`DataCacheWay),  
		MESI_Size = 2;	
	
	reg [DC_TagBits + DC_LRUBits + MESI_Size-1:0] DataCache[0:`DataCacheWay-1][0:`DataCacheSet-1]; //Data Cache	
	reg [DC_TagBits + DC_LRUBits + MESI_Size-1:0] DataLine; //Cache Data Line
	
	reg [1:0] MESI_Bits;	
	reg [DC_OffsetBits-1:0] Offset;
	reg [DC_IndexBits-1:0] Index;
	reg [DC_TagBits-1:0] Tag;

	//for data cache
	reg [DC_OffsetBits-1:0] DC_Offset;
	reg [DC_IndexBits-1:0] DC_Index;
	reg [DC_TagBits-1:0] DC_Tag;
	reg [DC_LRUBits-1:0] DC_LRU;

	//These are used to print the cache content
	reg [DC_TagBits-1:0] print_Tag [0:`DataCacheWay];
	reg [DC_LRUBits-1:0] print_LRU [0:`DataCacheWay];
	reg [1:0] print_MESI [0:`DataCacheWay];

	parameter TRUE = 1'b1;
	parameter FALSE = 1'b0;

	integer way, found, replaced, w, s, temp;	
	reg print;

	//Execute below on clock positive edge
	always @(posedge clk)
	begin
		//Parsing address to get offset, index and tag bits
		Offset = address[DC_OffsetBits-1:0];
		Index = address[DC_OffsetBits+DC_IndexBits-1:DC_OffsetBits];
		Tag = address[`AddressBits-1:`AddressBits-DC_TagBits];
		
		//Initially found and replaced values will be false
		found=0;
		replaced=0;

		case(command)
		//0 read data request to L1 data cache
		READ:
		begin
			DC_Reads=DC_Reads+1; //reads counter
			
			//see if the tag of the read address matches any tag in those set lines
			for(way=0;way<`DataCacheWay;way=way+1)
			begin		
				DataLine = DataCache[way][Index];
				MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];		
				DC_Tag = DataLine[DC_TagBits-1:0];

				if((MESI_Bits != Invalid) && (DC_Tag == Tag)) //if valid and tag match
				begin
					DC_Read_Hit=DC_Read_Hit+1;  //read hit counter
					DC_LRU=DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
					
					found=1;	//data in cache found!

					if (MESI_Bits == Exclusive) 
					begin
						MESI_Bits = Shared;  //change the MESI bits to Shared if it was Exclusive
					end

					DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = MESI_Bits;
					DataCache[way][Index] = DataLine;	
				end
			end
			// If tag is not found in the cache set from above
			if(found==0) 
			begin
				DC_Read_Miss=DC_Read_Miss+1;  //read miss counter
				
				if(mode == 1)
					$display("Read from L2 %h", address); //add lru and write

				//find an invalid way in set and put tag bits and set lru 111 and decreament lru for other ways by 1
				for(way=0;way<`DataCacheWay;way=way+1)
				begin
					DataLine = DataCache[way][Index];
					MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];		
					//DC_Tag = DataLine[DC_TagBits-1:0];
			
					if ((MESI_Bits == Invalid) && (found!=1))
					begin
						found=1; // invalid way found
						
						DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
						DataLine[DC_TagBits-1:0] = Tag;
						DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = Exclusive;
						DataCache[way][Index] = DataLine;
					end
				end	
				// if no invalid way, look for LRU=000 and check mesi bits
				if(found!=1)
				begin
					//$display("no invalid way found!");
					for(way=0;way<`DataCacheWay;way=way+1)
					begin
						DataLine = DataCache[way][Index];
						MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];		
						DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
						
						if (DC_LRU == 0 && replaced == 0)
						begin
							replaced = 1;
							// if mesi bit modified write to L2 and replace,ie, put tag bits there 
							if(MESI_Bits == Modified)
							begin
								Offset = 0;
								if(mode == 1)
									$display("Write to L2 %h", {DataLine[DC_TagBits-1:0], Index, Offset});
							end
							
							DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
							DataLine[DC_TagBits-1:0] = Tag;
							DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = Exclusive;
							DataCache[way][Index] = DataLine;
						end
					end
					DC_LRU = 0; //To replace '0'th LRU element
				end			
			end
		
			temp = UpdateData_LRU(DC_LRU, Index);	
		end

		//1 write data request to L1 data cache
		WRITE:
		begin
			DC_Writes=DC_Writes+1;  //writes counter
			//see if the tag of the write address matches any tag in those set lines
			for(way=0;way<`DataCacheWay;way=way+1)
			begin
				DataLine = DataCache[way][Index];
				MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
				DC_Tag = DataLine[DC_TagBits-1:0];
				
				if((MESI_Bits != Invalid) && (DC_Tag == Tag)) //if valid and tag match
				begin
					DC_Write_Hit=DC_Write_Hit+1;  //write hit counter
					DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
					
					found=1;	// cache line to be written found!

					if(MESI_Bits == Shared) 
					begin
						if(mode == 1)
							$display("Write	to L2 %h", address);
						MESI_Bits = Exclusive;
					end
					else if (MESI_Bits == Exclusive) 
					begin
						MESI_Bits = Modified;
					end
					else if (MESI_Bits == Modified) 
					begin
						MESI_Bits = Modified;
					end
					DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = MESI_Bits;
					DataCache[way][Index] = DataLine;			
				end			
			end
			// If tag is not found in the cache set from above
			if(found==0)
			begin
				DC_Write_Miss=DC_Write_Miss+1;  //write miss counter
				
				if(mode == 1)
					$display("Read for Ownership from L2 %h", address); //add lru and write

				//find an invalid way in set and put tag bits and set lru 111 and decreament lru for other ways by 1
				for(way=0;way<`DataCacheWay;way=way+1)
				begin
					DataLine=DataCache[way][Index];
					MESI_Bits=DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
			
					if((MESI_Bits == Invalid) && (found!=1))
					begin
						found=1; // invalid way found
						
						DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
						DataLine[DC_TagBits-1:0] = Tag;
						DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = Exclusive;
						DataCache[way][Index] = DataLine;
						// <write data to this line>
						//first write is write through
						if(mode == 1)
							$display("Write	to L2 %h ",address);
					end
				end	
				// if no invalid way, look for LRU=000 and check mesi bits
				if(found!=1)
				begin
					for(way=0;way<`DataCacheWay;way=way+1)
					begin
						DataLine = DataCache[way][Index];
						MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
						DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];

						if (DC_LRU == 0 && replaced == 0)
						begin
							replaced = 1;
							// if mesi bit modified write to L2 and replace,ie, put tag bits there 
							if(MESI_Bits == Modified)
							begin
								Offset = 0;
								if(mode == 1)
									$display("Write to L2 %h", {DataLine[DC_TagBits-1:0], Index, Offset});
							end
							
							DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
							DataLine[DC_TagBits-1:0] = Tag;
							DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = Modified;
							DataCache[way][Index] = DataLine;		
						end
					end
					DC_LRU = 0; //To replace '0'th LRU element
				end
			end	

			temp = UpdateData_LRU(DC_LRU, Index);	// update lru			
		end

		//3 invalidate command from L2
		INVALIDATE:
		begin
			// look up for line by going to set and comparing tags in ways
			for(way=0;way<`DataCacheWay;way=way+1)
			begin				
				DataLine = DataCache[way][Index];
				MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
				DC_Tag = DataLine[DC_TagBits-1:0];

				if(Tag == DC_Tag) //if tag match
				begin
					MESI_Bits = Invalid; //if line found then set MESI_Bits as invalid
					DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
					DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = MESI_Bits;
					DataLine[DC_TagBits-1:0] = 12'bx;
					DataCache[way][Index] = DataLine;
				end
			end
		
			temp = UpdateData_LRU(DC_LRU, Index);	// update lru	
		end

		//4 data request from L2 (in response to snoop)
		SNOOP:
		begin
			//look up for line with mesi modified
			for(way=0;way<`DataCacheWay;way=way+1)
			begin
				DataLine = DataCache[way][Index];
				MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
				DC_Tag = DataLine[DC_TagBits-1:0];			
				
				if((MESI_Bits == Modified) && (Tag == DC_Tag)) //if valid and tag match
				begin
					found=1;	// modified cache line found!
					if(mode == 1)
						$display("Return data to L2 %h",address); //Return data to L2 <address>	
				end			
				if(Tag == DC_Tag)
				begin
					found=1;	// modified cache line found!
					MESI_Bits = Invalid; //if found then change to invalid
					DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
					DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits] = MESI_Bits;
					DataLine[DC_TagBits-1:0] = 12'bx;
					DataCache[way][Index] = DataLine;
				end
			end

			temp = UpdateData_LRU(DC_LRU, Index);	// update lru		
		end

		//8 clear the cache and reset all state (and statistics)
		RESET:
		begin
			for (s=0; s<`DataCacheSet; s=s+1)
			begin	
				for (w=0; w<`DataCacheWay; w=w+1)
				begin
					DataLine=DataCache[w][s];
					//set all the cache MESI bits to Invalid
					DataLine[DC_TagBits + DC_LRUBits + MESI_Size-1 : DC_TagBits + DC_LRUBits] = Invalid;
					//Initially assign LRU bits to each cache line in a set to line number 
					DataLine[DC_TagBits + DC_LRUBits-1 : DC_TagBits] = w;
					//set tag bits to x
					DataLine[DC_TagBits-1:0] = 12'bx;
					DataCache[w][s] = DataLine;
				end
			end
			
			//set all summary paramentes to '0' on reset
			DC_Read_Hit = 32'b0;
			DC_Read_Miss = 32'b0;
			DC_Reads = 32'b0;
			DC_Write_Hit = 32'b0;
			DC_Write_Miss = 32'b0;
			DC_Writes = 32'b0;
		end

		//9 print contents and state of the cache (allow subsequent trace activity)
		PRINT:
		begin
			$display("__________________________________________________________________");	
			$display("                                                                  ");			
			$display("                        DATA CACHE CONTENTS                       ");
			$display("__________________________________________________________________");
			
			for (s=0;s<`DataCacheSet;s=s+1)
			begin
				print = FALSE;
				for (w=0;w<`DataCacheWay;w=w+1)
				begin
					DataLine = DataCache[w][s];
					MESI_Bits = DataLine[DC_TagBits+DC_LRUBits+MESI_Size-1:DC_TagBits+DC_LRUBits];
					DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
					DC_Tag = DataLine[DC_TagBits-1:0];
					if(print == TRUE || MESI_Bits != Invalid || DC_Tag != "x")
					begin
						if(print == FALSE)
						begin
							print = TRUE;
							w = -1;
						end
						else
						begin
							print_MESI[w] = MESI_Bits;
							print_LRU[w] = DC_LRU;
							print_Tag[w] = DC_Tag;
						end	
					end
				end			
				if(print == TRUE)
				begin
					$display("Set Index : %h", s);		
					$display("Way:	 1	 2	 3	 4	 5	 6	 7	 8");
					$display("Tag:	%h	%h	%h	%h	%h	%h	%h	%h", print_Tag[0], print_Tag[1], print_Tag[2], print_Tag[3], print_Tag[4], print_Tag[5], print_Tag[6], print_Tag[7]);
					$display("LRU:	%b	%b	%b	%b	%b	%b	%b	%b", print_LRU[0], print_LRU[1], print_LRU[2], print_LRU[3], print_LRU[4], print_LRU[5], print_LRU[6], print_LRU[7]);
					$display("MESI:	%s	%s	%s	%s	%s	%s	%s	%s", Get_MESI_ID(print_MESI[0]), Get_MESI_ID(print_MESI[1]), Get_MESI_ID(print_MESI[2]), Get_MESI_ID(print_MESI[3]), Get_MESI_ID(print_MESI[4]), Get_MESI_ID(print_MESI[5]), Get_MESI_ID(print_MESI[6]), Get_MESI_ID(print_MESI[7]));
					$display("                         ** END OF SET **                         ");
					$display("------------------------------------------------------------------");
				end
			end
			$display("                     END OF DATA CACHE CONTENTS                   ");
			$display("__________________________________________________________________");		
		end

		endcase	
	end
	
	//function to update LRU values of each line in a set based on line reference
	function UpdateData_LRU;
		input [DC_LRUBits-1:0] LRU;
		input [DC_IndexBits-1:0] index;
		
		integer w;

		begin 
			//update the LRU bits of each cache line in a set
			for (w=0; w<`DataCacheWay; w=w+1)
			begin
				DataLine = DataCache[w][index];
				DC_LRU = DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits];
				//if it is a most recently used/refered cache line then set the LRU bits to 111
				if(DC_LRU == LRU)
				begin
					DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits] = `DataCacheWay-1;
					DataCache[w][index] = DataLine;
				end
				//LRU bits higher than the most recently used bits are decremented by 1 
				else if(DC_LRU > LRU)
				begin
					DataLine[DC_TagBits+DC_LRUBits-1:DC_TagBits] = DC_LRU-1;
					DataCache[w][index] = DataLine;
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
