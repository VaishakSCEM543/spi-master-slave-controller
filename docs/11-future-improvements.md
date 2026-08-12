# 11 — Future Improvements

This document lists planned improvements to the SPI controller. All items here are **PLANNED** — none are implemented in the current version.

---

## Near-Term Improvements (Learning-Focused)

### 1. Capture and Commit Waveform Evidence

**What:** Run the Vivado behavioral simulation, screenshot the waveform, and commit it to `waveforms/`.  
**Why:** Makes the verification section of this repository genuinely evidence-based.  
**Effort:** Low — simulation already works.

**What to capture:**
- CS going LOW, all 8 SCLK edges, MOSI bit pattern, MISO bit pattern, CS returning HIGH
- Annotate the screenshot: label CS, SCLK, MOSI, MISO, mark the sampling edges

---

### 2. Expand the Testbench — More Test Cases

**What:** Add additional transactions covering edge cases.  
**Why:** A testbench that only tests one case leaves many bugs undetected.

Planned test cases:
| Test | Master TX | Slave TX | Purpose |
|---|---|---|---|
| All zeros | `0x00` | `0x00` | Verify no false positives from default register state |
| All ones | `0xFF` | `0xFF` | Verify all-ones path |
| Alternating bits | `0xAA` | `0x55` | Bus toggle pattern |
| Different A and B | `0x3C` | `0xC3` | Verify both directions |
| Reset mid-transfer | — | — | Verify clean abort |
| Back-to-back (10×) | random | random | Verify no state leaks |

---

### 3. Parameterize Data Width

**What:** Replace all `8` and `[7:0]` with a `DATA_WIDTH` parameter.  
**Why:** Makes the design reusable for 16-bit, 32-bit, and other widths.

```verilog
// Current:
reg [7:0] tx_shift;
reg [3:0] bit_cnt;
if (bit_cnt == 4'd8)

// Improved:
parameter DATA_WIDTH = 8;
reg [DATA_WIDTH-1:0] tx_shift;
reg [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;
if (bit_cnt == DATA_WIDTH[3:0])
```

---

### 4. Add SPI Modes 1, 2, 3

**What:** Add `CPOL` and `CPHA` parameters. Modify the sampling/shifting edge selection.  
**Why:** Real peripherals use all four modes. A production-quality SPI controller must support them.

```verilog
parameter CPOL = 0;
parameter CPHA = 0;
// ... select leading/trailing edge based on CPOL, CPHA
```

---

## Medium-Term Improvements (Design-Focused)

### 5. Multiple Slave Support

**What:** Add a `NUM_SLAVES` parameter and a `cs[NUM_SLAVES-1:0]` bus. Add a `slave_sel` input to select which CS to assert.  
**Why:** Real SPI masters connect to multiple peripherals.

```
spi_master
  ├── cs[0]  → Device 1
  ├── cs[1]  → Device 2
  └── cs[2]  → Device 3
```

---

### 6. Stronger Verification — Assertions

**What:** Add `assert` statements in SystemVerilog to verify protocol invariants automatically.

Examples:
```systemverilog
// CS must not change while SCLK is high
assert property (@(posedge clk) (sclk) |-> !$changed(cs));

// SCLK must not toggle while CS is high
assert property (@(posedge clk) (cs) |-> !$rose(sclk));

// bit_cnt must never exceed 8
assert property (@(posedge clk) (bit_cnt <= 8));
```

---

### 7. Constrained Random Verification

**What:** Use SystemVerilog `$urandom_range` or a UVM environment to apply random TX data values across hundreds of transactions automatically.  
**Why:** Directed testbenches only test what the designer expects. Random testing finds unexpected corner cases.

---

## Long-Term Improvements (Hardware-Focused)

### 8. FPGA Synthesis and Implementation

**What:** Run Vivado synthesis and implementation on the RTL. Resolve any timing violations or synthesis warnings.  
**Why:** Behavioral simulation only proves logical correctness. Synthesis proves the RTL is physically realizable.

Steps:
1. Run synthesis — check for warnings about latches, undriven signals, timing
2. Run implementation — check timing report (setup/hold slack)
3. Generate bitstream
4. Program FPGA board

---

### 9. FPGA Hardware Validation with Logic Analyzer

**What:** Program the FPGA. Connect a logic analyzer to the MOSI, MISO, SCLK, and CS pins. Capture actual SPI waveforms.  
**Why:** This is the only way to verify that the RTL works as real hardware — not just as a simulation model.

**What to verify:**
- SCLK frequency matches the expected value from CLK_DIV
- MOSI bit pattern matches the transmitted byte
- CS timing meets setup/hold requirements
- Signal integrity on the physical lines

---

### 10. Connect to a Real SPI Peripheral

**What:** Use the FPGA as an SPI master to communicate with a real SPI device — an SPI flash memory chip, an accelerometer like MPU-6500, or a DAC.  
**Why:** Validates that the RTL-designed controller is compatible with real-world SPI devices.

---

### 11. Formal Verification

**What:** Use a formal verification tool (SymbiYosys, Cadence JasperGold, Mentor Questa Formal) to mathematically prove protocol properties.  
**Why:** Formal verification can prove properties hold for ALL possible inputs, not just the tested cases.

---

## Improvement Roadmap

```
Current State
    │
    ├── Short-term
    │     ├── Commit waveform evidence
    │     ├── Expand testbench
    │     └── Parameterize data width
    │
    ├── Medium-term
    │     ├── Support SPI Modes 1-3
    │     ├── Multiple slave support
    │     └── SystemVerilog assertions
    │
    └── Long-term
          ├── FPGA synthesis
          ├── Hardware validation
          ├── Real SPI peripheral
          └── Formal verification
```
