# 08 — Verification

## What Verification Means in RTL Design

Writing RTL is not enough.  
You need to prove that the RTL actually behaves the way you intended.

The process of proving this is called **verification**.

In this project, verification was done through **behavioral simulation** using Vivado and a self-checking testbench.

---

## Key Terminology

| Term | Meaning |
|---|---|
| **DUT** | Device Under Test — the design being verified (`spi_top`) |
| **Testbench** | A non-synthesizable Verilog file that drives the DUT and checks its outputs |
| **Stimulus** | The inputs applied to the DUT (reset, start, tx_data) |
| **Expected output** | What the DUT should produce |
| **Actual output** | What the DUT actually produces during simulation |
| **Assertion / Check** | Comparison of actual vs. expected — produces PASS or FAIL |
| **Behavioral simulation** | Software simulation of the RTL — not physical hardware |

---

## The Testbench (`tb_spi_top.v`)

### DUT

```
tb_spi_top
    └── spi_top  (DUT)
            ├── spi_master
            │       └── clk_divider
            └── spi_slave
```

The entire hierarchy is instantiated and simulated together.

### Stimulus Applied

| Stimulus | Value | Purpose |
|---|---|---|
| `rst` | Held HIGH for 5 clock cycles | Initialize all registers to reset state |
| `master_tx_data` | `0xA5` (10100101) | Byte master will send to slave |
| `slave_tx_data` | `0x5A` (01011010) | Byte slave will send back to master |
| `start` | 1 cycle HIGH pulse | Triggers the transaction |

### Timing Assumptions

| Parameter | Value | Effect |
|---|---|---|
| `CLK_PERIOD` | 10 ns | 100 MHz system clock |
| `CLK_DIV` | 4 | SCLK half-period = 4 × 10 ns = 40 ns → SCLK ≈ 12.5 MHz |

---

## Checks Performed

The testbench performs five automatic checks:

### Check 1 — CS Asserts Correctly

```verilog
repeat (2) @(posedge clk);
if (cs !== 1'b0) begin
    $display("FAIL: CS did not assert low after start");
```

**What it verifies:** CS goes LOW within 2 clock cycles after `start`.

### Check 2 — Master Received Correct Data

```verilog
if (master_rx_data !== 8'h5A) begin
    $display("FAIL: master_rx_data mismatch");
```

**What it verifies:** The master received `0x5A` — the byte the slave was programmed to transmit.

### Check 3 — Slave Received Correct Data

```verilog
if (slave_rx_data !== 8'hA5) begin
    $display("FAIL: slave_rx_data mismatch");
```

**What it verifies:** The slave received `0xA5` — the byte the master transmitted.

### Check 4 — Exactly 8 SCLK Rising Edges

```verilog
// Always block running in parallel:
always @(posedge sclk) begin
    if (!cs) sclk_edge_count = sclk_edge_count + 1;
end

// After done:
if (sclk_edge_count !== 8) begin
    $display("FAIL: incorrect number of SCLK edges (got %0d)", sclk_edge_count);
```

**What it verifies:** Exactly 8 bits were clocked — no extra clock edges, no missing edges. This confirms the bit counter works correctly.

### Check 5 — CS Deasserts After Transaction

```verilog
if (cs !== 1'b1) begin
    $display("FAIL: CS did not return high after transaction");
```

**What it verifies:** CS returns HIGH after the transaction completes, leaving the bus in idle state.

### Timeout Guard

```verilog
while (!done && !timeout) begin
    @(posedge clk);
end
if (timeout) begin
    $display("FAIL: TIMEOUT - 'done' never asserted within %0d cycles", TIMEOUT_CYC);
```

**What it verifies:** The transaction completes within a reasonable time. If the design hangs (done never asserts), the simulation terminates with a clear FAIL message rather than running forever.

---

## Simulation Result

> [!IMPORTANT]
> The Vivado behavioral simulation was run and all checks passed. However, the console output was not saved to this repository. The simulation result below is based on the ChatGPT/Icarus Verilog pre-verification and the Vivado run — but no screenshot or log file is currently committed here.

**Expected output from testbench:**

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

## Verification Status

| Check | Status |
|---|---|
| CS asserts low after start | ✅ Passes (confirmed in simulation) |
| master_rx_data == 0x5A | ✅ Passes (confirmed in simulation) |
| slave_rx_data == 0xA5 | ✅ Passes (confirmed in simulation) |
| Exactly 8 SCLK rising edges | ✅ Passes (confirmed in simulation) |
| CS returns high after done | ✅ Passes (confirmed in simulation) |
| Timeout guard triggered | ✅ Not triggered (done arrived in time) |
| Waveform saved to repository | ❌ Not yet — to be captured and committed |

---

## What Was NOT Tested

| Test | Status | Notes |
|---|---|---|
| Multiple sequential transactions | NOT TESTED | Only one transaction per simulation run |
| Data value `0x00` (all zeros) | NOT TESTED | Edge case — shift register starts at 0 |
| Data value `0xFF` (all ones) | NOT TESTED | Edge case — all bits high |
| `0xAA` / `0x55` alternating patterns | NOT TESTED | Useful for bus integrity checks |
| Reset during active transaction | NOT TESTED | Should abort and return to IDLE |
| `start` while `busy` is high | NOT TESTED | Should be ignored by current design |
| Back-to-back transactions | NOT TESTED | No inter-transaction gap testing |

---

## Planned Tests

| Test | Purpose |
|---|---|
| `0x00` → `0x00` | Verify all-zero case (no false positives from default register state) |
| `0xFF` → `0xFF` | Verify all-one case |
| Reset mid-transaction | Verify FSM returns to IDLE cleanly |
| 10 back-to-back transactions | Verify no state leaks between transactions |
| Random values (if randomization added) | Increase confidence in correctness |

---

## How to Reproduce the Simulation

### Vivado

1. Create new RTL project
2. Add `rtl/clk_divider.v`, `rtl/spi_master.v`, `rtl/spi_slave.v`, `rtl/spi_top.v` as **Design Sources**
3. Add `sim/tb_spi_top.v` as a **Simulation Source**
4. Set `tb_spi_top` as the simulation top module
5. Run **Behavioral Simulation**
6. Check the Tcl console for `RESULT: ALL CHECKS PASSED`
7. Add signals to waveform and inspect CS, SCLK, MOSI, MISO

### Icarus Verilog (Free / Command Line)

```bash
iverilog -o sim.out \
  rtl/clk_divider.v \
  rtl/spi_master.v \
  rtl/spi_slave.v \
  rtl/spi_top.v \
  sim/tb_spi_top.v

vvp sim.out
```

View the waveform:
```bash
gtkwave tb_spi_top.vcd
```
