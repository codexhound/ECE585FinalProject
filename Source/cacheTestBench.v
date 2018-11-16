// icontest.v
//
// Drive the icon module to test correct mapping

`timescale 1ps/1ps

module cacheTestBench;
    reg clk,rst,write, writeI;//when write is 1 then the next command will be processed, dont write next command until processing output switches off
    //assuming a large address bitsize (60 bits)
    reg [59:0] address;
    reg [2:0] command; //read, write, invalidate,clear,datarequest
    reg [13:0] setRead, setReadI; //read a set for simulation
    //least sig 2 bits of L2message is the command, rest is the address
    wire [61:0] L2message, L2messageI; //return data (present and modified), write to L2, read from L2, read for ownership
    wire [45:0] way1D, way2D, way3D, way4D, way5D, way6D, way7D, way8D;
    wire [44:0] way1I, way2I, way3I, way4I;
    wire processingD, processingI, processing;
    wire [63:0] missesD, hitsD, totalD, writesD, readsD, missesI, hitsI, totalI, writesI, readsI;
    reg [63:0] misses, hits, total, reads, writes;
    integer mode;
    reg [63:0] counter;

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

    datacacheL1 L1D(
        .clk(clk),
        .rst(rst),
        .write(write),
        .address(address),
        .command(command),
        .setRead(setRead),
        .L2message(L2message),
        .processing(processingD),
        .way1(way1D),
        .way2(way2D), 
        .way3(way3D), 
        .way4(way4D), 
        .way5(way5D), 
        .way6(way6D), 
        .way7(way7D), 
        .way8(way8D),
        .reads(readsD),
        .writes(writesD),
        .hits(hitsD),
        .misses(missesD),
        .total(totalD)
    );
    
    instructioncacheL1 L1I(
        .clk(clk),
        .rst(rst),
        .write(writeI),
        .address(address),
        .command(command),
        .setRead(setReadI),
        .L2message(L2messageI),
        .processing(processingI),
        .way1(way1I),
        .way2(way2I), 
        .way3(way3I), 
        .way4(way4I),
        .reads(readsI),
        .writes(writesI),
        .hits(hitsI),
        .misses(missesI),
        .total(totalI)
    );

    assign processing = processingD | processingI; //only 1 cache has to be processing for processing to be true

    initial begin
    $value$plusargs ("MODE=%d", mode);
    if(mode == 0) begin //do mode 0 simulation

    end
    else begin //do mode 1 simulation

    end
    end
	
    integer endTime;
    initial
    begin
        counter = 0;
        command = READ;
        setRead = 14'h1960;
        setReadI = 14'h1960;
        address = 60'h3865837; //set h1960
        rst = 0;
        clk = 0;
        write = 1;
        writeI = 0;
        forever #1 clk = ~clk;
    end

    initial begin
      repeat (40) @(posedge clk);
      $stop;
    end
    
    always@(posedge clk) begin
        misses <= missesI + missesD;
        hits <= hitsI + hitsD;
        total <= totalI + totalD;
        reads <= readsI + readsD;
        writes <= writesI + writesD;

        counter <= counter + 1;
        if(processing && writeI) writeI <= 0; //turn off write, cache is processing
        if(processing && write) write <= 0; //turn off write, cache is processing

        if(counter < 20) begin
          if(!processing && !write) write <= 1; //turn back on write, cache is done processing
        end
        else begin
          if(!processing && !writeI) writeI <= 1; //turn back on write, cache is done processing
        end
    end
endmodule
