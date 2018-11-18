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
    //8-way set associatiave, 64 byte lines
    //3 bits for the LRU counter
    //6 bits for byte select
    //2 bits for MESI
    //1 bit for first write
    //16K sets so 14 bits for the index
    //tag bits -> 60-14-6 = 40 bits
    
    //cache array line size = 40(tag) + 2(MESI) + 2(LRU) + 1(FIRSTWRITE) = 45 bits
    
    //first index is the set (0-15999), determined by index select bits
    //second index is the line number in that set(4) 3:0
    reg [44:0] cacheArray [15999:0][3:0];
    
    reg [2:0] command1;
    reg [13:0] index1, index;
    reg [5:0] byte_sel1;
    reg [39:0] tag1, tag;
    reg [59:0] address1;

    assign index1 = address1[19:6];
    assign index = address[19:6];
    assign byte_sel1 = address1[5:0];
    assign tag1 = address1[59:20];
    assign tag = address[59:20];
        
    reg match1, match;
    reg [1:0] matchingLine1, matchingLine, matchingLineLRU, matchingLineLRU1;
    reg [2:0] line;
    reg [39:0] currentTag;//current loop tag
    
    reg [2:0] LRUupdatecount;
    reg LRUupdate; //have to update the LRU counters if this is true;
    
    reg [1:0] LRUcompValue;
    reg [1:0] LRULineSet; //line to set most used
    
    integer i, j, k;
    initial begin
        reads = 0;
        writes = 0;
        hits = 0;
        misses = 0;
        total = 0;
        
        processing = 0;
        LRUupdate = 0;
        L2message = 0;
        
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
    reg [1:0] lineArrayLRU [7:0]; //[2:0] is LRU value
    reg [1:0] lineArrayMESI [7:0]; //[1:0] is the MESI value

    //initialize the cache data and cache array here

    ////////////////////////////////////////////////
    //reset regs
    reg [14:0] curSet;
    reg [2:0] curLine, curLRU;

    //invalid LRU logic//////////////////
    reg invalidExists;
    reg [1:0] LRUinvalidLine, LRUinvalidValue;
    /////////////////////////////////////

    //LRU logic/////////////////////////
    reg [1:0] LRUline, LRULineValue;
    ////////////////////////////////////

    //Victim defines//////////////////////////
    reg [1:0] victimLine, victimLRUvalue, victimLine1, victimLRUvalue1;
    //////////////////////////////////////////
    
    //pipeline the cache command
    always@(posedge clk) begin
        if(rst) begin
            reads <= 0;
            writes <= 0;
            hits <= 0;
            misses <= 0;
            total <= 0;
        
            processing <= 0;
            LRUupdate <= 0;
            L2message <= 0;

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

               ///////////////////////////////////////////////////////////////////////
               //latch in all the combo logic for processing the various commands
               ///////////////////////////////////////////////////////////////////////

               command1 <= command;

               match1 <= match; //tag match (set) from recieved command (true or false)
               matchingLine1 <= matchingLine;
               matchingLineLRU1 <= matchingLineLRU;
               
               victimLine1 <= victimLine;
               victimLRUvalue1 <= victimLRUvalue;
               
               address1 <= address;
               L2message <= 0; //reset the message
               
               processing <= 1;

            end
            else if(processing) begin //processing
                if(LRUupdate) begin 
                    for(LRUupdatecount = 0; LRUupdatecount < 4; LRUupdatecount = LRUupdatecount + 1) begin
                        //increment all LRU bits that are less than the the replaced LRU
                        if(cacheArray[index1][LRUupdatecount][2:1] < LRUcompValue && LRUupdatecount != LRULineSet) begin 
                            cacheArray[index1][LRUupdatecount][2:1] <= cacheArray[index1][LRUupdatecount][2:1] + 1;
                        end
                        else if(LRUupdatecount == LRULineSet) begin //reset victim line to 0 (MRU), this is the line that has been replaced
                            cacheArray[index1][LRUupdatecount][2:1] <= 0;
                        end
                    end
                    LRUupdate <= 0; 
                    processing <= 0; //prosessing done once LRU updating is done
                end
                else begin //start processing the command, may say to update the LRU counters here, when done set processing to 0 for next command
                    //[44:5] is the tag
                    //[4:3] is MESI status
                    //[2:1] is the LRU bits
                    //[0] is the first write bit
                    
                    //INVALID = 2'd0,  
                    //MODIFIED = 2'd1, 
                    //SHARED = 2'd2,   
                    //EXCLUSIVE = 2'd3;
                    case(command1)
                        //When a line is changed to invalid, do not update the LRU bits, victim line is already calculated based on invalid lines first then total LRU second(based on documentation)

                        READ: begin
                            reads <= reads + 1;
                            total <= total + 1;
                            //check for tag, if no match, then check for LRU line
                            
                            if(!match1) begin//there was no match, cache miss
                                //cache miss, try to read from L2 (from the final project documentation)
                                L2message[61:2] <= address1;
                                L2message[2:0] <= L2READ;
                                
                                misses <= misses + 1; //replace LRU line
                                if(cacheArray[index1][victimLine1][4:3] == INVALID) begin //empty slot, goes to exclusive
                                    //write tag bits
                                    cacheArray[index1][victimLine1][44:5] <= tag1;
                                    //update MESI bits
                                    cacheArray[index1][victimLine1][4:3] <= EXCLUSIVE;
                                end
                                else begin //slot is not empty, needs to be a victim
                                    cacheArray[index1][victimLine1][44:5] <= tag1;
                                    //MESI state remains the same (read)
                                    cacheArray[index1][victimLine1][4:3] <= cacheArray[index1][victimLine1][5:4];
                                end

                                /////////////////////////////////
                                LRUupdate <= 1;
                                //set comp values for LRU update//
                                LRULineSet <= victimLine1;
                                LRUcompValue <= victimLRUvalue1;
                                /////////////////////////////////
                            end
                            else begin //found a matching tag
                                //hit, matching tag
                                hits <= hits + 1;
                                //snooping logic
                                if(cacheArray[index1][matchingLine1][4:3] == MODIFIED || cacheArray[index1][matchingLine1][4:3] == EXCLUSIVE) begin
                                    //was a hit and it was exlusive or modified, now its shared
                                    cacheArray[index1][matchingLine1][4:3] <= SHARED;
                                end
                                
                                LRUupdate <= 1;
                                //in this case update below matching line LRU values
                                LRUcompValue <= matchingLineLRU1;
                                LRULineSet <= matchingLine1;
                            end
                        end
                        WRITE: begin

                        end
                        INVALIDATE:
                        begin
                                               
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
                        L2DATAREQUEST: begin
                        
                        end
                        default: begin
                        
                        end
                    endcase
                end
            end
        end
    end
    
    
    //purely combinatorial logic
    always@(*) begin

        way1 = cacheArray[setRead][0];
        way2 = cacheArray[setRead][1];
        way3 = cacheArray[setRead][2];
        way4 = cacheArray[setRead][3];

        for(line = 0; line < 4; line=line+1) begin
            lineArrayLRU[line] = cacheArray[index][line][2:1];
            lineArrayMESI[line] = cacheArray[index][line][4:3];
        end

        match = 0;
        matchingLine = 0;
        matchingLineLRU = lineArrayLRU[0];

        ////////////////////////////////////////////////
        //logic to find matching tag line and LRU value
        ////////////////////////////////////////////////
        for(line = 0; line < 4; line=line+1) begin
            currentLineForMatching = cacheArray[index][line];
            currentTag = currentLineForMatching[44:5]; //only compare the tag bits
            if(currentTag == tag) begin
                match = 1;
                matchingLine = line;
                matchingLineLRU = lineArrayLRU[line];
                break;
            end
        end

        ///////////////////////////////////////////////////
        //logic to find LRU line out of only invalid lines
        ///////////////////////////////////////////////////

        LRUinvalidLine = 0;
        invalidExists = 0;
        LRUinvalidValue = 0;

        //find if invalid exists and find the starting(starting max min) invalid LRU for check
        for(line = 0; line < 4; line=line+1) begin
            if(lineArrayMESI[line] == INVALID) begin
                invalidExists = 1;
                LRUinvalidLine = line;
                LRUinvalidValue = lineArrayLRU[line];
                break;
            end
        end

        //find the LRU of invalid lines, similar to finding max or min
        if(invalidExists) begin
            for(line = 0; line < 4; line=line+1) begin
                if(lineArrayMESI[line] == INVALID && lineArrayLRU[line] > LRUinvalidValue) begin
                    LRUinvalidValue = lineArrayLRU[line];
                    LRUinvalidLine = line;
                end
            end
        end 
        
        /////////////////////////////////////////////////    
        //get the Least Accessed Line in the Set
        /////////////////////////////////////////////////
        //least in this scheme is the largest LRU value -> so 7

        LRUline = 0;
        LRULineValue = lineArrayLRU[0];
        //similar to finding max or min
        for(line = 0; line < 4; line=line+1) begin
            if(lineArrayLRU[line] > LRULineValue) begin
                LRUline = line;
                LRULineValue = lineArrayLRU[line];
            end
        end

        //////////////////////////////////////////////////
        //victim logic
        //////////////////////////////////////////////////
        if(invalidExists) begin
            victimLine = LRUinvalidLine;
            victimLRUvalue = LRUinvalidValue;
        end
        else begin
            victimLine = LRUline;
            victimLRUvalue = LRULineValue;
        end
    end
    
    
endmodule
