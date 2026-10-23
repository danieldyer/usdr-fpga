`timescale 1ns/1ps
module glbl; wire GSR=0; wire GTS=0; endmodule
module usdr_dsp_enable_test;
parameter RESET_DSP=0; parameter NO_STALL=0;
reg clk=0;always #5 clk=~clk;
reg rst=1,go=0,valid=0,tag=0,cv=0;
reg [72:0] data=0;
reg [47:0] c=0,pc=0;
reg [14:0] cmd=15'h0280;
wire [47:0] a,b;
wire av,bv,at,bt,atv,btv;wire [3:0] asv,bsv;
dsp48e1_pipeline #(.RESET_DSP48(RESET_DSP),.NO_STALL(NO_STALL)) changed(
 .clk(clk),.rst(rst),.s_stall_n(go),.s_adb_data(data),.s_adb_valid(valid),.s_adb_cmd(cmd),.s_adb_tag(tag),
 .s_c_data(c),.s_c_valid(cv),.m_p_data(a),.m_p_valid(av),.m_p_tag(at),.m_p_tv(atv),.m_p_svalid(asv),.dspcasc_p_i(pc));
dsp48e1_pipeline_reference #(.RESET_DSP48(RESET_DSP),.NO_STALL(NO_STALL)) original(
 .clk(clk),.rst(rst),.s_stall_n(go),.s_adb_data(data),.s_adb_valid(valid),.s_adb_cmd(cmd),.s_adb_tag(tag),
 .s_c_data(c),.s_c_valid(cv),.m_p_data(b),.m_p_valid(bv),.m_p_tag(bt),.m_p_tv(btv),.m_p_svalid(bsv),.dspcasc_p_i(pc));
integer n,seen=0,seed=128371,rv;
reg [14:0] ops[0:7];
always @(posedge clk) begin
 #1;
 if(!rst)begin
  if({av,atv,asv}!=={bv,btv,bsv})$fatal(1,"valid mismatch");
  if(av)begin
   if(a!==b || at!==bt || (^a)===1'bx)$fatal(1,"DSP result mismatch cycle=%d command=%h actual=%h reference=%h",n,cmd,a,b);
   seen=seen+1;
  end
 end
end
initial begin
 ops[0]=15'h0282;ops[1]=15'h1a82;ops[2]=15'h1282;ops[3]=15'h0a82;
 ops[4]=15'h0901;ops[5]=15'h0280;ops[6]=15'h0e01;ops[7]=15'h1e01;
 repeat(4)@(negedge clk);rst=0;
 for(n=0;n<200000;n=n+1)begin
  @(negedge clk);
  rv=$random(seed);go=(rv&3)!=0;valid=(rv&12)!=0;tag=(rv&16)!=0;cv=(rv&32)!=0;
  data={$random(seed),$random(seed),$random(seed)};
  c={$random(seed),$random(seed)};pc={$random(seed),$random(seed)};
  cmd=ops[(rv>>8)&7];
  if(n<16 || n%4096<16)begin cmd=15'h0280;valid=1;go=1;end
  rst=n%4096==4095;
 end
 if(seen<50000)$fatal(1,"insufficient output coverage");
 $display("PASS DSP clock-enable equivalence through 200000 cycles with bubbles, stalls, resets and FIR operations (%d valid outputs)",seen);$finish;
end
endmodule
