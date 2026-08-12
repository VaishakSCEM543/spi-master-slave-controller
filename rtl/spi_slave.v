// =============================================================
// Module      : spi_slave
// Purpose     : SPI Mode 0 (CPOL=0, CPHA=0) slave controller.
//               Has NO clock of its own - SCLK and CS are inputs
//               driven by the master. All internal logic still runs
//               on the single system clock 'clk'; SCLK edges are
//               detected by comparing SCLK's current sampled value
//               to its value one system-clock cycle earlier.
//
// Ports
//   clk      : system clock (same domain as the master)
//   rst      : asynchronous, active-high reset
//   cs       : active-low chip select, input from master
//   sclk     : SPI clock, input from master
//   mosi     : data in from master (input)
//   miso     : data out to master (output)
//   tx_data  : byte this slave will transmit back to the master
//   rx_data  : byte received from the master, valid when 'done' pulses
//   busy     : high while CS is asserted (transaction in progress)
//   done     : single-cycle pulse when 8 bits have been received
//
// Internal registers
//   sclk_d    : SCLK value delayed by 1 system-clock cycle, used
//               purely for edge detection (sclk_d vs sclk).
//   tx_shift  : shift register holding the byte being sent on MISO
//   rx_shift  : shift register accumulating the byte received on MOSI
//   bit_cnt   : counts bits sampled so far (0..8)
//   state     : IDLE / ACTIVE
//
// State machine
//   IDLE   : CS is high. Continuously preloads tx_shift/miso with
//            tx_data so that the instant CS drops, MISO is already
//            valid - satisfying CPHA=0's "data ready before first
//            rising edge" requirement without needing a "loaded" flag.
//   ACTIVE : CS is low.
//              - SCLK rising edge  (sclk_d=0,sclk=1): sample MOSI
//              - SCLK falling edge (sclk_d=1,sclk=0): shift tx_shift,
//                drive next bit onto MISO
//            After 8 sampled bits, latch rx_data, pulse 'done',
//            return to IDLE.
//
// Reset behavior : Asynchronous reset clears all state, MISO driven 0.
// Clocking        : Single clock domain (posedge clk only). This is
//                    the key design choice discussed earlier - we do
//                    NOT write "always @(posedge sclk)" because SCLK
//                    is just a same-domain derived signal here, not
//                    an independent clock.
// =============================================================
module spi_slave (
    input  wire       clk,
    input  wire       rst,
    input  wire       cs,
    input  wire       sclk,
    input  wire       mosi,
    output reg         miso,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done
);

    localparam IDLE   = 1'b0;
    localparam ACTIVE = 1'b1;

    reg       state;
    reg       sclk_d;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] bit_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            sclk_d   <= 1'b0;
            tx_shift <= 8'd0;
            rx_shift <= 8'd0;
            bit_cnt  <= 4'd0;
            miso     <= 1'b0;
            rx_data  <= 8'd0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            sclk_d <= sclk;   // 1-cycle-delayed copy, for edge detection
            done   <= 1'b0;   // default: done is a 1-cycle pulse

            case (state)
                IDLE: begin
                    busy     <= 1'b0;
                    bit_cnt  <= 4'd0;
                    tx_shift <= tx_data;
                    miso     <= tx_data[7]; // preload MSB before CS drops
                    if (!cs) begin
                        state <= ACTIVE;
                        busy  <= 1'b1;
                    end
                end

                ACTIVE: begin
                    if (cs) begin
                        // master ended the transaction (or aborted)
                        state <= IDLE;
                    end else begin
                        if (!sclk_d && sclk) begin
                            // rising edge: sample MOSI
                            rx_shift <= {rx_shift[6:0], mosi};
                            bit_cnt  <= bit_cnt + 1'b1;
                        end
                        if (sclk_d && !sclk) begin
                            // falling edge: shift out next bit
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            miso     <= tx_shift[6];
                        end
                        if (bit_cnt == 4'd8) begin
                            rx_data <= rx_shift;
                            done    <= 1'b1;
                            state   <= IDLE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
