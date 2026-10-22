// SPDX-License-Identifier: CERN-OHL-P
// Calibration-only DDS. Normal transmit samples bypass this block.
module usdr_tx_test(
    input clk, input rst, input advance,
    input [31:0] cmd, input cmd_valid,
    output reg enabled, output [31:0] data
);
reg [31:0] phase, step;
reg [15:0] phase_low;
reg signed [15:0] amp_i, amp_q;
wire signed [15:0] cosine, sine;
usdr_cal_sincos lut(.phase(phase[31:20]), .cosine(cosine), .sine(sine));
reg signed [31:0] ic, qs, is, qc;
always @(posedge clk) begin
    ic <= amp_i * cosine; qs <= amp_q * sine;
    is <= amp_i * sine; qc <= amp_q * cosine;
end
wire signed [32:0] vi = $signed({ic[31],ic}) - $signed({qs[31],qs});
wire signed [32:0] vq = $signed({is[31],is}) + $signed({qc[31],qc});
reg [31:0] samples;
assign data = samples;
always @(posedge clk) begin
    if (rst) samples <= 0;
    else samples <= {vq[30:15], vi[30:15]};
end
always @(posedge clk) begin
    if (rst) begin
        enabled <= 0; phase <= 0; step <= 0; phase_low <= 0; amp_i <= 0; amp_q <= 0;
    end else begin
        if (enabled && advance) phase <= phase + step;
        if (cmd_valid && !cmd[31]) case (cmd[30:24])
            0: if (cmd[8]) phase <= 0;
            7: case (cmd[23:16])
                0: begin enabled <= cmd[0]; phase <= 0; end
                4: amp_i <= cmd[15:0];
                5: amp_q <= cmd[15:0];
            endcase
            8: phase_low <= cmd[15:0];
            9: begin step <= {cmd[15:0],phase_low}; phase <= 0; end
        endcase
    end
end
endmodule
