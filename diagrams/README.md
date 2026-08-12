# Diagrams

This folder will contain block diagrams and timing diagrams for the SPI controller.

## Planned Diagrams

| Filename | Description | Status |
|---|---|---|
| `system-block-diagram.svg` | Top-level system hierarchy showing all modules and signal connections | PLANNED |
| `spi-master-fsm.svg` | State machine diagram for spi_master (IDLE → TRANSFER → FINISH) | PLANNED |
| `spi-slave-fsm.svg` | State machine diagram for spi_slave (IDLE → ACTIVE) | PLANNED |
| `mode0-timing.svg` | SPI Mode 0 timing waveform: CS, SCLK, MOSI, MISO for 8-bit transfer | PLANNED |
| `shift-register-datapath.svg` | Data flow through TX and RX shift registers in master and slave | PLANNED |
| `clock-divider-waveform.svg` | System clock vs. tick pulse timing diagram | PLANNED |

## Text Diagrams (Available Now)

Complete ASCII block diagrams and timing diagrams are included in the documentation:

- System block diagram: `docs/03-architecture.md`
- Transaction timeline: `docs/03-architecture.md`
- SCLK edge detection: `docs/03-architecture.md`
- Mode 0 timing: `docs/05-spi-mode-0.md`
- Master FSM: `docs/06-rtl-design.md`
- Data path summary: `docs/06-rtl-design.md`
