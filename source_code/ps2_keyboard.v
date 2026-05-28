// ============================================================================
// ps2_keyboard.v - PS/2 keyboard receiver for Pong controls
//   Recognizes W/S for left paddle, Up/Down arrows for right paddle,
//   and Enter for start/pause.
//   Based on the edge-detection method from Pan's code.
// ============================================================================

module ps2_keyboard (
    input  wire  clk,          // 25.175 MHz
    input  wire  rst_n,
    inout  wire  PS2_clk,
    inout  wire  PS2_data,
    output reg   left_up,
    output reg   left_down,
    output reg   right_up,
    output reg   right_down,
    output reg   start_pause
);

    // ------------------------------------------------------------------------
    // Synchronize and detect falling edge of PS2 clock
    // ------------------------------------------------------------------------
    reg ps2_clk_s0, ps2_clk_s1, ps2_clk_s2;
    wire neg_edge_ps2_clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_s0 <= 1'b1;
            ps2_clk_s1 <= 1'b1;
            ps2_clk_s2 <= 1'b1;
        end else begin
            ps2_clk_s0 <= PS2_clk;
            ps2_clk_s1 <= ps2_clk_s0;
            ps2_clk_s2 <= ps2_clk_s1;
        end
    end
    assign neg_edge_ps2_clk = !ps2_clk_s1 && ps2_clk_s2;

    // Also synchronize data line (only used when clock falls)
    reg ps2_data_s;
    always @(posedge clk) begin
        ps2_data_s <= PS2_data;
    end

    // ------------------------------------------------------------------------
    // Bit reception state machine
    // ------------------------------------------------------------------------
    reg [3:0] bit_cnt;       // counts bits 0..10
    reg [7:0] shift_reg;     // shift register to capture data bits
    reg       frame_done;    // pulse when 11 bits received

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 4'd0;
            shift_reg <= 8'd0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;  // default pulse low

            if (neg_edge_ps2_clk) begin
                case (bit_cnt)
                    4'd0:  bit_cnt <= bit_cnt + 1;    // start bit, ignore
                    4'd1:  begin shift_reg[0] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd2:  begin shift_reg[1] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd3:  begin shift_reg[2] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd4:  begin shift_reg[3] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd5:  begin shift_reg[4] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd6:  begin shift_reg[5] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd7:  begin shift_reg[6] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd8:  begin shift_reg[7] <= ps2_data_s; bit_cnt <= bit_cnt + 1; end
                    4'd9:  begin bit_cnt <= bit_cnt + 1; end  // parity, ignore
                    4'd10: begin
                        // stop bit, frame complete
                        frame_done <= 1'b1;
                        bit_cnt <= 4'd0;
                    end
                    default: bit_cnt <= 4'd0;
                endcase
            end
        end
    end

    // ------------------------------------------------------------------------
    // Decode scan codes (with E0 and F0 handling)
    // ------------------------------------------------------------------------
    reg        is_extended;     // E0 received
    reg        is_break;        // F0 received
    reg        is_break_latched;// captured is_break when key code arrives
    reg [7:0]  key_make_code;   // latched make code for multi-byte sequences
    reg        key_valid;       // pulse when a valid make/break is decoded

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_extended <= 1'b0;
            is_break    <= 1'b0;
            is_break_latched <= 1'b0;
            key_make_code <= 8'd0;
            key_valid   <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            if (frame_done) begin
                if (shift_reg == 8'hE0) begin
                    is_extended <= 1'b1;
                end else if (shift_reg == 8'hF0) begin
                    is_break <= 1'b1;
                end else begin
                    // This is a key code
                    is_break_latched <= is_break; // capture before clear
                    if (is_break) begin
                        // Break code: release
                        // is_extended preserved
                        key_make_code <= shift_reg;
                        key_valid <= 1'b1;
                        is_break <= 1'b0;
                    end else begin
                        // Make code
                        key_make_code <= shift_reg;
                        key_valid <= 1'b1;
                        // is_extended might be cleared after use
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Update paddle/start signals based on make/break events
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_up     <= 1'b0;
            left_down   <= 1'b0;
            right_up    <= 1'b0;
            right_down  <= 1'b0;
            start_pause <= 1'b0;
        end else if (key_valid) begin
            // Extended keys (arrows) have E0 prefix, others not
            if (is_extended) begin
                case (key_make_code)
                    8'h75: right_up   <= !is_break_latched;   // Up arrow
                    8'h72: right_down <= !is_break_latched;   // Down arrow
                    8'h6B: left_up    <= !is_break_latched;   // Left arrow (we use as left_up? No, we want W/S for left)
                    // We'll map left_up/down to W/S (not extended)
                    // For arrows, we just map to right paddle
                endcase
            end else begin
                case (key_make_code)
                    8'h1D: left_up    <= !is_break_latched;   // W
                    8'h1B: left_down  <= !is_break_latched;   // S
                    8'h5A: start_pause <= !is_break_latched;  // Enter
                endcase
            end
            is_extended <= 1'b0;   // clear after each key event
        end
    end

endmodule