# 03 — Architecture

## System Block Diagram

```
                       SYSTEM CLOCK (100 MHz)
                               │
                               │  clk
                               ▼
              ┌────────────────────────────────────┐
              │              spi_top               │
              │                                    │
              │   ┌───────────────────────────┐    │
              │   │        spi_master         │    │
              │   │                           │    │
  start ─────►│   │  ┌──────────────────────┐ │    │
  master_tx ─►│   │  │   clk_divider        │ │    │
              │   │  │   (DIVISOR=CLK_DIV)  │ │    │
              │   │  └──────────┬───────────┘ │    │
              │   │             │ tick         │    │
              │   │  FSM ───────┘             │    │
              │   │  IDLE→TRANSFER→FINISH     │    │
              │   │                           │    │
              │   │  TX shift reg [7:0] ──────┼────┼──► MOSI
              │   │  RX shift reg [7:0] ◄─────┼────┼─── MISO
              │   │  bit_cnt [3:0]            │    │
              │   │  sclk register ───────────┼────┼──► SCLK
              │   │  cs register ─────────────┼────┼──► CS
              │   └───────────────────────────┘    │
              │             MOSI/MISO/SCLK/CS      │
              │   ┌───────────────────────────┐    │
              │   │        spi_slave          │    │
              │   │                           │    │
              │   │  sclk_d (edge detect) ◄───┼────┼─── SCLK
              │   │  FSM: IDLE → ACTIVE       │    │
              │   │                           │    │
              │   │  TX shift reg [7:0] ──────┼────┼──► MISO
              │   │  RX shift reg [7:0] ◄─────┼────┼─── MOSI
              │   │  bit_cnt [3:0]            │    │
  slave_tx ──►│   │                           │    │
              │   └───────────────────────────┘    │
              │                                    │
  master_rx ◄─│                           done ◄───│
  slave_rx ◄──│                           busy ◄───│
              └────────────────────────────────────┘
```

---

## Module Responsibilities

### `clk_divider` — Clock Divider

**Purpose:** Generate a single-cycle tick pulse every `DIVISOR` system-clock cycles.

This tick marks the boundary of each half-SCLK-period. The master uses it to decide when to toggle SCLK.

**Key detail:** The divider is only enabled when the master FSM is in the `TRANSFER` state. This ensures every transaction starts with a fresh clock count — guaranteeing a full half-period of setup time before the first SCLK edge.

```
System clock:  _|‾|_|‾|_|‾|_|‾|_|‾|_
Counter:        0  1  2  3  0  1  2  3
Tick:           ___________________|‾|___
                           (every DIVISOR cycles)
```

**Parameters:** `DIVISOR` (default 4)

---

### `spi_master` — SPI Master Controller

**Purpose:** Own the entire SPI transaction. Assert CS, generate SCLK, shift out TX data on MOSI, sample RX data from MISO, count bits, signal completion.

**FSM States:**

```
         start asserted
IDLE ─────────────────────► TRANSFER ──────────► FINISH ──► IDLE
  CS=1                        CS=0                 CS=1
  SCLK=0                      SCLK toggles         done=1
  busy=0                      busy=1               busy=0
                               bit_cnt 0→8
```

**Internal datapath:**

```
tx_data (byte in)
    │ latched on start
    ▼
tx_shift [7:0]  ──── MOSI (MSB first)
                       │ shifts left on each SCLK falling edge

MISO ──────────────► rx_shift [7:0]
                       │ samples on each SCLK rising edge
                       ▼
                  rx_data (byte out, valid on done)
```

**Critical design note:** SCLK is a **register** (`sclk <= 1'b1` / `sclk <= 1'b0`). It is NOT used as a clock to trigger other flip-flops. This is a deliberate single-clock-domain design choice that avoids clock domain crossing issues.

---

### `spi_slave` — SPI Slave Controller

**Purpose:** Respond to the master. Detect SCLK edges using a delayed-SCLK register, sample MOSI, shift out MISO, count bits, signal when 8 bits are received.

**Key mechanism — SCLK edge detection:**

```
System clock:  _|‾|_|‾|_|‾|_|‾|_
SCLK:          _____|‾‾‾‾‾‾|______
sclk_d:        ________|‾‾‾‾‾‾|___
                        │     │
               rising   │     │ falling
               (sclk_d=0, sclk=1)   (sclk_d=1, sclk=0)
```

This pattern detects edges without using `posedge sclk` — keeping everything in the single system-clock domain.

**Preloading MISO:**
While in IDLE state, the slave continuously drives `miso <= tx_data[7]`. This guarantees that MISO is already valid at the instant CS drops — satisfying the CPHA=0 requirement that data is stable before the first rising clock edge.

---

### `spi_top` — Top-Level Structural Wrapper

**Purpose:** Wire master and slave together. Contains zero logic — pure port connections.

```
spi_top
  ├── u_master (spi_master)
  └── u_slave  (spi_slave)

Connections:
  master.mosi  →  slave.mosi
  master.sclk  →  slave.sclk
  master.cs    →  slave.cs
  slave.miso   →  master.miso
```

---

## Transaction Timeline

A complete 8-bit transaction with `Master TX = 0xA5`, `Slave TX = 0x5A`:

```
Cycle:     0   1   2   3   4   5   6   7   8   9  10 ...
           │   │   │   │   │   │   │   │   │   │
CS:        ‾‾‾‾‾\________________________/‾‾‾‾‾‾‾
                 ↑ asserts                ↑ deasserts

MOSI:      ‾‾‾‾‾1___0___1___0___0___1___0___1___
           (bit7=1, bit6=0, ... bit0=1 of 0xA5=10100101)

SCLK:      _______|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
                   ↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑  (8 rising edges)
                   Sample MISO on each ↑

MISO:      ‾‾‾‾‾0___1___0___1___1___0___1___0___
           (bit7=0, bit6=1, ... bit0=0 of 0x5A=01011010)

After transaction:
  master_rx_data = 0x5A  (received from slave)
  slave_rx_data  = 0xA5  (received from master)
```

---

## Clocking Architecture Summary

| Signal | Type | Domain |
|---|---|---|
| `clk` | Real clock | System — all flip-flops use this |
| `sclk` | Register | Driven by `spi_master` FSM — NOT a clock |
| `tick` | Combinational pulse | Output of `clk_divider` — gating signal for FSM |

**Why SCLK is not used as a real clock:**

If the slave were written as `always @(posedge sclk)`, that would create a second clock domain. SCLK would need to be treated as an independent clock net, requiring a clock constraint and potentially CDC synchronizers. By deriving SCLK from the same system clock and detecting its edges with `sclk_d`, this design stays entirely in one clock domain, making it simpler, more synthesis-friendly, and easier to verify.

This is a deliberate design decision worth explaining in an interview.
