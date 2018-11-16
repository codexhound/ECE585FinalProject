`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2018 03:51:40 PM
// Design Name: 
// Module Name: instructioncacheL1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////
//I think this can more or less be used for the instruction cache, bit locations are different as well as commands (inputs and outputs)

module instructioncacheL1(
    input clk,rst,write,//when write is 1 then the next command will be processed, dont write next command until processing output switches off
    //assuming a large address bitsize (60 bits)
    input [59:0] address,
    input [2:0] command, //read, write, invalidate,clear,datarequest
    input [13:0] setRead, //read a set for simulation
    //least sig 2 bits of L2message is the command, rest is the address
    output reg [61:0] L2message, //return data (present and modified), write to L2, read from L2, read for ownership
    output reg processing,
    
    output reg [44:0] way1, way2, way3, way4,
    output reg [63:0] hits, misses, total, reads, writes
    );
    
    parameter
      //input commands
      READ = 3'd0, //read address command
      WRITE = 3'd1, //write address command
      INVALIDATE = 3'd2, //invalidate command
      CLEAR = 3'd3, //clear the cache and reset command
      L2DATAREQUEST = 3'd4, //L2 Data request
      
      //out L2 messages
      RETURNDATA = 2'd0,
      LWWRITE = 2'd1,
      L2READ = 2'd2,
      L2READFOWN = 2'd3,
      
      //MESI status
      INVALID = 2'd0,
      MODIFIED = 2'd1,
      SHARED = 2'd2,
      EXCLUSIVE = 2'd3;
      
    //Cache Array Design
    //4-way set associatiave, 64 byte lines
    //2 bits for the LRU counter
    //6 bits for byte select
    //2 bits for MESI
    //1 bit for first write
    //16K sets so 14 bits for the index
    //tag bits -> 60-14-6 = 40 bits
    
    //cache array line size = 40(tag) + 2(MESI) + 2(LRU) + 1(FIRSTWRITE) = 45 bits
    
    //first index is the set (0-15999), determined by index select bits
    //second index is the line number in that set(4) 3:0
    reg [44:0] cacheArray [15999:0][3:0]; 
    
    wire [13:0] index;
    wire [5:0] byte_sel;
    wire [39:0] tag;
    
    assign index = address[19:6];
    assign byte_sel = address[5:0];
    assign tag = address[59:20];
    
    reg [2:0] command1;
    reg [13:0] index1;
    reg [5:0] byte_sel1;
    reg [39:0] tag1;
        
    reg match1, match;
    reg [1:0] matchingLine1, matchingLine;
    reg [2:0] line;
    reg [39:0] currentTag;//current loop tag
    reg [1:0] LRUline, LRUline1; //LRU line number
    
    wire [39:0] matchingLineTag;
    wire [1:0] matchingLineLRU;
    wire [1:0] matchingLineMESI;
    wire matchingLineWriteFirst;
    
    wire [39:0] LRULineTag;
    wire [1:0] LRULineLRU;
    wire [1:0] LRULineMESI;
    wire LRULineWriteFirst;
    
    assign LRULineTag = cacheArray[index1][LRUline1][44:5];
    assign LRULineMESI = cacheArray[index1][LRUline1][4:3];
    assign LRULineLRU = cacheArray[index1][LRUline1][2:1];
    assign LRULineWriteFirst = cacheArray[index1][LRUline1][0];
    
    assign matchingLineTag = cacheArray[index1][matchingLine1][44:5];
    assign matchingLineMESI = cacheArray[index1][matchingLine1][4:3];
    assign matchingLineLRU = cacheArray[index1][matchingLine1][2:1];
    assign matchingLineWriteFirst = cacheArray[index1][matchingLine1][0];
    
    reg [2:0] LRUupdatecount;
    reg LRUupdate; //have to update the LRU counters if this is true;
    
    reg [2:0] LRUcompValue;
    reg [2:0] LRULineSet; //line to set most used
    
    integer i, j, k;
    initial begin
        reads = 0;
        writes = 0;
        hits = 0;
        misses = 0;
        total = 0;
        
        processing = 0;
        LRUupdatecount = 0;
        LRUupdate = 0;
        
        LRUcompValue = 0;
        LRULineSet = 0;
        
        for(i = 0; i < 16000; i = i + 1) begin
            for(k = 0, j = 4; j > 0 && k < 4; j = j - 1, k = k + 1) begin
                cacheArray[i][k][44:5] = 0;
                cacheArray[i][k][4:3] = INVALID;
                cacheArray[i][k][2:1] = j-1;
                cacheArray[i][k][0] = 1; //first write bit
            end
        end
    end
    
    reg [44:0] currentLineForMatching;
    reg [1:0] lineArray [2:0]; //[1:0] is LRU value

    //initialize the cache data and cache array here

    ////////////////////////////////////////////////
    //reset regs
    reg [14:0] curSet;
    reg [2:0] curLine, curLRU;
    reg LRUupdateType;
    
    //pipeline the cache command
    always@(posedge clk) begin
        if(rst) begin
            reads <= 0;
            writes <= 0;
            hits <= 0;
            misses <= 0;
            total <= 0;
        
            processing <= 0;
            LRUupdatecount <= 0;
            
            LRUcompValue <= 0;
            LRULineSet <= 0;

            //reset the cache
            for(curSet = 0; curSet < 16000; curSet = curSet + 1) begin
            	for(curLine = 0, curLRU = 4; curLine < 4 && curLRU > 0; curLine = curLine + 1, curLRU = curLRU - 1) begin
            	    cacheArray[curSet][curLine][44:5] <= 0;
                	cacheArray[curSet][curLine][4:3] <= INVALID;
                	cacheArray[curSet][curLine][2:1] <= curLRU-1;
                	cacheArray[curSet][curLine][0] <= 1; //first write bit
            	end
             end
        end
        else begin
        
            if(!processing && write) begin //only change the command if the last command is done
               command1 <= command;
               match1 <= match; //tag match (set) from recieved command (true or false)
               matchingLine1 <= matchingLine; //matching line number from receieved command (in the set)
               
               LRUline1 <= LRUline; //LRU line from received command set
               
               index1 <= index;
               byte_sel1 <= byte_sel;
               tag1 <= tag;
               
               LRUupdatecount <= 0; //reset LRU update counter
               
               processing <= 1;
            end
            else if(processing) begin //processing
      
                if(LRUupdate) begin //increment all LRU bits that are less than the hitLRU or if full (the LU Line)
                  if(!LRUupdateType) begin //set SetLine to MSU -> LRU == 3 is LRU line
                        for(LRUupdatecount = 0; LRUupdatecount < 4; LRUupdatecount = LRUupdatecount + 1) begin
                            //increment all LRU bits that are less than the hitLRU, use when setting line to MSU
                            if(cacheArray[index][LRUupdatecount][2:1] < LRUcompValue && LRUupdatecount != LRULineSet) begin 
                                cacheArray[index][LRUupdatecount][2:1] <= cacheArray[index][LRUupdatecount][2:1] + 1;
                            end
                            else if(LRUupdatecount == LRULineSet) begin //reset LRU to 0 (MRU), this is the line that has been replaced in the case statement
                                cacheArray[index][LRUupdatecount][2:1] <= 0;
                            end
                        end   
                    end
                    else begin
                        for(LRUupdatecount = 0; LRUupdatecount < 4; LRUupdatecount = LRUupdatecount + 1) begin
                            //decrement all LRU bits that are greater than the hitLRU, use when setting a line to invalid (LSU)
                            if(cacheArray[index][LRUupdatecount][2:1] > LRUcompValue && LRUupdatecount != LRULineSet) begin
                                cacheArray[index][LRUupdatecount][2:1] <= cacheArray[index][LRUupdatecount][2:1] - 1;
                            end
                            else if(LRUupdatecount == LRULineSet) begin //reset LRU to 3 (LRU), this is the line that has been replaced in the case statement
                                cacheArray[index][LRUupdatecount][2:1] <= 3;
                            end
                        end  
                    end
                    LRUupdate <= 0; 
                    processing <= 0; //prosessing done once LRU updating is done
                end
                else begin //start processing the command, may say to update the LRU counters here, when done set processing to 0 for next command
                    //[45:5] is the tag
                    //[4:3] is MESI status
                    //[2:1] is the LRU bits
                    //[0] is the first write bit
                    
                    //INVALID = 2'd0,  
                    //MODIFIED = 2'd1, 
                    //SHARED = 2'd2,   
                    //EXCLUSIVE = 2'd3;
                    case(command1)
                        READ: begin
                            reads <= reads + 1;
                            total <= total + 1;
                            //check for tag, if no match, then check for LRU line
                            
                            if(!match1) begin//there was no match, cache miss
                                //still need L2 returns here
                                //cache miss, try to read from L2 (from the final project documentation)
                                
                                misses <= misses + 1; //replace LRU line
                                if(cacheArray[index1][LRUline1][4:3] == INVALID) begin//empty slot
                                    //write tag bits
                                    cacheArray[index1][LRUline1][44:5] <= tag1;
                                    //update MESI bits
                                    cacheArray[index1][LRUline1][4:3] <= EXCLUSIVE;
                                end
                                else begin//slot is not empty, needs to be a victim
                                    cacheArray[index1][LRUline1][44:5] <= tag1;
                                    
                                    //MESI state remains the same (read)
                                    cacheArray[index1][LRUline1][4:3] <= cacheArray[index][LRUline1][4:3];
                                end

                                LRUupdate <= 1;
                                //in this case remove the highest (LRU) line
                                LRUcompValue <= LRULineLRU;
                                LRULineSet <= LRUline1;
                                LRUupdateType <= 0;
                            end
                            else begin //found a matching tag
                                //hit, matching tag
                                hits <= hits + 1;
                                //snooping logic
                                if(cacheArray[index1][matchingLine1][4:3] == MODIFIED || cacheArray[index][matchingLine1][4:3] == EXCLUSIVE) begin
                                    //was a hit and it was exlusive or modified, now its shared
                                    cacheArray[index1][matchingLine1][4:3] <= SHARED;
                                end
                                
                                LRUupdate <= 1;
                                //in this case update below matching line LRU values
                                LRUcompValue <= matchingLineLRU;
                                LRULineSet <= matchingLine1;
                                LRUupdateType <= 0;
                            end
                        end
                        CLEAR: begin
                        	//reset the cache
            				for(curSet = 0; curSet < 16000; curSet = curSet + 1) begin
            					for(curLine = 0, curLRU = 4; curLine < 4 && curLRU > 0; curLine = curLine + 1, curLRU = curLRU - 1) begin
            					    cacheArray[curSet][curLine][44:5] <= 0;
             				   		cacheArray[curSet][curLine][4:3] <= INVALID;
             				   		cacheArray[curSet][curLine][2:1] <= curLRU-1;
             				   		cacheArray[curSet][curLine][0] <= 1; //first write bit
            					end
             				end
        					processing <= 0;
                        end
                    endcase
                end
            end
            else begin
                //do this after simulation is complete, all commands have been completed
                way1 <= cacheArray[setRead][0];
                way2 <= cacheArray[setRead][1];
                way3 <= cacheArray[setRead][2];
                way4 <= cacheArray[setRead][3];
            end
        end
    end
    
    
    //purely combinatorial logic
    always@(*) begin
        //find if there is a matching tag current in the set, if so return match = 1 and return the line number (relative to the set)
        matchingLine = 0;
        match = 0;
        
        for(line = 0; line < 4; line=line+1) begin
            currentLineForMatching = cacheArray[index][line];
            currentTag = currentLineForMatching[44:5]; //only compare the tag bits
            if(currentTag == tag) begin
                match = 1;
                matchingLine = line;
            end
        end
    
    //get the Least Accessed Line in the Set
    //least in this scheme is the largest LRU value -> so 3
        for(line = 0; line < 4; line=line+1) begin
            lineArray[line] = cacheArray[index][line][2:1];
        end
        
        if(lineArray[0] > lineArray[1] &&
            lineArray[0] > lineArray[2]) begin
            LRUline = 0;
        end
        else if(lineArray[1] > lineArray[0] &&
            lineArray[1] > lineArray[2]) begin
            LRUline = 1;
        end
        else if(lineArray[2] > lineArray[0] &&
            lineArray[2] > lineArray[1]) begin
            LRUline = 2;
        end
        else begin
            LRUline = 3;
        end
    end
    
    
endmodule
