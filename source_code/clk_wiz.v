// ============================================================================
// clk_wiz.v - MMCM wrapper for 100 MHz to 25.175 MHz
// ============================================================================

module clk_wiz (
    input  wire  clk_in1,     // 100 MHz
    input  wire  reset,       // MMCM reset (from SW[0])
    output wire  clk_out1,    // 25.175 MHz
    output wire  locked       // PLL locked
);

    //----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG

    clk_wiz_0 u_clk_wiz_0
    (
        // Clock out ports
        .clk_out1(clk_out1),     // output clk_out1
        // Status and control signals
        .reset(reset), // input reset
        .locked(locked),       // output locked
    // Clock in ports
        .clk_in1(clk_in1));      // input clk_in1

    // INST_TAG_END ------ End INSTANTIATION Template ---------

endmodule
