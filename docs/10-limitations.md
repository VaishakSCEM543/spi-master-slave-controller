# 10 — Limitations

This document honestly lists the current limitations of the SPI Master–Slave Controller implementation. These are not failures — they are deliberate design boundaries of version 1.

---

## 1. Fixed 8-Bit Data Width

**Limitation:** The data width is hardcoded to 8 bits.  
**Where:** `bit_cnt` reaches 8, `[7:0]` shift registers, hardcoded bit-width in all modules.  
**Impact:** Cannot transfer 16-bit or 32-bit data in a single transaction without modification.  
**Future fix:** Parameterize the data width — `parameter DATA_WIDTH = 8` — and use `DATA_WIDTH-1:0` ranges throughout.

---

## 2. SPI Mode 0 Only

**Limitation:** Only CPOL=0, CPHA=0 is implemented.  
**Where:** The FSM samples on rising edge and shifts on falling edge — hardcoded behavior.  
**Impact:** Cannot communicate with devices that require Mode 1, 2, or 3 without design changes.  
**Future fix:** Add `CPOL` and `CPHA` parameters. Add conditional logic to select which edge samples and which shifts based on those parameters.

---

## 3. Single Slave Only

**Limitation:** Exactly one slave is supported. CS is a single bit.  
**Where:** `spi_top.v` instantiates exactly one `spi_slave`. `spi_master.v` drives a single `cs` output.  
**Impact:** Cannot connect multiple physical peripherals without modifying the design.  
**Future fix:** Add a `NUM_SLAVES` parameter and a `cs[NUM_SLAVES-1:0]` output bus. Add a slave-select input to the master and drive the correct CS line.

---

## 4. Simulation-Only Verification (No Formal or Hardware Validation)

**Limitation:** The only verification evidence is behavioral simulation — not synthesis, not FPGA hardware testing, not formal verification.  
**Impact:** Behavioral simulation confirms logical correctness of the model, but does not prove:
  - The design is synthesizable without issues
  - Timing constraints are met on real hardware
  - The design works at the target FPGA frequency
  - Physical SPI signals meet the slave's setup/hold timing requirements

**Status:**
| Verification type | Status |
|---|---|
| Behavioral simulation | ✅ Done |
| Synthesis | ❌ Not yet |
| FPGA implementation | ❌ Not yet |
| Logic analyzer validation | ❌ Not yet |

---

## 5. No FIFO Buffering

**Limitation:** There is no FIFO between the application logic and the SPI master.  
**Impact:** `tx_data` must be presented and stable before `start` is asserted. The master cannot queue multiple bytes. For systems that need to transfer multi-byte packets, the application must manage byte-by-byte sequencing.

---

## 6. No Acknowledgment or Error Detection

**Limitation:** SPI itself has no acknowledgment mechanism. This implementation adds nothing on top.  
**Impact:** If the slave does not respond correctly (e.g., wrong MISO data), the master has no way to detect or report an error. The testbench checks for correctness, but the hardware controller itself does not.

---

## 7. `start` Ignored While Busy

**Limitation:** If `start` is asserted while the master is in `TRANSFER` or `FINISH` state, it is silently ignored — the `IDLE` state is the only one that checks `start`.  
**Impact:** For application code that does not check `busy` before asserting `start`, a missed transaction will occur.  
**Verification status:** This behavior is not tested in the current testbench.

---

## 8. No Waveform Evidence in Repository

**Limitation:** The Vivado behavioral simulation was run successfully, but no waveform screenshot or Tcl console log was saved to this repository.  
**Impact:** The verification section relies on reported results, not independent visual evidence captured in this repository.  
**Future action:** Run the simulation, screenshot the waveform showing CS/SCLK/MOSI/MISO, and commit to `waveforms/`.

---

## 9. No Inter-Transaction Gap Tested

**Limitation:** Only one transaction was simulated.  
**Impact:** Behavior during and between multiple sequential transactions is untested. Potential issues:
  - `bit_cnt` not resetting correctly
  - `slave` state not returning to IDLE properly
  - MISO preload not re-occurring correctly on second transaction

---

## 10. Clocking Strategy Limitations for Future Synthesis

**Limitation:** SCLK is a data register toggled by the FSM — which is correct for simulation. However, when implementing on an FPGA:
  - The synthesis tool must be told SCLK is NOT a real clock (via constraints)
  - If other logic accidentally uses `posedge sclk`, CDC issues arise
  - SCLK jitter will match the system-clock resolution

**For this simulation-only version:** These are non-issues. For future FPGA work, the constraint file must explicitly classify SCLK as a generated output, not a clock input.

---

## Summary

| Limitation | Severity | Future Plan |
|---|---|---|
| Fixed 8-bit width | Medium | Parameterize DATA_WIDTH |
| Mode 0 only | Medium | Add CPOL/CPHA parameters |
| Single slave | Medium | Add NUM_SLAVES and CS bus |
| Simulation only, no FPGA | High (for hardware claims) | Synthesize, implement, program |
| No FIFO | Low for single-byte use | Add FIFO module if needed |
| No error detection | Low for learning project | Add in v2 |
| No waveform in repo | Medium | Capture and commit |
| No back-to-back tests | Low | Add to testbench |
