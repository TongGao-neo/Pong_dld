// ============================================================================
// defines.vh - Global macro definitions for Pong project
// ============================================================================
`ifndef DEFINES_VH
`define DEFINES_VH

// ----------------------------------------------------------------------------
// Display geometry (640x480 VGA)
// ----------------------------------------------------------------------------
`define SCREEN_W        640
`define SCREEN_H        480

// ----------------------------------------------------------------------------
// Paddle characteristics
// ----------------------------------------------------------------------------
`define PADDLE_W        10          // width in pixels
`define PADDLE_H        80          // height in pixels
`define LEFT_PADDLE_X   20          // X coordinate of left paddle's left edge
`define RIGHT_PADDLE_X  (`SCREEN_W - `PADDLE_W - 20)  // X coordinate of right paddle's left edge
`define PADDLE_MIN_Y    0           // minimum Y coordinate (top of screen)
`define PADDLE_MAX_Y    (`SCREEN_H - `PADDLE_H)       // maximum Y coordinate (bottom edge)
`define PADDLE_SPEED    2           // pixels moved per game tick

// ----------------------------------------------------------------------------
// Ball characteristics
// ----------------------------------------------------------------------------
`define BALL_SIZE       8           // ball is a square of this size
`define BALL_MIN_X      0
`define BALL_MAX_X      (`SCREEN_W - `BALL_SIZE)
`define BALL_MIN_Y      0
`define BALL_MAX_Y      (`SCREEN_H - `BALL_SIZE)

// ----------------------------------------------------------------------------
// Game rules
// ----------------------------------------------------------------------------
`define MAX_SCORE       11          // points needed to win

// ----------------------------------------------------------------------------
// AI opponent (used in ai_paddle.v)
// ----------------------------------------------------------------------------
`define AI_DEAD_ZONE    4           // stop moving when ball is within this many pixels of paddle center

// ----------------------------------------------------------------------------
// Game logic timing
//   WARNING: For simulation, change TICK_MAX and SCORE_TIMEOUT to small
//            values (e.g., 10) so that state transitions happen quickly.
//            Restore original values before synthesis.
// ----------------------------------------------------------------------------
// Game tick rate: 25.175 MHz / (TICK_MAX+1) ~ 60 Hz
`define TICK_MAX        19'd10  // simulation: 10; actual: 419583
//`define TICK_MAX 10
// Score pause duration (in game ticks) ~1 second
`define SCORE_TIMEOUT   19'd10      // simulation: 10; actual: 60 (~1 second at 60 Hz)
//`define SCORE_TIMEOUT 10

// ----------------------------------------------------------------------------
// 7-segment display scanning (used in seg_display.v)
// ----------------------------------------------------------------------------
// Scan frequency = 25.175 MHz / (SCAN_MAX+1) ~ 4 kHz (250 Hz per digit)
`define SCAN_MAX        13'd10    // simulation: 10; actual: 6293
//`define SCAN_MAX 10

`endif