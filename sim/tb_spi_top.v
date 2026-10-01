`timescale 1ns/1ps

// =============================================================
// Module      : tb_spi_top  (v2)
// Purpose     : Self-checking testbench for spi_top.
//               Verilog-2001 compatible (no SystemVerilog).
//
// New in v2:
//   - Task-based structure: run_test() encapsulates one full
//     SPI transaction and its checks, making adding new tests trivial.
//   - 4 test vectors instead of 1:
//       TC-01: 0xA5 / 0x5A  (original nominal case)
//       TC-02: 0x00 / 0xFF  (all-zeros master; all-ones slave)
//       TC-03: 0xFF / 0x00  (all-ones master; all-zeros slave)
//       TC-04: Back-to-back — 0x12/0xED followed immediately by
//              0xAB/0x54 without reset in between.
//   - Reports per-test PASS/FAIL and a final overall result.
//
// Rationale for the extra test vectors:
//   TC-02: A shift register with a stuck bit can "hide" behind 0xA5/0x5A
//          because those patterns have alternating bits. All-zeros and
//          all-ones expose stuck-at faults and verify the register fully
//          clears between transactions.
//   TC-03: Complements TC-02. Tests the opposite boundary.
//   TC-04: Verifies that the master correctly re-enters IDLE and accepts
//          a new transaction without a reset in between (critical for
//          any real application that runs continuous transfers).
//
// Timeout: Verilog-2001 polling loop (no fork/join_any needed).
//          Each test gets TIMEOUT_CYC cycles or the simulation aborts.
// =============================================================
module tb_spi_top;

    // ----------------------------------------------------------------
    // Parameters — must match the DUT instantiation below
    // ----------------------------------------------------------------
    parameter CLK_PERIOD  = 10;    // 100 MHz system clock
    parameter CLK_DIV     = 4;     // sysclk cycles per SCLK half-period
    parameter DATA_WIDTH  = 8;     // bits per transaction
    parameter CPOL        = 0;
    parameter CPHA        = 0;
    parameter NUM_SLAVES  = 1;
    parameter TIMEOUT_CYC = 500;   // max cycles per transaction

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    reg                   clk;
    reg                   rst;
    reg                   start;
    reg  [3:0]            slave_sel;
    reg  [DATA_WIDTH-1:0] master_tx_data;
    reg  [DATA_WIDTH-1:0] slave_tx_data;
    wire [DATA_WIDTH-1:0] master_rx_data;
    wire [DATA_WIDTH-1:0] slave_rx_data;
    wire                  busy, done;
    wire                  slave_busy, slave_done;
    wire                  mosi, miso, sclk;
    wire [NUM_SLAVES-1:0] cs;

    integer sclk_edge_count;   // SCLK rising edges while CS[0] low
    integer total_errors;      // accumulated across all tests

    // Verilog-2001 timeout mechanism
    reg [31:0] wait_cnt;
    reg        timeout;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    spi_top #(
        .CLK_DIV    (CLK_DIV),
        .DATA_WIDTH (DATA_WIDTH),
        .CPOL       (CPOL),
        .CPHA       (CPHA),
        .NUM_SLAVES (NUM_SLAVES)
    ) DUT (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .slave_sel      (slave_sel),
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

    // ----------------------------------------------------------------
    // Clock generation
    // ----------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------------------------------------------------
    // SCLK rising-edge counter (only counts while CS[0] is asserted)
    // ----------------------------------------------------------------
    always @(posedge sclk) begin
        if (!cs[0]) sclk_edge_count = sclk_edge_count + 1;
    end

    // ----------------------------------------------------------------
    // Timeout counter: counts sysclk cycles while master is busy.
    // Resets when master is not busy. Sets 'timeout' if 'busy' stays
    // high for more than TIMEOUT_CYC cycles without 'done' pulsing.
    // ----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wait_cnt <= 32'd0;
            timeout  <= 1'b0;
        end else if (busy) begin
            if (wait_cnt >= TIMEOUT_CYC)
                timeout <= 1'b1;
            else
                wait_cnt <= wait_cnt + 32'd1;
        end else begin
            wait_cnt <= 32'd0;
            timeout  <= 1'b0;
        end
    end

    // ================================================================
    // Task: run_test
    //   Drives a single SPI transaction and checks 4 conditions:
    //   1. master_rx_data matches expected
    //   2. slave_rx_data  matches expected
    //   3. Exactly DATA_WIDTH SCLK rising edges while CS[0] low
    //   4. CS[0] deasserts (returns HIGH) after transaction
    //
    //   Increments total_errors for each failure.
    // ================================================================
    task run_test;
        input [DATA_WIDTH-1:0] m_tx;       // master transmit byte
        input [DATA_WIDTH-1:0] s_tx;       // slave  transmit byte
        input [DATA_WIDTH-1:0] exp_mrx;    // expected master receive
        input [DATA_WIDTH-1:0] exp_srx;    // expected slave  receive
        input integer           test_id;

        integer test_errors;
        begin
            test_errors     = 0;
            sclk_edge_count = 0;   // reset counter before each test

            // Set data
            master_tx_data = m_tx;
            slave_tx_data  = s_tx;

            // Pulse start for exactly 1 cycle
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Sanity check: CS[0] must assert shortly after start
            repeat (2) @(posedge clk);
            if (cs[0] !== 1'b0) begin
                $display("  [TC-%02d] FAIL: CS[0] did not assert after start", test_id);
                test_errors = test_errors + 1;
            end

            // Wait for done or timeout
            while (!done && !timeout) @(posedge clk);

            if (timeout) begin
                $display("  [TC-%02d] FAIL: TIMEOUT — done never asserted within %0d cycles",
                          test_id, TIMEOUT_CYC);
                test_errors = test_errors + 1;
            end

            // Give one more clock for latches to settle
            @(posedge clk);

            // ---- Print transaction summary ----
            $display("---------------------------------------------");
            $display("[TC-%02d] Master TX = %b (0x%02X)", test_id, m_tx, m_tx);
            $display("[TC-%02d] Slave  TX = %b (0x%02X)", test_id, s_tx, s_tx);
            $display("[TC-%02d] Master RX = %b (0x%02X)  expected 0x%02X",
                      test_id, master_rx_data, master_rx_data, exp_mrx);
            $display("[TC-%02d] Slave  RX = %b (0x%02X)  expected 0x%02X",
                      test_id, slave_rx_data,  slave_rx_data,  exp_srx);
            $display("[TC-%02d] SCLK rising edges during CS low = %0d  (expected %0d)",
                      test_id, sclk_edge_count, DATA_WIDTH);
            $display("[TC-%02d] Final CS[0] = %b  (expected 1)", test_id, cs[0]);

            // ---- Checks ----
            if (master_rx_data !== exp_mrx) begin
                $display("  [TC-%02d] FAIL: master_rx_data mismatch", test_id);
                test_errors = test_errors + 1;
            end

            if (slave_rx_data !== exp_srx) begin
                $display("  [TC-%02d] FAIL: slave_rx_data mismatch", test_id);
                test_errors = test_errors + 1;
            end

            if (sclk_edge_count !== DATA_WIDTH) begin
                $display("  [TC-%02d] FAIL: wrong SCLK edge count (got %0d, want %0d)",
                          test_id, sclk_edge_count, DATA_WIDTH);
                test_errors = test_errors + 1;
            end

            if (cs[0] !== 1'b1) begin
                $display("  [TC-%02d] FAIL: CS[0] did not return HIGH after transaction",
                          test_id);
                test_errors = test_errors + 1;
            end

            if (test_errors == 0)
                $display("  [TC-%02d] RESULT: PASS", test_id);
            else
                $display("  [TC-%02d] RESULT: FAIL (%0d error(s))", test_id, test_errors);

            total_errors = total_errors + test_errors;

            // Brief inter-test gap so master fully returns to IDLE
            repeat (4) @(posedge clk);
        end
    endtask

    // ================================================================
    // Main stimulus
    // ================================================================
    initial begin
        $dumpfile("tb_spi_top.vcd");
        $dumpvars(0, tb_spi_top);

        // Initialise
        rst             = 1'b1;
        start           = 1'b0;
        slave_sel       = 4'd0;
        master_tx_data  = {DATA_WIDTH{1'b0}};
        slave_tx_data   = {DATA_WIDTH{1'b0}};
        sclk_edge_count = 0;
        total_errors    = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        $display("=============================================");
        $display("SPI Controller v2 — Self-Checking Testbench");
        $display("  DATA_WIDTH=%0d  CPOL=%0d  CPHA=%0d  NUM_SLAVES=%0d",
                  DATA_WIDTH, CPOL, CPHA, NUM_SLAVES);
        $display("=============================================");

        // ----------------------------------------------------------
        // TC-01: Nominal case — alternating pattern (0xA5 / 0x5A)
        //        Tests basic MSB-first shifting correctness.
        // ----------------------------------------------------------
        run_test(8'hA5, 8'h5A, 8'h5A, 8'hA5, 1);

        // ----------------------------------------------------------
        // TC-02: All-zeros master / All-ones slave
        //        Verifies shift registers fully clear between transactions
        //        and no bits "stick" from the previous test.
        // ----------------------------------------------------------
        run_test(8'h00, 8'hFF, 8'hFF, 8'h00, 2);

        // ----------------------------------------------------------
        // TC-03: All-ones master / All-zeros slave (complement of TC-02)
        // ----------------------------------------------------------
        run_test(8'hFF, 8'h00, 8'h00, 8'hFF, 3);

        // ----------------------------------------------------------
        // TC-04a: Back-to-back — first transaction
        //         The second transaction (TC-04b) starts immediately
        //         after done pulses, without any reset. This verifies
        //         the master correctly re-enters IDLE and is ready for
        //         the next start pulse — a mandatory requirement for
        //         any application doing continuous SPI transfers.
        // ----------------------------------------------------------
        run_test(8'h12, 8'hED, 8'hED, 8'h12, 4);  // TC-04a (back-to-back part 1)
        run_test(8'hAB, 8'h54, 8'h54, 8'hAB, 5);  // TC-04b (back-to-back part 2, no reset)

        // ----------------------------------------------------------
        // Final result
        // ----------------------------------------------------------
        $display("=============================================");
        if (total_errors == 0)
            $display("RESULT: ALL CHECKS PASSED");
        else
            $display("RESULT: %0d TOTAL CHECK(S) FAILED", total_errors);
        $display("=============================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
