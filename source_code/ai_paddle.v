// ============================================================================
// ai_paddle.v - Simple AI opponent for Pong
// Tracks the ball's Y coordinate with a dead zone and limited speed
// ============================================================================

module ai_paddle (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  ball_y,
    input  wire [8:0]  paddle_y,        // current center Y of AI paddle
    output reg         move_up,
    output reg         move_down
);

    // Dead zone: if the difference is less than this, stop moving
    localparam DEAD_ZONE = 4;
    // Average the ball position (center of ball)
    wire [9:0] ball_center_y = ball_y + (`BALL_SIZE / 2);
    wire [9:0] paddle_center_y = paddle_y + (`PADDLE_H / 2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            move_up   <= 1'b0;
            move_down <= 1'b0;
        end else begin
            // Simple proportional control with dead zone
            if (ball_center_y < paddle_center_y - DEAD_ZONE) begin
                move_up   <= 1'b1;
                move_down <= 1'b0;
            end else if (ball_center_y > paddle_center_y + DEAD_ZONE) begin
                move_up   <= 1'b0;
                move_down <= 1'b1;
            end else begin
                move_up   <= 1'b0;
                move_down <= 1'b0;
            end
        end
    end

endmodule