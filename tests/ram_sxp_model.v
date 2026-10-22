// SPDX-License-Identifier: CERN-OHL-P
// Simulation model for the vendor distributed RAM primitive only.
module ram_sxp #(parameter DATA_WIDTH=6, ADDR_WIDTH=5, ULTRA_SCALE=0, MODE_SDP=1)
(input wclk, input we, input [ADDR_WIDTH-1:0] waddr, input [DATA_WIDTH-1:0] wdata,
 input [ADDR_WIDTH-1:0] raddr, output [DATA_WIDTH-1:0] rdata);
reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
always @(posedge wclk) if(we) memory[waddr]<=wdata;
assign rdata=memory[MODE_SDP ? raddr : waddr];
endmodule
