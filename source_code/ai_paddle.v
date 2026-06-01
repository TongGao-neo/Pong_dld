// ============================================================================
// ai_paddle.v - Simple AI opponent for Pong
// Tracks the ball's Y coordinate with a dead zone, limited speed,
// and randomized update delay to reduce AI strength.
// ============================================================================

`include "defines.vh"

module ai_paddle (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_tick,
    input  wire [9:0]  ball_y,
    input  wire [8:0]  paddle_y,
    output reg         move_up,
    output reg         move_down
);

    // Center-of-gravity calculations
    wire [9:0] ball_center_y   = ball_y   + (`BALL_SIZE / 2);
    wire [9:0] paddle_center_y = paddle_y + (`PADDLE_H  / 2);

    // ------------------------------------------------------------------------
    // Randomized update delay
    // AI only samples ball position every (AI_UPDATE_BASE + rand) game ticks.
    // Between updates, move_up/move_down hold their last decision.
    // ------------------------------------------------------------------------
    reg [15:0] rand_cnt;       // free-running counter for pseudo-random delay
    reg [3:0]  update_timer;   // counts down each game_tick; update when 0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rand_cnt    <= 16'd0;
            update_timer <= 4'd0;
            move_up     <= 1'b0;
            move_down   <= 1'b0;
        end else if (game_tick) begin
            rand_cnt <= rand_cnt + 1;

            if (update_timer == 4'd0) begin
                // Update AI decision
                if (ball_center_y < paddle_center_y - `AI_DEAD_ZONE) begin
                    move_up   <= 1'b1;
                    move_down <= 1'b0;
                end else if (ball_center_y > paddle_center_y + `AI_DEAD_ZONE) begin
                    move_up   <= 1'b0;
                    move_down <= 1'b1;
                end else begin
                    move_up   <= 1'b0;
                    move_down <= 1'b0;
                end

                // Reload timer with base + pseudo-random offset
                update_timer <= `AI_UPDATE_BASE + rand_cnt[2:0];
            end else begin
                // Count down each game tick
                update_timer <= update_timer - 1;
            end
        end
    end

endmodule
