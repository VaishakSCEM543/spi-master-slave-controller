# Learning Log

This is a personal record of my learning journey through the SPI Master–Slave Controller project. It documents what I understood, what was corrected, and where gaps remain.

---

## Starting Point — What I Initially Understood

Before this project, my understanding of SPI was at the embedded-systems user level:

- SPI is a fast communication protocol
- It uses 4 pins: MISO, MOSI, SCK, and chip select
- If I have 3 sensors, I don't need 12 pins — I need 6 (shared bus + individual CS)
- SPI is full duplex — send and receive at the same time
- CS goes LOW to select a sensor

**What I did NOT understand:**
- What CPOL and CPHA mean
- What Mode 0 specifically means in hardware
- What RTL actually is versus software
- Why an FSM is needed
- What a shift register does at the hardware level
- Why the SPI clock is a register in the RTL, not a real clock
- What simulation proves vs. what FPGA hardware validation proves
- What "verified" means in a rigorous engineering sense

---

## Corrections to My Initial Understanding

### Correction 1: CS polarity

**I originally said:** "CS goes HIGH if I want to communicate."  
**Correction:** CS is normally **active-low**. CS=LOW means selected. CS=HIGH means deselected.

### Correction 2: Power consumption

**I originally said:** "SPI uses more power than I²C."  
**Correction:** This is too absolute. Power consumption depends on clock frequency, voltage, load capacitance, and usage patterns. A safer statement: SPI can have higher switching activity at higher clock rates, but actual power depends on implementation.

### Correction 3: Camera interfaces

**I originally said:** "Cameras use SPI because they generate lots of data."  
**Correction:** Modern cameras typically use MIPI CSI-2 or parallel interfaces for image data. SPI may be used for control/configuration in some camera systems, but it is not the primary image data transport.

### Correction 4: "SPI reads sensors simultaneously"

**I originally said:** "With three sensors, we can read them all at the same time."  
**Correction:** SPI transfers on a shared bus are sequential. However, the sensor sampling (the physical measurement) can be synchronized independently via hardware trigger/sync pins. SPI transfer timing ≠ sensor sampling timing.

---

## Important Discoveries

### Discovery 1: SPI is a communication path, not a sensing mechanism

```
Physical motion
      ↓
Sensor's internal sensing circuitry
      ↓
Internal measurement registers / FIFO
      ↓ ← SPI operates here
STM32
```

SPI carries already-measured data. It does not perform the measurement.

### Discovery 2: Why only one CS should be active

If two CS lines go LOW simultaneously, both slaves try to drive MISO at the same time. Bus contention results — signals corrupt, excessive current flows. Only one CS should be active at any time when slaves share MISO.

### Discovery 3: Hi-Z behavior

When a slave's CS=HIGH, its MISO is in a high-impedance state — it does not actively drive the bus. This is what allows multiple slaves to share one MISO wire without collisions.

### Discovery 4: RTL vs. software is a fundamentally different mindset

Writing `always @(posedge clk)` is not the same as a for-loop.  
RTL describes hardware that operates every clock cycle, in parallel.  
Understanding the hardware that the RTL represents is the key skill for VLSI/RTL interviews.

### Discovery 5: SCLK as a register (not a real clock)

In synthesizable RTL, if the slave were written `always @(posedge sclk)`, SCLK would become a second clock domain. This requires CDC synchronizers and timing constraints. The better approach for this design: SCLK is a register toggled by the master FSM, and the slave detects edges using a delayed-SCLK register (`sclk_d`). Everything stays in one clock domain.

### Discovery 6: Simulation ≠ FPGA hardware validation

Passing a behavioral simulation proves the RTL logic is correct in a software model.  
It does NOT prove:
- The design synthesizes without issues
- Timing is met on real hardware
- Physical SPI signals meet device timing requirements

This is an important honesty distinction for interviews and documentation.

### Discovery 7: I followed the implementation blindly

At the time of initial implementation, I focused on getting a working simulation result rather than deeply understanding each module. I now understand the architecture and can explain each module, but the initial approach was tool-driven rather than understanding-driven.

This is why this repository exists — to build genuine understanding alongside the code.

---

## Current Understanding

After studying the project:

- I can explain what SPI is at both the protocol level and the hardware level
- I understand why Mode 0 uses rising-edge sampling and falling-edge shifting
- I can trace a bit through the TX shift register of the master to MOSI and into the RX shift register of the slave
- I understand why the FSM exists and what each state means
- I understand what behavioral simulation proves and what it does not prove
- I can explain why SCLK is a register, not a real clock
- I can discuss metastability and CDC at a conceptual level

---

## Remaining Gaps

| Topic | Status | Next Action |
|---|---|---|
| CPOL/CPHA for Modes 1-3 | Partially understood | Read the timing diagrams for Modes 1/2/3 |
| Synthesis process in Vivado | Not done | Run synthesis, read timing report |
| Flip-flop setup/hold timing | Conceptual only | Study with actual FPGA timing report |
| Metastability at circuit level | Conceptual only | Study flip-flop bistable behavior |
| Formal verification | Not started | Future learning goal |
| UVM testbench structure | Not started | Future learning goal |
| Reading FPGA timing reports | Not done | After synthesis |
| Logic analyzer usage | Not done | After FPGA programming |
