// =============================================================
// Module      : spi_slave  (v2)
// Purpose     : SPI Slave controller supporting all 4 SPI modes
//               (CPOL x CPHA) and parameterizable data width.
//               All internal logic runs on the single system clock
//               (posedge clk). SCLK is never used as a clock net.
//
// New parameters vs v1:
//   DATA_WIDTH : bits per transaction (default 8)
//   CPOL       : must match master — sets which SCLK edge is "leading"
//   CPHA       : must match master — sets which edge samples/drives
//
// Edge detection (unchanged approach, generalized):
//   sclk_d is a 1-cycle-delayed copy of SCLK (system-clock sampled).
//   leading_edge  and trailing_edge are combinational from sclk_d vs sclk.
//   For CPOL=0: leading=rising, trailing=falling.
//   For CPOL=1: leading=falling, trailing=rising.
//
// CPHA=0 (pre-load mode):
//   While IDLE, slave continuously drives MISO = tx_data[MSB] so it is
//   stable before the first leading edge — satisfying CPHA=0 timing.
//   Slave samples MOSI on the leading edge, drives next MISO bit on trailing.
//
// CPHA=1 (drive-on-first-edge mode):
//   No MISO pre-load. Slave drives MISO on the leading edge itself.
//   Slave samples MOSI on the trailing edge.
//
// All other design decisions unchanged from v1.
// =============================================================
module spi_slave #(
    parameter DATA_WIDTH = 8,   // bits per SPI transaction (must be >= 2)
    parameter CPOL       = 0,   // must match the master's CPOL
    parameter CPHA       = 0    // must match the master's CPHA
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    cs,          // active-low chip select from master
    input  wire                    sclk,        // SPI clock from master (data reg, not clock net)
    input  wire                    mosi,
    output reg                     miso,
    input  wire [DATA_WIDTH-1:0]   tx_data,     // byte to send back to master
    output reg  [DATA_WIDTH-1:0]   rx_data,     // byte received from master, valid on done
    output reg                     busy,
    output reg                     done         // 1-cycle pulse
);

    localparam IDLE   = 1'b0;
    localparam ACTIVE = 1'b1;

    // Bit counter: $clog2(DATA_WIDTH+1) bits to count 0..DATA_WIDTH.
    localparam BCNT_W = $clog2(DATA_WIDTH + 1);

    reg                  state;
    reg                  sclk_d;     // 1-cycle delayed SCLK for edge detection
    reg [DATA_WIDTH-1:0] tx_shift;
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [BCNT_W-1:0]     bit_cnt;

    // ------------------------------------------------------------------
    // Edge detection (combinational).
    // "Leading edge"  = SCLK transitions away from its idle level (CPOL).
    //   CPOL=0: leading = rising  (!sclk_d && sclk)
    //   CPOL=1: leading = falling (sclk_d  && !sclk)
    // "Trailing edge" = SCLK returns to idle.
    //   CPOL=0: trailing = falling (sclk_d  && !sclk)
    //   CPOL=1: trailing = rising  (!sclk_d && sclk)
    // ------------------------------------------------------------------
    reg leading_edge;
    reg trailing_edge;

    always @(*) begin
        if (CPOL == 0) begin
            leading_edge  = (!sclk_d && sclk);   // rising
            trailing_edge = ( sclk_d && !sclk);  // falling
        end else begin
            leading_edge  = ( sclk_d && !sclk);  // falling
            trailing_edge = (!sclk_d && sclk);   // rising
        end
    end

    // ------------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            sclk_d   <= CPOL[0];              // matches sclk idle level
            tx_shift <= {DATA_WIDTH{1'b0}};
            rx_shift <= {DATA_WIDTH{1'b0}};
            bit_cnt  <= {BCNT_W{1'b0}};
            miso     <= 1'b0;
            rx_data  <= {DATA_WIDTH{1'b0}};
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            sclk_d <= sclk;   // capture for next-cycle edge detection
            done   <= 1'b0;   // default: done is a 1-cycle pulse

            case (state)

                // ----------------------------------------------------------
                // IDLE: CS is high. Continuously load tx_shift and
                // pre-drive MISO (only for CPHA=0) so it is valid the
                // instant CS drops and the first leading edge arrives.
                // ----------------------------------------------------------
                IDLE: begin
                    busy    <= 1'b0;
                    bit_cnt <= {BCNT_W{1'b0}};
                    tx_shift <= tx_data;   // keep current; ready for any CS drop

                    // CPHA=0: MISO must be valid BEFORE the first leading edge.
                    // CPHA=1: MISO is driven ON the first leading edge; no pre-load.
                    if (CPHA == 0)
                        miso <= tx_data[DATA_WIDTH-1];

                    if (!cs) begin
                        state <= ACTIVE;
                        busy  <= 1'b1;
                    end
                end

                // ----------------------------------------------------------
                // ACTIVE: CS is low.
                //   CPHA=0: sample MOSI on leading, drive MISO on trailing.
                //   CPHA=1: drive MISO on leading, sample MOSI on trailing.
                // After DATA_WIDTH bits, latch rx_data, pulse done, go IDLE.
                // ----------------------------------------------------------
                ACTIVE: begin
                    if (cs) begin
                        // Master ended or aborted the transaction.
                        state <= IDLE;
                    end else begin

                        if (leading_edge) begin
                            if (CPHA == 0) begin
                                // CPHA=0: sample MOSI on leading edge
                                rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};
                                bit_cnt  <= bit_cnt + 1'b1;
                            end else begin
                                // CPHA=1: drive MISO on leading edge (MSB-first).
                                // Non-blocking: miso uses OLD tx_shift (correct).
                                miso     <= tx_shift[DATA_WIDTH-1];
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                            end
                        end

                        if (trailing_edge) begin
                            if (CPHA == 0) begin
                                // CPHA=0: drive next MISO bit on trailing edge.
                                // tx_shift[DATA_WIDTH-2] (old, via NBA) is next bit.
                                miso     <= tx_shift[DATA_WIDTH-2];
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                            end else begin
                                // CPHA=1: sample MOSI on trailing edge
                                rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};
                                bit_cnt  <= bit_cnt + 1'b1;
                            end
                        end

                        // Latch and pulse done when all bits have been sampled.
                        if (bit_cnt == DATA_WIDTH) begin
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
