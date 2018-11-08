// icontest.v
//
// Drive the icon module to test correct mapping

`timescale 1ps/1ps

module cacheTestBench;
    reg clk,rst,write;//when write is 1 then the next command will be processed, dont write next command until processing output switches off
    //assuming a large address bitsize (60 bits)
    reg [59:0] address;
    reg [2:0] command; //read, write, invalidate,clear,datarequest
    reg [13:0] setRead; //read a set for simulation
    //least sig 2 bits of L2message is the command, rest is the address
    wire [61:0] L2message; //return data (present and modified), write to L2, read from L2, read for ownership
    wire processing;
    wire [45:0] way1, way2, way3, way4, way5, way6, way7, way8;
    integer mode;

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
    
    datacacheL1 L1(
        .clk(clk),
        .rst(rst),
        .write(write),
        .address(address),
        .command(command),
        .setRead(setRead),
        .L2message(L2message),
        .processing(processing),
        .way1(way1),
        .way2(way2), 
        .way3(way3), 
        .way4(way4), 
        .way5(way5), 
        .way6(way6), 
        .way7(way7), 
        .way8(way8)
    );

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
        clk = 0;
        forever
            #1 clk = ~clk;
	
    end
    
    integer row;
    integer col;
    initial
    begin
       rst = 0;
       write = 1;
       address = 60'h3865837; //set h1960
       command = READ;
       setRead = 0;
       repeat (2) @(posedge clk);
       write = 0;
       repeat (18) @(posedge clk);
       setRead = 14'h1960;
       repeat (1) @(posedge clk);
       $stop;
    end
endmodule
