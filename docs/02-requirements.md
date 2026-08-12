# 02 — Requirements

## Design Requirements

These are the requirements established before implementation began.

---

### Protocol Requirements

| Requirement | Value | Rationale |
|---|---|---|
| SPI Mode | Mode 0 | CPOL=0, CPHA=0 — simplest mode: clock idles low, sample on rising edge |
| Data width | 8 bits | One byte per transaction — simplest complete unit |
| Bit order | MSB first | Standard convention for most SPI devices |
| Transfer type | Full duplex | Both master and slave can send and receive simultaneously |
| CS polarity | Active-low | Standard — CS=0 means selected, CS=1 means deselected |
| Clock relationship | SCLK derived from system clock | Single clock domain — no CDC |

---

### Architecture Requirements

| Requirement | Decision |
|---|---|
| Number of masters | 1 |
| Number of slaves | 1 |
| Clock architecture | All logic on `posedge clk` — SCLK is a register, not a clock net |
| Clock division | Parameterized — `CLK_DIV` system-clock cycles per SCLK half-period |
| Default CLK_DIV | 4 — at 100 MHz system clock: SCLK ≈ 12.5 MHz |
| Reset | Asynchronous active-high — forces clean initial state |
| Language | Synthesizable Verilog-2001 (RTL files); Verilog-2001 testbench |

---

### Functional Requirements

#### Master

| Requirement | Implementation |
|---|---|
| Accept a byte to transmit | `tx_data[7:0]` input, latched on `start` |
| Signal transaction in progress | `busy` output, high during transfer |
| Signal completion | `done` output, single-cycle pulse |
| Generate SCLK | Internal FSM toggles `sclk` register on each `tick` |
| Assert CS low at start, high at end | FSM-controlled |
| Preload MOSI with MSB before first SCLK edge | Required for CPHA=0 |
| Sample MISO on SCLK rising edge | `rx_shift <= {rx_shift[6:0], miso}` |
| Shift MOSI on SCLK falling edge | `tx_shift <= {tx_shift[6:0], 1'b0}` |
| Count exactly 8 bits | `bit_cnt` increments on each rising edge sample |

#### Slave

| Requirement | Implementation |
|---|---|
| Accept a byte to transmit back | `tx_data[7:0]` input |
| Detect SCLK edges without second clock domain | `sclk_d` register — edge detector pattern |
| Sample MOSI on SCLK rising edge | `rx_shift <= {rx_shift[6:0], mosi}` |
| Shift MISO on SCLK falling edge | `tx_shift <= {tx_shift[6:0], 1'b0}` |
| Preload MISO MSB while IDLE | So MISO is valid the instant CS drops |
| Detect CS assertion | `!cs` in IDLE state |
| Output received byte | `rx_data[7:0]`, valid when `done` pulses |

---

### Simulation Requirements

| Requirement | Implementation |
|---|---|
| Self-checking testbench | Automated PASS/FAIL, no manual waveform inspection required |
| Check master received data | `master_rx_data == 0x5A` |
| Check slave received data | `slave_rx_data == 0xA5` |
| Check SCLK edge count | Exactly 8 rising edges during CS-low window |
| Check CS behavior | Asserts low after start, returns high after done |
| Timeout guard | 500-cycle timeout on `busy` — prevents infinite simulation hang |
| Compatibility | Verilog-2001 only — no SystemVerilog constructs |

---

### Non-Functional Requirements

| Requirement | Note |
|---|---|
| Synthesizable RTL | No simulation-only constructs in RTL files |
| Single clock domain | No clock-domain-crossing concerns for this version |
| Parameterized timing | `CLK_DIV` parameter allows changing SPI speed without editing logic |
| Honest documentation | Status labels (IMPLEMENTED / SIMULATED / VERIFIED / PLANNED) used throughout |

---

### Out of Scope (This Version)

| Feature | Status |
|---|---|
| Parameterized data width | PLANNED |
| SPI Modes 1, 2, 3 | PLANNED |
| Multiple slaves with CS arbitration | PLANNED |
| FIFO buffering | PLANNED |
| SystemVerilog assertions | PLANNED |
| Formal verification | PLANNED |
| FPGA synthesis and implementation | PLANNED |
| Physical hardware validation | PLANNED |
