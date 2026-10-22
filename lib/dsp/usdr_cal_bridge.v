// SPDX-License-Identifier: CERN-OHL-P
// Ordered PHY commands and read responses across the converter clock boundary.
module usdr_cal_bridge #(parameter TIMEOUT_BITS = 24)(
    input host_clk, input host_rst,
    input [31:0] host_data, input host_valid, output host_ready,
    output [31:0] host_rdata, output host_rvalid, input host_rready,
    input cal_clk, input cal_rst,
    output [31:0] cmd, output cmd_valid, input [31:0] result
);
wire pending, response_ready;
wire command_ready, return_valid;
wire [31:0] return_data;
reg fault, read_pending;
reg [TIMEOUT_BITS-1:0] watchdog;
// A missing converter clock must not hang a PCIe read indefinitely. Once a
// timeout occurs, quarantine this bridge until reset and return poison reads.
// Delayed responses from the stopped clock cannot masquerade as a later read.
assign host_ready = fault || command_ready;
assign host_rvalid = fault ? read_pending : return_valid;
assign host_rdata = fault ? 32'hffffffff : return_data;
always @(posedge host_clk) begin
    if (host_rst) begin fault <= 0; read_pending <= 0; watchdog <= 0; end
    else begin
        if (host_valid && host_ready && host_data[31]) read_pending <= 1;
        if (host_rvalid && host_rready) read_pending <= 0;
        if ((host_valid && !host_ready) || (read_pending && !host_rvalid)) begin
            watchdog <= watchdog + 1'b1;
            if (&watchdog) fault <= 1;
        end else watchdog <= 0;
    end
end
wire consume = !cmd[31] || response_ready;
assign cmd_valid = pending && consume;
axis_cc_fifo #(.WIDTH(32), .DEEP_BITS(3)) commands (
    .rx_clk(host_clk), .rx_rst(host_rst),
    .s_rx_tdata(host_data), .s_rx_tvalid(host_valid && !fault), .s_rx_tready(command_ready),
    .tx_clk(cal_clk), .tx_rst(cal_rst),
    .m_tx_tdata(cmd), .m_tx_tvalid(pending), .m_tx_tready(consume)
);
axis_cc_fifo #(.WIDTH(32), .DEEP_BITS(3)) responses (
    .rx_clk(cal_clk), .rx_rst(cal_rst),
    .s_rx_tdata(result), .s_rx_tvalid(pending && cmd[31]), .s_rx_tready(response_ready),
    .tx_clk(host_clk), .tx_rst(host_rst),
    .m_tx_tdata(return_data), .m_tx_tvalid(return_valid), .m_tx_tready(host_rready || fault)
);
endmodule
