// =============================================================
// Module      : spi_top
// Purpose     : Pure structural top level - instantiates spi_master
//               and spi_slave and wires them together via the shared
//               SPI bus (mosi, miso, sclk, cs). Contains no logic of
//               its own, except output display latches added for FPGA
//               hardware testing (hold rx_data on LEDs after done pulse).
//
// Note on naming: the original signal list (tx_data/rx_data/busy/
// done) is expanded with master_/slave_ prefixes because this design
// has two independent data ports (one per side of the link). This is
// the one deliberate deviation from the literal port list - flagged
// here as an assumption per your instructions.
// =============================================================
module spi_top #(
    parameter CLK_DIV = 4
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,

    input  wire [7:0] master_tx_data,
    input  wire [7:0] slave_tx_data,
    output reg  [7:0] master_rx_data,   // reg: latched for LED display
    output reg  [7:0] slave_rx_data,    // reg: latched for LED display

    output wire        busy,        // master busy
    output wire        done,        // master done
    output wire        slave_busy,
    output wire        slave_done,

    output wire mosi,
    output wire miso,
    output wire sclk,
    output wire cs
);

    // Internal wires from master/slave rx_data outputs
    wire [7:0] master_rx_raw;
    wire [7:0] slave_rx_raw;

    spi_master #(
        .CLK_DIV(CLK_DIV)
    ) u_master (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .tx_data (master_tx_data),
        .rx_data (master_rx_raw),
        .busy    (busy),
        .done    (done),
        .mosi    (mosi),
        .miso    (miso),
        .sclk    (sclk),
        .cs      (cs)
    );

    spi_slave u_slave (
        .clk     (clk),
        .rst     (rst),
        .cs      (cs),
        .sclk    (sclk),
        .mosi    (mosi),
        .miso    (miso),
        .tx_data (slave_tx_data),
        .rx_data (slave_rx_raw),
        .busy    (slave_busy),
        .done    (slave_done)
    );

    // ---------------------------------------------------------------
    // Output display latches
    // Capture rx_data into registers when 'done' pulses so the LEDs
    // hold the result after the transaction ends. Without this, the
    // LEDs would only flicker for one clock cycle (10 ns) - invisible.
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            master_rx_data <= 8'd0;
            slave_rx_data  <= 8'd0;
        end else if (done) begin
            master_rx_data <= master_rx_raw;
            slave_rx_data  <= slave_rx_raw;
        end
    end

endmodule
