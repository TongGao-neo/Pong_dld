// ============================================================================
// seg_display.v - 4-digit 7-segment display driver (common anode)
// Displays difficulty: EASy, HArd, mSt (half-n halves), AUtO
// ============================================================================

`include "defines.vh"

module seg_display (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  difficulty,
    output reg  [3:0]  AN,
    output reg  [7:0]  SEGMENT
);

    // ------------------------------------------------------------------------
    // Digit decoding (active low for common anode)
    // SEGMENT mapping: {dp, g, f, e, d, c, b, a}
    // ------------------------------------------------------------------------
    localparam SEG_OFF = 8'b11111111;

    // Letter segments (common anode, 0=ON)
    localparam SEG_E   = 8'b10000110;  // a,d,e,f,g
    localparam SEG_A   = 8'b10001000;  // a,b,c,e,f,g
    localparam SEG_S   = 8'b10010010;  // a,c,d,f,g
    localparam SEG_y   = 8'b10010001;  // b,c,d,f,g
    localparam SEG_H   = 8'b10001001;  // b,c,e,f,g
    localparam SEG_r   = 8'b10001111;  // f,e,g
    localparam SEG_d   = 8'b10100001;  // b,c,d,e,g
    localparam SEG_t   = 8'b10000111;  // d,e,f,g
    localparam SEG_U   = 8'b11000001;  // b,c,d,e,f
    localparam SEG_O   = 8'b11000000;  // a,b,c,d,e,f
    localparam SEG_nL  = 8'b10101111;  // e,g (left half of n)
    localparam SEG_nR  = 8'b10111001;  // b,c,g (right half of n)

    // ------------------------------------------------------------------------
    // Character lookup
    // ------------------------------------------------------------------------
    function [7:0] char_at;
        input [1:0] diff;
        input [1:0] pos;  // 0=rightmost, 3=leftmost
        case (diff)
            2'b00: begin  // EASy
                case (pos)
                    2'd0: char_at = SEG_y;
                    2'd1: char_at = SEG_S;
                    2'd2: char_at = SEG_A;
                    2'd3: char_at = SEG_E;
                    default: char_at = SEG_OFF;
                endcase
            end
            2'b01: begin  // HArd
                case (pos)
                    2'd0: char_at = SEG_d;
                    2'd1: char_at = SEG_r;
                    2'd2: char_at = SEG_A;
                    2'd3: char_at = SEG_H;
                    default: char_at = SEG_OFF;
                endcase
            end
            2'b10: begin  // mSt (left half-n + right half-n)
                case (pos)
                    2'd0: char_at = SEG_t;
                    2'd1: char_at = SEG_S;
                    2'd2: char_at = SEG_nR;
                    2'd3: char_at = SEG_nL;
                    default: char_at = SEG_OFF;
                endcase
            end
            2'b11: begin  // AUtO
                case (pos)
                    2'd0: char_at = SEG_O;
                    2'd1: char_at = SEG_t;
                    2'd2: char_at = SEG_U;
                    2'd3: char_at = SEG_A;
                    default: char_at = SEG_OFF;
                endcase
            end
            default: char_at = SEG_OFF;
        endcase
    endfunction

    // ------------------------------------------------------------------------
    // Scan timing (4 kHz refresh)
    // ------------------------------------------------------------------------
    reg [12:0] scan_counter;
    wire scan_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_counter <= 13'd0;
        else if (scan_counter == `SCAN_MAX)
            scan_counter <= 13'd0;
        else
            scan_counter <= scan_counter + 1;
    end
    assign scan_tick = (scan_counter == `SCAN_MAX);

    // ------------------------------------------------------------------------
    // Digit multiplexing
    // ------------------------------------------------------------------------
    reg [1:0] digit_sel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_sel <= 2'd0;
            AN        <= 4'b1111;
            SEGMENT   <= 8'hFF;
        end else if (scan_tick) begin
            digit_sel <= digit_sel + 1;
            case (digit_sel)
                2'd0: begin  // Leftmost digit (AN[3]=0)
                    AN <= 4'b1110;
                    SEGMENT <= char_at(difficulty, 2'd0);
                end
                2'd1: begin
                    AN <= 4'b1101;
                    SEGMENT <= char_at(difficulty, 2'd1);
                end
                2'd2: begin
                    AN <= 4'b1011;
                    SEGMENT <= char_at(difficulty, 2'd2);
                end
                2'd3: begin  // Rightmost digit (AN[0]=0)
                    AN <= 4'b0111;
                    SEGMENT <= char_at(difficulty, 2'd3);
                end
            endcase
        end
    end

endmodule
