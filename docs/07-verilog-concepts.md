# 07 — Verilog Concepts

This document explains the Verilog constructs actually used in this project — what they mean in Verilog and what hardware they represent.

---

## 1. `module` and Ports

### Verilog Meaning

A `module` is the basic building block of Verilog. It defines a hardware component with a name, inputs, and outputs.

```verilog
module clk_divider #(
    parameter DIVISOR = 4
) (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  tick
);
```

### Hardware Meaning

A module corresponds to a physical hardware block — a chip, a sub-circuit, or a logical unit on an FPGA. Its ports are the physical wires connecting it to the rest of the system.

### In Our SPI Project

We have four modules: `clk_divider`, `spi_master`, `spi_slave`, `spi_top`. Each one maps to a distinct hardware function.

---

## 2. `wire` and `reg`

### `wire`

A `wire` is a combinational connection — it carries a signal driven by something else.

```verilog
wire tick;   // driven by clk_divider, read by spi_master
```

Hardware interpretation: A physical electrical connection.

### `reg`

A `reg` holds a value — it represents a **register** (flip-flop) when assigned inside a clocked `always` block.

```verilog
reg [7:0] tx_shift;   // shift register — holds the byte being transmitted
reg [3:0] bit_cnt;    // counter — counts bits transferred
```

Hardware interpretation: A flip-flop or a group of flip-flops that store state across clock cycles.

> **Important:** `reg` in Verilog does NOT always mean a physical register. When used inside `always @(*)` (combinational), it is still a wire in hardware. The keyword just tells Verilog the signal can be assigned inside an `always` block.

---

## 3. `always @(posedge clk or posedge rst)` — Clocked Process

### Verilog Meaning

```verilog
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // reset state
    end else begin
        // clocked logic
    end
end
```

This block runs whenever there is a **rising edge on `clk`** or a **rising edge on `rst`**.

### Hardware Meaning

This describes **synchronous flip-flops with asynchronous reset**.

Every `<=` assignment inside this block becomes a flip-flop:
- The input to the flip-flop is computed from the current signal values
- The output of the flip-flop updates on the next rising edge of `clk`

### In Our SPI Project

Every state register, shift register, counter, and output register is updated inside such a block. The entire design runs synchronously.

---

## 4. Non-Blocking Assignment `<=`

### Verilog Meaning

```verilog
always @(posedge clk) begin
    a <= b;
    b <= a;   // a and b SWAP — not sequential assignment
end
```

Non-blocking `<=` means: "evaluate the right-hand side **now** (current values), but update the left-hand side **at the end of the time step**."

Both assignments see the original values of `a` and `b`.

### Hardware Meaning

Represents flip-flop behavior — the current output of a flip-flop feeds into the next state computation, and the new state is captured on the clock edge.

### Why This Matters for Shift Registers

```verilog
tx_shift <= {tx_shift[6:0], 1'b0};   // shift left
mosi     <= tx_shift[6];             // output bit 6 (old value)
```

Because both use `<=`, `mosi` gets the OLD value of `tx_shift[6]` before the shift — which is exactly the next correct bit. If blocking `=` were used, `mosi` would get the bit AFTER the shift, giving wrong behavior.

---

## 5. `always @(*)` — Combinational Process

### Verilog Meaning

```verilog
always @(*) begin
    div_en = (state == TRANSFER);
end
```

The `*` means: "re-evaluate whenever any signal on the right-hand side changes." This is combinational logic — no flip-flops, no clock.

### Hardware Meaning

Combinational gate logic. In this case: a comparator whose output immediately reflects whether `state` equals `TRANSFER`.

### In Our SPI Project

Used to compute `div_en` — the enable signal for the clock divider. It is purely combinational: high when in TRANSFER state, low otherwise.

---

## 6. `case` Statement — Finite State Machine

### Verilog Meaning

```verilog
case (state)
    IDLE:     begin ... end
    TRANSFER: begin ... end
    FINISH:   begin ... end
    default:  state <= IDLE;
endcase
```

Selects one of several branches based on the value of `state`.

### Hardware Meaning

A multiplexer controlled by a state register. Each case arm drives a different set of register updates.

### In Our SPI Project

The master FSM uses a `case` statement with three states:

```
IDLE     → 2'd0
TRANSFER → 2'd1
FINISH   → 2'd2
```

The `state` register is 2 bits wide, stored in two flip-flops.

### Why We Need an FSM

Without an FSM, the master cannot know:
- "Am I idle or in the middle of a transfer?"
- "Have I finished?"
- "Should I sample MISO or shift MOSI right now?"

The FSM captures the *history* of what has happened and uses it to decide what to do next.

---

## 7. Shift Register

### What It Is

A shift register moves data one bit at a time:

```verilog
tx_shift <= {tx_shift[6:0], 1'b0};
```

This takes bits [6:0] (the lower 7 bits) and concatenates a 0 on the right — effectively shifting the whole register left by one position.

### Hardware Interpretation

```
Before:  D7 D6 D5 D4 D3 D2 D1 D0
After:   D6 D5 D4 D3 D2 D1 D0  0
```

Each clock cycle, the MSB is output and the register shifts left. After 8 shifts, all bits have been transmitted.

### In Our SPI Project

- **TX shift register:** Holds the byte being transmitted. MSB goes onto MOSI, then shifts left each falling SCLK edge.
- **RX shift register:** Captures bits from MISO/MOSI. Each rising SCLK edge, a new bit shifts into the LSB.

```verilog
rx_shift <= {rx_shift[6:0], miso};
// Bit enters from the right (LSB position)
// After 8 shifts, the full byte is assembled
```

---

## 8. Bit Counter

### What It Is

A counter that increments on each rising SCLK edge and stops the transfer when it reaches 8.

```verilog
bit_cnt <= bit_cnt + 1'b1;   // increment on rising edge sample
...
if (bit_cnt == 4'd8) begin
    state <= FINISH;
end
```

### Hardware Interpretation

A 4-bit binary counter (flip-flops). Counts 0, 1, 2, 3, 4, 5, 6, 7, 8 — then the FSM transitions.

### Why 4 Bits?

To count up to 8, we need at least ⌈log₂(9)⌉ = 4 bits. A 3-bit counter can only go to 7.

---

## 9. Parameter

### Verilog Meaning

```verilog
module clk_divider #(
    parameter DIVISOR = 4
)
```

A parameter is a compile-time constant that can be overridden when instantiating the module:

```verilog
clk_divider #(.DIVISOR(8)) u_div (...);
```

### Hardware Meaning

The synthesis tool uses the parameter value to generate different hardware. Changing `DIVISOR` changes the counter width and comparison logic.

### In Our SPI Project

`CLK_DIV` controls the SCLK frequency:
- `CLK_DIV = 4` → SCLK half-period = 4 system cycles → SCLK = 12.5 MHz at 100 MHz
- `CLK_DIV = 8` → SCLK half-period = 8 system cycles → SCLK = 6.25 MHz at 100 MHz

---

## 10. `localparam` — State Encoding

### Verilog Meaning

```verilog
localparam IDLE     = 2'd0;
localparam TRANSFER = 2'd1;
localparam FINISH   = 2'd2;
```

A constant local to the module. Cannot be overridden from outside (unlike `parameter`).

### Hardware Meaning

These are just named constants used to improve readability. In hardware, they compile down to binary comparison logic.

### Why Use It?

Writing `state == TRANSFER` is much clearer than `state == 2'd1`. Localparam makes the code self-documenting.

---

## 11. Concatenation `{}`

### Verilog Meaning

```verilog
{rx_shift[6:0], miso}
```

Joins two bit vectors into one. This takes bits [6:0] from `rx_shift` (7 bits) and appends `miso` (1 bit) → 8-bit result.

### Hardware Meaning

No hardware. This is just routing — wires connected in a specific order.

### In Our SPI Project

Used to implement the shift register:
```verilog
rx_shift <= {rx_shift[6:0], miso};
// Old bits 6:0 become the new 7:1, new bit enters at position 0
```

---

## 12. `posedge` / `negedge` — Edge Detection

### In Clock Sensitivity Lists

```verilog
always @(posedge clk or posedge rst)
```

Means: execute this block on a rising edge of `clk` or a rising edge of `rst`.

### Hardware Meaning

Rising-edge-triggered D flip-flop (the most common flip-flop type).

### In Our Slave Module — Software Edge Detection

The slave does NOT use `posedge sclk` in its sensitivity list. Instead:

```verilog
sclk_d <= sclk;                    // capture SCLK at system clock edge
if (!sclk_d && sclk) begin ... end // rising edge of SCLK
if (sclk_d  && !sclk) begin ... end // falling edge of SCLK
```

This detects SCLK transitions **using the system clock** — keeping everything in one clock domain.

---

## 13. `$dumpfile` / `$dumpvars` — Waveform Dump

### Verilog Meaning

```verilog
$dumpfile("tb_spi_top.vcd");
$dumpvars(0, tb_spi_top);
```

Simulation-only system tasks. Generate a VCD (Value Change Dump) file that can be viewed in GTKWave or Vivado waveform viewer.

### Hardware Meaning

None — these are simulation infrastructure only. They have no effect on synthesis.
