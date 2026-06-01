// ============================================================================
// tb_game_logic.v - Testbench for game_logic module
// Before simulation, temporarily change TICK_MAX and SCORE_TIMEOUT in
// game_logic.v to small values (e.g., 10 and 10) so game_tick fires quickly.
// ============================================================================

`timescale 1ns / 1ps
`include "defines.vh"

module tb_game_logic;

    reg        clk;
    reg        rst_n;
    reg        left_up, left_down;
    reg        right_up, right_down;
    reg        start_pause;
    reg        ai_enable;

    reg  [1:0] difficulty;

    wire [2:0] game_state;
    wire [3:0] score_left, score_right;
    wire [9:0] ball_x, ball_y;
    wire [8:0] paddle_left_y, paddle_right_y;
    wire       hit_paddle, score_event, game_over_event;

    // Instantiate DUT
    game_logic DUT (
        .clk            (clk),
        .rst_n          (rst_n),
        .left_up        (left_up),
        .left_down      (left_down),
        .right_up       (right_up),
        .right_down     (right_down),
        .start_pause    (start_pause),
        .ai_enable      (ai_enable),
        .difficulty     (difficulty),
        .game_state     (game_state),
        .score_left     (score_left),
        .score_right    (score_right),
        .ball_x         (ball_x),
        .ball_y         (ball_y),
        .paddle_left_y  (paddle_left_y),
        .paddle_right_y (paddle_right_y),
        .hit_paddle     (hit_paddle),
        .score_event    (score_event),
        .game_over_event(game_over_event),
        .serve_side     ()
    );

    // 25.175 MHz clock -> period ~39.7 ns
    // Using 25 MHz (40 ns) for simplicity
    always #20 clk = ~clk;  // 40 ns period

    // Test sequence
    initial begin
        // Initialize signals
        clk          = 0;
        rst_n        = 0;
        left_up      = 0;
        left_down    = 0;
        right_up     = 0;
        right_down   = 0;
        start_pause  = 0;
        ai_enable    = 0;   // two-player mode for testing
        difficulty   = 2'b00; // Easy mode

        // Reset
        #100 rst_n = 1;

        // Wait a few game_ticks to see IDLE state (score = 0, ball centered)
        #50000;  // enough time if TICK_MAX is small (e.g., 10)

        // Press start to begin (goes to SERVE)
        start_pause = 1;
        #500;
        start_pause = 0;
        #50000;

        // In SERVE, pressing start again should go to PLAY
        start_pause = 1;
        #500;
        start_pause = 0;
        #50000;

        // Simulate moving left paddle down and right paddle up to test collision
        // Let the ball travel; after some time, we can observe paddle control
        left_down  = 1;
        right_up   = 1;
        #200000;

        // Release paddle controls
        left_down  = 0;
        right_up   = 0;
        #500000;

        // Eventually ball will score if no paddle hit; observe score_event
        // Then game should transition to SCORE and SERVE again.
        // Wait long enough for multiple cycles.
        #1000000;

        // Press start to pause in PLAY state
        start_pause = 1;
        #500;
        start_pause = 0;
        #50000;
        // Press start again to resume
        start_pause = 1;
        #500;
        start_pause = 0;
        #50000;

        // For game over, we would need to accumulate 11 points; not feasible in simulation.
        // Instead, we could set MAX_SCORE to a low value temporarily for testing.
        // Or just observe normal play.

        $stop;
    end

endmodule