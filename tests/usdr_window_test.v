`timescale 1ns/1ps
module usdr_window_test;
reg clk=0;always #5 clk=~clk;
reg rst=1,cv=0,valid=0;
reg [31:0] cmd=0;
wire [31:0] result;
usdr_rx_measure dut(.clk(clk),.rst(rst),.cmd(cmd),.cmd_valid(cv),.result(result),
 .raw_data({-16'sd32000,16'sd32000}),.raw_valid(valid),.iq_data(32'b0),.iq_valid(1'b0),.iq_clipped(1'b0));
integer n;
initial begin
 repeat(16)@(negedge clk);rst=0;cmd=32'h06000000;cv=1;
 @(negedge clk);cv=0;valid=1;
 repeat(65535)@(negedge clk);
 valid=0;repeat(16)@(negedge clk);cmd=32'h86000000;#1;
 if(result!==0)$fatal(1,"window completed early");
 @(negedge clk);valid=1;@(negedge clk);valid=0;
 repeat(16)@(negedge clk);#1;
 if(result!==1)$fatal(1,"window length is not 65536");
 cmd=32'h86040000;#1;if($signed(result)!==32'sd2097152000)$fatal(1,"positive sum overflow");
 cmd=32'h86050000;#1;if($signed(result)!==-32'sd2097152000)$fatal(1,"negative sum overflow");
 cmd=32'h86010000;#1;if(result!==0)$fatal(1,"unclipped window flagged");
 valid=1;repeat(100)@(negedge clk);cmd=32'h86000000;#1;
 if(result!==1)$fatal(1,"measurement restarted itself");
 $display("PASS production 65536-sample window, near-full-scale signed sums and frozen completion");$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
