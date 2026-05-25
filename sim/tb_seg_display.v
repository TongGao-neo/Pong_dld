// ============================================================================
// tb_seg_display.v - Testbench for seg_display module
// Before simulation, temporarily change SCAN_MAX in seg_display.v to a small
// value (e.g., 10) so the digit scan cycles quickly.
// ============================================================================

`timescale 1ns / 1ps

module tb_seg_display;

    reg        clk;
    reg        rst_n;
    reg  [3:0] score_left;
    reg  [3:0] score_right;
    wire [3:0] AN;
    wire [7:0] SEGMENT;

    seg_display DUT (
        .clk         (clk),
        .rst_n       (rst_n),
        .score_left  (score_left),
        .score_right (score_right),
        .AN          (AN),
        .SEGMENT     (SEGMENT)
    );

    // 25 MHz clock
    always #20 clk = ~clk;

    initial begin
        clk         = 0;
        rst_n       = 0;
        score_left  = 0;
        score_right = 0;

        #100 rst_n = 1;

        // Test a known score
        score_left  = 5;
        score_right = 3;
        #10000;  // enough time to observe several scan cycles (if SCAN_MAX is small)

        // Change score
        score_left  = 10;
        score_right = 9;
        #10000;

        // Test max score
        score_left  = 11;
        score_right = 11;
        #10000;

        // Test zero
        score_left  = 0;
        score_right = 0;
        #10000;

        $stop;
    end

endmodule