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
        clk = 0; rst_n = 0;
        ball_y = 200; paddle_y = 200;
        #100 rst_n = 1;
    
        // 1. 球在上方
        ball_y = 100; paddle_y = 200;
        #1000;
        // 期望 move_up=1
    
        // 2. 球在下方
        ball_y = 400; paddle_y = 200;
        #1000;
        // 期望 move_down=1
    
        // 3. 死区：ball_y = paddle_y + 36
        ball_y = 236; paddle_y = 200;
        #1000;
        // 期望 move_up=0, move_down=0
    
        // 4. 略高于死区上界
        ball_y = 231; paddle_y = 200;  // 差值为 5，大于 DEAD_ZONE
        #1000;
        // 期望 move_up=1
    
        #1000 $stop;
    end
    
endmodule