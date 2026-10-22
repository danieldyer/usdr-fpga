`timescale 1ns/1ps
module usdr_cal_bridge_test;
reg hc=0, cc=0, clock_on=1; always #5 hc=~hc; always #7 if(clock_on) cc=~cc;
reg hr=1, cr=1, valid=0, ready=0;
reg [31:0] data=0;
wire wr, rv, cv;
wire [31:0] rd, cmd;
reg [31:0] stored=0;
wire [31:0] result=stored;
usdr_cal_bridge #(.TIMEOUT_BITS(7)) dut(hc,hr,data,valid,wr,rd,rv,ready,cc,cr,cmd,cv,result);
always @(posedge cc) if(cr) stored<=0; else if(cv && !cmd[31]) stored<=cmd;
task send; input [31:0] value; begin
 @(negedge hc); data=value; valid=1;
 while(!wr) @(negedge hc);
 @(negedge hc); valid=0;
end endtask
task receive; input [31:0] expected; begin
 while(!rv) @(negedge hc);
 if(rd!==expected) $fatal(1,"CDC response mismatch got %h expected %h",rd,expected);
 repeat(5) begin @(negedge hc); if(!rv || rd!==expected) $fatal(1,"stalled response changed"); end
 ready=1; @(negedge hc); ready=0;
end endtask
integer k;
initial begin
 repeat(10) @(negedge hc); hr=0; cr=0;
 for(k=1;k<33;k=k+1) begin
  send(k*12345); send(32'h86000000); receive(k*12345);
 end
 // A stopped converter clock cannot hang a host read or leak stale responses.
 @(negedge cc); clock_on=0;
 send(32'h86000000); receive(32'hffffffff);
 clock_on=1;
 send(32'h86000000); receive(32'hffffffff);
 hr=1; cr=1; repeat(10) @(negedge hc); hr=0; cr=0;
 send(32'h12345678); send(32'h86000000); receive(32'h12345678);
 $display("PASS ordered asynchronous PHY commands, response stalls, clock loss and reset"); $finish;
end
initial begin #100000; $fatal(1,"watchdog"); end
endmodule
