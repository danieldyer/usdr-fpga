`timescale 1ns/1ps
module usdr_meas_test;
reg clk=0; always #5 clk=~clk;
reg rst=1, cmd_valid=0, valid=0;
reg [31:0] cmd=0, data=0;
wire [31:0] corrected,result;
wire cv,clip;
usdr_iq_matrix matrix(clk,rst,cmd,cmd_valid,data,valid,corrected,cv,clip);
usdr_rx_measure #(.WINDOW_BITS(4)) measure(clk,rst,cmd,cmd_valid,result,data,valid,corrected,cv,clip);
task write; input [31:0] value; begin
 @(negedge clk); cmd=value; cmd_valid=1; @(negedge clk); cmd_valid=0;
end endtask
task read_check; input [7:0] addr; input signed [31:0] expected; begin
 @(negedge clk); cmd=32'h86000000 | (addr << 16); #1;
 if ($signed(result) !== expected) begin $display("FAIL read %d got %d expected %d",addr,$signed(result),expected); $fatal; end
end endtask
task sample; input signed [15:0] i,q; begin
 @(negedge clk); data={q,i}; valid=1; @(negedge clk); valid=0;
end endtask
integer n;
initial begin
 repeat(5) @(negedge clk); rst=0;
 // Raw mean must work with no stream running, signed data, and gaps.
 write(32'h06000000);
 for(n=0;n<16;n=n+1) begin sample(100,-200); if(n%3==0) repeat(3) @(negedge clk); end
 repeat(5) @(negedge clk);
 read_check(0,1); read_check(4,1600); read_check(5,-3200); read_check(1,0);
 for(n=0;n<8;n=n+1) sample(555,666);
 read_check(4,1600); read_check(0,1);
 // Abort discards partial windows; no phantom generation increment.
 write(32'h06000000); sample(7,9); write(32'h06000001);
 for(n=0;n<20;n=n+1) sample(7,9);
 read_check(0,1);
 // Clipping invalidates a complete window.
 write(32'h06000000);
 for(n=0;n<16;n=n+1) sample(-32768,32752);
 repeat(4) @(negedge clk); read_check(0,2); read_check(1,1);
 // Atomic coefficient commit, unity until fourth write.
 write(32'h02400000); write(32'h03400000); write(32'h04200000);
 sample(1000,2000); @(negedge clk);
 if (!cv || corrected !== {16'd2000,16'd1000}) $fatal(1,"matrix staging or valid alignment");
 write(32'h05200000);
 sample(1000,2000); @(negedge clk);
 if (!cv || corrected !== {16'd1250,16'd1000}) $fatal(1,"matrix cross terms");
 @(negedge clk); if(cv) $fatal(1,"valid extended across gap");
 // Saturation, no wraparound.
 write(32'h027fffff); write(32'h037fffff); write(32'h047fffff); write(32'h057fffff);
 sample(30000,30000); @(negedge clk);
 if(!clip || corrected !== 32'h7fff7fff) $fatal(1,"matrix saturation");
 @(negedge clk); rst=1; repeat(3) @(negedge clk); rst=0;
 read_check(0,0);
 // Coherent measurement mode with zero phase, unity matrix.
 write(32'h06080000); write(32'h06000000);
 for(n=0;n<16;n=n+1) sample(4096,-4096);
 repeat(5) @(negedge clk); read_check(4,65520); read_check(5,-65536);
 // Four quadrants at Fs/4, measured with -Fs/4. Phase advances per sample,
 // including gaps in valid, and both I/Q products must align.
 write(32'h06020000); write(32'h0603c000); write(32'h06000000);
 for(n=0;n<16;n=n+1) begin
  case(n%4)
   0: sample(8192,0);
   1: sample(0,8192);
   2: sample(-8192,0);
   3: sample(0,-8192);
  endcase
  if(n%3==0) repeat(2) @(negedge clk);
 end
 repeat(5) @(negedge clk); read_check(4,131056); read_check(5,0);
 $display("PASS raw signed means, finite windows, reset, clipping, IQ commit/alignment/saturation"); $finish;
end
initial begin #200000; $fatal(1,"watchdog"); end
endmodule
