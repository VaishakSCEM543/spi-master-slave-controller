# 🔁 SPI Master–Slave Controller

> **An 8-bit SPI Mode 0 Controller designed from first principles in synthesizable Verilog RTL.**
> This is not a firmware driver. This is the **actual hardware** — the circuit that lives inside a chip.

<br>

## 📊 Project Status

| Stage | Status |
|---|---|
| RTL Design | ✅ Complete |
| Behavioral Simulation | ✅ Verified — `ALL CHECKS PASSED` |
| Self-Checking Testbench | ✅ Complete |
| Vivado Synthesis Script | ✅ Ready — targets `xc7a35tcpg236-1` |
| Basys 3 Pin Assignments | ✅ Complete — all 46 signals mapped |
| Synthesis (Vivado) | ✅ Complete |
| FPGA Implementation | ✅ Complete |
| Physical Hardware Validation | ✅ Complete — tested on Basys 3 with 7-segment display |

> This repository is an honest learning project. Claims are backed by evidence. Simulation and hardware validation are never conflated.

<br>

---

## ⚡ Verified Result

The design was verified using a self-checking testbench in Vivado behavioral simulation.

```
---------------------------------------------
Master TX = 10100101  (0xA5)
Slave  TX = 01011010  (0x5A)
Master RX = 01011010  (0x5A)  ✔ expected 01011010 (0x5A)
Slave  RX = 10100101  (0xA5)  ✔ expected 10100101 (0xA5)
SCLK rising edges during CS low = 8  ✔ (expected 8)
Final CS = 1  ✔ (expected 1)
---------------------------------------------
RESULT: ALL CHECKS PASSED
```

**SPI Transaction — what actually happened on the wires:**

```
CS:   ‾‾‾‾‾\___________________________/‾‾‾‾‾‾
SCLK: _______|‾|_|‾|_|‾|_|‾|_|‾|_|‾|______
MOSI: _______1___0___1___0___0___1___0___1__   ← 0xA5  (Master → Slave)
MISO: _______0___1___0___1___1___0___1___0__   ← 0x5A  (Slave  → Master)
              ↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑
              └── 8 rising edges = 8 bits sampled on each ────┘
```

<br>

---

## 🗂️ Repository Structure

```
spi-master-slave-controller/
│
├── rtl/                    ← Synthesizable Verilog RTL (the actual hardware)
│   ├── clk_divider.v       ← Clock divider: 100 MHz → SPI tick
│   ├── spi_master.v        ← SPI Master: drives CS, SCLK, MOSI; samples MISO
│   ├── spi_slave.v         ← SPI Slave: waits for CS, samples MOSI, drives MISO
│   └── spi_top.v           ← Top-level: structural wrapper connecting master & slave
│
├── sim/
│   └── tb_spi_top.v        ← Self-checking simulation testbench
│
├── vivado/
│   ├── constraints.xdc     ← Basys 3 pin assignments + 100 MHz clock constraint
│   ├── synth.tcl           ← Automated synthesis + report generation script
│   └── README.md           ← How to run the Tcl script
│
├── docs/                   ← Deep-dive technical documentation (11 files)
├── learning/               ← Personal learning journal + interview prep
├── verification/           ← Test cases, expected results, results log
└── waveforms/              ← Vivado waveform screenshots
```

<br>

---

## 🧠 How SPI Works — From Zero

### The Four Signals

SPI connects one **Master** to one or more **Slaves** using 4 wires:

| Signal | Direction | What it does |
|---|---|---|
| `SCLK` (Serial Clock) | Master → Slave | The clock. Master generates it. Both devices use it to sync. |
| `MOSI` (Master Out Slave In) | Master → Slave | Data flowing FROM master TO slave. |
| `MISO` (Master In Slave Out) | Slave → Master | Data flowing FROM slave TO master. |
| `CS` (Chip Select) | Master → Slave | Active-**LOW**. `CS=0` means "you are selected, respond." |

### Full-Duplex Transfer

Because MOSI and MISO are **separate wires**, both can carry data at the same time.
In every clock cycle, the master sends a bit AND receives a bit simultaneously.

```
            ┌─────────┐   MOSI →   ┌─────────┐
            │  MASTER │   MISO ←   │  SLAVE  │
            │         │   SCLK →   │         │
            │         │   CS   →   │         │
            └─────────┘            └─────────┘
```

After 8 clock cycles:
- Master has sent its full byte **and** received the slave's full byte
- Slave has received the master's byte **and** sent its own byte back

This is **full-duplex** — two bytes exchanged in one transaction.

<br>

### SPI Mode 0 — The Timing Rules

This project uses **Mode 0 (CPOL=0, CPHA=0)**:

| Rule | Meaning |
|---|---|
| `CPOL = 0` | Clock **idles LOW**. No transaction = SCLK stays at 0. |
| `CPHA = 0` | Data is sampled on the **first** (rising) edge. Shifted on the **second** (falling) edge. |

**Critical Rule — Data must be ready BEFORE the first rising edge:**
- Master pre-loads bit 7 of its byte onto MOSI before CS drops
- Slave pre-loads bit 7 of its byte onto MISO before CS drops
- So when the first rising edge arrives, valid data is already on the bus

```
CS:       ‾‾\________________________________/‾‾
              ↑ CS drops                     ↑ CS rises (done)

SCLK:     ______|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|__
                 ↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑    ← SAMPLE on rising ↑
                   ↓   ↓   ↓   ↓   ↓   ↓   ↓      ← SHIFT  on falling ↓

MOSI:     ___B7___B6__B5__B4__B3__B2__B1__B0______
               ↑ pre-loaded before CS drops
```

<br>

---

## 🏗️ Architecture

### System Block Diagram

```
                   100 MHz system clock
                          │ clk
                          ▼
         ┌────────────────────────────────────┐
         │              spi_top               │
         │  ┌──────────────────────────────┐  │
         │  │         spi_master           │  │
 start ──┤  │  ┌────────────────────┐     │  │
master_tx┤  │  │   clk_divider      │     │  │
         │  │  │   (CLK_DIV = 4)    │     │  │
         │  │  └──────────┬─────────┘     │  │
         │  │             │ tick (pulse)   │  │
         │  │  FSM: IDLE ─► TRANSFER ─► FINISH │
         │  │                              │  ├──► MOSI
         │  │  TX shift reg [7:0] ─────────┤  ◄── MISO
         │  │  RX shift reg [7:0]          │  ├──► SCLK
         │  │  bit_cnt [3:0]  (0 → 8)      │  ├──► CS
         │  └──────────────────────────────┘  │
         │  ┌──────────────────────────────┐  │
         │  │         spi_slave            │  │
slave_tx─┤  │  sclk_d ← edge detect logic  ◄──┤── SCLK
         │  │  FSM: IDLE ─► ACTIVE         │  ◄── CS
         │  │  TX shift reg [7:0] ─────────┤  ├──► MISO
         │  │  RX shift reg [7:0]          │  ◄── MOSI
         │  └──────────────────────────────┘  │
         └────────────────────────────────────┘
```

<br>

### Module Breakdown

#### `clk_divider.v` — The Clock Divider

The system clock runs at **100 MHz**. SPI does not need to run that fast.
The `clk_divider` generates a single-cycle **tick** pulse every `DIVISOR` system clocks.
The master uses this tick to decide when to toggle SCLK.

With `CLK_DIV = 4`: SCLK frequency = 100 MHz ÷ (4 × 2) = **12.5 MHz**

```
System clock:  __|‾|_|‾|_|‾|_|‾|__
Counter:         0  1  2  3  0  ...
Tick:            ______________|‾|_   ← one-cycle pulse every DIVISOR cycles
```

**Key design decision:** The divider only runs when the master is in `TRANSFER` state.
This guarantees every transaction starts fresh — a clean first SCLK edge.

---

#### `spi_master.v` — The SPI Master (State Machine)

The master FSM controls the entire SPI transaction:

```
            start pulse
   ┌──────────────────────────┐
   ▼                          │
┌──────┐  start  ┌──────────┐  8 bits  ┌────────┐
│ IDLE │────────►│ TRANSFER │─────────►│ FINISH │──► IDLE
│      │         │          │          │        │
│CS=1  │         │CS=0      │          │CS=1    │
│SCLK=0│         │SCLK tog. │          │done=1  │
│busy=0│         │busy=1    │          │busy=0  │
└──────┘         └──────────┘          └────────┘
```

**What happens on each `tick` in TRANSFER state:**

```
if SCLK is currently 0:          ← generate a RISING edge
    SCLK ← 1
    rx_shift ← {rx_shift[6:0], MISO}    ← sample MISO (shift in from right)
    bit_cnt  ← bit_cnt + 1

else:                            ← generate a FALLING edge
    SCLK ← 0
    tx_shift ← {tx_shift[6:0], 0}       ← shift left (MSB already sent)
    MOSI ← tx_shift[6]                  ← put next bit on the wire
```

> **Important:** `SCLK` is a **register**, not a real clock net. This keeps everything in a single clock domain and avoids Clock Domain Crossing (CDC) issues.

---

#### `spi_slave.v` — The SPI Slave

The slave **cannot generate its own clock** — it uses the master's SCLK.
But all its logic still runs on the system clock (`posedge clk`).

**Edge detection trick — how the slave "sees" SCLK edges without using `posedge sclk`:**

```verilog
sclk_d <= sclk;   // one-cycle-delayed copy of SCLK

// Rising edge:  SCLK was 0, now 1
if (!sclk_d && sclk) begin  rx_shift <= {rx_shift[6:0], mosi}; end

// Falling edge: SCLK was 1, now 0
if (sclk_d && !sclk)  begin  miso <= tx_shift[6]; end
```

This is the key design technique. Without it, using `always @(posedge sclk)` would create a second clock domain.

**MISO pre-loading (CPHA=0 requirement):**

```verilog
// While IDLE, continuously pre-load bit 7 onto MISO
IDLE: begin
    miso <= tx_data[7];   // ready before CS drops
    if (!cs) state <= ACTIVE;
end
```

---

#### `spi_top.v` — The Structural Wrapper

Pure wiring. No logic. Just connects master and slave together.

```verilog
spi_master u_master (... .mosi(mosi), .miso(miso), .sclk(sclk), .cs(cs) ...);
spi_slave  u_slave  (... .mosi(mosi), .miso(miso), .sclk(sclk), .cs(cs) ...);
```

The SPI bus signals (`mosi`, `miso`, `sclk`, `cs`) are shared internal wires.

<br>

---

## 🔬 Data Flow — Tracing a Bit

Let's trace bit 7 of `master_tx_data = 0xA5 = 10100101`:

**Bit 7 = `1`**

```
Step 1: start asserted
        → tx_shift ← 8'b10100101
        → MOSI     ← tx_shift[7] = 1    ← pre-loaded!
        → CS       ← 0

Step 2: First tick (SCLK rising edge)
        → SCLK ← 1
        → master: rx_shift ← {rx_shift[6:0], MISO}   ← samples slave's bit 7
        → slave:  rx_shift ← {rx_shift[6:0], MOSI=1}  ← slave captures '1'
        → bit_cnt ← 1

Step 3: Second tick (SCLK falling edge)
        → SCLK ← 0
        → tx_shift ← {10100101[6:0], 0} = 01001010
        → MOSI ← tx_shift[6] = 0        ← bit 6 is now on the wire

... repeat for bits 6,5,4,3,2,1,0 ...

Step 17: bit_cnt == 8 → FINISH state
         → CS ← 1, done ← 1
         → master_rx_data = 0x5A (received from slave)
         → slave_rx_data  = 0xA5 (received from master)
```

<br>

---

## 🖥️ How to Simulate (Vivado)

### Step-by-Step GUI Method

1. Open **Vivado** → **Create Project** → RTL Project
2. **Add Design Sources** → select all 4 files from `rtl/`
3. **Add Constraints** → select `vivado/constraints.xdc`
4. **Add Simulation Sources** → select `sim/tb_spi_top.v`
5. **Target part:** search `xc7a35tcpg236-1` → select it
6. In Sources panel: right-click `tb_spi_top` → **Set as Top**
7. Click **Run Simulation** → **Run Behavioral Simulation**
8. ✅ Check the **Tcl Console** — you should see `RESULT: ALL CHECKS PASSED`

### Automated Tcl Script Method

Open the Vivado Tcl Console and run:

```tcl
cd "d:/MIRAFRA/spi project/spi-master-slave-controller/vivado"
source synth.tcl
```

This auto-creates the project, runs synthesis, and generates reports in `vivado/reports/`.

### Icarus Verilog (Free, No GUI)

```bash
iverilog -o sim.out rtl/clk_divider.v rtl/spi_master.v rtl/spi_slave.v rtl/spi_top.v sim/tb_spi_top.v
vvp sim.out
# Optional: gtkwave tb_spi_top.vcd
```

<br>

---

## 🔌 FPGA Implementation — Basys 3 Pin Map

Target board: **Basys 3** · Part: **Xilinx Artix-7 `xc7a35tcpg236-1`**

| Signal | Pin | Board Component | Notes |
|---|---|---|---|
| `clk` | W5 | 100 MHz oscillator | System clock |
| `rst` | U18 | BTNC (Center button) | Active-high reset |
| `start` | T18 | BTNU (Up button) | Pulse to start transaction |
| `master_tx_data[7:0]` | SW0–SW7 | Slide switches 0–7 | Master's byte to send |
| `slave_tx_data[7:0]` | SW8–SW15 | Slide switches 8–15 | Slave's byte to send |
| `master_rx_data[7:0]` | LED0–LED7 | LEDs 0–7 | What master received |
| `slave_rx_data[7:0]` | LED8–LED15 | LEDs 8–15 | What slave received |
| `cs` | J1 | Pmod JA Pin 1 | SPI chip select (probe here) |
| `mosi` | L2 | Pmod JA Pin 2 | SPI data M→S (probe here) |
| `miso` | J2 | Pmod JA Pin 3 | SPI data S→M (probe here) |
| `sclk` | G2 | Pmod JA Pin 4 | SPI clock (probe here) |
| `busy` | A14 | Pmod JB Pin 1 | Master busy indicator |
| `done` | A16 | Pmod JB Pin 2 | Transaction complete pulse |
| `slave_busy` | B15 | Pmod JB Pin 3 | Slave busy indicator |
| `slave_done` | B16 | Pmod JB Pin 4 | Slave done pulse |
| `seg[6:0]` | W7, W6, U8, V8, U5, V5, U7 | 7-Segment Segments | Displays HEX values |
| `an[3:0]` | U2, U4, V4, W4 | 7-Segment Anodes | Multiplexing display |

**How to use on the board:**
1. Set switches SW0–SW7 to the byte you want the master to send (e.g., SW7,SW5,SW3,SW0 = HIGH → `10101001 = 0xA9`)
2. Set switches SW8–SW15 to the byte you want the slave to send back
3. Press **BTNU** (start) — the transaction runs
4. **7-Segment Display** shows the results in real-time HEX format:
   - Left two digits = Master's received byte
   - Right two digits = Slave's received byte
5. Connect a logic analyzer to **Pmod JA** to probe `CS`, `MOSI`, `MISO`, `SCLK` in real time

<br>

---

## 📋 FPGA Synthesis → Bitstream: Full Steps

```
1. Simulation (done ✅)
         │
         ▼
2. Synthesis  → Verilog RTL  →  logic gates (AND/OR/flip-flops)
   [Run Synthesis in Vivado]
   Check: no latches, no undriven ports, timing feasible
         │
         ▼
3. Implementation → map gates to physical Artix-7 LUTs + routing
   [Run Implementation in Vivado]
   Check: timing report — all slack values POSITIVE
         │
         ▼
4. Generate Bitstream → creates .bit file
   [Generate Bitstream in Vivado]
         │
         ▼
5. Program FPGA (Hardware Manager)
   [Open Hardware Manager → Program Device]
   Select the .bit file → Program
         │
         ▼
6. Physical test with switches, LEDs, and logic analyzer
```

<br>

---

## 🎓 Interview Preparation — Q&A

### Protocol Level

**Q: What is SPI?**
> Synchronous serial protocol using 4 signals: `SCLK`, `MOSI`, `MISO`, `CS`. Master generates the clock and controls chip select. Full-duplex — both master and slave send data simultaneously.

**Q: What is CPOL and CPHA?**
> CPOL = Clock Polarity (idle level: 0=LOW, 1=HIGH). CPHA = Clock Phase (which edge samples data: 0=first/leading, 1=second/trailing). This project uses Mode 0: CPOL=0, CPHA=0 → clock idles low, sample on rising edge.

**Q: Why is CS active-low?**
> Convention — `CS=LOW` selects the device. `CS=HIGH` deselects it. When deselected, the slave's MISO enters Hi-Z (high impedance) so it doesn't corrupt the shared bus.

**Q: Can multiple slaves share MISO?**
> Yes — only the selected slave actively drives MISO. All others are in Hi-Z. Only one CS may be LOW at any time to prevent bus contention.

---

### RTL / Design Level

**Q: What is RTL?**
> Register Transfer Level — describing hardware in terms of what data is stored in registers (flip-flops) and how it moves between them each clock cycle. RTL is not a sequential program — all `always` blocks run concurrently every clock.

**Q: Why is SCLK a register and not a real clock?**
> If the slave used `always @(posedge sclk)`, it would create a second clock domain, requiring CDC synchronizers. By keeping SCLK as a data register toggled by the master FSM, the entire design runs on one clock domain (`posedge clk`). The slave detects SCLK edges using `sclk_d` — a one-cycle-delayed copy — comparing it to the current value.

**Q: Why use non-blocking assignment `<=`?**
> Non-blocking means: evaluate all right-hand sides first (using current register values), then update all left-hand sides simultaneously. This models flip-flop behavior. If blocking `=` were used, `tx_shift = {tx_shift[6:0], 0}` would update `tx_shift` immediately, and the next line `mosi = tx_shift[6]` would see the shifted value instead of the original — wrong hardware behavior.

**Q: What does `sclk_d` do in the slave?**
> It is a one-clock-delayed copy of SCLK, captured every `posedge clk`. Comparing `sclk_d` with `sclk` detects edges:
> - `!sclk_d && sclk` → rising edge (was 0, now 1) → sample MOSI
> - `sclk_d && !sclk` → falling edge (was 1, now 0) → shift MISO

**Q: Why does the slave pre-load MISO in IDLE state?**
> CPHA=0 requires data to be stable before the first rising clock edge. While idle, the slave continuously drives `miso <= tx_data[7]`. The moment CS drops, MISO already shows bit 7 — so the master can sample it on the very first rising edge.

**Q: What is Clock Domain Crossing (CDC)?**
> When a signal generated in one clock domain is used in another. Because the clocks are asynchronous to each other, setup/hold violations can occur, causing metastability. This design has **no CDC** — everything runs on `posedge clk`.

---

### Verification Level

**Q: What did your testbench verify?**
> 5 checks: (1) master received exactly `0x5A` from slave, (2) slave received exactly `0xA5` from master, (3) exactly 8 SCLK rising edges occurred while CS was LOW, (4) CS returned HIGH after the transaction, (5) the bit patterns were correct MSB-first.

**Q: What does behavioral simulation prove?**
> That the RTL logic is functionally correct in a software model. It does NOT prove the design synthesizes cleanly, meets timing on real hardware, or works at the target FPGA frequency. Those require synthesis, implementation, and physical FPGA testing (which we have successfully done on the Basys 3!).

---

### Design Decisions

**Q: Why no 8th falling edge?**
> After the 8th rising-edge sample, there is no 9th bit to shift out — so the falling edge is unnecessary. The master immediately moves to FINISH and deasserts CS. This is a deliberate simplification for the first implementation.

**Q: What would you improve in v2?**
> Parameterize data width (`DATA_WIDTH`), support all 4 SPI modes via `CPOL`/`CPHA` parameters, add multiple slave support with a `cs[N-1:0]` bus, add more testbench test cases (back-to-back, all-zeros, all-ones, reset mid-transfer), and validate on hardware with a logic analyzer.

<br>

---

## 🗺️ Learning Journey

This project was built as a structured learning exercise — moving from user-level SPI knowledge to hardware-level RTL design.

### Starting Point — What I Already Knew

- SPI uses 4 pins: MISO, MOSI, SCK, CS
- CS goes low to select a device
- SPI is full-duplex and fast
- For 3 sensors: 4 shared lines + 3 CS lines = 7 pins (not 12)

### What I Had Wrong

| Misconception | Correction |
|---|---|
| "CS=HIGH means selected" | CS is **active-low**. CS=LOW = selected. |
| "SPI reads all sensors simultaneously" | SPI transfers are sequential. Sensor *sampling* can be simultaneous (via SYNC pin), but readout is one-by-one. |
| "SPI uses more power than I²C" | Power depends on frequency, voltage, and load — not the protocol alone. |
| "Cameras use SPI for image data" | Cameras use MIPI CSI-2 or parallel interfaces. SPI is only for control/config. |

### What I Learned Building This

1. **RTL ≠ Software** — An `always @(posedge clk)` block describes hardware that operates every clock cycle in parallel. It is not a for-loop.
2. **SCLK as a register** — The most important design decision. Keeps everything in one clock domain.
3. **Shift registers** — The hardware bridge between parallel bytes and serial bit streams.
4. **FSMs** — The standard pattern for sequenced hardware behavior.
5. **Behavioral simulation ≠ FPGA validation** — Simulation proves logic. Hardware proves everything else.
6. **Pre-loading MISO** — The CPHA=0 requirement means data must be ready *before* the clock starts.

### Current Understanding

I can now:
- Explain SPI at both protocol and hardware level
- Trace a single bit through the entire data path: `master_tx_data[7]` → `tx_shift` → `MOSI` wire → `rx_shift` (slave) → `slave_rx_data`
- Explain every register in every module and why it exists
- Discuss why SCLK is a register (not a clock) and what CDC means
- Clearly state what has been verified (simulation) and what has not (hardware)

<br>

---

## ⚠️ Known Limitations (v1)

| Limitation | Impact | Future Fix |
|---|---|---|
| Fixed 8-bit data width | Cannot transfer 16/32-bit in one transaction | `parameter DATA_WIDTH = 8` |
| Mode 0 only (CPOL=0, CPHA=0) | Incompatible with Mode 1/2/3 devices | Add `CPOL`/`CPHA` parameters |
| Single slave only | Cannot address multiple peripherals | `parameter NUM_SLAVES = 1`, cs bus |
| No FIFO | Multi-byte transfers need application-level sequencing | Add FIFO module |
| No error detection | Silent failure if MISO is wrong | Out of scope for v1 |
| `start` ignored when busy | If asserted during transfer, silently dropped | Add FIFO or busy check in caller |

<br>

---

## 🔮 Future Roadmap

```
v1 — Current (this repository)
│   ✅ 8-bit Mode 0 RTL + simulation + Basys 3 pin assignments
│   ✅ Synthesis + Bitstream + Real Hardware Validation
│   ✅ 7-segment display integration for live HEX monitoring
│
├── Medium-term
│   ├── Parameterize DATA_WIDTH
│   ├── Add CPOL/CPHA parameters → support all 4 SPI modes
│   ├── Multiple slave support (cs bus)
│   └── Add SystemVerilog protocol assertions
│
└── Long-term
    ├── Constrained-random verification
    ├── Connect to real SPI peripheral (flash memory, accelerometer)
    └── Formal verification with SymbiYosys
```

<br>

---

## 📖 Documentation Index

| File | Contents |
|---|---|
| [`docs/01-project-definition.md`](docs/01-project-definition.md) | What the project is and what it is not |
| [`docs/02-requirements.md`](docs/02-requirements.md) | Design requirements and constraints |
| [`docs/03-architecture.md`](docs/03-architecture.md) | System block diagram, module responsibilities, transaction timeline |
| [`docs/04-spi-fundamentals.md`](docs/04-spi-fundamentals.md) | SPI from zero — protocol, signals, full duplex, multi-slave, Hi-Z |
| [`docs/05-spi-mode-0.md`](docs/05-spi-mode-0.md) | The four SPI modes, Mode 0 timing, CPHA=0 data preloading |
| [`docs/06-rtl-design.md`](docs/06-rtl-design.md) | Each module's RTL — datapath diagrams, port tables, FSM logic |
| [`docs/07-verilog-concepts.md`](docs/07-verilog-concepts.md) | Blocking vs non-blocking, parameters, sensitivity lists |
| [`docs/08-verification.md`](docs/08-verification.md) | Testbench structure, what was checked, expected results |
| [`docs/09-debugging.md`](docs/09-debugging.md) | Issues encountered and how they were resolved |
| [`docs/10-limitations.md`](docs/10-limitations.md) | Honest list of v1 limitations |
| [`docs/11-future-improvements.md`](docs/11-future-improvements.md) | Planned improvements roadmap |
| [`learning/learning-log.md`](learning/learning-log.md) | Personal record of corrections, discoveries, and gaps |
| [`learning/interview-preparation.md`](learning/interview-preparation.md) | 25 interview Q&As from basic to advanced |

<br>

---

## 📄 License

MIT — see [LICENSE](LICENSE)
