# SPI Master–Slave Controller

An 8-bit SPI Mode 0 Master–Slave Controller designed from scratch using synthesizable Verilog RTL.

This is not a firmware driver that configures a microcontroller's existing SPI peripheral. This is the **hardware design** of an SPI controller — the same kind that lives inside a microcontroller chip. The design transfers 8 bits full-duplex in a single SPI transaction.

---

## Project Status

| Stage | Status |
|---|---|
| RTL design and implementation | ✅ DONE |
| Behavioral simulation (Vivado) | ✅ DONE — ALL CHECKS PASSED |
| Self-checking testbench | ✅ DONE |
| Waveform screenshot | ✅ DONE |
| Synthesis (Vivado) | ❌ NOT YET |
| FPGA implementation and programming | ❌ NOT YET |
| Physical SPI hardware validation | ❌ NOT YET |

> This repository is an honest learning project. Claims are backed by evidence. Distinctions between simulation and hardware validation are explicitly stated.

---

## Verified Result

The design was verified in behavioral simulation using a self-checking testbench.

**Expected output:**
```
---------------------------------------------
Master TX = 10100101 (0xA5)
Slave  TX = 01011010 (0x5A)
Master RX = 01011010 (0x5A)  expected 01011010 (0x5A)
Slave  RX = 10100101 (0xA5)  expected 10100101 (0xA5)
SCLK rising edges during CS low = 8 (expected 8)
Final CS = 1 (expected 1)
---------------------------------------------
RESULT: ALL CHECKS PASSED
```

SPI Transaction Overview:

![SPI Transaction Waveform](waveforms/tc01-spi-transaction.jpeg)

```
CS:   ‾‾‾‾‾‾\_________________________/‾‾‾‾‾‾
SCLK: ________|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|___
MOSI: ________1___0___1___0___0___1___0___1___   ← 0xA5
MISO: ________0___1___0___1___1___0___1___0___   ← 0x5A
              ↑↑↑↑↑↑↑↑ 8 rising edges = 8 bits
```

---

## Quick Start

### Simulate with Vivado

1. Open Vivado → Create RTL Project
2. **Design Sources:** add `rtl/clk_divider.v`, `rtl/spi_master.v`, `rtl/spi_slave.v`, `rtl/spi_top.v`
3. **Simulation Sources:** add `sim/tb_spi_top.v`
4. Set `tb_spi_top` as Simulation Top
5. Run Behavioral Simulation
6. Check Tcl console: should show `RESULT: ALL CHECKS PASSED`

### Simulate with Icarus Verilog (Free)

```bash
iverilog -o sim.out \
  rtl/clk_divider.v \
  rtl/spi_master.v \
  rtl/spi_slave.v \
  rtl/spi_top.v \
  sim/tb_spi_top.v

vvp sim.out
# optional: gtkwave tb_spi_top.vcd
```

---

## Repository Structure

```
spi-master-slave-controller/
│
├── rtl/                          ← Synthesizable Verilog RTL
│   ├── clk_divider.v
│   ├── spi_master.v
│   ├── spi_slave.v
│   └── spi_top.v
│
├── sim/                          ← Simulation files
│   └── tb_spi_top.v
│
├── verification/                 ← Verification records
│   ├── test-cases.md
│   ├── expected-results.md
│   └── results.md
│
├── diagrams/                     ← Block and timing diagrams (planned)
│   └── README.md
│
├── waveforms/                    ← Vivado waveform screenshots
│   └── README.md
│
├── vivado/                       ← Vivado project recreation guide
│   └── README.md
│
├── .gitignore                    Excludes Vivado-generated files
└── LICENSE                       MIT
```

---

## License

MIT — see [`LICENSE`](LICENSE)
