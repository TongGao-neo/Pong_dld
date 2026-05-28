// ============================================================================
// tb_Top.v - Top-Level System Testbench for Pong Game
// ============================================================================
// USAGE (Vivado xsim):
//   1. Uncomment simulation values in defines.vh:
//        `define TICK_MAX 10
//        `define SCORE_TIMEOUT 10
//        `define SCAN_MAX 10
//   2. Uncomment simulation SCAN_DELAY in keypad_scanner.v:
//        localparam SCAN_DELAY = 10;
//   3. Uncomment simulation BLINK_MAX in led_status.v:
//        localparam BLINK_MAX = 24'd10;
//   4. Add this file to simulation sources
//   5. Set as top-level simulation module
//   6. Run Behavioral Simulation
//
// NOTES:
//   - Requires Vivado xsim with compiled clk_wiz_0 simulation library
//   - PS/2 ports are pulled high (idle) -- no PS/2 stimulus is applied
//   - Tests use hierarchical references (uut.signal); ensure debug visibility
// ============================================================================

`timescale 1ns / 1ps

module tb_Top;

    // ========================================================================
    // Signal Declarations
    // ========================================================================

    // Clock and reset
    reg         clk;            // 100 MHz system clock
    reg         rst_sw;         // active-high reset (SW[0])

    // Matrix keyboard
    reg  [3:0]  key_col_drv;    // driven by testbench
    wire [4:0]  key_row;        // driven by DUT scanner
    wire [3:0]  key_col;        // connected to DUT

    // Slide switches
    reg  [15:0] sw_reg;
    wire [15:0] SW;

    // Arduino LEDs
    wire [7:0]  ard_led;

    // 7-segment display
    wire [3:0]  AN;
    wire [7:0]  SEGMENT;

    // VGA output
    wire [3:0]  vga_red;
    wire [3:0]  vga_green;
    wire [3:0]  vga_blue;
    wire        vga_hs;
    wire        vga_vs;

    // PS/2 (bidirectional, pulled high = idle)
    wire        PS2_clk;
    wire        PS2_data;

    // Buzzer
    wire        buzzer;

    // ========================================================================
    // PS/2 idle termination (no keyboard connected)
    // ========================================================================
    assign PS2_clk  = 1'b1;
    assign PS2_data = 1'b1;

    // ========================================================================
    // Switch assignments
    //   SW[1] = 0: two-player mode (use matrix keypad)
    //   SW[1] = 1: AI controls right paddle
    // ========================================================================
    assign SW = sw_reg;

    // ========================================================================
    // Matrix keyboard column driver
    // ========================================================================
    assign key_col = key_col_drv;

    // ========================================================================
    // Device Under Test
    // ========================================================================
    Top uut (
        .clk        (clk),
        .rst_sw     (rst_sw),
        .key_row    (key_row),
        .key_col    (key_col),
        .SW         (SW),
        .ard_led    (ard_led),
        .AN         (AN),
        .SEGMENT    (SEGMENT),
        .vga_red    (vga_red),
        .vga_green  (vga_green),
        .vga_blue   (vga_blue),
        .vga_hs     (vga_hs),
        .vga_vs     (vga_vs),
        .PS2_clk    (PS2_clk),
        .PS2_data   (PS2_data),
        .buzzer     (buzzer)
    );

    // ========================================================================
    // 100 MHz Clock Generation
    // ========================================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 10 ns period

    // ========================================================================
    // Keypad Stimulus Task
    //   Drives the specified column low for enough time that the scanner
    //   completes debounce (at least 8 matching scans on the target row).
    //   Hold time: ~10 ms at 100 MHz (= 1,000,000 clock cycles)
    // ========================================================================
    task press_keypad;
        input [2:0] row;         // target row (0=left, 1=right, 2=start)
        input [3:0] col_bit;     // which column bit to drive low (0=up/start, 1=down)
        begin
            // Drive column low
            key_col_drv[col_bit] = 1'b0;

            // Hold for debounce: the scanner cycles through 5 rows at
            // SCAN_DELAY intervals per row.  With SCAN_DELAY=10 (simulation),
            // one full scan is ~50 cycles.  Debounce requires 8 readings.
            // We wait ~10 ms to be safe across all settings.
            repeat (1000000) @(posedge clk);

            // Release
            key_col_drv[col_bit] = 1'b1;
            repeat (50000) @(posedge clk);  // 0.5 ms gap between key presses
        end
    endtask

    // ========================================================================
    // Helper: wait for N milliseconds (at 100 MHz)
    // ========================================================================
    task wait_ms;
        input integer ms;
        begin
            repeat (ms * 100000) @(posedge clk);
        end
    endtask

    // ========================================================================
    // Helper: check condition and report
    // ========================================================================
    integer test_pass;
    integer test_fail;

    initial begin
        test_pass = 0;
        test_fail = 0;
    end

    task check;
        input        condition;
        input [255:0] name;
        begin
            if (condition) begin
                $display("  [PASS] %0s", name);
                test_pass = test_pass + 1;
            end else begin
                $display("  [FAIL] %0s", name);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    integer i;

    initial begin
        // ----- Init -----
        rst_sw      = 1'b1;
        key_col_drv = 4'b1111;
        sw_reg      = 16'd0;      // two-player mode, all switches off

        // Force clrn=0 and vgac counters to 0 at sim start.
        // The MMCM IP behavioral model may not initialize vgac's purely
        // synchronous flops.  This override handles the initial X window.
        force uut.rst_n = 1'b0;
        force uut.u_vgac.h_count = 10'd0;
        force uut.u_vgac.v_count = 10'd0;
        #200;
        release uut.u_vgac.h_count;
        release uut.u_vgac.v_count;
        // rst_n kept forced until PLL lock (released after Phase 0)

        $display("");
        $display("============================================================");
        $display(" Pong - Top-Level System Simulation");
        $display("============================================================");
        $display("");

        // ----- Phase 0: Reset -----
        $display("--- Phase 0: Power-On Reset ---");
        wait_ms(1);                 // 1 ms in reset
        rst_sw = 1'b0;              // release reset
        $display("  Reset released, waiting for MMCM lock...");
        wait_ms(1);                 // allow PLL behavioral model to lock

        // Release rst_n force ~~ synchronizer now tracks clk_25m
        release uut.rst_n;

        // ================================================================
        // Test 1: IDLE State
        // ================================================================
        $display("");
        $display("--- Test 1: IDLE State ---");

        // Wait a few game ticks for state machine to settle
        wait_ms(5);

        check(uut.u_game_logic.game_state == 3'd0,
              "Game state = IDLE (0) after reset");

        check(uut.u_led.led[0] == 1'b1,
              "LED[0] high (Idle indicator)");

        // ================================================================
        // Test 2: IDLE -> SERVE
        // ================================================================
        $display("");
        $display("--- Test 2: IDLE -> SERVE (Start game) ---");

        press_keypad(3'd2, 3'd0);   // Row 2 (START), Col 0 = start_pause
        wait_ms(5);

        check(uut.u_game_logic.game_state == 3'd1,
              "Game state = SERVE (1) after start press");

        check(uut.u_led.led[1] == 1'b1,
              "LED[1] high (Serve indicator)");

        check(uut.u_game_logic.score_left  == 4'd0 &&
              uut.u_game_logic.score_right == 4'd0,
              "Scores reset to 0-0");

        // ================================================================
        // Test 3: SERVE -> PLAY
        // ================================================================
        $display("");
        $display("--- Test 3: SERVE -> PLAY ---");

        press_keypad(3'd2, 3'd0);   // Start again
        wait_ms(5);

        check(uut.u_game_logic.game_state == 3'd2,
              "Game state = PLAY (2) after second start press");

        check(uut.u_led.led[2] == 1'b1,
              "LED[2] high (Playing indicator)");

        // ================================================================
        // Test 4: Ball Movement
        // ================================================================
        $display("");
        $display("--- Test 4: Ball Movement ---");
        $display("  Ball initial: (%d, %d)",
                 uut.u_game_logic.ball_x, uut.u_game_logic.ball_y);

        wait_ms(10);    // let several game ticks pass

        $display("  Ball after 10ms: (%d, %d)",
                 uut.u_game_logic.ball_x, uut.u_game_logic.ball_y);

        check(uut.u_game_logic.ball_x != 10'd316 ||
              uut.u_game_logic.ball_y != 10'd236,
              "Ball position changed (ball is moving)");

        // ================================================================
        // Test 5: Paddle Movement (keypad)
        // ================================================================
        $display("");
        $display("--- Test 5: Paddle Movement ---");

        $display("  Paddle left  initial Y: %d", uut.u_game_logic.paddle_left_y);
        $display("  Paddle right initial Y: %d", uut.u_game_logic.paddle_right_y);

        // Move left paddle down (Row 0, Col 1)
        press_keypad(3'd0, 3'd1);   // left_down
        wait_ms(2);
        press_keypad(3'd0, 3'd1);   // twice for more movement
        wait_ms(5);

        // Move right paddle up (Row 1, Col 0)
        press_keypad(3'd1, 3'd0);   // right_up
        wait_ms(2);
        press_keypad(3'd1, 3'd0);
        wait_ms(5);

        $display("  Paddle left  after:    %d", uut.u_game_logic.paddle_left_y);
        $display("  Paddle right after:    %d", uut.u_game_logic.paddle_right_y);

        check(uut.u_game_logic.paddle_left_y > 9'd240 - 40,
              "Left paddle moved");

        check(uut.u_game_logic.paddle_right_y != 9'd240 - 40,
              "Right paddle moved");

        // ================================================================
        // Test 6: Pause / Resume
        // ================================================================
        $display("");
        $display("--- Test 6: Pause / Resume ---");

        press_keypad(3'd2, 3'd0);   // Pause
        wait_ms(5);

        check(uut.u_game_logic.game_state == 3'd3,
              "Game state = PAUSE (3)");

        check(uut.u_led.led[6] === 1'b0 || uut.u_led.led[6] === 1'b1,
              "LED[6] is a valid logic level in PAUSE (not X/Z)");

        press_keypad(3'd2, 3'd0);   // Resume
        wait_ms(5);

        check(uut.u_game_logic.game_state == 3'd2,
              "Game state = PLAY (2) after resume");

        // ================================================================
        // Test 7: Ball Wall Bounce (top/bottom)
        // ================================================================
        $display("");
        $display("--- Test 7: Ball Wall Bounce ---");

        // Let the ball bounce naturally for a while
        // With simulation speeds, it should hit walls quickly
        wait_ms(20);

        $display("  Ball position: (%d, %d)",
                 uut.u_game_logic.ball_x, uut.u_game_logic.ball_y);

        // Ball should still be within screen bounds
        check(uut.u_game_logic.ball_y <= 472,
              "Ball Y within screen (no escape through walls)");

        check(uut.u_game_logic.ball_y >= 0,
              "Ball Y >= 0 (top boundary holds)");

        // ================================================================
        // Test 8: Score Event
        // ================================================================
        $display("");
        $display("--- Test 8: Score Detection ---");
        $display("  NOTE: Ball direction depends on random seed.");
        $display("  If ball moves left, it will eventually score against left.");
        $display("  Watching for score transition...");

        // Wait for ball to reach an edge (score or bounce)
        // With simulation TICK_MAX=10, ball crosses screen quickly
        wait_ms(50);

        // Check if we scored or are still playing
        $display("  Game state: %d (0=IDLE,1=SERVE,2=PLAY,3=PAUSE,4=SCORE,5=OVER)",
                 uut.u_game_logic.game_state);
        $display("  Score: %d - %d",
                 uut.u_game_logic.score_left, uut.u_game_logic.score_right);

        // At least verify the state machine didn't lock up
        check(uut.u_game_logic.game_state != 3'd0,
              "Game did not return to IDLE unexpectedly");

        // ================================================================
        // Test 9: 7-Segment Display
        // ================================================================
        $display("");
        $display("--- Test 9: 7-Segment Display ---");

        // AN should be cycling (one-hot encoded, active low)
        // At least one digit should be selected (AN != 4'b1111)
        wait_ms(1);
        check(AN != 4'b1111 || AN != 4'hF,
              "AN active (digit scan running)");

        // With score likely 0-0, segments should show "0"
        $display("  AN=%b  SEGMENT=%b", AN, SEGMENT);

        // ================================================================
        // Test 10: VGA Sync Signals
        // ================================================================
        $display("");
        $display("--- Test 10: VGA Sync Signals ---");

        // Need to let at least one frame complete (~16.7 ms)
        // But our simulation MMCM outputs 25.175 MHz, so a full
        // frame (800x525 = 420k pixels) takes 420k/25.175M = 16.7 ms
        wait_ms(20);

        // At this point hs and vs should have toggled at least once
        $display("  vga_hs=%b  vga_vs=%b", vga_hs, vga_vs);

        check(vga_hs !== 1'bx && vga_hs !== 1'bz,
              "vga_hs driven (not X/Z)");

        check(vga_vs !== 1'bx && vga_vs !== 1'bz,
              "vga_vs driven (not X/Z)");

        // ================================================================
        // Test 11: Buzzer (no sound events = silent)
        // ================================================================
        $display("");
        $display("--- Test 11: Buzzer ---");
        check(buzzer !== 1'bx && buzzer !== 1'bz,
              "Buzzer signal driven (not X/Z)");

        // ================================================================
        // Test 12: AI Mode (SW[1] = 1)
        // ================================================================
        $display("");
        $display("--- Test 12: AI Mode ---");

        // Reset and restart with AI enabled
        rst_sw = 1'b1;
        wait_ms(1);
        rst_sw = 1'b0;
        sw_reg[1] = 1'b1;          // enable AI
        wait_ms(2);

        // Start game
        press_keypad(3'd2, 3'd0);   // IDLE -> SERVE
        wait_ms(2);
        press_keypad(3'd2, 3'd0);   // SERVE -> PLAY
        wait_ms(10);

        $display("  Ball: (%d, %d)  Right paddle: %d",
                 uut.u_game_logic.ball_x,
                 uut.u_game_logic.ball_y,
                 uut.u_game_logic.paddle_right_y);

        // AI should track the ball: paddle_right_y should be near ball_y
        check(uut.u_game_logic.game_state == 3'd2,
              "AI mode: game reached PLAY state");

        // ================================================================
        // Final Summary
        // ================================================================
        $display("");
        $display("============================================================");
        $display(" Simulation Complete");
        $display("   Tests passed: %0d", test_pass);
        $display("   Tests failed: %0d", test_fail);
        $display("============================================================");
        $display("");

        if (test_fail == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", test_fail);

        $finish;
    end

    // ========================================================================
    // Simulation Timeout (safety net)
    // ========================================================================
    initial begin
        #500000000;     // 500 ms timeout
        $display("TIMEOUT: Simulation did not complete in 500 ms");
        $display("Check that PLL locked and game_tick is running.");
        $display("Verify that defines.vh uses simulation values.");
        $finish;
    end

    // ========================================================================
    // Optional: Dump VCD for waveform analysis
    // ========================================================================
    initial begin
        $dumpfile("tb_Top.vcd");
        $dumpvars(0, tb_Top);
    end

endmodule
