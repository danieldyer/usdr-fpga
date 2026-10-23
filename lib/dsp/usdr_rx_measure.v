// SPDX-License-Identifier: CERN-OHL-P
// Single-shot 65536-sample mean or coherent tone measurement. Results stay
// frozen until the next completed window. Generation and clipping travel via
// ordered PHY reads, never by independently synchronizing a multi-bit bus.
module usdr_rx_measure # (parameter WINDOW_BITS = 16)(
    input clk, input rst,
    input [31:0] cmd, input cmd_valid, output reg [31:0] result,
    input [31:0] raw_data, input raw_valid,
    input [31:0] iq_data, input iq_valid, input iq_clipped
);
reg raw_mode, running, finishing;
reg [15:0] phase_low;
reg [31:0] step, phase, generation;
reg [WINDOW_BITS-1:0] count;
reg signed [47:0] sum_i, sum_q;
reg signed [31:0] value_i, value_q;
reg clip_window, clip_result;
wire [31:0] data = raw_mode ? raw_data : iq_data;
wire valid = raw_mode ? raw_valid : iq_valid;
wire input_clip = raw_mode ? (raw_data[15:0] == 16'h8000 || raw_data[15:0] == 16'h7ff0 ||
                             raw_data[31:16] == 16'h8000 || raw_data[31:16] == 16'h7ff0) : iq_clipped;
wire signed [15:0] cosine, sine;
usdr_cal_sincos lut(.clk(clk), .phase(phase[31:20]), .cosine(cosine), .sine(sine));
// Match the three-cycle sine/cosine latency, including gaps in valid.
reg [31:0] data_pipe[0:2];
reg [2:0] valid_pipe, clip_pipe, raw_pipe;
integer k;
reg signed [31:0] ic, qs, is, qc;
reg product_valid, product_clip, product_raw;
reg [31:0] raw_delay;
wire signed [32:0] mixed_i = $signed({ic[31],ic}) - $signed({qs[31],qs});
wire signed [32:0] mixed_q = $signed({is[31],is}) + $signed({qc[31],qc});
reg signed [32:0] sample_i, sample_q;
reg sample_valid, sample_clip;
wire signed [47:0] next_i = sum_i + sample_i;
wire signed [47:0] next_q = sum_q + sample_q;
wire overflow = sum_i[47:31] != {17{sum_i[31]}} ||
                sum_q[47:31] != {17{sum_q[31]}};
always @* begin
    result = 0;
    if (cmd[30:24] == 6) case (cmd[23:16])
        0: result = generation;
        1: result = {31'b0,clip_result};
        4: result = value_i;
        5: result = value_q;
    endcase
end
always @(posedge clk) begin
    if (rst) begin
        raw_mode <= 1; running <= 0; phase_low <= 0; step <= 0; phase <= 0;
        generation <= 0; count <= 0; sum_i <= 0; sum_q <= 0;
        value_i <= 0; value_q <= 0; clip_window <= 0; clip_result <= 0;
        valid_pipe <= 0; clip_pipe <= 0; raw_pipe <= 0;
        product_valid <= 0; product_clip <= 0; product_raw <= 1;
        sample_valid <= 0; sample_clip <= 0; finishing <= 0;
    end else begin
        valid_pipe <= {valid_pipe[1:0], running && valid};
        clip_pipe <= {clip_pipe[1:0], input_clip};
        raw_pipe <= {raw_pipe[1:0], raw_mode};
        data_pipe[0] <= data;
        for (k=1;k<3;k=k+1) data_pipe[k] <= data_pipe[k-1];
        if (running && valid) phase <= phase + step;
        product_valid <= valid_pipe[2];
        product_clip <= clip_pipe[2]; product_raw <= raw_pipe[2];
        ic <= $signed(data_pipe[2][15:0]) * cosine;
        qs <= $signed(data_pipe[2][31:16]) * sine;
        is <= $signed(data_pipe[2][15:0]) * sine;
        qc <= $signed(data_pipe[2][31:16]) * cosine;
        raw_delay <= data_pipe[2];
        sample_valid <= product_valid; sample_clip <= product_clip;
        sample_i <= product_raw ? $signed(raw_delay[15:0]) : (mixed_i >>> 15);
        sample_q <= product_raw ? $signed(raw_delay[31:16]) : (mixed_q >>> 15);
        if (running && sample_valid) begin
            sum_i <= next_i; sum_q <= next_q; count <= count + 1'b1;
            clip_window <= clip_window || sample_clip;
            if (&count) begin running <= 0; finishing <= 1; end
        end
        // Keep the wide accumulator and final overflow check on separate cycles.
        if (finishing) begin
            finishing <= 0;
            value_i <= sum_i[31:0]; value_q <= sum_q[31:0];
            clip_result <= clip_window || overflow;
            generation <= generation + 1'b1;
        end
        if (cmd_valid && !cmd[31] && cmd[30:24] == 6) case (cmd[23:16])
            0: begin
                running <= !cmd[0]; finishing <= 0;
                valid_pipe <= 0; product_valid <= 0; sample_valid <= 0;
                count <= 0; phase <= 0; sum_i <= 0; sum_q <= 0; clip_window <= 0;
            end
            2: phase_low <= cmd[15:0];
            3: step <= {cmd[15:0],phase_low};
            8: raw_mode <= cmd[0];
        endcase
    end
end
endmodule
