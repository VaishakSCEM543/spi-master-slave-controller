# Verification Results

This document records actual simulation results as they are produced.

---

## TC-01 — Basic Full Duplex Transfer (`0xA5` / `0x5A`)

**Date:** 2026-08-12  
**Tool:** Vivado Behavioral Simulation (Tcl console)  
**Status:** ✅ PASSED

**Test parameters:**
- System clock: 100 MHz (10 ns period)
- CLK_DIV: 4 (SCLK half-period = 40 ns, SCLK ≈ 12.5 MHz)
- Master TX: `0xA5` (10100101)
- Slave TX: `0x5A` (01011010)

**Observed output:**
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

**Checks:**

| Check | Result |
|---|---|
| CS asserted LOW within 2 cycles of start | ✅ PASSED |
| master_rx_data == 0x5A | ✅ PASSED |
| slave_rx_data == 0xA5 | ✅ PASSED |
| SCLK rising edges == 8 | ✅ PASSED |
| CS returns HIGH after transaction | ✅ PASSED |

**Evidence:**  
⚠️ Tcl console output observed during session but not captured as a file.  
Waveform screenshot: not yet committed to this repository.  
**Action required:** Reproduce simulation and capture waveform to `waveforms/` folder.

---

## Pending Results

| Test Case | Status |
|---|---|
| TC-02 (All zeros) | ⬜ PENDING |
| TC-03 (All ones) | ⬜ PENDING |
| TC-04 (Alternating) | ⬜ PENDING |
| TC-05 (Different pattern) | ⬜ PENDING |
| TC-06 (Asymmetric) | ⬜ PENDING |
| TC-07 (Reset mid-transfer) | ⬜ PENDING |
| TC-08 (Back-to-back) | ⬜ PENDING |
| TC-09 (Start while busy) | ⬜ PENDING |

---

## How to Run

### Vivado

1. Open Vivado, create RTL project
2. Add `rtl/clk_divider.v`, `rtl/spi_master.v`, `rtl/spi_slave.v`, `rtl/spi_top.v` as Design Sources
3. Add `sim/tb_spi_top.v` as Simulation Source
4. Set `tb_spi_top` as Simulation Top
5. Flow → Run Simulation → Run Behavioral Simulation
6. Check Tcl Console for `RESULT:` line

### Icarus Verilog

```bash
iverilog -o sim.out rtl/clk_divider.v rtl/spi_master.v rtl/spi_slave.v rtl/spi_top.v sim/tb_spi_top.v
vvp sim.out
gtkwave tb_spi_top.vcd   # view waveform
```
