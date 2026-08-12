# 09 — Debugging

This document records actual problems encountered during development and how they were resolved.

---

## How to Read This Document

Each entry follows this structure:
- **Problem** — what went wrong
- **Symptom** — what was observed
- **Root Cause** — why it happened
- **Fix** — what solved it
- **Lesson** — what this teaches about digital design

---

## Bug 1 — Testbench Not Recognized as Simulation Source

### Problem

After creating the Vivado project and adding all `.v` files, the simulation could not find the top-level testbench module.

### Symptom

Vivado complained that `tb_spi_top` was not found as the simulation top, or the simulation hierarchy showed unexpected modules as the top.

### Root Cause

The testbench file (`tb_spi_top.v`) was added to the project as a **Design Source** instead of a **Simulation Source**. Vivado treats these differently:

- Design Sources → synthesizable RTL intended for hardware
- Simulation Sources → testbench files that exist only for simulation

When a testbench is in Design Sources, Vivado may attempt (and fail) to synthesize it, because testbenches contain simulation-only constructs (`$display`, `$finish`, `$dumpfile`, `#` delays) that are not synthesizable.

### Fix

Remove `tb_spi_top.v` from Design Sources.  
Re-add it explicitly as a **Simulation Source** in Vivado.  
Then set `tb_spi_top` as the Simulation Top.

### Lesson

In Vivado (and most EDA tools), the tool needs to know which files are RTL and which are testbenches. Mixing them causes synthesis errors and incorrect simulation behavior. Always add testbench files as simulation-only sources.

---

## Bug 2 — SystemVerilog Construct in Verilog Project

### Problem

The original testbench used `fork...join_any` and `disable fork` — constructs from **SystemVerilog**, not standard Verilog-2001.

```verilog
// Original testbench (tb_spi_top.v):
fork
    begin
        wait (done == 1'b1);
    end
    begin
        repeat (500) @(posedge clk);
        $display("FAIL: TIMEOUT");
    end
join_any
disable fork;
```

### Symptom

Vivado reported a syntax error or elaboration error when the project was set to **Verilog** mode (not SystemVerilog). The simulation would not compile.

### Root Cause

`join_any` and `disable fork` are defined in SystemVerilog (IEEE 1800), not in standard Verilog-2001 (IEEE 1364). When Vivado processes a `.v` file in strict Verilog-2001 mode, these constructs are illegal.

### Fix

Create a new testbench (`tb_spi_top1.v` → renamed to `tb_spi_top.v` in the repository) that implements the timeout using a plain Verilog-2001 pattern:

```verilog
// Replacement: always block counter (plain Verilog-2001)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wait_cnt <= 0;
        timeout  <= 1'b0;
    end else if (busy) begin
        if (wait_cnt >= TIMEOUT_CYC)
            timeout <= 1'b1;
        else
            wait_cnt <= wait_cnt + 1;
    end else begin
        wait_cnt <= 0;
        timeout  <= 1'b0;
    end
end

// In initial block:
while (!done && !timeout) begin
    @(posedge clk);
end
```

The behavior is equivalent: if `done` does not arrive within `TIMEOUT_CYC` busy cycles, the simulation exits with a FAIL message.

### Lesson

Verilog-2001 and SystemVerilog are different standards. Many constructs that are legal in SystemVerilog (`fork/join_any`, `logic`, interfaces, `always_ff`, etc.) are not legal in plain Verilog. When writing RTL intended for maximum synthesis compatibility, stick to Verilog-2001 or explicitly choose and declare SystemVerilog.

In Vivado, you can set the file type to `.sv` and enable SystemVerilog elaboration if needed.

---

## Bug 3 — Clock Divider Not Appearing in Hierarchy

### Problem

After adding all design sources, the Vivado Sources panel showed `clk_divider` missing from the design hierarchy under `spi_master`.

### Symptom

The Elaborated Design view (or the Sources hierarchy) showed `spi_master` without `clk_divider` as a sub-module, or Vivado reported a missing module reference.

### Root Cause

`clk_divider.v` was either:
- Not added to the project at all, or
- Added but Vivado had not refreshed its file index, or
- The file was in the wrong source set

Vivado requires all module definitions to be present in the correct source set before elaboration.

### Fix

Explicitly add `clk_divider.v` as a Design Source (File → Add Sources → Design Sources).  
Re-run Elaboration or refresh the Sources panel.  
Verify the hierarchy shows: `spi_top` → `spi_master` → `clk_divider`.

### Lesson

In Vivado, all modules instantiated in RTL must be present in the project's Design Sources. The tool does not automatically search arbitrary directories. Hierarchy is only correct when all source files are correctly added and their module names match the instantiation names in the RTL.

---

## Observation — Duplicate Files

During the project, multiple versions of some files existed:

| File pair | Relationship |
|---|---|
| `spi_master.v` and `spi_master-1.v` | **Identical** — byte-for-byte the same file |
| `tb_spi_top.v` and `tb_spi_top1.v` | **Different** — `tb_spi_top1.v` is the Verilog-2001 compatible version |
| `spi_slave-1.v` | The canonical slave (only one version) |
| `spi_top-1.v` | The canonical top (only one version) |

### Repository Decision

- Canonical RTL: `rtl/spi_master.v`, `rtl/spi_slave.v`, `rtl/spi_top.v`, `rtl/clk_divider.v`
- Canonical testbench: `sim/tb_spi_top.v` (Verilog-2001 compatible version)
- Duplicate files: not included in the repository

The `-1` suffix files in the original Vivado project appear to be Vivado-generated renamed copies from the "Copy to project" import behavior. They are functionally identical to the originals.

---

## What Was Not Debugged (Limitations Not Yet Explored)

| Scenario | Status |
|---|---|
| Reset during active transaction | Not tested — unknown if FSM returns to IDLE cleanly |
| Start pulse while busy | Not tested — likely ignored but unverified |
| CLK_DIV = 1 (SCLK = system clock) | Not tested — may cause timing edge cases |
| Very long CLK_DIV values | Not tested |
| Multiple back-to-back transactions | Not tested |

These represent potential debugging areas for future work.
