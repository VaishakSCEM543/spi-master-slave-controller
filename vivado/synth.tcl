# ===================================================================
# synth.tcl - Vivado Synthesis Automation Script
# Target: Xilinx Artix-7 XC7A35T-1CPG236C (Basys 3)
# 
# Run this from the Vivado Tcl Console or via command line:
#   cd "d:/MIRAFRA/spi project/spi-master-slave-controller/vivado"
#   source synth.tcl
# Or from command line:
#   vivado -mode batch -source synth.tcl
# ===================================================================

# Set the project name and directory
set project_name "SPI_Project"
set project_dir "./vivado_proj"
set part_number "xc7a35tcpg236-1"

# Create project (overwrite if exists)
create_project -force $project_name $project_dir -part $part_number

# Add RTL source files
add_files ../rtl/clk_divider.v
add_files ../rtl/spi_master.v
add_files ../rtl/spi_slave.v
add_files ../rtl/spi_top.v

# Add constraints file
add_files ./constraints.xdc

# Set the top module
set_property top spi_top [current_fileset]
update_compile_order -fileset sources_1

puts "========================================"
puts "Starting Synthesis..."
puts "========================================"

# Launch synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check if synthesis was successful
set synth_status [get_property STATUS [get_runs synth_1]]
if { $synth_status != "synth_design Complete!" } {
    puts "Error: Synthesis failed. Check the logs in $project_dir."
    exit 1
}

# Open the synthesized design for reporting
open_run synth_1 -name synth_1

# Create a reports directory
file mkdir ./reports

# Generate timing and utilization reports
puts "Generating Reports..."
report_timing_summary -file ./reports/timing_summary.txt
report_utilization -file ./reports/utilization.txt

puts "========================================"
puts "Synthesis completed successfully!"
puts "Reports generated in vivado/reports/"
puts "You can now open the project in Vivado GUI from: $project_dir/$project_name.xpr"
puts "========================================"
