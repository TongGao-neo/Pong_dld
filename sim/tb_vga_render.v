`timescale 1ns / 1ps
`include "defines.vh"

module tb_vga_render;

    reg        clk;
    reg        rdn;
    reg [8:0]  row_addr;
    reg [9:0]  col_addr;
    reg [9:0]  ball_x, ball_y;
    reg [8:0]  paddle_left_y, paddle_right_y;
    reg [3:0]  score_left, score_right;
    reg [2:0]  game_state;
    wire [11:0] rgb_out;

    vga_render DUT (
        .clk           (clk),
        .rdn           (rdn),
        .row_addr      (row_addr),
        .col_addr      (col_addr),
        .ball_x        (ball_x),
        .ball_y        (ball_y),
        .paddle_left_y (paddle_left_y),
        .paddle_right_y(paddle_right_y),
        .score_left    (score_left),
        .score_right   (score_right),
        .game_state    (game_state),
        .rgb_out       (rgb_out)
    );

    // 25.175 MHz clock
    always #19.86 clk = ~clk;

    initial begin
        clk = 0;
        rdn = 1;
        row_addr = 0;
        col_addr = 0;
        // Initialize objects
        ball_x = 320; ball_y = 240;
        paddle_left_y  = 200;
        paddle_right_y = 200;
        score_left  = 3;
        score_right = 7;
        game_state  = 2;   // PLAY state (not game over)

        #100;
        // Test background
        rdn = 0; col_addr = 100; row_addr = 100;
        #20;
        if (rgb_out !== 12'h000) $display("FAIL: background not black");

        // Test ball
        col_addr = 320; row_addr = 240;
        #20;
        if (rgb_out !== 12'hFFF) $display("FAIL: ball pixel not white");

        // Test score digit (left tens, 3)
        col_addr = 200; row_addr = 30;
        #20;
        // Just observe, no strict check

        // Now test GAME OVER display
        game_state = 5;   // S_OVER
        // Point to first letter 'G', top-left pixel
        col_addr = 284; row_addr = 232;
        #20;
        if (rgb_out !== 12'hFFF) $display("FAIL: GAME OVER 'G' top-left not white");

        // Somewhere inside the word
        col_addr = 300; row_addr = 240;
        #20;
        // Should be white or black depending on letter
        // At least not overriding other objects? Just check it's not black only?
        // For report we just observe waveforms.

        // Return to PLAY, text should disappear
        game_state = 2;
        #20;
        if (rgb_out === 12'hFFF) $display("WARNING: pixel still white after leaving OVER state");

        #1000 $stop;
    end

endmodule