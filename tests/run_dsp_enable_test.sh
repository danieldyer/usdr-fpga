#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$root"
# Set DSP48_MODEL to Vivado/data/verilog/src/unisims/DSP48E1.v for the AMD model.
model=${DSP48_MODEL:-sym/xilinx/DSP48E1.v}
for reset in 0 1; do
    for stall in 0 1; do
        "${IVERILOG:-iverilog}" ${IVERILOG_FLAGS:-} -g2005 -s usdr_dsp_enable_test -s glbl \
            -Pusdr_dsp_enable_test.RESET_DSP=$reset -Pusdr_dsp_enable_test.NO_STALL=$stall \
            -o "$work/proof" tests/usdr_dsp_enable_test.v tests/dsp48e1_pipeline_reference.v \
            lib/xilinx/dsp48e1_pipeline.v "$model"
        "${VVP:-vvp}" "$work/proof"
    done
done
