// =============================================================
// Module      : spi_master  (v2)
// Purpose     : SPI Master controller supporting all 4 SPI modes
//               (CPOL x CPHA), parameterizable data width, and
//               multiple independent chip-select lines.
//
// New parameters vs v1:
//   DATA_WIDTH : bits per transaction (default 8)
//   CPOL       : clock polarity — 0=idles LOW, 1=idles HIGH
//   CPHA       : clock phase    — 0=sample leading edge, 1=sample trailing
//   NUM_SLAVES : number of independent CS outputs (default 1)
//   slave_sel  : 4-bit input selects which CS to assert (0-based)
//
// SPI Mode table:
//   Mode 0 : CPOL=0, CPHA=0  — leading=rising,  sample on rising
//   Mode 1 : CPOL=0, CPHA=1  — leading=rising,  sample on falling
//   Mode 2 : CPOL=1, CPHA=0  — leading=falling, sample on falling
//   Mode 3 : CPOL=1, CPHA=1  — leading=falling, sample on rising
//
// CPHA=0 timing (unchanged from v1):
//   MSB pre-loaded onto MOSI before CS drops. Sample on leading edge.
//   Drive next bit on trailing edge.
//
// CPHA=1 timing (new):
//   No pre-load. First bit driven ON the leading edge itself.
//   Sample on trailing edge.
//
// Multi-slave:
//   On 'start', only cs[slave_sel] goes LOW. All others stay HIGH.
//   On FINISH, all CS lines return HIGH.
//   slave_sel is 4-bit, supporting up to 16 slaves.
//
// Counter width fix:
//   bit_cnt is now $clog2(DATA_WIDTH+1) bits instead of hardcoded [3:0].
//
// All other design decisions unchanged (single clock domain, SCLK as
// register, asynchronous reset, non-blocking assignments throughout).
// =============================================================
module spi_master #(
    parameter DATA_WIDTH = 8,   // bits per SPI transaction (must be >= 2)
    parameter CLK_DIV    = 4,   // sysclk cycles per SCLK half-period (must be >= 2)
    parameter CPOL       = 0,   // 0 = SCLK idles LOW,  1 = SCLK idles HIGH
    parameter CPHA       = 0,   // 0 = sample on leading edge, 1 = on trailing
    parameter NUM_SLAVES = 1    // number of independent chip-select lines
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,       // 1-cycle pulse to begin transaction
    input  wire [3:0]              slave_sel,   // which slave CS to assert (0-based)
    input  wire [DATA_WIDTH-1:0]   tx_data,     // byte to transmit, latched on start
    output reg  [DATA_WIDTH-1:0]   rx_data,     // received byte, valid when done pulses
    output reg                     busy,
    output reg                     done,        // 1-cycle pulse on completion
    output reg                     mosi,
    input  wire                    miso,
    output reg                     sclk,
    output reg  [NUM_SLAVES-1:0]   cs           // active-low, one line per slave
);

    localparam IDLE     = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam FINISH   = 2'd2;

    // Bit counter: needs to count 0..DATA_WIDTH.
    // $clog2(DATA_WIDTH+1) gives exactly the bits needed.
    localparam BCNT_W = $clog2(DATA_WIDTH + 1);

    reg [1:0]            state;
    reg [DATA_WIDTH-1:0] tx_shift;
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [BCNT_W-1:0]     bit_cnt;
    reg                  div_en;
    wire                 tick;
    integer              k;   // for-loop variable for CS bus assignment

    clk_divider #(.DIVISOR(CLK_DIV)) u_div (
        .clk    (clk),
        .rst    (rst),
        .enable (div_en),
        .tick   (tick)
    );

    // Divider runs only during TRANSFER; resets cleanly between transactions.
    always @(*) begin
        div_en = (state == TRANSFER);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            sclk     <= CPOL[0];              // idle at the correct polarity
            cs       <= {NUM_SLAVES{1'b1}};   // all CS deasserted
            mosi     <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
            bit_cnt  <= {BCNT_W{1'b0}};
            tx_shift <= {DATA_WIDTH{1'b0}};
            rx_shift <= {DATA_WIDTH{1'b0}};
            rx_data  <= {DATA_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;   // default: done is a 1-cycle pulse

            case (state)

                // ----------------------------------------------------------
                // IDLE: Clock at idle polarity, all CS high. Wait for start.
                // ----------------------------------------------------------
                IDLE: begin
                    sclk <= CPOL[0];
                    cs   <= {NUM_SLAVES{1'b1}};
                    if (start && !busy) begin
                        tx_shift <= tx_data;
                        bit_cnt  <= {BCNT_W{1'b0}};

                        // Assert only the selected slave's CS; all others stay HIGH.
                        for (k = 0; k < NUM_SLAVES; k = k + 1)
                            cs[k] <= (k == slave_sel) ? 1'b0 : 1'b1;

                        // CPHA=0: pre-load MSB onto MOSI before CS drops,
                        //         so it is valid for the first leading edge.
                        // CPHA=1: first bit is driven ON the first leading edge;
                        //         MOSI before that edge is don't-care.
                        if (CPHA == 0)
                            mosi <= tx_data[DATA_WIDTH-1];

                        busy  <= 1'b1;
                        state <= TRANSFER;
                    end
                end

                // ----------------------------------------------------------
                // TRANSFER: Toggle SCLK on each tick. For each pair of edges:
                //   CPHA=0 - sample on LEADING, drive on TRAILING
                //   CPHA=1 - drive  on LEADING, sample on TRAILING
                //
                // "Leading edge"  = SCLK transitioning away from idle (CPOL).
                // "Trailing edge" = SCLK returning to idle.
                //
                // After DATA_WIDTH samples, transition to FINISH.
                // ----------------------------------------------------------
                TRANSFER: begin
                    if (tick) begin
                        if (sclk == CPOL[0]) begin
                            // ---- LEADING EDGE: sclk goes from idle to active ----
                            sclk <= ~CPOL[0];

                            if (CPHA == 0) begin
                                // Sample MISO on the leading edge.
                                rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                                bit_cnt  <= bit_cnt + 1'b1;
                            end else begin
                                // Drive MOSI on the leading edge (first edge for CPHA=1).
                                // Non-blocking: mosi uses OLD tx_shift value (correct MSB-first).
                                mosi     <= tx_shift[DATA_WIDTH-1];
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                            end

                        end else begin
                            // ---- TRAILING EDGE: sclk returns to idle ----
                            sclk <= CPOL[0];

                            if (CPHA == 0) begin
                                // Drive next bit on the trailing edge.
                                // tx_shift[DATA_WIDTH-2] (old, via NBA) is the next bit.
                                mosi     <= tx_shift[DATA_WIDTH-2];
                                tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                            end else begin
                                // Sample MISO on the trailing edge.
                                rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                                bit_cnt  <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    // Transition once DATA_WIDTH bits have been sampled.
                    // bit_cnt updates via NBA so the check fires one cycle after
                    // the last sample — timing is safe for CLK_DIV >= 2.
                    if (bit_cnt == DATA_WIDTH) begin
                        state <= FINISH;
                    end
                end

                // ----------------------------------------------------------
                // FINISH: Deassert CS, capture rx_shift, pulse done, go IDLE.
                // ----------------------------------------------------------
                FINISH: begin
                    cs      <= {NUM_SLAVES{1'b1}};
                    sclk    <= CPOL[0];
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
