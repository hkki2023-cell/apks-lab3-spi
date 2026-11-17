#!/usr/bin/env bash
# Functional simulation with GHDL (VHDL-2008).
# Waveform: build/spi.ghw -> gtkwave build/spi.ghw sim/spi.gtkw
# Install once (WSL Ubuntu): sudo apt install ghdl gtkwave
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
FLAGS="--std=08 --workdir=build"
ghdl -a $FLAGS rtl/spi_tx.vhd rtl/spi_rx.vhd rtl/spi_master.vhd
ghdl -a $FLAGS tb/tb_spi_master.vhd
ghdl -e $FLAGS tb_spi_master
ghdl -r $FLAGS tb_spi_master --wave=build/spi.ghw --stop-time=20us \
  | tee build/sim.log
echo "Waveform: build/spi.ghw"
