// ============================================================================
// game_logic.v - Pong game state machine, ball physics, paddle control
// ============================================================================

`include "defines.vh"

module game_logic (
    input  wire        clk,
    input  wire        rst_n,
    // Control inputs (from merged button/keyboard)
    input  wire        left_up,
    input  wire        left_down,
    input  wire        right_up,
    input  wire        right_down,
    input  wire        start_pause,
    // Mode / difficulty selection
    input  wire        ai_enable,      // 0 = two-player, 1 = AI controls right paddle
    input  wire [1:0]  difficulty,     // SW[3:2]: 00=Easy, 01=Hard, 10=Master, 11=Auto
    // Game state outputs
    output reg  [2:0]  game_state,
    output reg  [3:0]  score_left,
    output reg  [3:0]  score_right,
    output reg  [9:0]  ball_x,
    output reg  [9:0]  ball_y,
    output reg  [8:0]  paddle_left_y,
    output reg  [8:0]  paddle_right_y,
    // Sound event pulses (one clock wide)
    output reg         serve_side,
    output reg         hit_paddle,
    output reg         score_event,
    output reg         game_over_event
);

    // ------------------------------------------------------------------------
    // State encoding
    // ------------------------------------------------------------------------
    localparam S_IDLE  = 3'd0;
    localparam S_SERVE = 3'd1;
    localparam S_PLAY  = 3'd2;
    localparam S_PAUSE = 3'd3;
    localparam S_SCORE = 3'd4;
    localparam S_OVER  = 3'd5;

    // ------------------------------------------------------------------------
    // Game tick generation (variable rate based on difficulty)
    // ------------------------------------------------------------------------
    reg [18:0] tick_counter;
    reg [18:0] tick_threshold = `TICK_THRESH_SPEED1;
    wire game_tick;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter <= 19'd0;
        end else if (tick_counter >= tick_threshold) begin
            tick_counter <= 19'd0;
        end else begin
            tick_counter <= tick_counter + 1;
        end
    end
    assign game_tick = (tick_counter >= tick_threshold);

    // ------------------------------------------------------------------------
    // AI paddle control
    // ------------------------------------------------------------------------
    wire ai_right_up, ai_right_down;
    wire ball_toward_ai = ~ball_dx[9];  // 1 = ball moving right (toward right-paddle AI)
    ai_paddle u_ai (
        .clk        (clk),
        .rst_n      (rst_n),
        .game_tick  (game_tick),
        .ball_y     (ball_y),
        .paddle_y   (paddle_right_y),
        .ball_toward_ai (ball_toward_ai),
        .move_up    (ai_right_up),
        .move_down  (ai_right_down)
    );

    // Mux between player and AI for right paddle
    wire right_up_sel   = ai_enable ? ai_right_up   : right_up;
    wire right_down_sel = ai_enable ? ai_right_down : right_down;

    // ------------------------------------------------------------------------
    // Speed computation helper (used in S_SERVE to set tick_threshold)
    // ------------------------------------------------------------------------
    reg [2:0] ball_speed_idx;

    always @* begin
        case (difficulty)
            2'b00: ball_speed_idx = 3'd1;  // Easy
            2'b01: ball_speed_idx = 3'd2;  // Hard
            2'b10: ball_speed_idx = 3'd3;  // Master
            2'b11: begin                   // Auto: speed = 1 + round_count
                if (score_left + score_right >= `AUTO_MAX_SPEED - 1)
                    ball_speed_idx = `AUTO_MAX_SPEED;
                else
                    ball_speed_idx = score_left + score_right + 3'd1;
            end
            default: ball_speed_idx = 3'd1;
        endcase
    end

    // ------------------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------------------
    reg  [2:0]  next_state;
    reg  [3:0]  next_score_left, next_score_right;
    reg  [9:0]  next_ball_x, next_ball_y;
    reg  [8:0]  next_paddle_left_y, next_paddle_right_y;
    reg  [9:0]  ball_dx, ball_dy;     // ball velocity (direction only, magnitude 1)
    reg  [19:0] score_timer;          // delay after scoring
    reg  [19:0] serve_timer;          // delay before auto-serve
    reg         start_pause_d;       // delayed copy for edge detection
    reg  [15:0] rand_cnt;            // free-running counter for serve random

    // ------------------------------------------------------------------------
    // State machine
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            game_state      <= S_IDLE;
            score_left      <= 4'd0;
            score_right     <= 4'd0;
            ball_x          <= 10'd320 - (`BALL_SIZE / 2);
            ball_y          <= 10'd240 - (`BALL_SIZE / 2);
            paddle_left_y   <= 9'd240 - (`PADDLE_H / 2);
            paddle_right_y  <= 9'd240 - (`PADDLE_H / 2);
            ball_dx         <= 10'd1;
            ball_dy         <= 10'd1;
            serve_side      <= 1'b0;
            score_timer     <= 20'd0;
            serve_timer     <= 20'd0;
            start_pause_d   <= 1'b0;
            rand_cnt        <= 16'd0;
            tick_threshold  <= `TICK_THRESH_SPEED1;
            hit_paddle      <= 1'b0;
            score_event     <= 1'b0;
            game_over_event <= 1'b0;
        end else if (game_tick) begin
            // Default event pulses are one-shot
            hit_paddle      <= 1'b0;
            score_event     <= 1'b0;
            game_over_event <= 1'b0;
            start_pause_d   <= start_pause;   // edge detection
            rand_cnt        <= rand_cnt + 1;  // free-running for serve RNG

            // Default: next_* hold current value (prevents X propagation)
            next_state         = game_state;
            next_paddle_left_y = paddle_left_y;
            next_paddle_right_y= paddle_right_y;
            next_ball_x        = ball_x;
            next_ball_y        = ball_y;
            next_score_left    = score_left;
            next_score_right   = score_right;

            case (game_state)
                // ------- IDLE -------
                S_IDLE: begin
                    if (start_pause && !start_pause_d) begin
                        // reset scores and start new game
                        next_score_left  = 4'd0;
                        next_score_right = 4'd0;
                        serve_side      <= 1'b0;
                        serve_timer     <= 20'd0;
                        next_state       = S_SERVE;
                    end else begin
                        next_state = S_IDLE;
                    end
                end

                // ------- SERVE -------
                S_SERVE: begin
                    // One-time setup on first entry
                    if (serve_timer == 20'd0) begin
                        // Place ball at center, set direction toward serving side
                        next_ball_x = 10'd320 - (`BALL_SIZE / 2);
                        next_ball_y = 10'd240 - (`BALL_SIZE / 2);
                        if (serve_side == 1'b0) begin
                            ball_dx <= 10'd1;   // moving right
                        end else begin
                            ball_dx <= -10'd1;  // moving left
                        end
                        ball_dy <= (rand_cnt[0]) ? 10'd1 : -10'd1;   // pseudo-random up/down

                        // Update tick threshold for this round
                        case (ball_speed_idx)
                            3'd1: tick_threshold <= `TICK_THRESH_SPEED1;
                            3'd2: tick_threshold <= `TICK_THRESH_SPEED2;
                            3'd3: tick_threshold <= `TICK_THRESH_SPEED3;
                            3'd4: tick_threshold <= `TICK_THRESH_SPEED4;
                            3'd5: tick_threshold <= `TICK_THRESH_SPEED5;
                            default: tick_threshold <= `TICK_THRESH_SPEED1;
                        endcase
                    end

                    // Increment serve timer
                    if (serve_timer < `SERVE_TIMEOUT)
                        serve_timer <= serve_timer + 1;

                    // Transition: manual start or auto-serve timeout
                    if (start_pause && !start_pause_d) begin
                        serve_timer  <= 20'd0;
                        next_state = S_PLAY;
                    end else if (serve_timer >= `SERVE_TIMEOUT) begin
                        serve_timer  <= 20'd0;
                        next_state = S_PLAY;
                    end else begin
                        next_state = S_SERVE;
                    end
                end

                // ------- PLAY -------
                S_PLAY: begin
                    // --- Pause check ---
                    if (start_pause && !start_pause_d) begin
                        next_state = S_PAUSE;
                    end else begin
                        // --- Paddle movement ---
                        // Left paddle
                        if (left_up && (paddle_left_y > `PADDLE_MIN_Y))
                            next_paddle_left_y = paddle_left_y - `PADDLE_SPEED;
                        else if (left_down && (paddle_left_y < `PADDLE_MAX_Y))
                            next_paddle_left_y = paddle_left_y + `PADDLE_SPEED;
                        else
                            next_paddle_left_y = paddle_left_y;
                        
                        // Right paddle
                        if (right_up_sel && (paddle_right_y > `PADDLE_MIN_Y))
                            next_paddle_right_y = paddle_right_y - `PADDLE_SPEED;
                        else if (right_down_sel && (paddle_right_y < `PADDLE_MAX_Y))
                            next_paddle_right_y = paddle_right_y + `PADDLE_SPEED;
                        else
                            next_paddle_right_y = paddle_right_y;

                        // --- Ball movement ---
                        next_ball_x = ball_x + ball_dx;
                        next_ball_y = ball_y + ball_dy;

                        // --- Top/Bottom boundary bounce ---
                        if (next_ball_y <= `BALL_MIN_Y) begin
                            next_ball_y = `BALL_MIN_Y;
                            ball_dy <= -ball_dy; // bounce down
                        end else if (next_ball_y + `BALL_SIZE >= `BALL_MAX_Y) begin
                            next_ball_y = `BALL_MAX_Y - `BALL_SIZE;
                            ball_dy <= -ball_dy; // bounce up
                        end

                        // --- Left paddle collision ---
                        if ((next_ball_x <= `LEFT_PADDLE_X + `PADDLE_W) &&
                            (next_ball_x + `BALL_SIZE >= `LEFT_PADDLE_X) &&
                            (next_ball_y + `BALL_SIZE > paddle_left_y) &&
                            (next_ball_y < paddle_left_y + `PADDLE_H)) begin
                            next_ball_x = `LEFT_PADDLE_X + `PADDLE_W;
                            ball_dx <= 10'd1;  // reverse direction to right
                            hit_paddle <= 1'b1;
                        end

                        // --- Right paddle collision ---
                        if ((next_ball_x + `BALL_SIZE >= `RIGHT_PADDLE_X) &&
                            (next_ball_x <= `RIGHT_PADDLE_X + `PADDLE_W) &&
                            (next_ball_y + `BALL_SIZE > paddle_right_y) &&
                            (next_ball_y < paddle_right_y + `PADDLE_H)) begin
                            next_ball_x = `RIGHT_PADDLE_X - `BALL_SIZE;
                            ball_dx <= -10'd1; // reverse direction to left
                            hit_paddle <= 1'b1;
                        end

                        // --- Score detection ---
                        if (next_ball_x <= `BALL_MIN_X) begin
                            // Right player scores
                            next_score_right = score_right + 1;
                            score_event <= 1'b1;
                            if (next_score_right == `MAX_SCORE) begin
                                next_state = S_OVER;
                            end else begin
                                serve_side <= 1'b0;   // left serves next
                                next_state = S_SCORE;
                            end
                        end else if (next_ball_x + `BALL_SIZE >= `BALL_MAX_X) begin
                            // Left player scores
                            next_score_left = score_left + 1;
                            score_event <= 1'b1;
                            if (next_score_left == `MAX_SCORE) begin
                                next_state = S_OVER;
                            end else begin
                                serve_side <= 1'b1;   // right serves next
                                next_state = S_SCORE;
                            end
                        end else begin
                            next_state = S_PLAY;
                        end
                    end
                end

                // ------- PAUSE -------
                S_PAUSE: begin
                    if (start_pause && !start_pause_d)
                        next_state = S_PLAY;
                    else
                        next_state = S_PAUSE;
                end

                // ------- SCORE (brief delay) -------
                S_SCORE: begin
                    if (score_timer == `SCORE_TIMEOUT) begin
                        score_timer <= 20'd0;
                        serve_timer <= 20'd0;   // reset auto-serve timer
                        next_state = S_SERVE;
                    end else begin
                        score_timer <= score_timer + 1;
                        next_state = S_SCORE;
                    end
                end

                // ------- GAME OVER -------
                S_OVER: begin
                    game_over_event <= 1'b1;
                    if (start_pause && !start_pause_d) begin
                        // go back to idle and reset scores
                        next_score_left  = 4'd0;
                        next_score_right = 4'd0;
                        next_state = S_IDLE;
                    end else begin
                        next_state = S_OVER;
                    end
                end

                default: next_state = S_IDLE;
            endcase

            // Register updates (except those already assigned)
            game_state     <= next_state;
            paddle_left_y  <= next_paddle_left_y;
            paddle_right_y <= next_paddle_right_y;
            ball_x         <= next_ball_x;
            ball_y         <= next_ball_y;
            score_left     <= next_score_left;
            score_right    <= next_score_right;
        end
    end

endmodule