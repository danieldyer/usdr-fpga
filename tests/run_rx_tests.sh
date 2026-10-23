#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$root"
# IVERILOG_FLAGS supports an extracted Icarus installation's -B path.
find lib -name "*.v" ! -name ram_sxp.v > "$work/sources.txt"
for test in usdr_ready_test usdr_meas_test usdr_cal_bridge_test usdr_dma_stop_test usdr_rx_flow_test usdr_memwr_drain_test usdr_memwr_order_test usdr_window_test usdr_tx_test_test; do
    "${IVERILOG:-iverilog}" ${IVERILOG_FLAGS:-} -g2005 -Ihw -Ilib/usb -Ilib/pci -Ilib/dsp_fft -s "$test" -o "$work/$test" \
        "tests/$test.v" tests/ram_sxp_model.v sym/xilinx/*.v -c "$work/sources.txt"
    "${VVP:-vvp}" "$work/$test"
done
