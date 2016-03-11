#!/bin/bash
REPO_ROOT=".."
CWD="$(pwd)"

cd $REPO_ROOT
cp -v --parents \
x393/simulation_modules/simul_axi_master_wraddr.v \
x393/simulation_modules/simul_axi_master_rdaddr.v \
x393/simulation_modules/simul_axi_master_wdata.v \
x393/simulation_modules/simul_axi_slow_ready.v \
x393/simulation_modules/simul_axi_hp_rd.v \
x393/simulation_modules/simul_axi_hp_wr.v \
x393/simulation_modules/simul_axi_read.v \
x393/util_modules/fifo_same_clock_fill.v \
x393/util_modules/dly_16.v \
x393/util_modules/axi_hp_clk.v \
x393/simulation_modules/simul_fifo.v \
x393/simulation_modules/simul_axi_fifo_out.v \
x393/util_modules/dly01_16.v \
x393/wrap/pll_base.v \
x393/wrap/ram18p_var_w_var_r.v \
x393/util_modules/fifo_sameclock_control.v \
x393/util_modules/pulse_cross_clock.v \
x393/axi/axibram_read.v \
x393/wrap/ram_var_w_var_r.v \
x393/wrap/ramt_var_wb_var_r.v \
x393/util_modules/fifo_cross_clocks.v \
x393/axi/axibram_write.v \
x393/util_modules/fifo_same_clock.v \
x393/util_modules/resync_data.v \
x393/wrap/ramt_var_w_var_r.v \
x393/glbl.v \
$CWD
cd $CWD
