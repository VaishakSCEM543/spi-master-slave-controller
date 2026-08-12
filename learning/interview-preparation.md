# 12 — Interview Preparation

This document organizes interview questions from basic to advanced, with honest expected answers, key points, likely follow-ups, and common traps.

---

## Level 1 — SPI Fundamentals

### Q1: What is SPI?

**Answer:**  
SPI, or Serial Peripheral Interface, is a synchronous serial communication protocol commonly used between a microcontroller and peripherals like sensors, memory, and displays. A typical SPI interface uses four signals: SCK (clock), MOSI (master out, slave in), MISO (master in, slave out), and CS (chip select). The master generates the clock and selects the slave using CS.

**Key points:**
- Synchronous (uses a shared clock)
- Serial (one bit at a time)
- Usually full duplex (separate MOSI and MISO lines)
- Master controls everything

**Common mistake:**  
Saying "SPI is a 4-pin protocol" — SPI typically uses 4 signal lines, but it is not universally defined as exactly 4 pins. Some implementations are 3-wire, half-duplex, or have multiple CS pins.

---

### Q2: What does MOSI mean?

**Answer:**  
MOSI = Master Out, Slave In. It is the data line that carries data from the master to the slave. From the master's perspective, it is an output. From the slave's perspective, it is an input.

**Follow-up:** What is MISO?  
Master In, Slave Out — data from slave to master.

---

### Q3: Why does SPI need a clock?

**Answer:**  
SPI is a synchronous protocol. Both devices need to agree on exactly when each bit is valid. The clock provides a shared timing reference. On each clock edge, both devices either transmit or sample a bit. Without a shared clock, neither device would know when to read the incoming data line.

---

### Q4: What does CS=LOW mean?

**Answer:**  
CS is active-low. CS=LOW means the slave is selected and should participate in the transaction. CS=HIGH means the slave is deselected — it enters a high-impedance state on MISO and ignores MOSI.

**Common mistake:** Saying CS=HIGH means selected. The opposite is true for the standard active-low convention.

---

### Q5: Can multiple devices share the MISO line?

**Answer:**  
Yes — but only one slave should actively drive MISO at a time. When a slave is not selected (CS=HIGH), its MISO output is in a high-impedance (Hi-Z) state, so it does not interfere with the bus. The master selects exactly one slave at a time by pulling only that slave's CS LOW.

---

## Level 2 — Project-Specific Questions

### Q6: What did you build?

**Answer:**  
An 8-bit SPI Mode 0 master-slave controller in synthesizable Verilog RTL. The master generates SCLK, asserts CS, shifts 8 bits out on MOSI, and samples 8 bits from MISO simultaneously. The slave detects SCLK edges, samples MOSI, and shifts data out on MISO. I verified the design using Vivado behavioral simulation with a self-checking testbench.

**Key distinction to make:**  
I designed the SPI hardware itself — not a firmware driver that uses an existing SPI peripheral.

---

### Q7: Why did you choose SPI Mode 0?

**Answer:**  
Mode 0 uses CPOL=0 (clock idles LOW) and CPHA=0 (data sampled on the first, rising edge). It is the most common and simplest mode to implement first. Most general-purpose SPI peripherals support Mode 0. Starting with Mode 0 allowed me to focus on the core logic — shift registers, FSM, bit counting — without adding mode-selection complexity.

---

### Q8: Why use a clock divider?

**Answer:**  
The system clock runs at 100 MHz in our testbench. SPI devices typically run at a lower frequency. The clock divider generates a periodic tick pulse — one per CLK_DIV system-clock cycles — that the master uses to toggle SCLK. With CLK_DIV=4, the SCLK half-period is 4 system-clock cycles, giving SCLK ≈ 12.5 MHz.

**Follow-up:** Why not just use SCLK as a real clock?  
See Q14 below.

---

### Q9: Why MSB first?

**Answer:**  
MSB-first is the standard convention for most SPI devices. Shifting MSB first means the most significant bit is transmitted first and received first — which is the natural order for reading the byte after the full transfer.

---

### Q10: Why use a shift register?

**Answer:**  
SPI is a serial interface — it sends one bit per clock cycle. A shift register converts between parallel (the full 8-bit byte) and serial (one bit at a time). On each SCLK edge, the shift register moves one bit position: the MSB is output on MOSI/MISO, and the register shifts left, exposing the next bit. After 8 shifts, all bits have been transmitted.

---

### Q11: Why use a bit counter?

**Answer:**  
The master needs to know when exactly 8 bits have been transferred to end the transaction. The bit counter increments on each SCLK rising edge (each sampled bit). When it reaches 8, the FSM transitions to FINISH and deasserts CS.

---

## Level 3 — RTL and Digital Design

### Q12: What is RTL?

**Answer:**  
RTL stands for Register Transfer Level. It is a design abstraction where we describe hardware in terms of registers (flip-flops that store state) and how data moves between them at each clock edge. Verilog written at RTL level describes actual hardware — flip-flops, multiplexers, counters — not software instructions.

---

### Q13: Why use non-blocking assignment `<=` instead of blocking `=`?

**Answer:**  
Non-blocking assignment means all right-hand sides are evaluated simultaneously using current values, and all left-hand sides are updated at the end of the time step. This models flip-flop behavior correctly.

If I wrote `tx_shift = {tx_shift[6:0], 1'b0}` followed by `mosi = tx_shift[6]`, the shift would happen first and MOSI would get the wrong bit — the bit after the shift, not before. With `<=`, both see the old value, which is the correct hardware behavior.

---

### Q14: Why is SCLK implemented as a register, not a real clock?

**Answer:**  
If SCLK were used as a clock (i.e., the slave were written `always @(posedge sclk)`), it would create a second clock domain. The SCLK and system clock would have different clock constraints, requiring CDC synchronizers between them.

In this design, everything runs on `posedge clk`. SCLK is just a data register that the master toggles. The slave detects SCLK edges by comparing `sclk` to a one-cycle-delayed copy `sclk_d`. This keeps the entire design in a single clock domain — simpler, synthesis-friendly, and CDC-free.

**Key insight for interviews:** This is a deliberate design decision, not a shortcut.

---

### Q15: What does the slave's `sclk_d` register do?

**Answer:**  
`sclk_d` is a one-system-clock-cycle-delayed copy of SCLK. By comparing `sclk` (current) with `sclk_d` (one cycle ago):

- `!sclk_d && sclk` → SCLK just went 0→1 (rising edge)
- `sclk_d && !sclk` → SCLK just went 1→0 (falling edge)

This gives the slave a way to detect SCLK transitions using only the system clock, without needing `posedge sclk` in its sensitivity list.

---

### Q16: What happens during reset?

**Answer:**  
The reset is asynchronous active-high. On `posedge rst`:
- FSM returns to IDLE
- CS is forced HIGH (deselected)
- SCLK is forced LOW (CPOL=0 idle)
- All shift registers cleared to 0
- bit_cnt cleared to 0
- busy and done forced LOW

This ensures the system starts in a known, safe state regardless of where in the transaction it was.

---

## Level 4 — Verification

### Q17: What is a testbench?

**Answer:**  
A testbench is a non-synthesizable Verilog file that instantiates the DUT (Device Under Test) and drives its inputs with test stimuli, then checks its outputs against expected values. The testbench generates the clock, applies reset, initiates transactions, and reports PASS or FAIL. It is simulation infrastructure — it has no hardware equivalent.

---

### Q18: How did you verify the 8-bit transfer?

**Answer:**  
I used a self-checking testbench that:
1. Applied Master TX = 0xA5, Slave TX = 0x5A
2. Counted SCLK rising edges while CS was LOW using an always block
3. After `done` asserted, compared `master_rx_data` against `0x5A` and `slave_rx_data` against `0xA5`
4. Verified the edge count was exactly 8
5. Verified CS returned HIGH after the transaction

All five checks passed.

---

### Q19: What is behavioral simulation vs. FPGA validation?

**Answer:**  
Behavioral simulation runs the RTL model in software — it verifies the logical behavior of the design. FPGA validation means the RTL has been synthesized, implemented, and programmed onto physical FPGA hardware, where actual electrical signals are generated and can be measured.

This project has completed behavioral simulation. FPGA hardware validation is planned future work. These must not be confused in documentation or conversation.

---

## Level 5 — FPGA and Synthesis

### Q20: What happens after RTL is written?

**Answer:**  
The synthesis tool (like Vivado) converts the RTL into a netlist of logic gates and flip-flops. Then the implementation tool maps that netlist to the FPGA's physical resources (LUTs, flip-flops, routing). A bitstream is generated. The bitstream is loaded onto the FPGA board, and the design becomes real hardware.

```
Verilog RTL → Synthesis → Netlist → Implementation → Bitstream → FPGA
```

---

### Q21: Did you program an FPGA?

**Honest answer:**  
No. The current status of this project is behavioral simulation. The RTL has been written in synthesizable Verilog-2001 style, but I have not yet run synthesis, implementation, or programmed a physical FPGA board. That is planned future work.

**What I have done:** Designed RTL, ran Vivado behavioral simulation, verified correctness through a self-checking testbench.

---

## Level 6 — Deeper Follow-Ups

### Q22: What is metastability?

**Answer:**  
Metastability occurs when a flip-flop's setup or hold time is violated — typically when data changes too close to the clock edge. The flip-flop enters an undefined intermediate state and may take longer than one clock period to resolve. If the output is used before it resolves, it can propagate an indeterminate value through the design, causing glitches or incorrect behavior.

**Relevance to SPI:** In this design, SCLK and the system clock are from the same domain, so metastability is not a concern. If SCLK were an independent external clock (e.g., from a real external master), synchronization registers would be needed before the slave samples SCLK.

---

### Q23: What is clock domain crossing (CDC)?

**Answer:**  
CDC occurs when a signal produced by logic in one clock domain is used by logic in another clock domain. Because the two clocks are asynchronous relative to each other, setup and hold times may be violated, causing metastability.

**In this project:** There is no CDC. Everything runs on `posedge clk`. SCLK is a register — not a real clock net. This was a deliberate design choice to avoid CDC complexity.

---

### Q24: What would you change if designing a second version?

**Key points to mention:**
- Parameterize data width
- Add support for all four SPI modes via CPOL/CPHA parameters
- Add multiple slave support with CS bus
- Write more testbench test cases
- Run synthesis and check timing reports
- Eventually validate on real FPGA hardware with a logic analyzer

---

### Q25: What happens if CPHA = 1?

**Answer:**  
With CPHA=1, data is sampled on the second clock edge (falling edge for CPOL=0) instead of the first (rising edge). The current design always samples on the rising edge. Changing to CPHA=1 would require:
- Master: sample MISO on falling edge instead of rising edge
- Master: shift TX on rising edge instead of falling edge
- Slave: same swap
- The data preloading must also change — no longer preloaded before CS, but driven after the first edge

This is a significant behavioral change and would require modifying the FSM and shift logic.

---

## Quick Reference Answers

| Question | Short Answer |
|---|---|
| What is SPI? | Synchronous serial protocol: SCK, MOSI, MISO, CS |
| Who generates SCLK? | Master |
| What is CS=LOW? | Slave is selected |
| What is full duplex? | MOSI and MISO simultaneously |
| What is CPOL=0? | Clock idles LOW |
| What is CPHA=0? | Sample on first (rising) edge |
| What is MSB first? | Bit 7 transmitted first |
| What is RTL? | Register Transfer Level — hardware description |
| Why non-blocking <=? | Models flip-flop behavior — all updates simultaneous |
| Did you use FPGA? | No — behavioral simulation only |
| What is metastability? | Flip-flop in undefined state due to timing violation |
| What is CDC? | Signal crossing clock domains — needs synchronizers |
