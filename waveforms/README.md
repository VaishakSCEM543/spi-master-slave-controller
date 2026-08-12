# Waveforms

This folder stores waveform screenshots from Vivado behavioral simulation.

## Status

| Waveform | Description | Status |
|---|---|---|
| `tc01-spi-transaction.png` | CS, SCLK, MOSI, MISO for TC-01 (0xA5 / 0x5A) | ⚠️ PENDING |

## Action Required

The Vivado behavioral simulation for TC-01 was completed and **RESULT: ALL CHECKS PASSED** was observed in the Tcl console. However, the waveform screenshot was not saved at that time.

### To capture the waveform:

1. Reproduce the simulation using the steps in `verification/results.md`
2. In the Vivado waveform window, add these signals:
   - `cs`
   - `sclk`
   - `mosi`
   - `miso`
   - `busy`
   - `done`
   - `master_rx_data` (hex display)
   - `slave_rx_data` (hex display)
3. Zoom to show the full transaction (from CS falling to CS rising)
4. Take a screenshot
5. Save as `waveforms/tc01-spi-transaction.png`
6. Commit to git

## What the Waveform Should Show

```
cs:    ‾‾‾‾‾‾‾\___________________________/‾‾‾‾‾‾‾
sclk:  ________|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_______
mosi:  ________1___0___1___0___0___1___0___1_______
miso:  ________0___1___0___1___1___0___1___0_______
done:  _________________________________________|‾|_
```

8 SCLK rising edges between CS assertion and CS deassert.  
MOSI = 10100101 (0xA5, MSB first)  
MISO = 01011010 (0x5A, MSB first)
