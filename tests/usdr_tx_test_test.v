`timescale 1ns/1ps
module usdr_tx_test_test;
reg clk=0;always #5 clk=~clk;
reg rst=1,cv=0,advance=0;
reg [31:0] cmd=0;
wire enabled;
wire [31:0] data;
usdr_tx_test dut(.clk(clk),.rst(rst),.cmd(cmd),.cmd_valid(cv),.advance(advance),.enabled(enabled),.data(data));
task write;input [31:0] v;begin @(negedge clk);cmd=v;cv=1;@(negedge clk);cv=0;end endtask
reg rotate=0;
always @(negedge clk) if(rotate)advance=~advance;
reg signed [15:0] pi,pq,ci,cq;
integer n;
initial begin
 repeat(16)@(negedge clk);rst=0;
 write(32'h07042000);write(32'h07050000); // Amplitude 8192, Q=0.
 write(32'h08000000);write(32'h09004000); // Fs/4 phase increment.
 write(32'h07000001);rotate=1;
 repeat(16)@(posedge clk);
 @(negedge clk);while(!advance)@(negedge clk);
 #1;pi=$signed(data[15:0]);pq=$signed(data[31:16]);
 if(!enabled || (pi==0 && pq==0))$fatal(1,"DDS not enabled");
 for(n=0;n<16;n=n+1)begin
  repeat(2)@(negedge clk);#1;ci=$signed(data[15:0]);cq=$signed(data[31:16]);
  // Q1.15 multiplication floors negative values, allowing one LSB asymmetry.
  if(ci+pq < -1 || ci+pq > 1 || cq-pi < -1 || cq-pi > 1)$fatal(1,"DDS phase/cadence error");
  pi=ci;pq=cq;
 end
 rotate=0;advance=0;repeat(16)@(negedge clk);pi=$signed(data[15:0]);pq=$signed(data[31:16]);
 repeat(8)begin @(negedge clk);if(data!=={pq,pi})$fatal(1,"DDS advanced without a consumed pair");end
 write(32'h07000000);if(enabled)$fatal(1,"DDS did not disable");
 $display("PASS calibration DDS phase direction, paired-sample cadence, hold and disable");$finish;
end
initial begin #20000;$fatal(1,"watchdog");end
endmodule
