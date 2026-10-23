// SPDX-License-Identifier: CERN-OHL-P
// Decode the first non-bypassed downstream stage alongside the existing
// registered bypass controls. The ready path then uses a parallel one-hot mux
// instead of traversing a chain of bypass multiplexers. No extra stall latency.
module reconf_dsp_ready #(parameter STAGES=8)(
    input clk,
    input [STAGES-1:0] bypass_next,
    input [STAGES-1:0] dsp_ready,
    input last_bypass_ready,
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
    wire [STAGES-1:0] mask = select_stage(bypass_next, i);
    reg [STAGES-1:0] selected_dsp;
    reg selected_bypass;
    always @(posedge clk) begin
        selected_dsp <= mask & ~bypass_next;
        selected_bypass <= mask[STAGES-1] && bypass_next[STAGES-1];
    end
    // Exactly one downstream source is selected. Decode its stall condition
    // so the local valid/ready terms can share a LUT with the selection bit.
    assign group_ready[i] = !(|(selected_dsp & ~dsp_ready) ||
                             (selected_bypass && !last_bypass_ready));
end endgenerate
endmodule
