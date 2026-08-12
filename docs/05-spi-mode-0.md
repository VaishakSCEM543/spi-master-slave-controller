# 05 — SPI Mode 0

## The Four SPI Modes

SPI does not define a single fixed timing relationship between the clock and data.  
Instead, there are **four modes**, defined by two parameters:

| Parameter | Meaning | Values |
|---|---|---|
| CPOL — Clock Polarity | What level SCLK sits at when idle (no transfer) | 0 = idle LOW, 1 = idle HIGH |
| CPHA — Clock Phase | Which clock edge is used to sample data | 0 = first edge (leading), 1 = second edge (trailing) |

Combining these gives four modes:

| Mode | CPOL | CPHA | Clock idle | Sample edge | Shift edge |
|---|---|---|---|---|---|
| 0 | 0 | 0 | LOW | Rising (1st) | Falling (2nd) |
| 1 | 0 | 1 | LOW | Falling (2nd) | Rising (1st) |
| 2 | 1 | 0 | HIGH | Falling (1st) | Rising (2nd) |
| 3 | 1 | 1 | HIGH | Rising (2nd) | Falling (1st) |

---

## This Project Uses Mode 0

**CPOL = 0:** Clock idles LOW.  
**CPHA = 0:** Data is sampled on the **first** edge (rising edge) and shifted on the **second** edge (falling edge).

---

## Why Mode 0?

Mode 0 is the most common and the simplest to implement:

- Clock starts at 0 — easy initial state
- Sample on rising edge — intuitive
- Most SPI sensors and memory devices support Mode 0

For a first RTL implementation, Mode 0 is the natural starting point.

---

## Mode 0 Timing Diagram

A complete 8-bit Mode 0 transaction:

```
CS:       ‾‾‾‾‾\_________________________________/‾‾‾‾‾‾
                ↑ CS goes LOW                    ↑ CS goes HIGH

SCLK:     _____|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|___
                  ↑   ↑   ↑   ↑   ↑   ↑   ↑   ↑
                  └───────────────────────────────── 8 rising edges
                  (sample MISO on each ↑)

MOSI:     _____B7__B6__B5__B4__B3__B2__B1__B0_____
               ↑ preloaded        ↓ shifted on ↓ edges

MISO:     _____B7__B6__B5__B4__B3__B2__B1__B0_____
               ↑ preloaded by slave before CS drops
```

**B7 = MSB (bit 7), B0 = LSB (bit 0)**

---

## CPHA=0: The "Data Before Clock" Rule

CPHA=0 means the data must be **stable before the first clock edge**.

For the master:
- When `start` is asserted, the FSM immediately puts `tx_data[7]` onto MOSI
- Then CS goes LOW
- Only then does SCLK start toggling
- So when the first rising edge arrives, MOSI bit 7 is already stable

For the slave:
- While in IDLE state, the slave continuously drives `miso <= tx_data[7]`
- The moment CS drops LOW, MISO is already showing bit 7
- The master samples that bit on the first rising SCLK edge

This pre-loading behavior is the key implementation detail for CPHA=0.

---

## Sampling and Shifting — Detailed

### What "Sample" Means

On the **rising edge of SCLK**, both master and slave capture the current bit from the incoming data line:

```
Master samples:   miso at posedge sclk → bit goes into rx_shift
Slave samples:    mosi at posedge sclk → bit goes into rx_shift
```

### What "Shift" Means

On the **falling edge of SCLK**, both master and slave shift their TX register left by one bit, placing the next bit onto the output line:

```
Master shifts:    tx_shift << 1, new MSB onto MOSI
Slave shifts:     tx_shift << 1, new MSB onto MISO
```

### The Full Bit Flow

For each of the 8 bits (starting from MSB):

```
1. [Before CS asserts]  Data preloaded — bit 7 on MOSI, bit 7 on MISO
2. CS asserts LOW
3. SCLK rising edge     → Both sides SAMPLE (capture current bit)
4. SCLK falling edge    → Both sides SHIFT (next bit onto output line)
5. Repeat steps 3-4 for bits 6, 5, 4, 3, 2, 1, 0
6. After 8th sample     → CS deasserts HIGH, done pulse
```

---

## Why Full Duplex Works

During each clock cycle, the master's TX bit moves in one direction and the slave's TX bit moves in the opposite direction — on completely separate wires:

```
           MOSI wire
Master TX ─────────────────────────────► Slave RX

           MISO wire
Master RX ◄─────────────────────────── Slave TX
```

Because these are separate physical wires, both transfers happen in the same clock cycle without interference.  
That is why SPI is naturally **full duplex**.

---

## This Implementation's Specific Mode 0 Behavior

From the actual RTL (`spi_master.v`):

```verilog
// SCLK rising edge: sample MISO
if (sclk == 1'b0) begin          // sclk is about to go 0→1
    sclk     <= 1'b1;
    rx_shift <= {rx_shift[6:0], miso};  // sample MISO
    bit_cnt  <= bit_cnt + 1'b1;
end

// SCLK falling edge: shift next MOSI bit
else begin                        // sclk is about to go 1→0
    sclk     <= 1'b0;
    tx_shift <= {tx_shift[6:0], 1'b0};
    mosi     <= tx_shift[6];      // next bit ready
end
```

From `spi_slave.v`:

```verilog
// Rising edge detection
if (!sclk_d && sclk) begin        // sclk_d=0, sclk=1 → rising
    rx_shift <= {rx_shift[6:0], mosi};
    bit_cnt  <= bit_cnt + 1'b1;
end

// Falling edge detection
if (sclk_d && !sclk) begin        // sclk_d=1, sclk=0 → falling
    tx_shift <= {tx_shift[6:0], 1'b0};
    miso     <= tx_shift[6];
end
```

Both master and slave implement identical Mode 0 timing — sample on rising, shift on falling.

---

## Design Simplification: No 8th Falling Edge

After the 8th rising-edge sample, the master immediately transitions to FINISH state and deasserts CS — without generating an 8th falling edge.

This is a **deliberate simplification**: there is no 9th bit to shift out, so the falling edge serves no purpose. CS is dropped as soon as all 8 bits have been received.

This is noted in the RTL header and is worth mentioning if asked in an interview.
