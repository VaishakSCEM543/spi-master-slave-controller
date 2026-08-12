# SPI Master–Slave Controller

An **8-bit SPI Mode 0 Master–Slave Controller** designed from scratch using synthesizable Verilog RTL.

This is not a firmware driver that configures a microcontroller's existing SPI peripheral.  
This is the **hardware design** of an SPI controller — the same kind that lives inside a microcontroller chip.

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

## What Was Built

```
spi_top (structural wrapper)
  ├── spi_master
  │     ├── clk_divider (internal)
  │     ├── TX shift register
  │     ├── RX shift register
  │     ├── Bit counter
  │     └── FSM: IDLE → TRANSFER → FINISH
  └── spi_slave
        ├── SCLK edge detector (sclk_d pattern)
        ├── TX shift register
        ├── RX shift register
        └── FSM: IDLE → ACTIVE
```

### Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| SPI Mode | Mode 0 (CPOL=0, CPHA=0) | Simplest mode; most common default |
| Data width | 8 bits | Standard byte transfer |
| Bit order | MSB first | Conventional standard |
| Clock architecture | Single system clock domain | Avoids CDC complexity |
| SCLK implementation | Register (not real clock net) | Slave uses `sclk_d` for edge detection; no second clock domain |
| Reset | Asynchronous active-high | Clean power-up and testbench reset |

---

## Repository Structure

```
spi-master-slave-controller/
│
├── rtl/                          ← Synthesizable Verilog RTL
│   ├── clk_divider.v             Clock divider (tick generator)
│   ├── spi_master.v              SPI master controller
│   ├── spi_slave.v               SPI slave controller
│   └── spi_top.v                 Structural top-level wrapper
│
├── sim/                          ← Simulation files
│   └── tb_spi_top.v              Self-checking testbench (Verilog-2001)
│
├── docs/                         ← Technical documentation
│   ├── 01-project-definition.md  Problem, goal, and honest status
│   ├── 02-requirements.md        Protocol, architecture, and functional requirements
│   ├── 03-architecture.md        Block diagrams, module roles, transaction timeline
│   ├── 04-spi-fundamentals.md    SPI from absolute basics to interview depth
│   ├── 05-spi-mode-0.md          CPOL/CPHA, Mode 0 timing, sample/shift behavior
│   ├── 06-rtl-design.md          Module-by-module RTL explanation with datapaths
│   ├── 07-verilog-concepts.md    Every Verilog construct used, with hardware meaning
│   ├── 08-verification.md        Testbench structure, checks, results, how to reproduce
│   ├── 09-debugging.md           Three real bugs encountered and fixed
│   ├── 10-limitations.md         Current constraints, honestly described
│   ├── 11-future-improvements.md Near, medium, and long-term improvement roadmap
│   └── 12-interview-preparation.md 25 Q&A from basics to CDC and metastability
│
├── learning/                     ← Personal learning journal
│   ├── learning-log.md           Initial understanding, corrections, discoveries
│   ├── concepts-mastered.md      Status tracking per topic
│   └── questions-to-revisit.md   Open questions and interview practice list
│
├── verification/                 ← Verification records
│   ├── test-cases.md             All test cases (TC-01 passed, others planned)
│   ├── expected-results.md       Bit-by-bit expected outputs
│   └── results.md                Actual simulation results
│
├── diagrams/                     ← Block and timing diagrams (planned)
│   └── README.md
│
├── waveforms/                    ← Vivado waveform screenshots
│   └── README.md                 Capture instructions (screenshots pending)
│
├── vivado/                       ← Vivado project recreation guide
│   └── README.md
│
├── .gitignore                    Excludes Vivado-generated files
└── LICENSE                       MIT
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

---

## SPI Transaction Overview

The design transfers 8 bits full-duplex in a single SPI transaction:

```
CS:   ‾‾‾‾‾‾\_________________________/‾‾‾‾‾‾
SCLK: ________|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|___
MOSI: ________1___0___1___0___0___1___0___1___   ← 0xA5
MISO: ________0___1___0___1___1___0___1___0___   ← 0x5A
              ↑↑↑↑↑↑↑↑ 8 rising edges = 8 bits
```

After the transaction:
- `master_rx_data` = `0x5A` (received from slave)
- `slave_rx_data` = `0xA5` (received from master)

---

## SPI Mode 0

| Parameter | Value | Meaning |
|---|---|---|
| CPOL | 0 | Clock idles LOW |
| CPHA | 0 | Sample on FIRST (rising) edge |
| Shift edge | Falling | New bit driven on falling edge |
| Idle SCLK | 0 | |

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `CLK_DIV` | 4 | System clock cycles per SCLK half-period |

At 100 MHz system clock and `CLK_DIV=4`:  
SCLK half-period = 40 ns → SCLK = 12.5 MHz

---

## Documentation

All documentation is in `docs/`. Start with:

1. [`01-project-definition.md`](docs/01-project-definition.md) — What was built and why
2. [`04-spi-fundamentals.md`](docs/04-spi-fundamentals.md) — SPI from the ground up
3. [`06-rtl-design.md`](docs/06-rtl-design.md) — How the RTL works
4. [`12-interview-preparation.md`](docs/12-interview-preparation.md) — 25 interview questions

---

## About This Project

This repository was built as part of VLSI/RTL interview preparation for Mirafra Technologies (2026).

The goal was to document the complete engineering journey — not just upload source files:
- Requirements before implementation
- Architecture before code
- Verification evidence alongside code
- Honest status for every claim
- Learning notes documenting real understanding, real corrections, and real gaps

The learning notes in `learning/` record the actual journey, including the acknowledgment that the initial implementation was followed without full understanding, and the subsequent work to develop genuine knowledge of every module.

---

## License

MIT — see [`LICENSE`](LICENSE)
