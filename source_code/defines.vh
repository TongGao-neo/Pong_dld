// defines.vh
`ifndef DEFINES_VH
`define DEFINES_VH

// Screen size
`define SCREEN_W        640
`define SCREEN_H        480

// Paddle
`define PADDLE_W        10
`define PADDLE_H        80
`define LEFT_PADDLE_X   20
`define RIGHT_PADDLE_X  (`SCREEN_W - `PADDLE_W - 20)  // 610
`define PADDLE_MIN_Y    0
`define PADDLE_MAX_Y    (`SCREEN_H - `PADDLE_H)       // 400
`define PADDLE_SPEED    2

// Ball
`define BALL_SIZE       8
`define BALL_MIN_X      0
`define BALL_MAX_X      (`SCREEN_W - `BALL_SIZE)
`define BALL_MIN_Y      0
`define BALL_MAX_Y      (`SCREEN_H - `BALL_SIZE)

// Game rules
`define MAX_SCORE       11

`endif