`timescale 1ns/1ps
module usdr_memwr_drain_test;
reg clk=0; always #5 clk=~clk;
reg rst=1, request=0, ready=1, rv=0;
wire req_ready, complete, valid, last, arvalid, arid, rready;
wire [63:0] payload;
reg [63:0] rd=64'h0123456789abcdef;
reg rid=0;
al_ram_to_pcie_memwr #(.LOCAL_ADDR_WIDTH(12),.DATA_BITS(3),.EARLY_CNF(0)) dut(
 .clk(clk),.rst(rst),.s_tcq_valid(request),.s_tcq_ready(req_ready),
 .s_tcq_laddr(9'b0),.s_tcq_raddr(29'h2000),.s_tcq_length(6'b0),.s_tcq_tag(1'b0),
 .s_tcq_cvalid(complete),.s_tcq_cready(1'b1),.cfg_pcie_reqid(16'h0100),.cfg_pcie_attr(2'b0),
 .pcie7s_tx_buf_av(6'd32),.pcieus_tx_busy(1'b0),
 .m_axis_tx_tready(ready),.m_axis_tx_tdata(payload),.m_axis_tx_tvalid(valid),.m_axis_tx_tlast(last),
 .m_al_arvalid(arvalid),.m_al_arid(arid),.m_al_arready(1'b1),
 .m_al_rdata(rd),.m_al_rvalid(rv),.m_al_rready(rready),.m_al_rid(rid));
always @(posedge clk) begin
 if(rst) rv<=0;
 else begin
  if(rv && rready)rv<=0;
  if(arvalid)begin rv<=1;rid<=arid;end
 end
end
reg [63:0] held;
initial begin
 repeat(5) @(negedge clk);rst=0;request=1;
 wait(req_ready);@(negedge clk);request=0;
 // The 32-bit-address final DWORD is buffered after the RAM last beat.
 wait(valid && last);@(negedge clk);ready=0;held=payload;
 repeat(12)begin @(negedge clk);
  if(complete || !valid || !last || payload!==held)$fatal(1,"completed or changed a stalled final PCIe beat");
 end
 ready=1;@(negedge clk);
 if(!complete)$fatal(1,"missing completion after final transfer");
 @(negedge clk);if(complete)$fatal(1,"duplicate completion");
 $display("PASS PCIe write completion waits for the accepted final payload beat");$finish;
end
initial begin #10000;$fatal(1,"watchdog");end
endmodule
