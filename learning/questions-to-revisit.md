# Questions to Revisit

This document tracks questions, concepts, and implementation details that need deeper study before the interview. Update this list as you work through them.

---

## SPI Protocol — Open Questions

- [ ] What exactly does CPHA=1 change in the transaction timing? Walk through a full bit cycle.
- [ ] For Mode 2 and Mode 3, draw the SCLK, MOSI, MISO waveform yourself without looking it up.
- [ ] If CS goes HIGH in the middle of a transfer, what should happen on each side?
- [ ] Is it ever valid to have two CS lines LOW at the same time? When?

---

## RTL Implementation — Open Questions

- [ ] In the slave's ACTIVE state: if `bit_cnt == 8` is checked in the same always block as edge detection — what happens if the 8th bit is processed and bit_cnt=8 in the same cycle? Does the FSM immediately transition to IDLE correctly?
- [ ] What happens in the master if `start` is pulsed while `busy` is HIGH? Trace through the FSM.
- [ ] What happens if `CLK_DIV = 1`? Does the first tick fire in the right relationship to CS assertion?
- [ ] In the master TRANSFER state — `bit_cnt` is checked OUTSIDE the `if (tick)` block. Why? What could go wrong if it were inside?
- [ ] Trace a full 0xA5 transmission manually, bit by bit, through `tx_shift`, cycle by cycle.

---

## Verilog Concepts — Needs Reinforcement

- [ ] What is the difference between `always @(*)` and `always @(a or b or c)` in Verilog-2001?
- [ ] What is an inferred latch? When does it accidentally appear?
- [ ] What does the `default` case in an FSM `case` statement prevent?
- [ ] What is the difference between `===` (case equality) and `==` (logical equality) in testbenches?
- [ ] What does `reg` mean inside `always @(*)`? Why is it still not a flip-flop?

---

## Verification — Open Questions

- [ ] How would I verify the reset-during-transfer scenario? Write the testbench code.
- [ ] How would I count SCLK edges across multiple back-to-back transactions?
- [ ] What is a VCD file? How do I open it in GTKWave?
- [ ] What is a SystemVerilog assertion? Write a property for "CS must be LOW while SCLK is active."

---

## FPGA and Synthesis — Open Questions

- [ ] What warnings does Vivado typically flag during synthesis for this design?
- [ ] What is a timing report? What is setup slack?
- [ ] How do I tell Vivado that SCLK is not a real clock (it's a data signal)?
- [ ] What is the difference between LUT and flip-flop in FPGA resource usage?
- [ ] What would the logic analyzer waveform look like for a 0xA5 transaction at 12.5 MHz? Sketch it.

---

## Interview Scenarios — Practice These

- [ ] "Draw the SPI Master FSM states and transitions on a whiteboard."
- [ ] "Explain why non-blocking assignment is needed in this shift register."
- [ ] "The interviewer changes CLK_DIV to 2. What happens to the SCLK frequency? How many system-clock cycles does the full 8-bit transaction take?"
- [ ] "Can your slave work if connected to a real external SPI master (from another FPGA)?"
- [ ] "If the testbench used blocking `=` instead of `<=` in the initial block, what would happen?"
- [ ] "Explain metastability to me."
- [ ] "You said behavioral simulation passed. What does that mean, exactly? What does it NOT prove?"

---

## Things I Cannot Yet Answer Confidently

| Question | Gap |
|---|---|
| Draw Mode 1 timing diagram | Not practiced |
| Explain setup time violation with a concrete example | Conceptual only |
| Describe what Vivado synthesis output looks like | Never run synthesis |
| Read a timing report and explain slack | No experience |
| Explain what happens when two clock domains cross without synchronizers | Conceptual only |
| Describe CDC synchronizer circuit | Not studied |

---

## Resources to Study

- [ ] Re-read `docs/05-spi-mode-0.md` and draw Mode 1, 2, 3 timing yourself
- [ ] Re-read `docs/06-rtl-design.md` and trace through one complete bit cycle
- [ ] Run the simulation again and capture the waveform
- [ ] Try to answer all 25 questions in `learning/interview-preparation.md` without looking at the answers
- [ ] Study what Vivado synthesis reports look like (YouTube: "Vivado synthesis tutorial")
