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

There are two ways to recreate the Vivado project from source: automatically via a Tcl script, or manually through the GUI.

### Method 1: Automated (Tcl Script) - Recommended

A Tcl automation script is provided to instantly generate the project and run synthesis for the **Xilinx Artix-7 XC7A35T-1CPG236C (Basys 3)**.

**If you have Vivado in your system PATH:**
1. Open a terminal / command prompt.
2. Navigate to the `vivado` directory: `cd "d:/MIRAFRA/spi project/spi-master-slave-controller/vivado"`
3. Run the script in batch mode:
   ```bash
   vivado -mode batch -source synth.tcl
   ```

**If you prefer using the Vivado GUI:**
1. Open Vivado.
2. At the bottom of the screen, open the **Tcl Console** tab.
3. Use the `cd` command to navigate to the `vivado` directory. Note that Tcl uses forward slashes:
   ```tcl
   cd "d:/MIRAFRA/spi project/spi-master-slave-controller/vivado"
   ```
4. Source the script:
   ```tcl
   source synth.tcl
   ```

This script will create a new Vivado project under `vivado/vivado_proj/`, run synthesis, and dump timing/utilization reports into `vivado/reports/`. You can then open the `.xpr` project file in the GUI for further inspection.

### Method 2: Manual (GUI)

To recreate the Vivado project from source manually:

1. Open Vivado
2. Create new RTL Project
3. **Design Sources** → Add Files:
   - `rtl/clk_divider.v`
   - `rtl/spi_master.v`
   - `rtl/spi_slave.v`
   - `rtl/spi_top.v`
4. **Constraints** → Add Files:
   - `vivado/constraints.xdc`
5. **Simulation Sources** → Add Files:
   - `sim/tb_spi_top.v`
6. Right-click `tb_spi_top` in Sources → Set as Simulation Top
7. Target FPGA: Search and select **xc7a35tcpg236-1** (Basys 3).
8. Verify hierarchy: `spi_top` → `spi_master` → `clk_divider`, `spi_slave`
9. Run Synthesis or Behavioral Simulation as needed.

## Synthesis XDC Constraints File

The synthesis constraint file `constraints.xdc` targets the Basys 3 development board. Currently, it includes:
- A 100 MHz clock definition (`create_clock`) on pin `W5`.

If you decide to proceed to Implementation (generating a bitstream) on physical hardware, you will need to uncomment and map the I/O pins (e.g., switches, LEDs, and Pmod ports) at the bottom of the `constraints.xdc` file.
