// ============================================================================
// tb_keypad_scanner.v - Testbench for keypad_scanner module
// ============================================================================
`timescale 1ns / 1ps

module tb_keypad_scanner;

    reg        clk;
    reg        rst_n;
    wire [4:0] key_row;
    reg  [3:0] key_col;
    wire       left_up, left_down, right_up, right_down, start_pause;

    keypad_scanner DUT (
        .clk         (clk),
        .rst_n       (rst_n),
        .key_row     (key_row),
        .key_col     (key_col),
        .left_up     (left_up),
        .left_down   (left_down),
        .right_up    (right_up),
        .right_down  (right_down),
        .start_pause (start_pause)
    );

    // Clock
    always #19.86 clk = ~clk;   // 25.175 MHz

    // Simulate key press: when the row is active (low) and we want to simulate press,
    // drive the corresponding column low.
    // We'll monitor key_row and react after some delay to mimic real wiring.
    // For simplicity, just use a task.

    reg [4:0] row_cur;
    always @(key_row) row_cur = key_row;

    // Default column state: pull-up (high)
    initial begin
        clk = 0;
        rst_n = 0;
        key_col = 4'b1111;

        #200 rst_n = 1;

        // Wait for the scanner to start
        #10000;

        // Simulate Left Up press (Row0, Col0)
        // Wait until row_cur[0] is low (active)
        @(negedge key_row[0]); // row0 just driven low
        // Apply column low to simulate press (will be held for many scan ticks)
        key_col[0] = 1'b0;
        // Wait enough time for debounce (8 scan ticks = 8 * ~1ms each simulation? SCAN_DELAY is 10, so scan_tick every ~400ns, 8*400ns=3.2us)
        #5000;  // hold for a while
        key_col[0] = 1'b1; // release

        // Now check if left_up went high during this time (can see in waveform)

        #10000;

        // Simulate Right Down press (Row1, Col1)
        @(negedge key_row[1]);
        key_col[1] = 1'b0;
        #5000;
        key_col[1] = 1'b1;

        #10000;

        // Simulate Start press (Row2, Col0)
        @(negedge key_row[2]);
        key_col[0] = 1'b0;
        #5000;
        key_col[0] = 1'b1;

        #20000;
        $stop;
    end

endmodule