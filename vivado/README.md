# Vivado Project

This folder is the intended location for Vivado project files.

## Current Status

The Vivado project (`SPI.xpr`) exists locally but is not tracked in this repository.

The `.gitignore` in this repository deliberately excludes Vivado-generated files:
- `.xpr` — Vivado project descriptor
- `.Xil/`, `.cache/`, `.hw/`, `.ip_user_files/`, `.sim/`, `.runs/`, `.gen/` — all generated artifacts

These files are large, binary, machine-specific, and regeneratable — they should not be in a version-controlled source repository.

## What Is Tracked

Only clean, human-authored source files are in this repository:
- `rtl/` — synthesizable Verilog-2001 source files
- `sim/` — testbench files
- `docs/` — documentation
- `learning/` — learning notes
- `verification/` — test tracking
- `diagrams/` — diagrams (planned)
- `waveforms/` — simulation screenshots

## How to Recreate the Vivado Project

To recreate the Vivado project from source:

1. Open Vivado
2. Create new RTL Project
3. **Design Sources** → Add Files:
   - `rtl/clk_divider.v`
   - `rtl/spi_master.v`
   - `rtl/spi_slave.v`
   - `rtl/spi_top.v`
4. **Simulation Sources** → Add Files:
   - `sim/tb_spi_top.v`
5. Right-click `tb_spi_top` in Sources → Set as Simulation Top
6. Target FPGA (if synthesizing): Set appropriate part number
7. Verify hierarchy: `spi_top` → `spi_master` → `clk_divider`, `spi_slave`
8. Run Behavioral Simulation → Check Tcl console for `RESULT: ALL CHECKS PASSED`

## Planned: Synthesis XDC Constraints File

When synthesis is run, a constraints file will be needed to:
- Define the system clock (`create_clock`)
- Specify that SCLK is a generated output (not a clock net) to prevent Vivado from treating it as a clock
- Assign FPGA pin locations if implementing for a physical board

This file will be committed here as `vivado/constraints.xdc` when available.
