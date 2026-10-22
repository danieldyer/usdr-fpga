`timescale 1ns/1ps
module usdr_memwr_order_test;
reg clk=0;always #5 clk=~clk;
reg rst=1,complete_ready=0,rv=0,rid=0;
integer requests=0,completed=0,packets=0;
wire ready,complete,valid,last,arvalid,arid,rready;
wire [1:0] tag;
al_ram_to_pcie_memwr #(.LOCAL_ADDR_WIDTH(12),.DATA_BITS(4),.ULTRA_SCALE(1),.MEM_TAG(2),.EARLY_CNF(0)) dut(
 .clk(clk),.rst(rst),.s_tcq_valid(requests<3),.s_tcq_ready(ready),
 .s_tcq_laddr(8'b0),.s_tcq_raddr(28'h2000),.s_tcq_length(6'b0),.s_tcq_tag(requests[1:0]),
 .s_tcq_cvalid(complete),.s_tcq_cready(complete_ready),.s_tcq_ctag(tag),
 .cfg_pcie_reqid(16'h0100),.cfg_pcie_attr(2'b0),.pcie7s_tx_buf_av(6'd32),.pcieus_tx_busy(1'b0),
 .m_axis_tx_tready(1'b1),.m_axis_tx_tvalid(valid),.m_axis_tx_tlast(last),
 .m_al_arvalid(arvalid),.m_al_arid(arid),.m_al_arready(!rv || rready),
 .m_al_rdata(128'h1234),.m_al_rvalid(rv),.m_al_rready(rready),.m_al_rid(rid));
always @(posedge clk)begin
 if(rst)rv<=0;
 else begin
  if(ready && requests<3)requests<=requests+1;
  if(rv && rready)rv<=0;
  if(arvalid && (!rv || rready))begin rv<=1;rid<=arid;end
  if(valid && last)packets=packets+1;
  if(complete)begin
   if(tag!==completed[1:0] || packets<=completed)$fatal(1,"completion tag overwritten or completion too early");
   if(complete_ready)completed=completed+1;
  end
 end
end
initial begin
 repeat(5)@(negedge clk);rst=0;
 wait(complete);repeat(12)@(negedge clk);
 if(!complete || tag!==0 || completed!=0)$fatal(1,"completion was not held");
 complete_ready=1;wait(completed==3);repeat(5)@(negedge clk);
 if(packets!=3 || requests!=3 || complete)$fatal(1,"missing or duplicate transfer");
 $display("PASS back-to-back PCIe requests preserve completion tags under backpressure");$finish;
end
initial begin #10000;$fatal(1,"watchdog");end
endmodule
