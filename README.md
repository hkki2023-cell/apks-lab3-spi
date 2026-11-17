# Лабораторна робота №3 — SPI Master на ПЛІС (VHDL)

| | |
|---|---|
| Студент | Кузнєцов Григорій Д., КІ-409 |
| Варіант | 9 — SPI, VHDL |
| Режим SPI | mode 0 (CPOL = 0, CPHA = 0), 8 біт, MSB first |
| Цільова ПЛІС | Lattice iCE40 HX8K (відкритий маршрут Yosys + nextpnr) |

## Структура
```
rtl/spi_tx.vhd        передавач (зсувний регістр MOSI)
rtl/spi_rx.vhd        приймач (зсувний регістр MISO)
rtl/spi_master.vhd    керування: FSM, дільник SCLK, SS_N
tb/tb_spi_master.vhd  самоперевірний тестбенч + модель SPI slave
sim/run_sim.sh        симуляція GHDL -> build/spi.ghw
sim/spi.gtkw          набір сигналів для GTKWave
syn/synth.sh          синтез Yosys + P&R/таймінг nextpnr (iCE40)
docs/fsm.png          діаграма станів
```

## Запуск (WSL Ubuntu)
```bash
sudo apt install ghdl gtkwave yosys nextpnr-ice40 yosys-plugin-ghdl
./sim/run_sim.sh                     # очікується: TEST PASSED: 5 transfers, 0 errors
gtkwave build/spi.ghw sim/spi.gtkw   # осцилограми
./syn/synth.sh                       # ресурси (LUT, DFF) і Max frequency
```
