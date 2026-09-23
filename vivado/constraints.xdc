# ===================================================================
# constraints.xdc - Vivado constraints for SPI Master-Slave Controller
# Target: Xilinx Artix-7 XC7A35T-1CPG236C (Basys 3)
# ===================================================================

# -------------------------------------------------------------------
# Clock Constraint
# -------------------------------------------------------------------
# The Basys 3 board has a 100 MHz oscillator on pin W5.
# This defines a 10.0 ns period clock.
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

# Note: sclk is driven by logic inside the FPGA (a register output, not a
# clock net). Vivado will analyze it as a data path so no create_generated_clock
# is needed for internal timing purposes.

# -------------------------------------------------------------------
# Control Inputs (Buttons)
# -------------------------------------------------------------------
# rst   -> BTNC (Center button) - active-high asynchronous reset
# start -> BTNU (Up button)     - pulse to begin SPI transaction
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

set_property PACKAGE_PIN T18 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]

# -------------------------------------------------------------------
# Data Inputs: master_tx_data[7:0] -> SW0..SW7
# -------------------------------------------------------------------
# SW0 (LSB)
set_property PACKAGE_PIN V17 [get_ports {master_tx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[0]}]
# SW1
set_property PACKAGE_PIN V16 [get_ports {master_tx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[1]}]
# SW2
set_property PACKAGE_PIN W16 [get_ports {master_tx_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[2]}]
# SW3
set_property PACKAGE_PIN W17 [get_ports {master_tx_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[3]}]
# SW4
set_property PACKAGE_PIN W15 [get_ports {master_tx_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[4]}]
# SW5
set_property PACKAGE_PIN V15 [get_ports {master_tx_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[5]}]
# SW6
set_property PACKAGE_PIN W14 [get_ports {master_tx_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[6]}]
# SW7 (MSB)
set_property PACKAGE_PIN W13 [get_ports {master_tx_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_tx_data[7]}]

# -------------------------------------------------------------------
# Data Inputs: slave_tx_data[7:0] -> SW8..SW15
# -------------------------------------------------------------------
# SW8 (LSB)
set_property PACKAGE_PIN V2  [get_ports {slave_tx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[0]}]
# SW9
set_property PACKAGE_PIN T3  [get_ports {slave_tx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[1]}]
# SW10
set_property PACKAGE_PIN T2  [get_ports {slave_tx_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[2]}]
# SW11
set_property PACKAGE_PIN R3  [get_ports {slave_tx_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[3]}]
# SW12
set_property PACKAGE_PIN W2  [get_ports {slave_tx_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[4]}]
# SW13
set_property PACKAGE_PIN U1  [get_ports {slave_tx_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[5]}]
# SW14
set_property PACKAGE_PIN T1  [get_ports {slave_tx_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[6]}]
# SW15 (MSB)
set_property PACKAGE_PIN R2  [get_ports {slave_tx_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_tx_data[7]}]

# -------------------------------------------------------------------
# Data Outputs: master_rx_data[7:0] -> LED0..LED7
# -------------------------------------------------------------------
# LED0 (LSB)
set_property PACKAGE_PIN U16 [get_ports {master_rx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[0]}]
# LED1
set_property PACKAGE_PIN E19 [get_ports {master_rx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[1]}]
# LED2
set_property PACKAGE_PIN U19 [get_ports {master_rx_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[2]}]
# LED3
set_property PACKAGE_PIN V19 [get_ports {master_rx_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[3]}]
# LED4
set_property PACKAGE_PIN W18 [get_ports {master_rx_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[4]}]
# LED5
set_property PACKAGE_PIN U15 [get_ports {master_rx_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[5]}]
# LED6
set_property PACKAGE_PIN U14 [get_ports {master_rx_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[6]}]
# LED7 (MSB)
set_property PACKAGE_PIN V14 [get_ports {master_rx_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {master_rx_data[7]}]

# -------------------------------------------------------------------
# Data Outputs: slave_rx_data[7:0] -> LED8..LED15
# -------------------------------------------------------------------
# LED8 (LSB)
set_property PACKAGE_PIN V13 [get_ports {slave_rx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[0]}]
# LED9
set_property PACKAGE_PIN V3  [get_ports {slave_rx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[1]}]
# LED10
set_property PACKAGE_PIN W3  [get_ports {slave_rx_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[2]}]
# LED11
set_property PACKAGE_PIN U3  [get_ports {slave_rx_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[3]}]
# LED12
set_property PACKAGE_PIN P3  [get_ports {slave_rx_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[4]}]
# LED13
set_property PACKAGE_PIN N3  [get_ports {slave_rx_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[5]}]
# LED14
set_property PACKAGE_PIN P1  [get_ports {slave_rx_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[6]}]
# LED15 (MSB)
set_property PACKAGE_PIN L1  [get_ports {slave_rx_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slave_rx_data[7]}]

# -------------------------------------------------------------------
# SPI Bus signals -> Pmod JA (for probing with oscilloscope / logic analyzer)
# -------------------------------------------------------------------
# Pmod JA Pin 1: cs   (active-low chip select)
set_property PACKAGE_PIN J1  [get_ports cs]
set_property IOSTANDARD LVCMOS33 [get_ports cs]
# Pmod JA Pin 2: mosi (master-out slave-in)
set_property PACKAGE_PIN L2  [get_ports mosi]
set_property IOSTANDARD LVCMOS33 [get_ports mosi]
# Pmod JA Pin 3: miso (master-in slave-out)
set_property PACKAGE_PIN J2  [get_ports miso]
set_property IOSTANDARD LVCMOS33 [get_ports miso]
# Pmod JA Pin 4: sclk (SPI clock)
set_property PACKAGE_PIN G2  [get_ports sclk]
set_property IOSTANDARD LVCMOS33 [get_ports sclk]

# -------------------------------------------------------------------
# Status Outputs -> Pmod JB
# -------------------------------------------------------------------
# Pmod JB Pin 1: busy       (master busy)
set_property PACKAGE_PIN A14 [get_ports busy]
set_property IOSTANDARD LVCMOS33 [get_ports busy]
# Pmod JB Pin 2: done       (master transaction complete, 1-cycle pulse)
set_property PACKAGE_PIN A16 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports done]
# Pmod JB Pin 3: slave_busy (slave busy)
set_property PACKAGE_PIN B15 [get_ports slave_busy]
set_property IOSTANDARD LVCMOS33 [get_ports slave_busy]
# Pmod JB Pin 4: slave_done (slave transaction complete, 1-cycle pulse)
set_property PACKAGE_PIN B16 [get_ports slave_done]
set_property IOSTANDARD LVCMOS33 [get_ports slave_done]

# -------------------------------------------------------------------
# 7-Segment Display — Basys 3
# seg[6:0] = {CG, CF, CE, CD, CC, CB, CA} = {g,f,e,d,c,b,a}
# Active LOW: 0 = segment ON
# an[3:0]: active LOW anodes (AN3=leftmost, AN0=rightmost)
# -------------------------------------------------------------------
set_property PACKAGE_PIN W7  [get_ports {seg[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6  [get_ports {seg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8  [get_ports {seg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8  [get_ports {seg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5  [get_ports {seg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5  [get_ports {seg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7  [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

set_property PACKAGE_PIN V7  [get_ports dp]
set_property IOSTANDARD LVCMOS33 [get_ports dp]

set_property PACKAGE_PIN U2  [get_ports {an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4  [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4  [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4  [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
