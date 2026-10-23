`timescale 1ns/1ps
module usdr_pcie_rx_buffer_test;
reg clk=0; always #5 clk=~clk;
reg rst=1,sv=0,mr=0;
reg [73:0] sd=0;
wire sr,mv; wire [73:0] md;
axis_fifo_trd #(.WIDTH(74)) dut(clk,rst,sd,sv,sr,md,mv,mr);
reg [73:0] expected[0:1023];
reg [73:0] held;
reg stalled=0, accepted=0;
integer sent=0,received=0,cycle=0,producer=0,fill;
always @(posedge clk) begin
    accepted=sv&&sr&&!rst;
    if(rst) begin sent=0;received=0;stalled=0; end
    else begin
        if(stalled && (!mv || md !== held)) $fatal(1,"PCIe beat changed under backpressure");
        stalled=mv&&!mr;held=md;
        if(sv&&sr) begin expected[sent]=sd;sent=sent+1;end
        if(mv&&mr) begin
            if(received>=sent || md!==expected[received]) $fatal(1,"PCIe data/keep/last/BAR mismatch");
            received=received+1;
        end
    end
end
initial begin
    repeat(4)@(negedge clk);rst=0;
    // Keep a pending source beat stable until accepted, with long/full stalls.
    for(cycle=0;cycle<3000;cycle=cycle+1) begin
        @(negedge clk);
        if(!sv || accepted) begin
            if(producer<500 && cycle%7!=0) begin
                sd={producer[6:0],(producer%5==4),producer[1:0],32'h13579bdf,producer[31:0]};
                sv=1;producer=producer+1;
            end else sv=0;
        end
        mr=(cycle%37>12)&&(cycle%5!=0);
    end
    sv=0;mr=1;repeat(8)@(negedge clk);
    if(sent!=500 || received!=500) $fatal(1,"lost or duplicated PCIe beats");
    mr=0;sv=1;sd=74'h12345;repeat(4)@(negedge clk);sv=0;
    rst=1;repeat(2)@(negedge clk);rst=0;mr=1;
    repeat(4)begin @(negedge clk);if(mv)$fatal(1,"pre-reset PCIe beat leaked");end
    $display("PASS PCIe RX buffer preserves data/keep/last/BAR across stalls and flushes on reset");$finish;
end
initial begin #100000;$fatal(1,"watchdog");end
endmodule
