`timescale 1ns/1ps

// =============================================================
// Module      : tb_spi_top
// Purpose     : Self-checking testbench for spi_top. Verilog-2001
//               compatible (no SystemVerilog constructs).
//               Drives reset and a single transaction, then
//               automatically checks:
//                 - master_rx_data == expected slave TX byte
//                 - slave_rx_data  == expected master TX byte
//                 - exactly 8 SCLK rising edges occurred while CS low
//                 - CS asserts low after start, and returns high
//                   after the transaction completes
//               Prints PASS/FAIL for each check and an overall result.
//
// Timeout note: the original testbench used a SystemVerilog
// fork/join_any + disable fork race between "wait for done" and
// "wait 500 cycles". Verilog-2001 has no join_any/disable fork, so
// this version instead computes a 'timeout' flag in an always block
// (a free-running counter that only counts while the master is
// busy) and waits with a single 'while (!done && !timeout)' polling
// loop - functionally equivalent, but plain Verilog-2001.
//
// Assumptions : 100 MHz system clock (10 ns period), CLK_DIV = 4
//               (SPI clock period = 8 sysclk cycles = 12.5 MHz).
//               Both are parameters and easy to change below.
// =============================================================
module tb_spi_top;

    parameter CLK_PERIOD  = 10;   // 100 MHz system clock
    parameter CLK_DIV     = 4;    // sysclk cycles per SCLK half-period
    parameter TIMEOUT_CYC = 500;  // max cycles to wait for 'done'

    reg        clk;
    reg        rst;
    reg        start;
    reg  [7:0] master_tx_data;
    reg  [7:0] slave_tx_data;
    wire [7:0] master_rx_data;
    wire [7:0] slave_rx_data;
    wire       busy, done;
    wire       slave_busy, slave_done;
    wire       mosi, miso, sclk, cs;

    integer sclk_edge_count;
    integer errors;

    // ---- Verilog-2001 timeout mechanism (replaces fork/join_any) ----
    reg [31:0] wait_cnt;
    reg        timeout;

    spi_top #(
        .CLK_DIV(CLK_DIV)
    ) DUT (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .master_tx_data (master_tx_data),
        .slave_tx_data  (slave_tx_data),
        .master_rx_data (master_rx_data),
        .slave_rx_data  (slave_rx_data),
        .busy           (busy),
        .done           (done),
        .slave_busy     (slave_busy),
        .slave_done     (slave_done),
        .mosi           (mosi),
        .miso           (miso),
        .sclk           (sclk),
        .cs             (cs)
    );

    // system clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // count SPI clock edges actually seen while CS is asserted
    always @(posedge sclk) begin
        if (!cs) sclk_edge_count = sclk_edge_count + 1;
    end

    // Timeout counter: counts system-clock cycles while the master
    // is busy; sets 'timeout' if 'busy' stays high too long without
    // 'done' ever pulsing. Resets whenever not busy.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wait_cnt <= 32'd0;
            timeout  <= 1'b0;
        end else if (busy) begin
            if (wait_cnt >= TIMEOUT_CYC) begin
                timeout <= 1'b1;
            end else begin
                wait_cnt <= wait_cnt + 32'd1;
            end
        end else begin
            wait_cnt <= 32'd0;
            timeout  <= 1'b0;
        end
    end

    initial begin
        // Optional waveform dump for viewing in Vivado / gtkwave
        $dumpfile("tb_spi_top.vcd");
        $dumpvars(0, tb_spi_top);

        rst             = 1'b1;
        start           = 1'b0;
        master_tx_data  = 8'h00;
        slave_tx_data   = 8'h00;
        sclk_edge_count = 0;
        errors          = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        // Functional target values from the spec
        master_tx_data = 8'hA5; // 8'b10100101
        slave_tx_data  = 8'h5A; // 8'b01011010

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // sanity check: CS should assert shortly after start
        repeat (2) @(posedge clk);
        if (cs !== 1'b0) begin
            $display("FAIL: CS did not assert low after start");
            errors = errors + 1;
        end

        // Wait for the transaction to finish, or bail out on timeout.
        // Plain Verilog-2001 polling loop - no fork/join_any needed.
        while (!done && !timeout) begin
            @(posedge clk);
        end

        if (timeout) begin
            $display("FAIL: TIMEOUT - 'done' never asserted within %0d cycles",
                      TIMEOUT_CYC);
            errors = errors + 1;
        end

        @(posedge clk);

        $display("---------------------------------------------");
        $display("Master TX = %b (0x%0h)", 8'hA5, 8'hA5);
        $display("Slave  TX = %b (0x%0h)", 8'h5A, 8'h5A);
        $display("Master RX = %b (0x%0h)  expected 01011010 (0x5A)",
                  master_rx_data, master_rx_data);
        $display("Slave  RX = %b (0x%0h)  expected 10100101 (0xA5)",
                  slave_rx_data, slave_rx_data);
        $display("SCLK rising edges during CS low = %0d (expected 8)",
                  sclk_edge_count);
        $display("Final CS = %b (expected 1)", cs);
        $display("---------------------------------------------");

        if (master_rx_data !== 8'h5A) begin
            $display("FAIL: master_rx_data mismatch");
            errors = errors + 1;
        end

        if (slave_rx_data !== 8'hA5) begin
            $display("FAIL: slave_rx_data mismatch");
            errors = errors + 1;
        end

        if (sclk_edge_count !== 8) begin
            $display("FAIL: incorrect number of SCLK edges (got %0d)",
                      sclk_edge_count);
            errors = errors + 1;
        end

        if (cs !== 1'b1) begin
            $display("FAIL: CS did not return high after transaction");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("RESULT: ALL CHECKS PASSED");
        else
            $display("RESULT: %0d CHECK(S) FAILED", errors);

        #(CLK_PERIOD*10);
        $finish;
    end

endmodule
