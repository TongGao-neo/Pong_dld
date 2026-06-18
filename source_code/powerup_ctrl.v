// ============================================================================
// powerup_ctrl.v - Wide-paddle powerup controller
//   Spawns a 6x6 diamond-shaped powerup on the left or right paddle lane.
//   Paddle overlap triggers hit_left/hit_right pulse and deactivates powerup.
//   After cooldown, a new powerup spawns at a random Y.
// ============================================================================

`include "defines.vh"

module powerup_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        game_tick,
    //    === No external rand_cnt — internal free-running counter below ===
    input  wire [9:0]  paddle_left_y,
    input  wire [9:0]  paddle_right_y,
    output reg         powerup_active,
    output reg  [9:0]  powerup_x,
    output reg  [9:0]  powerup_y,
    output reg         hit_left,
    output reg         hit_right
);

    // ------------------------------------------------------------------------
    // Timing constants (in game_ticks)
    // ------------------------------------------------------------------------
    localparam LIFETIME       = 150;   // ~2.5 sec at 60 Hz
    localparam COOLDOWN_BASE  = 120;   // ~2.0 sec at 60 Hz

    // ------------------------------------------------------------------------
    // Lane X positions (center of the powerup on each side)
    // ------------------------------------------------------------------------
    localparam LANE_LEFT_X  = `LEFT_PADDLE_X + (`PADDLE_W >> 1);   // 25
    localparam LANE_RIGHT_X = `RIGHT_PADDLE_X + (`PADDLE_W >> 1);  // 615

    // ------------------------------------------------------------------------
    // Powerup size
    // ------------------------------------------------------------------------
    localparam PU_SIZE = 6;

    // ------------------------------------------------------------------------
    // Internal state
    // ------------------------------------------------------------------------
    reg [7:0] lifetime_cnt;      // counts up in ACTIVE state
    reg [7:0] cooldown_cnt;      // counts up in COOLDOWN state
    reg [7:0] cooldown_target;
    reg [15:0] rand_cnt;     // free-running for spawn randomness   // random cooldown duration (latched at enter)
    reg [1:0] state;             // 0=COOLDOWN, 1=ACTIVE

    localparam S_COOLDOWN = 2'd0;
    localparam S_ACTIVE   = 2'd1;

    // ------------------------------------------------------------------------
    // Internal random counter (free-running)
    // ------------------------------------------------------------------------
    reg [15:0] rand_cnt;

    // ------------------------------------------------------------------------
    // State machine
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_COOLDOWN;
            powerup_active  <= 1'b0;
            powerup_x       <= 10'd0;
            powerup_y       <= 10'd0;
            lifetime_cnt    <= 8'd0;
            cooldown_cnt    <= 8'd0;
            cooldown_target <= 8'd0;
            rand_cnt        <= 16'd0;
            hit_left        <= 1'b0;
            hit_right       <= 1'b0;
            rand_cnt        <= 16'd0;
        end else if (game_tick) begin
            rand_cnt <= rand_cnt + 1;   // free-running RNG source
            // Default: pulse low
            hit_left  <= 1'b0;
            hit_right <= 1'b0;

            case (state)

                // ============================================================
                // COOLDOWN — wait before spawning the next powerup
                // ============================================================
                S_COOLDOWN: begin
                    powerup_active <= 1'b0;

                    if (cooldown_target == 8'd0) begin
                        // First entry or just entered cooldown: compute duration
                        cooldown_target <= COOLDOWN_BASE + {2'd0, rand_cnt[5:0]};
                        cooldown_cnt    <= 8'd0;
                    end else if (cooldown_cnt >= cooldown_target) begin
                        // Cooldown expired: spawn new powerup
                        cooldown_target <= 8'd0;
                        cooldown_cnt    <= 8'd0;
                        lifetime_cnt    <= 8'd0;

                        // Pick left or right lane from rand_cnt[0]
                        if (rand_cnt[0]) begin
                            powerup_x <= LANE_RIGHT_X;
                        end else begin
                            powerup_x <= LANE_LEFT_X;
                        end

                        // Random Y: 40 + rand[9:4]*4 → range 40 .. 292
                        powerup_y       <= 10'd40 + {6'd0, rand_cnt[9:4], 2'b00};
                        powerup_active  <= 1'b1;
                        state           <= S_ACTIVE;
                    end else begin
                        cooldown_cnt <= cooldown_cnt + 1;
                    end
                end

                // ============================================================
                // ACTIVE — powerup is visible, check for paddle hit or timeout
                // ============================================================
                S_ACTIVE: begin
                    // Check timeout first
                    if (lifetime_cnt >= LIFETIME - 1) begin
                        // Timed out: no hit, return to cooldown
                        powerup_active  <= 1'b0;
                        cooldown_cnt    <= 8'd0;
                        cooldown_target <= 8'd0;
                        state           <= S_COOLDOWN;
                    end else begin
                        lifetime_cnt <= lifetime_cnt + 1;

                        // --- Paddle collision detection ---
                        // Left lane: powerup_x is 25 (±3), paddle is X=20..30
                        if (powerup_x == LANE_LEFT_X) begin
                            // Y overlap: powerup_y..powerup_y+6 vs paddle_y..paddle_y+80
                            if ((powerup_y + PU_SIZE) > paddle_left_y &&
                                 powerup_y < (paddle_left_y + `PADDLE_H)) begin
                                hit_left        <= 1'b1;
                                powerup_active  <= 1'b0;
                                cooldown_cnt    <= 8'd0;
                                cooldown_target <= 8'd0;
                                state           <= S_COOLDOWN;
                            end
                        end

                        // Right lane: powerup_x is 615 (±3), paddle is X=610..620
                        if (powerup_x == LANE_RIGHT_X) begin
                            if ((powerup_y + PU_SIZE) > paddle_right_y &&
                                 powerup_y < (paddle_right_y + `PADDLE_H)) begin
                                hit_right       <= 1'b1;
                                powerup_active  <= 1'b0;
                                cooldown_cnt    <= 8'd0;
                                cooldown_target <= 8'd0;
                                state           <= S_COOLDOWN;
                            end
                        end
                    end
                end

                default: begin
                    state <= S_COOLDOWN;
                end

            endcase
        end
    end

endmodule
