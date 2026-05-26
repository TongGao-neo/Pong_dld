// ============================================================================
// keypad_scanner.v - 5x4 matrix keyboard scanner with debounce
// Outputs: left_up, left_down, right_up, right_down, start_pause
// ============================================================================

`include "defines.vh"

module keypad_scanner (
    input  wire        clk,          // 25.175 MHz
    input  wire        rst_n,
    output reg  [4:0]  key_row,      // driven low one at a time
    input  wire [3:0]  key_col,      // read with internal pull-up
    output reg         left_up,
    output reg         left_down,
    output reg         right_up,
    output reg         right_down,
    output reg         start_pause
);

    // ------------------------------------------------------------------------
    // Physical key mapping (rows × cols)
    //   Row 0: Left   up / down
    //   Row 1: Right up / down
    //   Row 2: Start/Pause
    //   Row 3: (unused)
    //   Row 4: (unused)
    // Col 0: Up / Start
    // Col 1: Down
    // Col 2-3: (unused)
    // ------------------------------------------------------------------------
    localparam ROW_LEFT   = 3'd0;
    localparam ROW_RIGHT  = 3'd1;
    localparam ROW_START  = 3'd2;

    // ------------------------------------------------------------------------
    // Scan timing: scan each row for ~1 ms -> 5 kHz total scan rate
    // 25.175 MHz / 5000 = 5035 -> use 5035
    // ------------------------------------------------------------------------
    localparam SCAN_DELAY = 5035;    // simulation: 10
    // localparam SCAN_DELAY = 10;

    reg [12:0] scan_cnt;
    wire scan_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_cnt <= 13'd0;
        else if (scan_cnt == SCAN_DELAY - 1)
            scan_cnt <= 13'd0;
        else
            scan_cnt <= scan_cnt + 1;
    end
    assign scan_tick = (scan_cnt == SCAN_DELAY - 1);

    // ------------------------------------------------------------------------
    // Row driver state machine
    // ------------------------------------------------------------------------
    reg [2:0] current_row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_row <= 3'd0;
            key_row <= 5'b11111;      // all rows inactive (high)
        end else if (scan_tick) begin
            // Move to next row
            current_row <= (current_row == 3'd4) ? 3'd0 : current_row + 1;

            // Drive exactly one row low
            case (current_row)
                3'd0: key_row <= 5'b11110;
                3'd1: key_row <= 5'b11101;
                3'd2: key_row <= 5'b11011;
                3'd3: key_row <= 5'b10111;
                3'd4: key_row <= 5'b01111;
                default: key_row <= 5'b11111;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Debounce: 8 consecutive stable readings (~8 ms) required
    // ------------------------------------------------------------------------
    localparam DEBOUNCE_CNT = 8;     // number of matching scans

    // Synchronous column capture
    reg [3:0] col_sync;
    always @(posedge clk) begin
        col_sync <= key_col;         // input already synchronized by IOB flops
    end

    // For each of the 5 keys we need a debounce counter
    reg [2:0] db_cnt_left_up,    db_cnt_left_down;
    reg [2:0] db_cnt_right_up,   db_cnt_right_down;
    reg [2:0] db_cnt_start;

    // Current key states (after debounce)
    reg kp_left_up, kp_left_down, kp_right_up, kp_right_down, kp_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt_left_up   <= 3'd0;
            db_cnt_left_down <= 3'd0;
            db_cnt_right_up  <= 3'd0;
            db_cnt_right_down<= 3'd0;
            db_cnt_start     <= 3'd0;
            kp_left_up       <= 1'b0;
            kp_left_down     <= 1'b0;
            kp_right_up      <= 1'b0;
            kp_right_down    <= 1'b0;
            kp_start         <= 1'b0;
        end else if (scan_tick) begin
            // Only check keys on their respective row
            // Left paddle keys (ROW_LEFT)
            if (current_row == ROW_LEFT) begin
                // Col 0 -> left_up
                if (col_sync[0] == 1'b0) begin
                    if (db_cnt_left_up < DEBOUNCE_CNT)
                        db_cnt_left_up <= db_cnt_left_up + 1;
                end else begin
                    if (db_cnt_left_up > 0)
                        db_cnt_left_up <= db_cnt_left_up - 1;
                end
                // Col 1 -> left_down
                if (col_sync[1] == 1'b0) begin
                    if (db_cnt_left_down < DEBOUNCE_CNT)
                        db_cnt_left_down <= db_cnt_left_down + 1;
                end else begin
                    if (db_cnt_left_down > 0)
                        db_cnt_left_down <= db_cnt_left_down - 1;
                end

                // Update debounced outputs when counter reaches threshold
                kp_left_up   <= (db_cnt_left_up   == DEBOUNCE_CNT) ||
                                ((db_cnt_left_up   == DEBOUNCE_CNT-1) && (col_sync[0] == 1'b0));
                kp_left_down <= (db_cnt_left_down == DEBOUNCE_CNT) ||
                                ((db_cnt_left_down == DEBOUNCE_CNT-1) && (col_sync[1] == 1'b0));
            end

            // Right paddle keys (ROW_RIGHT)
            if (current_row == ROW_RIGHT) begin
                // Col 0 -> right_up
                if (col_sync[0] == 1'b0) begin
                    if (db_cnt_right_up < DEBOUNCE_CNT)
                        db_cnt_right_up <= db_cnt_right_up + 1;
                end else begin
                    if (db_cnt_right_up > 0)
                        db_cnt_right_up <= db_cnt_right_up - 1;
                end
                // Col 1 -> right_down
                if (col_sync[1] == 1'b0) begin
                    if (db_cnt_right_down < DEBOUNCE_CNT)
                        db_cnt_right_down <= db_cnt_right_down + 1;
                end else begin
                    if (db_cnt_right_down > 0)
                        db_cnt_right_down <= db_cnt_right_down - 1;
                end

                kp_right_up   <= (db_cnt_right_up   == DEBOUNCE_CNT) ||
                                 ((db_cnt_right_up   == DEBOUNCE_CNT-1) && (col_sync[0] == 1'b0));
                kp_right_down <= (db_cnt_right_down == DEBOUNCE_CNT) ||
                                 ((db_cnt_right_down == DEBOUNCE_CNT-1) && (col_sync[1] == 1'b0));
            end

            // Start/Pause key (ROW_START, Col 0)
            if (current_row == ROW_START) begin
                if (col_sync[0] == 1'b0) begin
                    if (db_cnt_start < DEBOUNCE_CNT)
                        db_cnt_start <= db_cnt_start + 1;
                end else begin
                    if (db_cnt_start > 0)
                        db_cnt_start <= db_cnt_start - 1;
                end

                kp_start <= (db_cnt_start == DEBOUNCE_CNT) ||
                            ((db_cnt_start == DEBOUNCE_CNT-1) && (col_sync[0] == 1'b0));
            end
        end
    end

    // ------------------------------------------------------------------------
    // Output assignment
    // ------------------------------------------------------------------------
    always @* begin
        left_up     = kp_left_up;
        left_down   = kp_left_down;
        right_up    = kp_right_up;
        right_down  = kp_right_down;
        start_pause = kp_start;
    end

endmodule