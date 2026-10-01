// =============================================================
// Module      : spi_top  (v2)
// Purpose     : Structural top-level. Instantiates spi_master and
//               spi_slave and connects them via the shared SPI bus.
//               Contains no SPI protocol logic of its own.
//
//               Added in v2:
//               - DATA_WIDTH, CPOL, CPHA, NUM_SLAVES parameters
//                 propagated to spi_master and spi_slave.
//               - slave_sel input (4-bit) forwarded to spi_master.
//               - cs output is now [NUM_SLAVES-1:0] bus; cs[0] always
//                 connects to the internal spi_slave for loopback test.
//
// Output display latches (unchanged from v1):
//               master_rx_data and slave_rx_data are output regs latched
//               when 'done' pulses. Without this, the combinational
//               rx_data from the modules would go invalid one clock after
//               FINISH (when state returns to IDLE), making LEDs flicker
//               for only ~10 ns - invisible to human eyes.
//
// Notes on FPGA use with NUM_SLAVES=1 (default):
//               slave_sel is unused — tie to 4'd0 in your constraints
//               or just leave it unconnected (it defaults to 0 anyway).
//               cs is a 1-bit bus [0:0]; map cs[0] to your Pmod pin.
// =============================================================
module spi_top #(
    parameter CLK_DIV    = 4,   // sysclk cycles per SCLK half-period
    parameter DATA_WIDTH = 8,   // bits per SPI transaction
    parameter CPOL       = 0,   // 0 = SCLK idles LOW,  1 = HIGH
    parameter CPHA       = 0,   // 0 = sample leading,  1 = sample trailing
    parameter NUM_SLAVES = 1    // number of independent CS outputs
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    input  wire [3:0]              slave_sel,         // which slave to address

    input  wire [DATA_WIDTH-1:0]   master_tx_data,
    input  wire [DATA_WIDTH-1:0]   slave_tx_data,
    output reg  [DATA_WIDTH-1:0]   master_rx_data,   // latched for LED display
    output reg  [DATA_WIDTH-1:0]   slave_rx_data,    // latched for LED display

    output wire                    busy,
    output wire                    done,
    output wire                    slave_busy,
    output wire                    slave_done,

    output wire                    mosi,
    output wire                    miso,
    output wire                    sclk,
    output wire [NUM_SLAVES-1:0]   cs                // active-low bus
);

    // Internal wires: rx_data outputs from master/slave modules.
    // These are only valid for one clock cycle (FINISH state).
    // The display latches below hold them steady on LEDs.
    wire [DATA_WIDTH-1:0] master_rx_raw;
    wire [DATA_WIDTH-1:0] slave_rx_raw;

    spi_master #(
        .CLK_DIV    (CLK_DIV),
        .DATA_WIDTH (DATA_WIDTH),
        .CPOL       (CPOL),
        .CPHA       (CPHA),
        .NUM_SLAVES (NUM_SLAVES)
    ) u_master (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .slave_sel (slave_sel),
        .tx_data   (master_tx_data),
        .rx_data   (master_rx_raw),
        .busy      (busy),
        .done      (done),
        .mosi      (mosi),
        .miso      (miso),
        .sclk      (sclk),
        .cs        (cs)
    );

    spi_slave #(
        .DATA_WIDTH (DATA_WIDTH),
        .CPOL       (CPOL),
        .CPHA       (CPHA)
    ) u_slave (
        .clk     (clk),
        .rst     (rst),
        .cs      (cs[0]),   // internal slave always on cs[0]
        .sclk    (sclk),
        .mosi    (mosi),
        .miso    (miso),
        .tx_data (slave_tx_data),
        .rx_data (slave_rx_raw),
        .busy    (slave_busy),
        .done    (slave_done)
    );

    // ------------------------------------------------------------------
    // Output display latches
    // Capture rx_data on 'done' so LEDs hold the result after the
    // transaction ends. Without this, rx_data is valid for ~10 ns
    // (one clock cycle in FINISH state) — invisible to human eyes.
    // ------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            master_rx_data <= {DATA_WIDTH{1'b0}};
            slave_rx_data  <= {DATA_WIDTH{1'b0}};
        end else if (done) begin
            master_rx_data <= master_rx_raw;
            slave_rx_data  <= slave_rx_raw;
        end
    end

endmodule
