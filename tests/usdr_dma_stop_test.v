`timescale 1ns/1ps
module usdr_dma_stop_test;
reg clk=0; always #5 clk=~clk;
reg rst=1, control_valid=0, ready=0, done=0;
reg [2:0] control=0;
wire [31:0] status;
wire valid;
wire [11:0] local_addr;
wire [27:0] remote_addr;
dma_rxrq_us dut(.clk(clk),.rst(rst),
 .s_al_waddr(8'b0),.s_al_wdata(32'b0),.s_al_wvalid(1'b0),
 .axis_control_data(control),.axis_control_valid(control_valid),
 .axis_confirm_valid(1'b0),.axis_stat_data(status),.axis_stat_ready(1'b0),
 .axis_fburts_ready(1'b0),.axis_fbuffs_ready(1'b0),.int_ready(1'b1),.stat_cnf_valid(1'b0),
 .inplace_cnf_enabled(1'b0),.inplace_cnf_ready(1'b0),.cfg_max_payload_sz(2'b0),.fe_stat(6'b0),
 .m_tcq_valid(valid),.m_tcq_ready(ready),.m_tcq_laddr(local_addr),.m_tcq_raddr(remote_addr),
 .m_tcq_cvalid(done),.m_tcq_ctag(5'b0),.fifo_burst_avail_z(11'b0),
 .fifo_burst_skip(1'b0),.fifo_burst_fill(1'b0),.fifo_burst_mlowmrk(1'b0));
initial begin
 repeat(4) @(negedge clk); rst=0;
 // Inject one queued descriptor to isolate the stop transition. The actual
 // control, request stall, completion and status logic execute unmodified.
 force dut.mem_wr_event=0;
 dut.dma_en=1; dut.req_tag_busy=1; dut.req_tag_dummy=0;
 dut.req_trans_last=1; dut.m_tcq_dma_done=1;
 dut.m_tcq_valid=1; dut.m_tcq_laddr=12'h123; dut.m_tcq_raddr=28'h1234567;
 control=0; control_valid=1; @(negedge clk); control_valid=0;
 repeat(8) begin
  @(negedge clk);
  if(!valid || local_addr!==12'h123 || remote_addr!==28'h1234567 || status[31:30]!==2'b10)
   $fatal(1,"stop changed an outstanding descriptor or advertised idle");
 end
 ready=1; @(negedge clk); ready=0;
 repeat(8) begin @(negedge clk); if(valid || status[31:30]!==2'b10) $fatal(1,"did not wait for completion"); end
 done=1; @(negedge clk); done=0;
 repeat(3) @(negedge clk);
 if(status[31:30]!==0) $fatal(1,"drain did not complete");
 $display("PASS DMA stop preserves stalled descriptors and waits for completion"); $finish;
end
initial begin #10000; $fatal(1,"watchdog"); end
endmodule
