`timescale 1ns/1ps
module usdr_rx_flow_test;
reg ac=0,dc=0; always #7 ac=~ac; always #5 dc=~dc;
reg ar=1,dr=1,iv=0,ready=0;
reg [31:0] data=0;
wire ov,valid;
wire [31:0] output_data;
rx_dsp_chain #(.ADC_WIDTH(16),.CFG_WIDTH(8),.STAGES(8),.DC_CORR(0),.CORDIC(0)) dut(
 .adc_clk(ac),.adc_rst(ar),.adc_data(data),.adc_valid(iv),.adc_overflow(ov),
 .adc_dsp_cordic_phase(32'b0),.adc_dc_corr_en(1'b0),
 .dsp_clk(dc),.dsp_rst(dr),.dsp_data(output_data),.dsp_valid(valid),.dsp_ready(ready),
 .dsp_cfg_valid(1'b0),.dsp_cfg_data(8'b0));
reg [31:0] expected [0:2047];
integer put=0,get=0,cycle=0,n;
reg [31:0] stalled;
reg was_stalled=0,random_stalls=0;
always @(posedge ac) if(!ar && dut.adc_armed && iv && dut.adc_ready) begin expected[put]=data;put=put+1;end
always @(posedge dc) begin
 if(dr) was_stalled=0;
 else begin
  if(was_stalled && (!valid || output_data!==stalled)) $fatal(1,"output changed while stalled");
  was_stalled=valid&&!ready; stalled=output_data;
  if(valid&&ready) begin
   if(get>=put || output_data!==expected[get]) $fatal(1,"data mismatch %d got %h expected %h",get,output_data,expected[get]);
   get=get+1;
  end
 end
end
always @(negedge dc) if(random_stalls) begin cycle=cycle+1;ready=(cycle%7!=0)&&(cycle%11!=0);end
initial begin
 repeat(10) @(negedge ac); ar=0;dr=0;ready=1;random_stalls=1;
 repeat(15) @(negedge ac);
 for(n=1;n<301;n=n+1) begin data=n;iv=1;@(negedge ac);iv=0;@(negedge ac);end
 repeat(100) @(negedge ac);
 if(get!=put || ov) $fatal(1,"loss under bounded stalls get %d put %d ov %b",get,put,ov);
 random_stalls=0;ready=0;
 for(n=301;n<501;n=n+1) begin data=n;iv=1;@(negedge ac);end
 iv=0;
 if(!ov) $fatal(1,"ADC overflow was hidden");
 ready=1; repeat(500) @(negedge ac);
 if(get!=put) $fatal(1,"accepted samples not drained");
 ar=1;dr=1; repeat(10) @(negedge ac);
 if(ov) $fatal(1,"overflow not reset");
 $display("PASS actual RX FIR chain preserves data under stalls and reports ADC overflow");$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
