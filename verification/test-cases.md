# Test Cases

This document tracks all test cases for the SPI Master–Slave Controller.

---

## Status Legend

| Status | Meaning |
|---|---|
| ✅ PASSED | Ran in simulation, all checks passed |
| ❌ FAILED | Ran in simulation, one or more checks failed |
| 🔶 PARTIAL | Ran but some checks not applied |
| ⬜ PLANNED | Not yet run |

---

## Executed Test Cases

| # | Test Name | Master TX | Slave TX | Expected Master RX | Expected Slave RX | Expected SCLK Edges | Status |
|---|---|---|---|---|---|---|---|
| TC-01 | Basic full duplex transfer | `0xA5` (10100101) | `0x5A` (01011010) | `0x5A` | `0xA5` | 8 | ✅ PASSED |

**TC-01 details:**
- Verified in Vivado behavioral simulation
- Tcl console reported RESULT: ALL CHECKS PASSED
- 5 checks performed: CS assert, master_rx, slave_rx, SCLK count, CS deassert

---

## Planned Test Cases

| # | Test Name | Master TX | Slave TX | Expected Master RX | Expected Slave RX | Purpose |
|---|---|---|---|---|---|---|
| TC-02 | All zeros | `0x00` | `0x00` | `0x00` | `0x00` | Verify no false positives from default 0 state |
| TC-03 | All ones | `0xFF` | `0xFF` | `0xFF` | `0xFF` | Verify all-ones path through shift registers |
| TC-04 | Alternating bits A | `0xAA` | `0x55` | `0x55` | `0xAA` | Maximum toggle frequency on bus |
| TC-05 | Different pattern | `0x3C` | `0xC3` | `0xC3` | `0x3C` | Non-complementary pattern |
| TC-06 | Asymmetric values | `0xF0` | `0x0F` | `0x0F` | `0xF0` | High nibble / low nibble |
| TC-07 | Reset during transfer | — | — | CS returns HIGH | FSM in IDLE | Verify abort on reset |
| TC-08 | Back-to-back (5×) | Alternating | Alternating | Correct each time | Correct each time | No state leaks between transactions |
| TC-09 | Start while busy | `0xA5` → `0xFF` (ignored) | `0x5A` | `0x5A` | `0xA5` | Verify start ignored if busy |

---

## Edge Cases Not Yet Considered

| Case | Concern |
|---|---|
| CLK_DIV = 1 | SCLK at system frequency — may cause edge-detection issues |
| Very large CLK_DIV (e.g., 256) | Long simulation time, but otherwise should work |
| `start` asserted for multiple cycles | Only first cycle should matter (IDLE → TRANSFER) |
| Slave `tx_data` changed during transaction | Should have no effect — tx_shift latched at start of transaction |
