// ============================================================================
// tb_ai_paddle.v - Testbench for ai_paddle module
// No internal long counters; can run directly.
// ============================================================================

`timescale 1ns / 1ps
`include "defines.vh"

module tb_ai_paddle;

    reg        clk;
    reg        rst_n;
    reg [9:0]  ball_y;
    reg [8:0]  paddle_y;
    wire       move_up;
    wire       move_down;

    ai_paddle DUT (
        .clk       (clk),
        .rst_n     (rst_n),
        .ball_y    (ball_y),
        .paddle_y  (paddle_y),
        .move_up   (move_up),
        .move_down (move_down)
    );

    // 25 MHz clock
    always #20 clk = ~clk;

    initial begin
        clk      = 0;
        rst_n    = 0;
        ball_y   = 200;
        paddle_y = 200;

        #100 rst_n = 1;

        // Case 1: ball above paddle => expect move_up
        ball_y   = 100;   // ball center ~104, paddle center ~240, difference > DEAD_ZONE
        paddle_y = 200;
        #1000;
        if (move_up !== 1 || move_down !== 0) $display("ERROR: Expected move_up=1, move_down=0");

        // Case 2: ball below paddle => expect move_down
        ball_y   = 400;
        paddle_y = 200;
        #1000;
        if (move_down !== 1 || move_up !== 0) $display("ERROR: Expected move_down=1, move_up=0");

        // Case 3: ball within dead zone => both 0
        ball_y   = 200;   // paddle_y = 200, difference < DEAD_ZONE
        paddle_y = 200;
        #1000;
        if (move_up !== 0 || move_down !== 0) $display("ERROR: Expected both 0 in dead zone");

        // Case 4: slightly above dead zone
        ball_y   = 190;   // paddle_y=200, difference ~10, should be up
        paddle_y = 200;
        #1000;
        // Not strictly checking here, just observe

        #1000 $stop;
    end

endmodule