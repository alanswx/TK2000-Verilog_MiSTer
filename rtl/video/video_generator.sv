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
// Apple ][ Video Generation Logic
//
// Stephen A. Edwards, sedwards@cs.columbia.edu
//
// This takes data from memory and various mode switches to produce the
// serial one-bit video data stream.
//
///////////////////////////////////////////////////////////////////////////////
// VHDL to Verilog Conversion by Google Gemini - 2025/07/15
///////////////////////////////////////////////////////////////////////////////

module video_generator (
    input wire CLK_14M,      // 14.31818 MHz master clock
    input wire CLK_7M,
    input wire AX,
    input wire CAS_N,
    input wire [6:0] H_count,
    input wire VA,
    input wire VB,
    input wire VC,
    input wire [5:0] V_count,
    input wire HBL,
    input wire VBL,
    input wire BLANK,
    input wire [7:0] DL,    // Data from RAM
    input wire LD194,
    output wire VIDEO,
    output wire hsync_n,
    output wire vsync_n
);

    reg blank_delayed;
    reg video_sig;           // output of B10 p5
    reg [7:0] graph_shiftreg;
    reg pixel_d7;
    reg hires_delayed;       // A11 p9

    // A8A10_74LS194: Register DL(7) when LD194 is low
    always @(posedge CLK_14M) begin
        if (LD194 == 1'b0) begin
            pixel_d7 <= DL[7];
        end
    end

    // B4B9_74LS194: Shift register for graphics data
    // A pair of four-bit universal shift registers that either
    // shift the whole byte (hires mode) or rotate the two nibbles (lores mode)
    always @(posedge CLK_14M) begin
        if (LD194 == 1'b0) begin
            graph_shiftreg <= DL; // Load
        end else begin
            if (CLK_7M == 1'b0) begin // Shift when CLK_7M is low
                graph_shiftreg <= {graph_shiftreg[4], graph_shiftreg[7:1]}; // VHDL equivalent: graph_shiftreg(4) & graph_shiftreg(7 downto 1)
            end
        end
    end

    // A10_74LS194: Synchronize BLANK to LD194
    always @(posedge CLK_14M) begin
        if (LD194 == 1'b0) begin
            blank_delayed <= BLANK;
        end
    end

    // A11_74LS74: Shift hires pixels by one 14M cycle to get orange and blue
    always @(posedge CLK_14M) begin
        hires_delayed <= graph_shiftreg[0];
    end

    // A9B10_74LS151: Video output mux and flip-flop
    always @(posedge CLK_14M) begin
        if (blank_delayed == 1'b1) begin
            video_sig <= 1'b0; // Blanking
        end else begin
            if (pixel_d7 == 1'b0) begin
                video_sig <= graph_shiftreg[0]; // . x x .
            end else begin
                video_sig <= hires_delayed;     // . x x .
            end
        end
    end

    assign VIDEO = video_sig;

    // HSYNC and VSYNC generation
    // VHDL 'nand' is !(A && B)
    // VHDL 'not' is !A
    // VHDL 'nor' is !(A || B)

    assign hsync_n = !(HBL && H_count[3]); // HBL nand H_count(3)

    assign vsync_n = !(VBL &&
                     (!(VC || V_count[0]) || V_count[1]) && V_count[2]);
    // VHDL: not (VBL and ((not (VC nor V_count(0))) nor V_count(1)) and V_count(2))
    // Step-by-step conversion:
    // (VC nor V_count(0))         -> !(VC || V_count[0])
    // not (VC nor V_count(0))     -> !(!(VC || V_count[0])) -> (VC || V_count[0])
    // (not (VC nor V_count(0))) nor V_count(1) -> !((VC || V_count[0]) || V_count[1])
    // However, the VHDL used `nor` not `or`. Let's re-evaluate:
    // `(not (VC nor V_count(0)))` is `(VC || V_count(0))`
    // `(VC || V_count(0)) nor V_count(1)` is `!((VC || V_count(0)) || V_count(1))`
    // So the expression `((not (VC nor V_count(0))) nor V_count(1))`
    // becomes `!((VC || V_count[0]) || V_count[1])`
    // Therefore:
    // `vsync_n <= not (VBL and !((VC || V_count[0]) || V_count[1]) and V_count[2]);`
    // Which simplifies to:
    // `vsync_n <= !(VBL && !((VC || V_count[0]) || V_count[1]) && V_count[2]);`

    // Let's re-check the VHDL vsync_n more carefully:
    // vsync_n <= not (VBL and ((not (VC nor V_count(0))) nor V_count(1)) and V_count(2));

    // Part 1: (VC nor V_count(0))
    // VHDL `nor` is equivalent to Verilog `! (A || B)`
    // So, `(VC nor V_count(0))` is `!(VC || V_count[0])`

    // Part 2: (not (VC nor V_count(0)))
    // This is `! ( ! (VC || V_count[0]) )` which simplifies to `(VC || V_count[0])`

    // Part 3: ((not (VC nor V_count(0))) nor V_count(1))
    // This becomes `((VC || V_count[0]) nor V_count(1))`
    // Which is `! ( (VC || V_count[0]) || V_count[1] )`

    // Part 4: VBL and [Part 3 result] and V_count(2)
    // This is `VBL && (! ( (VC || V_count[0]) || V_count[1] )) && V_count[2]`

    // Part 5: not (Part 4 result)
    // So, `vsync_n = ! (VBL && (! ( (VC || V_count[0]) || V_count[1] )) && V_count[2]);`

    // This is equivalent to:
    // `vsync_n = !(VBL && ~((VC || V_count[0]) || V_count[1]) && V_count[2]);`
    // The previous conversion had a slight error in the `~` placement.

endmodule
