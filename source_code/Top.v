// ============================================================================
// Pong Game - Top Module
// Sword Kintex 7 FPGA (SWORD4)
// 100MHz main clock, 25.175MHz VGA clock via MMCM
// ============================================================================

`include "defines.vh"

module Top (
    // 100MHz system clock
    input  wire        clk,

    // Matrix keyboard (5 rows, 4 columns) - verify actual pins!
    output wire [4:0]  key_row,    // driven low sequentially
    input  wire [3:0]  key_col,    // read with internal pull-up

    // Slide switches
    input  wire [15:0] SW,

    // Arduino LEDs (active high)
    output wire [7:0]  ard_led,

    // 4-digit 7-segment display (common anode)
    output wire [3:0]  AN,
    output wire [7:0]  SEGMENT,

    // VGA output (12-bit color)
    output wire [3:0]  vga_red,
    output wire [3:0]  vga_green,
    output wire [3:0]  vga_blue,
    output wire        vga_hs,
    output wire        vga_vs,

    // PS/2 keyboard
    input  wire        PS2_clk,
    input  wire        PS2_data,

    // Buzzer
    output wire        buzzer
);

// ============================================================================
// Clock generation (100MHz -> 25.175MHz)
// ============================================================================
wire clk_25m;
wire pll_locked;

// MMCM wrapper (clk_wiz.v, internally instantiates clk_wiz_0 IP)
clk_wiz u_clk_wiz (
    .clk_in1  (clk),
    .clk_out1 (clk_25m),
    .reset    (SW[0]),
    .locked   (pll_locked)
);

// ============================================================================
// Synchronous reset release
// ============================================================================
reg rst_s1, rst_s2;
wire rst_n;

always @(posedge clk_25m) begin
    rst_s1 <= SW[0] || !pll_locked;         // SW[0] high-active reset
    rst_s2 <= rst_s1;
end
assign rst_n = !rst_s2;      // active-low internal reset

// ============================================================================
// Input devices
// ============================================================================
// Signals from matrix keyboard (5 buttons: left_up/down, right_up/down, start)
wire kp_left_up, kp_left_down, kp_right_up, kp_right_down, kp_start;

keypad_scanner u_keypad (
    .clk        (clk_25m),
    .rst_n      (rst_n),
    .key_row    (key_row),
    .key_col    (key_col),
    .left_up    (kp_left_up),
    .left_down  (kp_left_down),
    .right_up   (kp_right_up),
    .right_down (kp_right_down),
    .start_pause(kp_start)
);

// Signals from PS/2 keyboard (W/S, Up/Down, Enter)
wire ps2_left_up, ps2_left_down, ps2_right_up, ps2_right_down, ps2_start;

ps2_keyboard u_ps2 (
    .clk        (clk_25m),
    .rst_n      (rst_n),
    .PS2_clk    (PS2_clk),
    .PS2_data   (PS2_data),
    .left_up    (ps2_left_up),
    .left_down  (ps2_left_down),
    .right_up   (ps2_right_up),
    .right_down (ps2_right_down),
    .start_pause(ps2_start)
);

// Merge two input sources (OR logic)
wire left_up, left_down, right_up, right_down, start_pause;

input_merger u_input_merger (
    .kp_left_up    (kp_left_up),
    .kp_left_down  (kp_left_down),
    .kp_right_up   (kp_right_up),
    .kp_right_down (kp_right_down),
    .kp_start      (kp_start),
    .ps2_left_up    (ps2_left_up),
    .ps2_left_down  (ps2_left_down),
    .ps2_right_up   (ps2_right_up),
    .ps2_right_down (ps2_right_down),
    .ps2_start      (ps2_start),
    .left_up        (left_up),
    .left_down      (left_down),
    .right_up       (right_up),
    .right_down     (right_down),
    .start_pause    (start_pause)
);

// ============================================================================
// Game logic (state machine, ball physics, paddle control, AI)
// ============================================================================
// Game state outputs (to be used by VGA, LED, buzzer)
wire [2:0]  game_state;      // encoded states
wire [3:0]  score_left, score_right;
wire [9:0]  ball_x, ball_y;
wire [8:0]  paddle_left_y, paddle_right_y;
// Event pulses for sound
wire        hit_paddle, score_event, game_over_event;
wire        serve_side;

game_logic u_game_logic (
    .clk            (clk_25m),
    .rst_n          (rst_n),
    // Control inputs
    .left_up        (left_up),
    .left_down      (left_down),
    .right_up       (right_up),
    .right_down     (right_down),
    .start_pause    (start_pause),
    // Mode selection (e.g., SW[1]: 0=dual, 1=AI)
    .ai_enable      (SW[1]),
    .difficulty     (SW[3:2]),
    // Game state outputs
    .game_state     (game_state),
    .score_left     (score_left),
    .score_right    (score_right),
    .ball_x         (ball_x),
    .ball_y         (ball_y),
    .paddle_left_y  (paddle_left_y),
    .paddle_right_y (paddle_right_y),
    // Sound events
    .hit_paddle     (hit_paddle),
    .score_event    (score_event),
    .game_over_event(game_over_event),
    .serve_side     (serve_side)
);

// ============================================================================
// VGA display
// ============================================================================
// vgac generates sync signals and scanning addresses
wire [8:0]  row_addr;
wire [9:0]  col_addr;
wire        rdn;            // low during active display
wire [11:0] vga_rgb;        // 12-bit color from render

vgac u_vgac (
    .vga_clk    (clk_25m),
    .clrn       (rst_n),
    .d_in       (vga_rgb),
    .row_addr   (row_addr),
    .col_addr   (col_addr),
    .rdn        (rdn),
    .r          (vga_red),
    .g          (vga_green),
    .b          (vga_blue),
    .hs         (vga_hs),
    .vs         (vga_vs)
);

// Render module: decides pixel color based on game objects
vga_render u_vga_render (
    .clk            (clk_25m),
    .rdn            (rdn),
    .row_addr       (row_addr),
    .col_addr       (col_addr),
    .ball_x         (ball_x),
    .ball_y         (ball_y),
    .paddle_left_y  (paddle_left_y),
    .paddle_right_y (paddle_right_y),
    .score_left     (score_left),
    .score_right    (score_right),
    .game_state     (game_state),
    .rgb_out        (vga_rgb)
);

// ============================================================================
// 7-segment display (score)
// ============================================================================
seg_display u_seg (
    .clk        (clk_25m),
    .rst_n      (rst_n),
    .score_left (score_left),
    .score_right(score_right),
    .AN         (AN),
    .SEGMENT    (SEGMENT)
);

// ============================================================================
// LED status indicators
// ============================================================================
led_status u_led (
    .clk        (clk_25m),
    .rst_n      (rst_n),
    .game_state (game_state),
    .score_left (score_left),
    .score_right(score_right),
    .serve_side (serve_side),
    .led        (ard_led)
);

// ============================================================================
// Buzzer sound effects
// ============================================================================
buzzer_ctrl u_buzzer (
    .clk            (clk_25m),
    .rst_n          (rst_n),
    .hit_paddle     (hit_paddle),
    .score_event    (score_event),
    .game_over_event(game_over_event),
    .buzzer         (buzzer)
);

endmodule