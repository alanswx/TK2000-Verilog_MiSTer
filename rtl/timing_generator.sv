//
// Multicore 2 / Multicore 2+
//
// Copyright (c) 2017-2020 - Victor Trucco
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// You are responsible for any legal issues arising from your use of this code.
//
///////////////////////////////////////////////////////////////////////////////
//
// Apple ][ Timing logic
//
// Stephen A. Edwards, sedwards@cs.columbia.edu
//
// Taken more-or-less verbatim from the schematics in the
// Apple ][ reference manual
//
// This takes a 14.31818 MHz master clock and divides it down to generate
// the various lower-frequency signals (e.g., 7M, phase 0, colorburst)
// as well as horizontal and vertical blanking and sync signals for the video
// and the video addresses.
//
///////////////////////////////////////////////////////////////////////////////

module timing_generator (
    input wire clock_14_i,              // 14.31818 MHz master clock
    output reg clock_7_o = 1'b0,
    output reg q3_o = 1'b0,             // 2 MHz signal in phase with PHI0
    output reg ras_n_o = 1'b0,
    output reg cas_n_o = 1'b0,
    output reg ax_o = 1'b0,
    output reg phi0_o = 1'b0,           // phase 0
    output reg phi1_o = 1'b0,           // phase 1
    output reg phi2_o = 1'b0,           // phase 2 (renamed from phi1_o in VHDL for clarity)
    output reg color_ref_o = 1'b0,      // 3.579545 MHz colorburst

    input wire page2_i,

    output wire [15:0] video_addr_o,
    output wire [6:0] h_count_o,
    output wire va_o,                   // Character row address
    output wire vb_o,
    output wire vc_o,
    output wire [5:0] v_count_o,
    output reg hbl_o,                   // Horizontal blanking
    output reg vbl_o,                   // Vertical blanking
    output reg blank_o,                 // Composite blanking
    output reg ld194_o                  // Load graph data
);

    reg [6:0] H_s = 7'b0000000;
    reg [8:0] V_s = 9'b011111010;
    reg [15:0] video_addr_s;
    reg COLOR_DELAY_N_s = 1'b0;
    reg clk7_s = 1'b0;
    reg q3_s = 1'b0;
    reg ras_n_s = 1'b0;
    reg cas_n_s = 1'b0;
    reg ax_s = 1'b0;
    reg phi0_s = 1'b0;
    reg phi2_s_internal = 1'b0; // Renamed to avoid conflict with output phi2_o
    reg color_ref_s = 1'b0;
    reg hbl_s = 1'b0;
    reg vbl_s = 1'b0;

    // To generate the once-a-line hiccup: D1 pin 6
    assign COLOR_DELAY_N_s = ~((~color_ref_s) & (~ax_s & ~cas_n_s) & phi2_s_internal & (~H_s[6]));

    // The DRAM signal generator
    always @(posedge clock_14_i) begin
        if (q3_s == 1'b1) begin          // shift
            {q3_s, cas_n_s, ax_s, ras_n_s} <= {cas_n_s, ax_s, ras_n_s, 1'b0};
        end else begin                   // load
            {q3_s, cas_n_s, ax_s, ras_n_s} <= {ras_n_s, ax_s, COLOR_DELAY_N_s, ax_s};
        end
    end

    assign q3_o = q3_s;
    assign ras_n_o = ras_n_s;
    assign cas_n_o = cas_n_s;
    assign ax_o = ax_s;

    // The main clock signal generator
    always @(posedge clock_14_i) begin
        color_ref_s <= clk7_s ^ color_ref_s;
        clk7_s <= ~clk7_s;
        phi2_s_internal <= phi0_s;
        if (ax_s == 1'b1) begin
            phi0_s <= ~(q3_s ^ phi2_s_internal);  // B1 pin 10
        end
    end

    assign clock_7_o = clk7_s;
    assign phi0_o = phi0_s;
    assign phi1_o = ~phi2_s_internal; // phi1_o is the inverse of phi2
    assign phi2_o = phi2_s_internal;  // Output phi2 is internal phi2_s_internal
    assign color_ref_o = color_ref_s;
    assign ld194_o = ~((phi2_s_internal) & (~ax_s) & (~cas_n_s) & (~clk7_s));

    // Four four-bit presettable binary counters
    // Seven-bit horizontal counter counts 0, 40, 41, ..., 7F (65 states)
    // Nine-bit vertical counter counts $FA .. $1FF  (262 states)
    always @(posedge clock_14_i) begin
        // True the cycle before the rising edge of LDPS_N: emulates
        // the effects of using LDPS_N as the clock for the video counters
        if ((phi2_s_internal & ~ax_s & ((q3_s & ras_n_s) | (~q3_s & COLOR_DELAY_N_s))) == 1'b1) begin
            if (H_s[6] == 1'b0) begin
                H_s <= 7'b1000000;
            end else begin
                H_s <= H_s + 2'b01;
                if (H_s == 7'b1111111) begin
                    V_s <= V_s + 2'b01;
                    if (V_s == 9'b111111111) begin
                        V_s <= 9'b011111010;
                    end
                end
            end
        end
    end

    assign h_count_o = H_s;
    assign va_o = V_s[0];
    assign vb_o = V_s[1];
    assign vc_o = V_s[2];
    assign v_count_o = V_s[8:3];

    always @(*) begin // Combinational logic for HBL and VBL
        hbl_s = ~((H_s[5]) | (H_s[3] & H_s[4]));
        vbl_s = V_s[6] & V_s[7];
        blank_o = hbl_s | vbl_s;
        hbl_o = hbl_s;
        vbl_o = vbl_s;
    end

    // Video address calculation
    always @(*) begin // Combinational logic for video_addr_s
        reg [3:0] term1, term2, term3;
        video_addr_s[15] = page2_i;                 // 2000 or A000
        video_addr_s[14:13] = 2'b01;
        video_addr_s[12:10] = V_s[2:0];
        video_addr_s[9:7] = V_s[5:3];
        // ... (other video_addr_s assignments)

        // Ensure each term is treated as a 4-bit number for addition

        // Term 1: (not H_s(5) & V_s(6) & H_s(4) & H_s(3))
        term1 = {~H_s[5], V_s[6], H_s[4], H_s[3]};

        // Term 2: (V_s(7) & not H_s(5) & V_s(7) & '1')
        term2 = {V_s[7], ~H_s[5], V_s[7], 1'b1};

        // Term 3: ("000" & V_s(6))
        // This means V_s(6) followed by three '0's. E.g., if V_s(6) is '1', this is "1000" (8)
        //term3 = {V_s[6], 3'b000}; // This is the corrected interpretation
        term3 = {3'b000, V_s[6]}; // This is the corrected interpretation

        // Sum the terms and assign to video_addr_s[6:3]
        // Use a wider temporary register if there's a possibility of overflow
        // for these intermediate sums before truncating to 4 bits.
        // The maximum value for each 4-bit term is 15. Max sum = 15+15+15 = 45.
        // A 6-bit register (max 63) is sufficient to hold the sum before truncation.
        video_addr_s[6:3] = (term1 + term2 + term3); // The result will be implicitly truncated to 4 bits

        video_addr_s[2:0] = H_s[2:0];
    end


    assign video_addr_o = video_addr_s;

endmodule
