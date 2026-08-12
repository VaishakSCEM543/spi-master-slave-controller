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
| Waveform screenshot | ⚠️ Pending commit |
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
├── docs/                         ← Technical documentation
│   ├── 01-project-definition.md
│   ├── 02-requirements.md
│   ├── 03-architecture.md
│   ├── 04-spi-fundamentals.md
│   ├── 05-spi-mode-0.md
│   ├── 06-rtl-design.md
│   ├── 07-verilog-concepts.md
│   ├── 08-verification.md
│   ├── 09-debugging.md
│   ├── 10-limitations.md
│   └── 11-future-improvements.md
│
├── learning/                     ← Personal learning journal
│   ├── learning-log.md
│   ├── concepts-mastered.md
│   ├── questions-to-revisit.md
│   └── interview-preparation.md
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

## Documentation

The `docs/` folder contains further reading for design rationale and interview depth. These are NOT required reading for evaluating the core deliverable, but they demonstrate the structured engineering approach:

1. [`01-project-definition.md`](docs/01-project-definition.md)
2. [`02-requirements.md`](docs/02-requirements.md)
3. [`03-architecture.md`](docs/03-architecture.md)
4. [`04-spi-fundamentals.md`](docs/04-spi-fundamentals.md)
5. [`05-spi-mode-0.md`](docs/05-spi-mode-0.md)
6. [`06-rtl-design.md`](docs/06-rtl-design.md)
7. [`07-verilog-concepts.md`](docs/07-verilog-concepts.md)
8. [`08-verification.md`](docs/08-verification.md)
9. [`09-debugging.md`](docs/09-debugging.md)
10. [`10-limitations.md`](docs/10-limitations.md)
11. [`11-future-improvements.md`](docs/11-future-improvements.md)

---

## Learning Journal

The `learning/` directory contains my personal study notes, concepts mastered trackers, and interview preparation materials. These files are kept in the repository for transparency regarding the learning journey, but they are an internal tracker and not part of the primary engineering deliverable.

---

## License

MIT — see [`LICENSE`](LICENSE)
