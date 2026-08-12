# 06 — RTL Design

RTL means **Register Transfer Level**.

It is a way of describing digital hardware in terms of:
- What data is stored in **registers** (flip-flops)
- How data is **transferred** between registers
- When those transfers happen (usually on a **clock edge**)

RTL is not a program that executes sequentially.  
It describes **hardware that operates in parallel** every clock cycle.

---

## Module 1: `clk_divider`

### What It Does

Takes a fast system clock and produces a slow **tick** pulse — one per `DIVISOR` clock cycles.  
This tick is the heartbeat of the SPI clock.

### Why It Exists

SPI peripherals often run slower than the system clock.  
For example: System = 100 MHz, SPI = 12.5 MHz.  
The divider bridges that speed difference.

### Hardware It Represents

```
System clock ─── [32-bit counter] ─── compare to DIVISOR-1 ─── one-cycle tick
```

Every time the counter reaches `DIVISOR-1`, it resets to 0 and emits a single-cycle pulse.

### Inputs / Outputs

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst` | input | 1 | Async active-high reset |
| `enable` | input | 1 | When low, counter stays at 0 |
| `tick` | output | 1 | One-cycle pulse every DIVISOR cycles |

### Internal State

| Register | Width | Purpose |
|---|---|---|
| `cnt` | 32 bits | Counts system-clock cycles |
| `tick` | 1 bit | Output pulse register |

### Key Design Decision

The divider is enabled only when `spi_master` is in `TRANSFER` state.  
This guarantees each transaction starts with a fresh counter — the first SCLK edge always arrives exactly `DIVISOR` cycles after the transaction begins.

---

## Module 2: `spi_master`

### What It Does

Owns the entire SPI transaction:
1. Waits for `start`
2. Asserts CS low
3. Pre-loads MOSI with MSB
4. Generates SCLK by toggling a register on each `tick`
5. Samples MISO on SCLK rising edges
6. Shifts MOSI on SCLK falling edges
7. Counts bits (stops at 8)
8. Deasserts CS, pulses `done`

### Why It Exists

In real SPI hardware (inside a chip), there must be a controller that manages all the signaling. This FSM is that controller.

### Hardware It Represents

```
┌────────────────────────────────────────┐
│              spi_master                │
│                                        │
│   ┌──────┐    ┌──────────────────┐     │
│   │ FSM  │    │  clk_divider     │     │
│   │IDLE  │◄───│  (tick gen)      │     │
│   │TRANS │    └──────────────────┘     │
│   │FINISH│                             │
│   └──┬───┘                             │
│      │                                 │
│   ┌──▼───────────┐                     │
│   │  TX shift reg│──────────────► MOSI │
│   │  [7:0]       │                     │
│   └──────────────┘                     │
│                                        │
│   ┌──────────────┐                     │
│   │  RX shift reg│◄───────────── MISO  │
│   │  [7:0]       │──────────────► rx_data│
│   └──────────────┘                     │
│                                        │
│   ┌──────────────┐                     │
│   │  bit_cnt[3:0]│ (0 to 8)           │
│   └──────────────┘                     │
│                                        │
│   sclk register ──────────────────► SCLK│
│   cs   register ──────────────────► CS  │
└────────────────────────────────────────┘
```

### Inputs / Outputs

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst` | input | 1 | Async reset |
| `start` | input | 1 | Pulse to begin transaction |
| `tx_data` | input | 8 | Byte to transmit |
| `miso` | input | 1 | SPI data in |
| `rx_data` | output | 8 | Byte received, valid on `done` |
| `busy` | output | 1 | High during transaction |
| `done` | output | 1 | Single-cycle pulse on completion |
| `mosi` | output | 1 | SPI data out |
| `sclk` | output | 1 | SPI clock (register, not real clock) |
| `cs` | output | 1 | Chip select (active-low) |

### FSM States and Transitions

```
                    start=1
     ┌──────────────────────────────────────────────────┐
     │                                                  │
     ▼                                                  │
  ┌──────┐    start=1        ┌──────────┐   bit_cnt=8  ┌────────┐
  │ IDLE │──────────────────►│ TRANSFER │─────────────►│ FINISH │
  │      │                  │          │              │        │
  │CS=1  │                  │CS=0      │              │CS=1    │
  │SCLK=0│                  │SCLK tog. │              │done=1  │
  │busy=0│                  │busy=1    │              └───┬────┘
  └──────┘                  └──────────┘                  │
     ▲                                                     │
     └─────────────────────────────────────────────────────┘
                         always → IDLE
```

### TRANSFER State — Detailed Logic

```
On each tick from clk_divider:
  if sclk == 0:              ← about to generate a rising edge
      sclk     <= 1
      rx_shift <= {rx_shift[6:0], miso}   ← sample MISO
      bit_cnt  <= bit_cnt + 1
  else:                      ← about to generate a falling edge
      sclk     <= 0
      tx_shift <= {tx_shift[6:0], 1'b0}   ← shift left
      mosi     <= tx_shift[6]             ← next bit on line
```

After `bit_cnt == 8`, transition to FINISH.

### Reset Behavior

All registers cleared. CS forced HIGH. SCLK forced LOW. FSM in IDLE.

---

## Module 3: `spi_slave`

### What It Does

Responds to the master:
1. In IDLE, continuously preloads MISO with TX data MSB
2. When CS drops, enters ACTIVE state
3. Detects SCLK edges using `sclk_d` (delayed SCLK register)
4. Samples MOSI on rising edges
5. Shifts MISO on falling edges
6. After 8 bits, latches `rx_data`, pulses `done`

### Why It Exists

In a real SPI peripheral (sensor chip), there is receiver/transmitter logic on the other side of the bus. This module represents that hardware.

### Hardware It Represents

```
System clock → [sclk_d register] → edge detection logic
                                          │
                   ┌──────────────────────┘
                   │
              ┌────▼──────────────────────┐
              │  Rising edge detected?     │
              │  → sample MOSI → rx_shift  │
              │                           │
              │  Falling edge detected?    │
              │  → shift tx_shift → MISO  │
              └───────────────────────────┘
```

### The Edge Detection Pattern

The slave does NOT use `always @(posedge sclk)`.  
Instead, it detects edges by comparing `sclk` and `sclk_d`:

```verilog
sclk_d <= sclk;   // delayed by one system clock cycle

// Rising edge: sclk was 0, now is 1
if (!sclk_d && sclk) begin ... end

// Falling edge: sclk was 1, now is 0
if (sclk_d && !sclk) begin ... end
```

**Why this matters:** This keeps everything in the single system-clock domain. Using `posedge sclk` would create a second clock domain requiring CDC synchronizers.

### Inputs / Outputs

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst` | input | 1 | Async reset |
| `cs` | input | 1 | Chip select from master |
| `sclk` | input | 1 | SPI clock from master |
| `mosi` | input | 1 | Data from master |
| `miso` | output | 1 | Data to master |
| `tx_data` | input | 8 | Byte to transmit back |
| `rx_data` | output | 8 | Byte received, valid on `done` |
| `busy` | output | 1 | High while CS is asserted |
| `done` | output | 1 | Single-cycle pulse on completion |

### FSM States

```
  ┌──────┐  cs goes LOW   ┌─────────┐  bit_cnt=8   ┌──────┐
  │ IDLE │───────────────►│ ACTIVE  │─────────────►│ IDLE │
  │      │◄──────────────│         │              └──────┘
  │      │  cs goes HIGH  │ CS=0    │
  │ Preload MISO          │ edge det│
  └──────┘                └─────────┘
```

---

## Module 4: `spi_top`

### What It Does

Pure structural wrapper. Instantiates `spi_master` and `spi_slave`. Connects their ports with wires.

No logic, no always blocks, no registers.

### Why It Exists

Provides a clean top-level port for the testbench. Separates structural hierarchy from behavioral logic.

```verilog
// Exactly what spi_top does:
spi_master u_master (...);
spi_slave  u_slave  (...);
// MOSI, MISO, SCLK, CS are shared wires
```

---

## Data Path Summary

```
master_tx_data[7:0]
      │
      ▼
  tx_shift[7:0]  (master)
      │ MSB first, shifted left each SCLK falling edge
      ▼
    MOSI ──────────────────────────────────────────►
                                                    │
                                             rx_shift[7:0] (slave)
                                                    │
                                             slave_rx_data[7:0]

slave_tx_data[7:0]
      │
      ▼
  tx_shift[7:0]  (slave)
      │ MSB first, shifted left each SCLK falling edge
      ▼
    MISO ◄──────────────────────────────────────────
      │
  rx_shift[7:0] (master)
      │
  master_rx_data[7:0]
```

After 8 clock cycles:  
**master_rx_data = slave_tx_data**  
**slave_rx_data = master_tx_data**
