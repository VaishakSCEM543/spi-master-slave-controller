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
// Reset       : Synchronous behavior is not used here on purpose -
//               reset is asynchronous (posedge rst) for a clean,
//               predictable power-up / testbench reset state.
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

    reg [31:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt  <= 32'd0;
            tick <= 1'b0;
        end else if (!enable) begin
            // Hold divider in a known state whenever it is not
            // actively being used, so each transaction starts clean.
            cnt  <= 32'd0;
            tick <= 1'b0;
        end else begin
            if (cnt == DIVISOR - 1) begin
                cnt  <= 32'd0;
                tick <= 1'b1;   // one-cycle pulse
            end else begin
                cnt  <= cnt + 32'd1;
                tick <= 1'b0;
            end
        end
    end

endmodule
