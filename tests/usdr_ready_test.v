`timescale 1ns/1ps
module usdr_ready_test;
reg clk=0; always #5 clk=~clk;
reg [7:0] bypass=0, ready=0;
wire [7:0] actual;
reg [7:0] expected;
integer b,r,i;
reconf_dsp_ready dut(clk,bypass,ready,actual);
initial begin
    // Exhaust the original recursive equation, including every bypass layout.
    for(b=0;b<256;b=b+1) begin
        @(negedge clk); bypass=b;
        @(posedge clk); #1;
        for(r=0;r<256;r=r+1) begin
            ready=r; expected[7]=ready[7];
            for(i=6;i>=0;i=i-1) expected[i]=bypass[i]?expected[i+1]:ready[i];
            #1; if(actual !== expected) $fatal(1,"ready decode mismatch bypass=%h ready=%h got=%h expected=%h",bypass,ready,actual,expected);
        end
    end
    $display("PASS all 65536 bypass/ready combinations preserve the original FIR stall equation"); $finish;
end
endmodule
