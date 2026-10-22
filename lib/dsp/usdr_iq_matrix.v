// SPDX-License-Identifier: CERN-OHL-P
// Q1.23 coefficients; commit all four when bank 5 is written. No DC filter.
module usdr_iq_matrix(
    input clk, input rst,
    input [31:0] cmd, input cmd_valid,
    input [31:0] in_data, input in_valid,
    output reg [31:0] out_data, output reg out_valid,
    output reg clipped
);
reg signed [23:0] staged_i, staged_q, staged_qi;
reg signed [23:0] ci, cq, cqi, ciq;
reg signed [39:0] ii, qq, iq, qi;
reg products_valid;
wire signed [40:0] si = {ii[39],ii} + {iq[39],iq} + 41'sd4194304;
wire signed [40:0] sq = {qq[39],qq} + {qi[39],qi} + 41'sd4194304;
function [15:0] saturate;
    input signed [40:0] value;
    begin
        if ((value >>> 23) > 32767) saturate = 16'h7fff;
        else if ((value >>> 23) < -32768) saturate = 16'h8000;
        else saturate = value[38:23];
    end
endfunction
always @(posedge clk) begin
    if (rst) begin
        ci <= 24'h7fffff; cq <= 24'h7fffff; cqi <= 0; ciq <= 0;
        staged_i <= 24'h7fffff; staged_q <= 24'h7fffff; staged_qi <= 0;
        products_valid <= 0; out_valid <= 0; out_data <= 0; clipped <= 0;
    end else begin
        if (cmd_valid && !cmd[31]) case (cmd[30:24])
            2: staged_i <= cmd[23:0];
            3: staged_q <= cmd[23:0];
            4: staged_qi <= cmd[23:0];
            5: begin ci <= staged_i; cq <= staged_q; cqi <= staged_qi; ciq <= cmd[23:0]; end
        endcase
        products_valid <= in_valid;
        if (in_valid) begin
            ii <= $signed(in_data[15:0]) * ci;
            qq <= $signed(in_data[31:16]) * cq;
            iq <= $signed(in_data[31:16]) * ciq;
            qi <= $signed(in_data[15:0]) * cqi;
        end
        out_valid <= products_valid;
        clipped <= products_valid && (((si >>> 23) > 32767) || ((si >>> 23) < -32768) ||
                                     ((sq >>> 23) > 32767) || ((sq >>> 23) < -32768));
        if (products_valid) out_data <= {saturate(sq), saturate(si)};
    end
end
endmodule
