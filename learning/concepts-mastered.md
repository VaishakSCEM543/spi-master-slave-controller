# Concepts Mastered

Tracking understanding of each concept in this project.

**Status legend:**
- ✅ **MASTERED** — Can explain from first principles, answer follow-ups, trace through hardware
- 🔶 **UNDERSTANDING** — Core concept clear, some deeper details need reinforcement
- 🔴 **NEEDS PRACTICE** — Rough understanding, cannot defend under follow-up questioning
- ⬜ **NOT STARTED** — Not yet studied

---

## SPI Protocol

| Concept | Status | Notes |
|---|---|---|
| What SPI is | ✅ MASTERED | Can explain clearly at multiple levels |
| Four SPI signals (SCK, MOSI, MISO, CS) | ✅ MASTERED | Direction, purpose, and naming understood |
| Master/slave roles | ✅ MASTERED | Master controls clock and CS |
| Active-low CS | ✅ MASTERED | CS=LOW means selected |
| Full duplex | ✅ MASTERED | Separate MOSI/MISO lines, simultaneous |
| Multiple slaves — pin count math | ✅ MASTERED | 3 shared + 3 CS = 6 for 3 slaves |
| Hi-Z behavior on shared MISO | ✅ MASTERED | Only selected slave drives MISO |
| Bus contention | ✅ MASTERED | Two CS active = both slaves drive MISO = corruption |
| SPI vs. I²C comparison | 🔶 UNDERSTANDING | Key differences known, deeper I²C not studied |
| Sensor sampling vs. SPI transfer timing | ✅ MASTERED | Two separate concepts |
| CPOL / CPHA definition | ✅ MASTERED | CPOL=idle level, CPHA=which edge |
| SPI Mode 0 timing | ✅ MASTERED | Idle LOW, sample rising, shift falling |
| SPI Modes 1, 2, 3 | 🔴 NEEDS PRACTICE | Know they exist, cannot fully describe each |

---

## Digital Hardware Fundamentals

| Concept | Status | Notes |
|---|---|---|
| What a register/flip-flop is | ✅ MASTERED | Stores state, updates on clock edge |
| What a clock edge means | ✅ MASTERED | Rising edge = posedge clk |
| Serial vs. parallel data | ✅ MASTERED | One bit at a time vs. all bits at once |
| What a shift register does | ✅ MASTERED | Converts parallel to serial and back |
| How bits shift left on MOSI | ✅ MASTERED | `{tx_shift[6:0], 1'b0}` — MSB exits first |
| How bits accumulate in RX shift | ✅ MASTERED | `{rx_shift[6:0], miso}` — enters at LSB |
| What a counter does | ✅ MASTERED | Increments each clock, compared to limit |
| What an FSM is | 🔶 UNDERSTANDING | Can describe states and transitions, Moore/Mealy not clear |
| Combinational vs. sequential logic | 🔶 UNDERSTANDING | Understand the concept, full formal definition needs review |
| What a clock divider does | ✅ MASTERED | Generates slower clock from faster one |

---

## Verilog RTL

| Concept | Status | Notes |
|---|---|---|
| What RTL means | ✅ MASTERED | Register Transfer Level — hardware description |
| `module` and ports | ✅ MASTERED | Hardware component boundary |
| `wire` vs. `reg` | 🔶 UNDERSTANDING | Know the difference, not-always-a-register subtlety |
| `always @(posedge clk)` | ✅ MASTERED | Clocked sequential logic — flip-flop synthesis |
| Non-blocking `<=` | ✅ MASTERED | Why it's needed for shift registers (all RHS evaluated first) |
| Blocking `=` vs. non-blocking `<=` | 🔶 UNDERSTANDING | Know the rule, need practice to spot bugs |
| `case` statement for FSM | ✅ MASTERED | State register, case arms select behavior |
| `parameter` and `localparam` | ✅ MASTERED | Compile-time constants |
| Concatenation `{}` | ✅ MASTERED | Used in shift operations |
| `always @(*)` | 🔶 UNDERSTANDING | Combinational — understand concept |
| Asynchronous reset | ✅ MASTERED | `posedge rst` in sensitivity list |
| Simulation tasks (`$display`, `$dumpfile`) | ✅ MASTERED | Testbench-only, not synthesizable |

---

## Verification

| Concept | Status | Notes |
|---|---|---|
| What a testbench is | ✅ MASTERED | Non-synthesizable DUT driver and checker |
| What DUT means | ✅ MASTERED | Device Under Test |
| What stimulus means | ✅ MASTERED | Inputs applied to DUT |
| Self-checking testbench | ✅ MASTERED | Automated PASS/FAIL without manual inspection |
| Behavioral simulation | ✅ MASTERED | Software simulation of RTL logic |
| Behavioral vs. FPGA hardware validation | ✅ MASTERED | Critical distinction — can explain clearly |
| VCD waveform files | 🔶 UNDERSTANDING | Know what they are, not practiced reading them |
| Timeout mechanism in testbench | ✅ MASTERED | Why needed, both versions (fork/join_any vs. counter) |
| Assertions / formal verification | ⬜ NOT STARTED | Future learning |
| UVM | ⬜ NOT STARTED | Future learning |

---

## FPGA and Synthesis

| Concept | Status | Notes |
|---|---|---|
| RTL → Synthesis → Implementation → Bitstream | 🔶 UNDERSTANDING | Can describe the pipeline, details of each step unclear |
| What synthesis does | 🔶 UNDERSTANDING | Converts RTL to gate-level netlist |
| What implementation does | 🔴 NEEDS PRACTICE | Place and route — details unclear |
| What a bitstream is | 🔶 UNDERSTANDING | Configuration file for FPGA hardware |
| Timing constraints | ⬜ NOT STARTED | Future learning |
| Setup and hold time | 🔴 NEEDS PRACTICE | Conceptual only |
| Metastability | 🔴 NEEDS PRACTICE | Conceptual only — flip-flop instability |
| Clock Domain Crossing (CDC) | 🔶 UNDERSTANDING | Understand the concept, mitigation techniques unclear |
| Logic analyzer usage | ⬜ NOT STARTED | Future hardware work |
