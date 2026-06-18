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
    output reg  [9:0]  paddle_left_y,
    output reg  [9:0]  paddle_right_y,
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
    // Signed temporary signals for position updates and boundary checks
    // ------------------------------------------------------------------------
    wire signed [10:0] next_x_s = $signed({1'b0, ball_x}) + ball_dx;
    wire signed [10:0] next_y_s = $signed({1'b0, ball_y}) + ball_dy;

    // Center-of-gravity positions for paddle hit offset calculation
    wire [9:0] ball_center_y  = ball_y  + (`BALL_SIZE  >> 1);
    wire [9:0] pad_l_center_y = paddle_left_y  + (`PADDLE_H >> 1);
    wire [9:0] pad_r_center_y = paddle_right_y + (`PADDLE_H >> 1);

    // ------------------------------------------------------------------------
    // AI paddle control
    // ------------------------------------------------------------------------
    wire ai_right_up, ai_right_down;
    wire ball_toward_ai = ball_dx > 0;  // signed: positive = moving right
    ai_paddle u_ai (
        .clk            (clk),
        .rst_n          (rst_n),
        .game_tick      (game_tick),
        .ball_y         (ball_y),
        .paddle_y       (paddle_right_y),
        .ball_toward_ai (ball_toward_ai),
        .move_up        (ai_right_up),
        .move_down      (ai_right_down)
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
            2'b11: ball_speed_idx = 3'd0;  // Auto (speed controlled by auto_threshold)
            default: ball_speed_idx = 3'd1;
        endcase
    end

    // ------------------------------------------------------------------------
    // Paddle speed selection (scales with difficulty)
    // Easy(60Hz)=6→360, Hard(120Hz)=4→480, Master(180Hz)=3→540, Auto(start)=6→360
    // ------------------------------------------------------------------------
    reg [2:0] paddle_speed;

    always @* begin
        case (difficulty)
            2'b00: paddle_speed = 3'd6;  // Easy:   60 Hz × 6 = 360 px/s
            2'b01: paddle_speed = 3'd4;  // Hard:  120 Hz × 4 = 480 px/s
            2'b10: paddle_speed = 3'd3;  // Master: 180 Hz × 3 = 540 px/s
            2'b11: paddle_speed = 3'd6;  // Auto:   starts at 60 Hz × 6
            default: paddle_speed = 3'd6;
        endcase
    end

    // ------------------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------------------
    reg  [2:0]  next_state;
    reg  [3:0]  next_score_left, next_score_right;
    reg  [9:0]  next_ball_x, next_ball_y;
    reg  [9:0]  next_paddle_left_y, next_paddle_right_y;
    reg signed  [10:0] ball_dx, ball_dy;  // signed velocity
    reg  [19:0] score_timer;              // delay after scoring
    reg  [19:0] serve_timer;              // delay before auto-serve
    reg         start_pause_d;           // delayed copy for edge detection
    reg  [15:0] rand_cnt;                // free-running counter for serve random
    reg         hit_paddle_this;          // pulsed if paddle hit in this tick

    // Velocity lookup table registers (combinational outputs)
    reg signed  [3:0]  angle_index;      // angle index (-4..+4) for lookup
    reg         [2:0]  vel_dx_mag;       // dx magnitude from lookup
    reg signed  [10:0] vel_dy;           // dy from lookup
    reg  [18:0] auto_threshold;         // auto-mode speed, decreases per hit

    // ------------------------------------------------------------------------
    // Velocity lookup table: angle-index -> (dx_mag, dy)   with |V|≈5
    // Keeps total speed approximately constant regardless of angle.
    // ------------------------------------------------------------------------
    always @* begin
        case (angle_index)
            -4'sd4: begin vel_dx_mag = 3'd3; vel_dy = -11'sd4; end  // steep up
            -4'sd3: begin vel_dx_mag = 3'd4; vel_dy = -11'sd3; end  // medium up
            -4'sd2: begin vel_dx_mag = 3'd4; vel_dy = -11'sd2; end  // mild up
            -4'sd1: begin vel_dx_mag = 3'd5; vel_dy = -11'sd1; end  // slight up
             4'sd0: begin vel_dx_mag = 3'd5; vel_dy =  11'sd0; end  // horizontal
             4'sd1: begin vel_dx_mag = 3'd5; vel_dy =  11'sd1; end  // slight down
             4'sd2: begin vel_dx_mag = 3'd4; vel_dy =  11'sd2; end  // mild down
             4'sd3: begin vel_dx_mag = 3'd4; vel_dy =  11'sd3; end  // medium down
             4'sd4: begin vel_dx_mag = 3'd3; vel_dy =  11'sd4; end  // steep down
            default: begin vel_dx_mag = 3'd5; vel_dy =  11'sd0; end
        endcase
    end

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
            paddle_left_y   <= 10'd240 - (`PADDLE_H / 2);
            paddle_right_y  <= 10'd240 - (`PADDLE_H / 2);
            ball_dx         <= 1;
            ball_dy         <= 0;
            serve_side      <= 1'b0;
            score_timer     <= 20'd0;
            serve_timer     <= 20'd0;
            start_pause_d   <= 1'b0;
            rand_cnt        <= 16'd0;
            tick_threshold  <= `TICK_THRESH_SPEED1;
            auto_threshold  <= `TICK_THRESH_SPEED1;
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
                        next_score_left  = 4'd0;
                        next_score_right = 4'd0;
                        serve_side      <= 1'b0;
                        serve_timer     <= 20'd0;
                        auto_threshold  <= `TICK_THRESH_SPEED1;
                        next_state       = S_SERVE;
                    end else begin
                        next_state = S_IDLE;
                    end
                end

                // ------- SERVE -------
                S_SERVE: begin
                    if (serve_timer == 20'd0) begin
                        next_ball_x = 10'd320 - (`BALL_SIZE / 2);
                        next_ball_y = 10'd240 - (`BALL_SIZE / 2);

                        // Serve: random angle from 7 options, |V|≈5 constant
                        case (rand_cnt[5:3])
                            3'd0: angle_index =  4'sd0;   // horizontal
                            3'd1: angle_index =  4'sd1;   // slight down
                            3'd2: angle_index = -4'sd1;   // slight up
                            3'd3: angle_index =  4'sd2;   // mild down
                            3'd4: angle_index = -4'sd2;   // mild up
                            3'd5: angle_index =  4'sd3;   // medium down
                            3'd6: angle_index = -4'sd3;   // medium up
                            3'd7: angle_index =  4'sd0;   // horizontal (extra)
                        endcase
                        if (serve_side == 1'b0)
                            ball_dx <= $signed({1'b0, vel_dx_mag});   // right
                        else
                            ball_dx <= -$signed({1'b0, vel_dx_mag});  // left
                        ball_dy <= vel_dy;

                        // Update tick threshold for this round
                        if (difficulty == 2'b11)
                            tick_threshold <= auto_threshold;
                        else
                            case (ball_speed_idx)
                                3'd1: tick_threshold <= `TICK_THRESH_SPEED1;
                                3'd2: tick_threshold <= `TICK_THRESH_SPEED2;
                                3'd3: tick_threshold <= `TICK_THRESH_SPEED3;
                                default: tick_threshold <= `TICK_THRESH_SPEED1;
                            endcase
                    end

                    if (serve_timer < `SERVE_TIMEOUT)
                        serve_timer <= serve_timer + 1;

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
                    if (start_pause && !start_pause_d) begin
                        next_state = S_PAUSE;
                    end else begin
                        // --- Paddle movement (constant effective speed across difficulties) ---
                        if (left_up && (paddle_left_y > `PADDLE_MIN_Y))
                            next_paddle_left_y = paddle_left_y - paddle_speed;
                        else if (left_down && (paddle_left_y < `PADDLE_MAX_Y))
                            next_paddle_left_y = paddle_left_y + paddle_speed;
                        else
                            next_paddle_left_y = paddle_left_y;
                        
                        if (right_up_sel && (paddle_right_y > `PADDLE_MIN_Y))
                            next_paddle_right_y = paddle_right_y - paddle_speed;
                        else if (right_down_sel && (paddle_right_y < `PADDLE_MAX_Y))
                            next_paddle_right_y = paddle_right_y + paddle_speed;
                        else
                            next_paddle_right_y = paddle_right_y;

                        // --- Ball movement ---
                        next_ball_x = next_x_s[9:0];
                        next_ball_y = next_y_s[9:0];

                        // --- Top/Bottom boundary bounce ---
                        if (next_y_s <= 11'sd0) begin
                            next_ball_y = `BALL_MIN_Y;
                            ball_dy <= -ball_dy;
                        end else if (next_y_s >= 11'sd464) begin
                            next_ball_y = `SCREEN_H - `BALL_SIZE - `BALL_SIZE;
                            ball_dy <= -ball_dy;
                        end

                        hit_paddle_this = 1'b0;

                        // --- Left paddle collision ---
                        if ((next_x_s <= 11'sd30) &&
                            (next_x_s + 11'sd8 >= 11'sd20) &&
                            (next_y_s + 11'sd8 > $signed({1'b0, paddle_left_y})) &&
                            (next_y_s < $signed({1'b0, paddle_left_y}) + 11'sd80)) begin
                            hit_paddle_this   = 1'b1;
                            next_ball_x       = `LEFT_PADDLE_X + `PADDLE_W;
                            hit_paddle        <= 1'b1;

                            // Angle from hit offset -> constant-speed velocity (reduced range)
                            if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_l_center_y}) > 11'sd20)
                                angle_index =  4'sd2;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_l_center_y}) > 11'sd5)
                                angle_index =  4'sd1;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_l_center_y}) > -11'sd5)
                                angle_index =  4'sd0;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_l_center_y}) > -11'sd20)
                                angle_index = -4'sd1;
                            else
                                angle_index = -4'sd2;

                            ball_dx <=  $signed({1'b0, vel_dx_mag});  // bounce right
                            ball_dy <=  vel_dy;

                            // Auto mode: speed ×1.1 per paddle hit
                            if (difficulty == 2'b11)
                                auto_threshold <= ({4'd0, auto_threshold} * 5'd10) / 5'd11;
                        end

                        // --- Right paddle collision ---
                        if ((next_x_s + 11'sd8 >= 11'sd610) &&
                            (next_x_s <= 11'sd620) &&
                            (next_y_s + 11'sd8 > $signed({1'b0, paddle_right_y})) &&
                            (next_y_s < $signed({1'b0, paddle_right_y}) + 11'sd80)) begin
                            hit_paddle_this   = 1'b1;
                            next_ball_x       = `RIGHT_PADDLE_X - `BALL_SIZE;
                            hit_paddle        <= 1'b1;

                            // Angle from hit offset -> constant-speed velocity (reduced range)
                            if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_r_center_y}) > 11'sd20)
                                angle_index =  4'sd2;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_r_center_y}) > 11'sd5)
                                angle_index =  4'sd1;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_r_center_y}) > -11'sd5)
                                angle_index =  4'sd0;
                            else if ($signed({1'b0, ball_center_y}) - $signed({1'b0, pad_r_center_y}) > -11'sd20)
                                angle_index = -4'sd1;
                            else
                                angle_index = -4'sd2;

                            ball_dx <= -$signed({1'b0, vel_dx_mag});  // bounce left
                            ball_dy <=  vel_dy;

                            // Auto mode: speed ×1.1 per paddle hit
                            if (difficulty == 2'b11)
                                auto_threshold <= ({4'd0, auto_threshold} * 5'd10) / 5'd11;
                        end

                        // --- Score detection ---
                        if (!hit_paddle_this) begin
                            if (next_x_s <= 11'sd0) begin
                                next_score_right = score_right + 1;
                                score_event <= 1'b1;
                                if (next_score_right == `MAX_SCORE) begin
                                    next_state = S_OVER;
                                end else begin
                                    serve_side <= 1'b0;
                                    next_state = S_SCORE;
                                end
                            end else if (next_x_s + 11'sd8 >= 11'sd640) begin
                                next_score_left = score_left + 1;
                                score_event <= 1'b1;
                                if (next_score_left == `MAX_SCORE) begin
                                    next_state = S_OVER;
                                end else begin
                                    serve_side <= 1'b1;
                                    next_state = S_SCORE;
                                end
                            end else begin
                                next_state = S_PLAY;
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
                        serve_timer <= 20'd0;
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
                        next_score_left  = 4'd0;
                        next_score_right = 4'd0;
                        next_state = S_IDLE;
                    end else begin
                        next_state = S_OVER;
                    end
                end

                default: next_state = S_IDLE;
            endcase

            // Register updates
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
