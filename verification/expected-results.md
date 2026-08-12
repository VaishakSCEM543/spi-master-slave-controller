# Expected Results

Expected outputs for all test cases, derived from the design specification.

---

## How Expected Results Are Derived

For an 8-bit, full-duplex, MSB-first SPI Mode 0 transaction:

After 8 SCLK rising-edge samples:
- `master_rx_data` = whatever the slave had in `tx_data` at the start of the transaction
- `slave_rx_data` = whatever the master had in `tx_data` at the start of the transaction

Because SPI is full duplex: the two bytes simply swap — master gets slave's byte, slave gets master's byte.

---

## TC-01 — Basic Full Duplex Transfer

| Signal | Expected |
|---|---|
| `master_rx_data` | `0x5A` (01011010) |
| `slave_rx_data` | `0xA5` (10100101) |
| SCLK rising edges (during CS low) | 8 |
| CS after transaction | 1 (HIGH) |
| CS after `start` | 0 (LOW, within 2 cycles) |
| `done` asserted | 1 (single cycle pulse) |

**Bit-by-bit trace of MOSI (Master TX = 0xA5 = 10100101, MSB first):**
```
Clock edge 1: MOSI = 1 (bit 7)
Clock edge 2: MOSI = 0 (bit 6)
Clock edge 3: MOSI = 1 (bit 5)
Clock edge 4: MOSI = 0 (bit 4)
Clock edge 5: MOSI = 0 (bit 3)
Clock edge 6: MOSI = 1 (bit 2)
Clock edge 7: MOSI = 0 (bit 1)
Clock edge 8: MOSI = 1 (bit 0)
```

**Bit-by-bit trace of MISO (Slave TX = 0x5A = 01011010, MSB first):**
```
Clock edge 1: MISO = 0 (bit 7)
Clock edge 2: MISO = 1 (bit 6)
Clock edge 3: MISO = 0 (bit 5)
Clock edge 4: MISO = 1 (bit 4)
Clock edge 5: MISO = 1 (bit 3)
Clock edge 6: MISO = 0 (bit 2)
Clock edge 7: MISO = 1 (bit 1)
Clock edge 8: MISO = 0 (bit 0)
```

---

## TC-02 — All Zeros

| Signal | Expected |
|---|---|
| `master_rx_data` | `0x00` |
| `slave_rx_data` | `0x00` |
| SCLK edges | 8 |
| CS final | HIGH |

**Purpose:** Confirms that a result of `0x00` is actually the correct received data, not merely the default/uninitialized register state.

---

## TC-03 — All Ones

| Signal | Expected |
|---|---|
| `master_rx_data` | `0xFF` |
| `slave_rx_data` | `0xFF` |
| SCLK edges | 8 |
| CS final | HIGH |

---

## TC-04 — Alternating Bits

| Signal | Expected |
|---|---|
| `master_rx_data` | `0x55` (01010101) |
| `slave_rx_data` | `0xAA` (10101010) |
| SCLK edges | 8 |
| CS final | HIGH |

**Purpose:** Maximum toggling on MOSI and MISO — reveals any edge-timing issues in the shift register.

---

## TC-07 — Reset During Transfer (Expected Behavior)

| Signal | Expected |
|---|---|
| `busy` after reset | 0 (LOW) |
| `cs` after reset | 1 (HIGH) |
| `sclk` after reset | 0 (LOW) |
| `state` after reset | IDLE |
| `master_rx_data` | 0 (cleared) |
| `slave_rx_data` | 0 (cleared) |

**Purpose:** Confirms that mid-transaction reset cleanly aborts the transfer and returns to a safe idle state.
