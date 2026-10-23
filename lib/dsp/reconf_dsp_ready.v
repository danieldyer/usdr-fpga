// SPDX-License-Identifier: CERN-OHL-P
// Decode the first non-bypassed downstream stage alongside the existing
// registered bypass controls. The ready path then uses a parallel one-hot mux
// instead of traversing a chain of bypass multiplexers. No extra stall latency.
module reconf_dsp_ready #(parameter STAGES=8)(
    input clk,
    input [STAGES-1:0] bypass_next,
    input [STAGES-1:0] local_ready,
    output [STAGES-1:0] group_ready
);
function [STAGES-1:0] select_stage;
    input [STAGES-1:0] bypass;
    input integer start;
    integer j;
    reg found;
    begin
        select_stage = 0; found = 0;
        for (j=0;j<STAGES;j=j+1) begin
            if (j>=start && !found && (!bypass[j] || j==STAGES-1)) begin
                select_stage[j] = 1; found = 1;
            end
        end
    end
endfunction
genvar i;
generate for(i=0;i<STAGES;i=i+1) begin: stage
    reg [STAGES-1:0] selected;
    always @(posedge clk) selected <= select_stage(bypass_next, i);
    assign group_ready[i] = |(selected & local_ready);
end endgenerate
endmodule
