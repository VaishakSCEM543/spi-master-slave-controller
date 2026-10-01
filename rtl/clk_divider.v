// =============================================================
// Module      : clk_divider
// Purpose     : Generates a single-cycle "tick" pulse once every
//               DIVISOR system-clock cycles. This tick is used by
//               spi_master as the "half SCLK period elapsed" event.
//               It only counts while 'enable' is high; otherwise it
//               stays reset. This lets the master start the divider
//               fresh at the beginning of every transaction so the
//               first SCLK edge always occurs a full DIVISOR cycles
//               after CS asserts (guaranteed setup time for MOSI/MISO).
//
// Counter width fix (v2):
//               Was [31:0] - 32 flip-flops regardless of DIVISOR.
//               Now [CNT_W-1:0] where CNT_W = $clog2(DIVISOR).
//               For CLK_DIV=4: was 32 FFs, now 2. For CLK_DIV=100: 7.
//               Minimum DIVISOR is 2 (CLK_DIV=1 gives SCLK=clk,
//               which violates SPI setup/hold on any real device).
//
// Reset       : Asynchronous (posedge rst) for clean power-up state.
// Clocking    : Single clock domain - posedge clk only.
// =============================================================
module clk_divider #(
    parameter DIVISOR = 4   // system-clock cycles per half SCLK period
) (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg  tick
);

    // Exact bit-width to count 0..(DIVISOR-1).
    // $clog2(N) = ceil(log2(N)). Guard against DIVISOR<=1 -> 0-bit counter.
    localparam CNT_W = (DIVISOR > 1) ? $clog2(DIVISOR) : 1;

    reg [CNT_W-1:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt  <= {CNT_W{1'b0}};
            tick <= 1'b0;
        end else if (!enable) begin
            // Hold in known state between transactions so each one starts
            // fresh - guarantees a full DIVISOR-cycle setup before first edge.
            cnt  <= {CNT_W{1'b0}};
            tick <= 1'b0;
        end else if (cnt == (DIVISOR - 1)) begin
            cnt  <= {CNT_W{1'b0}};
            tick <= 1'b1;   // one-cycle pulse
        end else begin
            cnt  <= cnt + 1'b1;
            tick <= 1'b0;
        end
    end

endmodule
