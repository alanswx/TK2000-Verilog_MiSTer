`default_nettype none

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

//
//
//
// fase 0         ___|----|____|----|____|-----
// fase 1         ----|____|----|____|----|____
// fase 2         ____|----|____|----|____|----
// Clock Q3       --|_|--|_|--|_|--|_|--|_|--|_
// R/W da CPU
// Address bus    ---------X---------X---------
// Dados capt     ---O---------O---------O-----
// CPU Dout       -------O-X-------O-X-------O-
// IO & DevSel    ---------X---------X---------

module tk2000 (
    input wire clock_14_i,
    input wire reset_i,
    input wire CPU_WAIT,
    // RAM da CPU
    output reg [15:0] ram_addr_o,
    output [7:0] ram_data_to_o,
    input wire [7:0] ram_data_from_i,
    output ram_oe_o,
    output ram_we_o,
    // ROM
    output [13:0] rom_addr_o,
    input wire [7:0] rom_data_from_i,
    output rom_oe_o,
    output rom_we_o,
    // Keyboard
    output reg [7:0] kbd_rows_o,
    input wire [5:0] kbd_cols_i,
    output kbd_ctrl_o,
    // Audio
    output spk_o,
    // Video
    output video_color_o,
    output video_bit_o,
    output video_hsync_n_o,
    output video_vsync_n_o,
    output video_hbl_o,
    output video_vbl_o,
    output video_ld194_o,
    // Cassette
    input wire cas_i,
    output cas_o,
    output [1:0] cas_motor_o,
    // LPT
    output lpt_stb_o,
    input wire lpt_busy_i,
    // Periferico
    output phi0_o,
    output phi1_o,
    output phi2_o,
    output clock_2m_o,
    output read_write_o,
    input wire irq_n_i,
    input wire nmi_n_i,
    input wire dis_rom_i,                  // Se 1 desabilita ROM ou RAM em $C1xx
    output io_select_n_o,              // Sai 0 se dis_rom=1 e acesso em $C1xx
    output dev_select_n_o,             // Sai 0 se acesso em $C09x
    output [7:0] per_addr_o,           // Address bus
    input wire [7:0] per_data_from_i,
    output [7:0] per_data_to_o
);

    // Component declaration (assuming T65, timing_generator, and video_generator are separate modules)
    // You would typically include these modules as separate .v files in your project.

    // T65 CPU
    wire [23:0] cpu_addr_s;
    wire [7:0] cpu_di_s;
    wire [7:0] cpu_dout_s;
    wire cpu_we_s;
    wire r_w_n;

    // Timing
    wire clock_7_s;
    wire clock_q3_s;
    wire t_ras_n_s;
    wire t_cas_n_s;
    wire t_ax_s;
    wire t_phi0_s;
    wire t_phi1_s;
    wire t_phi2_s;

    // Video
    wire [15:0] video_addr_s;
    wire video_hbl_s;
    wire video_vbl_s;
    wire video_blank_s;
    wire [6:0] video_hcount_s;
    wire video_va_s;
    wire video_vb_s;
    wire video_vc_s;
    wire [5:0] video_vcount_s;
    wire video_ld194_s;
    reg [7:0] video_d_latch_s;

    // Control signals
    reg rom_cs_s;
    reg ram_cs_s;
    reg kbd_o_cs_s;
    reg kbd_i_cs_s;
    reg cas_o_cs_s;
    reg speaker_cs_s;
    reg softswitch_cs_s;
    reg [7:0] softswitches_s = 8'b00000000;
    wire ss_color_s;
    wire ss_motorA_s;
    wire ss_page2_s;
    wire ss_motorB_s;
    wire ss_lpt_stb_s;
    wire ss_romram_s;
    wire ss_ctrl_s;
    wire [7:0] kbd_data_s;
    reg io_sel_n_s;
    reg dev_sel_n_s;
    reg speaker_s = 1'b0;
    reg cas_o_s = 1'b0;

    wire CPU_EN;
    reg PHASE_ZERO_D;

    // Instance of T65 CPU
    T65 cpu6502 (
        .Mode       (2'b00),
        .Clk        (clock_14_i),
        .Enable     (CPU_EN && !CPU_WAIT),
        .Res_n (!reset_i),
        .Rdy        (1'b1),
        .Abort_n    (1'b1),
        .SO_n       (1'b1),
        .IRQ_n      (irq_n_i),
        .NMI_n      (nmi_n_i),
        .R_W_n      (r_w_n),
        .A          (cpu_addr_s),
        .DI         (cpu_di_s),
        .DO         (cpu_dout_s)
    );

    assign cpu_we_s = !r_w_n;

    assign CPU_EN = (PHASE_ZERO_D == 1'b1 && t_phi0_s == 1'b0) ? 1'b1 : 1'b0;

    always @(posedge clock_14_i) begin
        PHASE_ZERO_D <= t_phi0_s;
    end

    // Instance of timing_generator
    timing_generator timing (
        .clock_14_i     (clock_14_i),
        .clock_7_o      (clock_7_s),
        .q3_o           (clock_q3_s),
        .ras_n_o        (t_ras_n_s),
        .cas_n_o        (t_cas_n_s),
        .ax_o           (t_ax_s),
        .phi0_o         (t_phi0_s),
        .phi1_o         (t_phi1_s),
        .phi2_o         (t_phi2_s),
        .color_ref_o    (), // Not connected, similar to VHDL 'open'
        .page2_i        (ss_page2_s),
        .video_addr_o   (video_addr_s),
        .h_count_o      (video_hcount_s),
        .va_o           (video_va_s),
        .vb_o           (video_vb_s),
        .vc_o           (video_vc_s),
        .v_count_o      (video_vcount_s),
        .hbl_o          (video_hbl_s),
        .vbl_o          (video_vbl_s),
        .blank_o        (video_blank_s),
        .ld194_o        (video_ld194_s)
    );

    // Instance of video_generator
    video_generator video (
        .CLK_14M    (clock_14_i),
        .CLK_7M     (clock_7_s),
        .AX         (t_ax_s),
        .CAS_N      (t_cas_n_s),
        .H_count    (video_hcount_s),
        .VA         (video_va_s),
        .VB         (video_vb_s),
        .VC         (video_vc_s),
        .V_count    (video_vcount_s),
        .HBL        (video_hbl_s),
        .VBL        (video_vbl_s),
        .BLANK      (video_blank_s),
        .DL         (video_d_latch_s),
        .LD194      (video_ld194_s),
        .VIDEO      (video_bit_o),
        .hsync_n    (video_hsync_n_o),
        .vsync_n    (video_vsync_n_o)
    );


    // ROM (16K)
    assign rom_addr_o = cpu_addr_s[13:0];
    assign rom_oe_o = (rom_cs_s == 1'b1 && t_phi1_s == 1'b0 && cpu_we_s == 1'b0 && clock_q3_s == 1'b0) ? 1'b1 : 1'b0;
    assign rom_we_o = (rom_cs_s == 1'b1 && t_phi1_s == 1'b0 && cpu_we_s == 1'b1 && clock_q3_s == 1'b0) ? 1'b1 : 1'b0;

    // RAM Address
    always @(cpu_addr_s or t_phi1_s or video_addr_s) begin
        if (t_phi1_s == 1'b1) begin
            ram_addr_o = video_addr_s;
        end else begin
            ram_addr_o = cpu_addr_s[15:0];
        end
    end

    assign ram_oe_o = (((ram_cs_s == 1'b1 && t_phi1_s == 1'b0 && cpu_we_s == 1'b0) || t_phi1_s == 1'b1)) && clock_q3_s == 1'b0 ? 1'b1 : 1'b0;
    assign ram_we_o = (ram_cs_s == 1'b1 && t_phi1_s == 1'b0 && cpu_we_s == 1'b1) && clock_q3_s == 1'b0 ? 1'b1 : 1'b0;

    // Latch video RAM data on the rising edge of RAS
    always @(posedge clock_14_i) begin
        if (t_ax_s == 1'b1 && t_cas_n_s == 1'b1 && t_ras_n_s == 1'b1) begin
            if (t_phi1_s == 1'b1) begin
                video_d_latch_s <= ram_data_from_i;
            end
        end
    end

    // CPU Data Out and Peripheral Data Out
    assign ram_data_to_o = cpu_dout_s;
    assign per_data_to_o = cpu_dout_s;

    // CPU Data In multiplexer
    assign cpu_di_s = (ram_cs_s == 1'b1) ? ram_data_from_i :
                      (kbd_i_cs_s == 1'b1) ? kbd_data_s :
                      (rom_cs_s == 1'b1) ? rom_data_from_i :
                      (dis_rom_i == 1'b1) ? per_data_from_i : 8'b00000000;

    // Keyboard Data
    assign kbd_data_s = {cas_i, lpt_busy_i, kbd_cols_i};

    // Peripheral Outputs
    assign read_write_o = cpu_we_s;
    assign phi0_o = t_phi0_s;
    assign phi1_o = t_phi1_s;
    assign phi2_o = t_phi2_s;
    assign clock_2m_o = clock_q3_s;
    assign per_addr_o = cpu_addr_s[7:0];
    assign io_select_n_o = io_sel_n_s;
    assign dev_select_n_o = dev_sel_n_s;

    // Address Decoder
    always @(cpu_addr_s or dis_rom_i or ss_romram_s) begin
        ram_cs_s = 1'b0;
        kbd_o_cs_s = 1'b0;
        kbd_i_cs_s = 1'b0;
        cas_o_cs_s = 1'b0;
        speaker_cs_s = 1'b0;
        softswitch_cs_s = 1'b0;
        dev_sel_n_s = 1'b1;
        io_sel_n_s = 1'b1;
        rom_cs_s = 1'b0;

        case (cpu_addr_s[15:14])
            2'b00, 2'b01, 2'b10: begin // 0000-BFFF = RAM
                ram_cs_s = 1'b1;
            end
            2'b11: begin // C000-FFFF:
                case (cpu_addr_s[13:12])
                    2'b00: begin // C000-CFFF:
                        case (cpu_addr_s[11:8])
                            4'h0: begin // C000-C0FF:
                                case (cpu_addr_s[7:4])
                                    4'h0: begin // C000-C00F = KBD OUT
                                        kbd_o_cs_s = 1'b1;
                                    end
                                    4'h1: begin // C010-C01F = KBD IN
                                        kbd_i_cs_s = 1'b1;
                                    end
                                    4'h2: begin // C020-C02F = K7 out
                                        cas_o_cs_s = 1'b1;
                                    end
                                    4'h3: begin // C030-C03F = Speaker Toggle
                                        speaker_cs_s = 1'b1;
                                    end
                                    4'h4: begin // C040-C04F = ?
                                        // null;
                                    end
                                    4'h5: begin // C050-C05F = Soft Switches
                                        softswitch_cs_s = 1'b1;
                                    end
                                    4'h6: begin // C060-C06F = ?
                                        // null;
                                    end
                                    4'h7: begin // C070-C07F = ?
                                        // null;
                                    end
                                    4'h8: begin // C080-C08F = Saturn 128K
                                        // ram_bank1 <= cpu_addr_s[3];
                                        // ram_bank2
                                        // ram_pre_wr_en <= cpu_addr_s[0] && !cpu_we;
                                        // ram_write_en <= cpu_addr_s[0] && ram_pre_wr_en && !cpu_we;
                                        // ram_read_en <= !(cpu_addr_s[0] ^ cpu_addr_s[1]);
                                    end
                                    4'h9: begin // C090-C09F = null / periferico
                                        dev_sel_n_s = 1'b0;
                                    end
                                    4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF: begin // C0A0-C0FF = null
                                        // null;
                                    end
                                    default: begin
                                        // null;
                                    end
                                endcase
                            end
                            4'h1: begin // C100 - C1FF = ROM / RAM / periferico
                                if (dis_rom_i == 1'b0) begin
                                    if (ss_romram_s == 1'b0) begin
                                        rom_cs_s = 1'b1;
                                    end else begin
                                        ram_cs_s = 1'b1;
                                    end
                                end else begin
                                    io_sel_n_s = 1'b0;
                                end
                            end
                            4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7: begin // C200 - C7FF = ROM / RAM
                                if (ss_romram_s == 1'b0) begin
                                    rom_cs_s = 1'b1;
				    end else begin
                                    ram_cs_s = 1'b1;
                                end
                            end
                            4'h8, 4'h9, 4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF: begin // C800 - CFFF = ROM / RAM
                                if (ss_romram_s == 1'b0) begin
                                    rom_cs_s = 1'b1;
                                end else begin
                                    ram_cs_s = 1'b1;
                                end
                            end
                            default: begin
                                // null;
                            end
                        endcase
                    end
                    2'b01, 2'b10, 2'b11: begin // D000 - FFFF = ROM
                        if (ss_romram_s == 1'b0) begin
                            rom_cs_s = 1'b1;
                        end else begin
                            ram_cs_s = 1'b1;
                        end
                    end
                    default: begin
                        // null;
                    end
                endcase
            end
            default: begin
                // null;
            end
        endcase
    end

    // Keyboard Output
    always @(posedge clock_14_i or posedge reset_i) begin
        if (reset_i == 1'b1) begin
            kbd_rows_o <= 8'b00000000;
        end else begin
            if (kbd_o_cs_s == 1'b1 && t_phi0_s == 1'b1) begin
                kbd_rows_o <= cpu_dout_s;
            end
        end
    end

    // Soft Switches
    always @(posedge clock_14_i or posedge reset_i) begin
        if (reset_i == 1'b1) begin
            softswitches_s <= 8'b00000000;
        end else begin
            if (t_phi0_s == 1'b1 && softswitch_cs_s == 1'b1) begin
                softswitches_s[cpu_addr_s[3:1]] <= cpu_addr_s[0];
            end
        end
    end

    assign ss_color_s = softswitches_s[0];     // C050/51
    assign ss_motorA_s = softswitches_s[1];    // C052/53
    assign ss_page2_s = softswitches_s[2];     // C054/55
    assign ss_motorB_s = softswitches_s[3];    // C056/57
    assign ss_lpt_stb_s = softswitches_s[4];   // C058/59
    assign ss_romram_s = softswitches_s[5];    // C05A/5B
    // (6) ??
    assign ss_ctrl_s = softswitches_s[7];      // C05E/5F

    assign video_color_o = ss_color_s;
    assign cas_motor_o = {ss_motorB_s, ss_motorA_s};
    assign lpt_stb_o = ss_lpt_stb_s;
    assign kbd_ctrl_o = ss_ctrl_s;
    assign video_hbl_o = video_hbl_s;
    assign video_vbl_o = video_vbl_s;
    assign video_ld194_o = video_ld194_s;

    // Speaker
    always @(posedge clock_14_i) begin
        if (t_phi0_s == 1'b1 && speaker_cs_s == 1'b1) begin
            speaker_s <= !speaker_s;
        end
    end
    assign spk_o = speaker_s;

    // Cassette
    always @(posedge clock_14_i) begin
        if (t_phi0_s == 1'b1 && cas_o_cs_s == 1'b1) begin
            cas_o_s <= !cas_o_s;
        end
    end
    assign cas_o = cas_o_s;


endmodule

