// =============================================================
// Module      : spi_master
// Purpose     : SPI Mode 0 (CPOL=0, CPHA=0) master controller.
//               Drives CS and SCLK, shifts out tx_data MSB-first on
//               MOSI, and simultaneously samples MISO into rx_data.
//
// Ports
//   clk      : system clock (all logic runs on this clock only)
//   rst      : asynchronous, active-high reset
//   start    : pulse (1 cycle is enough) to begin a transaction
//   tx_data  : byte to transmit, latched on 'start'
//   rx_data  : byte received from the slave, valid when 'done' pulses
//   busy     : high for the entire duration of a transaction
//   done     : single-cycle pulse when the 8-bit transfer completes
//   mosi     : master-out-slave-in data line
//   miso     : master-in-slave-out data line (input)
//   sclk     : generated SPI clock, idles low (CPOL=0)
//   cs       : active-low chip select
//
// Internal registers
//   state     : IDLE / TRANSFER / FINISH  (see explanation below)
//   tx_shift  : shift register holding the byte being sent
//   rx_shift  : shift register accumulating the byte being received
//   bit_cnt   : counts how many bits have been sampled (0..8)
//   tick      : from clk_divider - marks each half-SCLK-period boundary
//
// State machine
//   IDLE     : CS high, SCLK low. Waiting for 'start'. On start:
//              latch tx_data, preload MOSI with bit 7 (MSB) BEFORE
//              any clock edge (required by CPHA=0), assert CS low.
//   TRANSFER : Each 'tick' toggles SCLK.
//                - SCLK 0->1 (rising edge)  : sample MISO into rx_shift
//                - SCLK 1->0 (falling edge) : shift tx_shift, drive
//                                              next MSB onto MOSI
//              After the 8th rising-edge sample, move to FINISH.
//   FINISH   : Deassert CS, pulse 'done', latch rx_shift into rx_data,
//              return to IDLE.
//
// Reset behavior  : Asynchronous reset forces IDLE, CS high, SCLK low,
//                    busy/done low, all counters/shift regs cleared.
// Clocking         : Single clock domain (posedge clk). SCLK is a
//                     regular register, not a real clock net used to
//                     clock other flops.
//
// Design decision worth noting: the master does not generate a
// redundant 8th falling edge, because there is no 9th bit to shift
// out - CS is dropped right after the 8th bit is sampled. This is a
// deliberate simplification for a first learning implementation.
// =============================================================
module spi_master #(
    parameter CLK_DIV = 4   // system-clock cycles per SCLK half-period
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done,
    output reg        mosi,
    input  wire       miso,
    output reg        sclk,
    output reg        cs
);

    localparam IDLE     = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam FINISH   = 2'd2;

    reg [1:0] state;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] bit_cnt;

    reg  div_en;
    wire tick;

    clk_divider #(.DIVISOR(CLK_DIV)) u_div (
        .clk    (clk),
        .rst    (rst),
        .enable (div_en),
        .tick   (tick)
    );

    always @(*) begin
        div_en = (state == TRANSFER);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            sclk     <= 1'b0;
            cs       <= 1'b1;
            mosi     <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
            bit_cnt  <= 4'd0;
            tx_shift <= 8'd0;
            rx_shift <= 8'd0;
            rx_data  <= 8'd0;
        end else begin
            done <= 1'b0; // default: done is a 1-cycle pulse

            case (state)
                IDLE: begin
                    sclk <= 1'b0;
                    cs   <= 1'b1;
                    if (start) begin
                        tx_shift <= tx_data;
                        mosi     <= tx_data[7]; // preload MSB before 1st edge
                        cs       <= 1'b0;
                        bit_cnt  <= 4'd0;
                        busy     <= 1'b1;
                        state    <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (tick) begin
                        if (sclk == 1'b0) begin
                            // rising edge: sample MISO
                            sclk     <= 1'b1;
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt  <= bit_cnt + 1'b1;
                        end else begin
                            // falling edge: shift out next bit
                            sclk     <= 1'b0;
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi     <= tx_shift[6];
                        end
                    end
                    if (bit_cnt == 4'd8) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    cs      <= 1'b1;
                    sclk    <= 1'b0;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    rx_data <= rx_shift;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
