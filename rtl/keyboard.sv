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
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Redistributions in synthesized form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// * Neither the name of the author nor the names of other contributors may
//   be used to endorse or promote products derived from this software without
//   specific prior written agreement from the author.
//
// * License is granted for non-commercial use only. A fee may not be charged
//   for redistributions as source code or in synthesized/hardware form without
//   specific prior written agreement from the author.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
///////////////////////////////////////////////////////////////////////////////

// PS/2 scancode to TK2000 matrix conversion


module keyboard #( 
    parameter integer clkfreq_g            // This is the system clock value in kHz
) (
    input wire clock_i,
    input wire reset_i,
    // PS/2 interface
	 input wire [10:0] ps2_key,
    // Row input
    input wire [7:0] rows_i,
    input wire row_ctrl_i,
    // Column output
    output wire [5:0] cols_o
);
`include "keyscans.vh" // Include the header file with scancode definitions

    // Internal signals
    // In Verilog, a "type key_matrix_t is array (8 downto 0) of std_logic_vector(5 downto 0)"
    // is declared as an array of registers.
    reg [5:0] keys_s [8:0]; // Array of 6-bit registers, 9 elements (0 to 8)
    reg shift_s;
    reg [5:0] k1_s, k2_s, k3_s, k4_s, k5_s, k6_s, k7_s, k8_s, k9_s;

	     // Wires to decode the ps2_key input for easier use
    wire is_extended = ps2_key[8];     // Extended key flag (e.    always @(posedge clock_i or posedge reset_i) beging., arrow keys)
    wire is_press    = ps2_key[9];     // Key press (1) or release (0) flag
    wire [7:0] scancode = ps2_key[7:0]; // The 8-bit key scancode

	 // Wires to decode the ps2_key input for easier use

    reg last_toggle_s;     // Stores the last state of the event toggle bit

    // Merging of rows (combinational logic)
    always @(*) begin
        k1_s = (rows_i[0] == 1'b1) ? keys_s[0] : 6'b0;
        k2_s = (rows_i[1] == 1'b1) ? keys_s[1] : 6'b0;
        k3_s = (rows_i[2] == 1'b1) ? keys_s[2] : 6'b0;
        k4_s = (rows_i[3] == 1'b1) ? keys_s[3] : 6'b0;
        k5_s = (rows_i[4] == 1'b1) ? keys_s[4] : 6'b0;
        k6_s = (rows_i[5] == 1'b1) ? keys_s[5] : 6'b0;
        k7_s = (rows_i[6] == 1'b1) ? keys_s[6] : 6'b0;
        k8_s = (rows_i[7] == 1'b1) ? keys_s[7] : 6'b0;
        k9_s = (row_ctrl_i == 1'b1) ? keys_s[8] : 6'b0;
    end

    assign cols_o = k1_s | k2_s | k3_s | k4_s | k5_s | k6_s | k7_s | k8_s | k9_s;

    // Main Keyboard Processing Logic
    always @(posedge clock_i) begin

        if (reset_i) begin
            // Reset all internal states
            shift_s <= 1'b0;
            last_toggle_s <= 1'b0;
            for (integer i = 0; i <= 8; i = i + 1) begin
                keys_s[i] <= 6'b0;
            end

        end else begin
            // Store the current toggle bit state to compare against the next one
            last_toggle_s <= ps2_key[10];

            // A new key event is detected when the toggle bit (ps2_key[10]) changes.
            if (ps2_key[10] != last_toggle_s) begin

                // Handle shift keys specifically
                if (scancode == KEY_LSHIFT || scancode == KEY_RSHIFT) begin
                    shift_s <= is_press;
                end

                 // Update the key matrix based on scancode, press/release status, and extended status
               if (!is_extended) begin
                    // --- Normal Scancodes ---
                    if (!shift_s) begin // SHIFT not pressed
                        case (scancode)
                                KEY_B:         keys_s[0][1] <= is_press; // B
                                KEY_V:         keys_s[0][2] <= is_press; // V
                                KEY_C:         keys_s[0][3] <= is_press; // C
                                KEY_X:         keys_s[0][4] <= is_press; // X
                                KEY_Z:         keys_s[0][5] <= is_press; // Z

                                KEY_G:         keys_s[1][1] <= is_press; // G
                                KEY_F:         keys_s[1][2] <= is_press; // F
                                KEY_D:         keys_s[1][3] <= is_press; // D
                                KEY_S:         keys_s[1][4] <= is_press; // S
                                KEY_A:         keys_s[1][5] <= is_press; // A

                                KEY_SPACE:     keys_s[2][0] <= is_press; // SPACE
                                KEY_T:         keys_s[2][1] <= is_press; // T
                                KEY_R:         keys_s[2][2] <= is_press; // R
                                KEY_E:         keys_s[2][3] <= is_press; // E
                                KEY_W:         keys_s[2][4] <= is_press; // W
                                KEY_Q:         keys_s[2][5] <= is_press; // Q

                                KEY_BACKSPACE: keys_s[3][0] <= is_press; // Backspace (<-)
                                KEY_5:         keys_s[3][1] <= is_press; // 5 %
                                KEY_4:         keys_s[3][2] <= is_press; // 4 $
                                KEY_3:         keys_s[3][3] <= is_press; // 3 #
                                KEY_2:         keys_s[3][4] <= is_press; // 2 @
                                KEY_1:         keys_s[3][5] <= is_press; // 1 !

                                KEY_6:         keys_s[4][1] <= is_press; // 6 ¨
                                KEY_7:         keys_s[4][2] <= is_press; // 7 &
                                KEY_8:         keys_s[4][3] <= is_press; // 8 *
                                KEY_9:         keys_s[4][4] <= is_press; // 9 (
                                KEY_0:         keys_s[4][5] <= is_press; // 0 )

                                KEY_Y:         keys_s[5][1] <= is_press; // Y
                                KEY_U:         keys_s[5][2] <= is_press; // U
                                KEY_I:         keys_s[5][3] <= is_press; // I
                                KEY_O:         keys_s[5][4] <= is_press; // O
                                KEY_P:         keys_s[5][5] <= is_press; // P

                                KEY_H:         keys_s[6][1] <= is_press; // H
                                KEY_J:         keys_s[6][2] <= is_press; // J
                                KEY_K:         keys_s[6][3] <= is_press; // K
                                KEY_L:         keys_s[6][4] <= is_press; // L
                                KEY_TWOPOINT:  begin keys_s[6][5] <= is_press; keys_s[0][0] <= is_press; end // ; : (Invertido, setar SHIFT)

                                KEY_ENTER:     begin keys_s[7][0] <= is_press;  end // ENTER
                                KEY_N:         keys_s[7][1] <= is_press; // N
                                KEY_M:         keys_s[7][2] <= is_press; // M
                                KEY_COMMA:     keys_s[7][3] <= is_press; // ,
                                KEY_KPCOMMA:   keys_s[7][3] <= is_press; // ,
                                KEY_POINT:     keys_s[7][4] <= is_press; // .
                                KEY_KPPOINT:   keys_s[7][4] <= is_press; // .
                                KEY_SLASH:     begin keys_s[7][5] <= is_press; keys_s[0][0] <= is_press; end // / ? (Invertido, setar SHIFT)

                                KEY_KP0:       keys_s[4][5] <= is_press; // 0
                                KEY_KP1:       keys_s[3][5] <= is_press; // 1
                                KEY_KP2:       keys_s[3][4] <= is_press; // 2
                                KEY_KP3:       keys_s[3][3] <= is_press; // 3
                                KEY_KP4:       keys_s[3][2] <= is_press; // 4
                                KEY_KP5:       keys_s[3][1] <= is_press; // 5
                                KEY_KP6:       keys_s[4][1] <= is_press; // 6
                                KEY_KP7:       keys_s[4][2] <= is_press; // 7
                                KEY_KP8:       keys_s[4][3] <= is_press; // 8
                                KEY_KP9:       keys_s[4][4] <= is_press; // 9

                                KEY_LCTRL:     keys_s[8][0] <= is_press; // Left CTRL

                                // Other special keys sent as key combinations
                                KEY_MINUS:     begin keys_s[5][3] <= is_press; keys_s[0][0] <= is_press; end // - _ (SHIFT + I)
                                KEY_KPMINUS:   begin keys_s[5][3] <= is_press; keys_s[0][0] <= is_press; end // -   (SHIFT + I)
                                KEY_BL:        begin keys_s[4][2] <= is_press; keys_s[0][0] <= is_press; end // ' " (SHIFT + 7)
                                KEY_EQUAL:     begin keys_s[5][4] <= is_press; keys_s[0][0] <= is_press; end // = + (SHIFT + O)
                                KEY_KPASTER:   begin keys_s[4][5] <= is_press; keys_s[0][0] <= is_press; end // * (SHIFT + 0)
                                KEY_KPPLUS:    begin keys_s[5][5] <= is_press; keys_s[0][0] <= is_press; end // +   (SHIFT + P)


                                default: ; // Do nothing for unhandled scancodes
                            endcase

                        end else begin // SHIFT pressed
                        case (scancode)
                            
                                KEY_B:         begin keys_s[0][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_V:         begin keys_s[0][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_C:         begin keys_s[0][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_X:         begin keys_s[0][4] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_Z:         begin keys_s[0][5] <= is_press; keys_s[0][0] <= is_press; end

                                KEY_G:         begin keys_s[1][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_F:         begin keys_s[1][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_D:         begin keys_s[1][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_S:         begin keys_s[1][4] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_A:         begin keys_s[1][5] <= is_press; keys_s[0][0] <= is_press; end

                                KEY_SPACE:     begin keys_s[2][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_T:         begin keys_s[2][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_R:         begin keys_s[2][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_E:         begin keys_s[2][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_W:         begin keys_s[2][4] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_Q:         begin keys_s[2][5] <= is_press; keys_s[0][0] <= is_press; end

                                KEY_BACKSPACE: begin keys_s[3][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_5:         begin keys_s[3][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_4:         begin keys_s[3][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_3:         begin keys_s[3][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_2:         begin keys_s[6][4] <= is_press; keys_s[0][0] <= is_press; end // 2 @ (SHIFT + L)
                                KEY_1:         begin keys_s[3][5] <= is_press; keys_s[0][0] <= is_press; end

                                // KEY_6:       -- Not existing as shifted char in VHDL comment
                                KEY_7:         begin keys_s[4][1] <= is_press; keys_s[0][0] <= is_press; end // 7 &  (SHIFT + 6)
                                KEY_8:         begin keys_s[4][5] <= is_press; keys_s[0][0] <= is_press; end // 8 * (SHIFT + 0)
                                KEY_9:         begin keys_s[4][3] <= is_press; keys_s[0][0] <= is_press; end // 9 (  (SHIFT + 8)
                                KEY_0:         begin keys_s[4][4] <= is_press; keys_s[0][0] <= is_press; end // 0 )  (SHIFT + 9)

                                KEY_Y:         begin keys_s[5][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_U:         begin keys_s[5][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_I:         begin keys_s[5][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_O:         begin keys_s[5][4] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_P:         begin keys_s[5][5] <= is_press; keys_s[0][0] <= is_press; end

                                KEY_H:         begin keys_s[6][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_J:         begin keys_s[6][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_K:         begin keys_s[6][3] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_L:         begin keys_s[6][4] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_TWOPOINT:  keys_s[6][5] <= is_press; // ; : (Invertido, nao setar SHIFT)

                                KEY_ENTER:     begin keys_s[7][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_N:         begin keys_s[7][1] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_M:         begin keys_s[7][2] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_COMMA:     begin keys_s[7][3] <= is_press; keys_s[0][0] <= is_press; end // , <
                                KEY_KPCOMMA:   keys_s[7][3] <= is_press; // ,
                                KEY_POINT:     begin keys_s[7][4] <= is_press; keys_s[0][0] <= is_press; end // . >
                                KEY_KPPOINT:   keys_s[7][4] <= is_press; // .
                                KEY_SLASH:     keys_s[7][5] <= is_press; // / ? is_press(Invertido, nao setar SHIFT)

                                KEY_KP0:       keys_s[4][5] <= is_press; // 0
                                KEY_KP1:       keys_s[3][5] <= is_press; // 1
                                KEY_KP2:       keys_s[3][4] <= is_press; // 2
                                KEY_KP3:       keys_s[3][3] <= is_press; // 3
                                KEY_KP4:       keys_s[3][2] <= is_press; // 4
                                KEY_KP5:       keys_s[3][1] <= is_press; // 5
                                KEY_KP6:       keys_s[4][1] <= is_press; // 6
                                KEY_KP7:       keys_s[4][2] <= is_press; // 7
                                KEY_KP8:       keys_s[4][3] <= is_press; // 8
                                KEY_KP9:       keys_s[4][4] <= is_press; // 9

                                KEY_LCTRL:     begin keys_s[8][0] <= is_press; keys_s[0][0] <= is_press; end // Left CTRL

                                // Other special keys sent as key combinations
                                // KEY_MINUS: -- Not existing as shifted char in VHDL comment
                                KEY_KPMINUS:   begin keys_s[5][3] <= is_press; keys_s[0][0] <= is_press; end // - (SHIFT + I)
                                KEY_BL:        begin keys_s[3][4] <= is_press; keys_s[0][0] <= is_press; end // ' " (SHIFT + 2)
                                KEY_EQUAL:     begin keys_s[5][5] <= is_press; keys_s[0][0] <= is_press; end // = + (SHIFT + P)
                                KEY_KPASTER:   begin keys_s[4][5] <= is_press; keys_s[0][0] <= is_press; end // * (SHIFT + 0)
                                KEY_KPPLUS:    begin keys_s[5][5] <= is_press; keys_s[0][0] <= is_press; end // + (SHIFT + P)
                                KEY_TILDE:     begin keys_s[6][3] <= is_press; keys_s[0][0] <= is_press; end // ~ ^ (SHIFT + K)

                                default: ;
                            endcase
                        end // end if shift = 0

                    end else begin // Extended scancodes
                    if (!shift_s) begin // SHIFT not pressed
                            case (scancode)
                                KEY_KPENTER:   begin keys_s[7][0] <= is_press;  end // ENTER

                                // Cursor keys
                                KEY_LEFT:      begin keys_s[3][0] <= is_press;  end // Left
                                KEY_RIGHT:     begin keys_s[4][0] <= is_press;  end // Right
                                KEY_DOWN:      begin keys_s[5][0] <= is_press;  end // Down
                                KEY_UP:        begin keys_s[6][0] <= is_press;  end // Up
                                KEY_RCTRL:     keys_s[8][0] <= is_press; // Right CTRL

                                // Other special keys sent as key combinations
                                KEY_KPSLASH:   begin keys_s[7][5] <= is_press; keys_s[0][0] <= is_press; end // / (SHIFT + ?)

                                default: ;
                            endcase
                        end else begin // With shift
                            case (scancode)
                                KEY_KPENTER:   begin keys_s[7][0] <= is_press; keys_s[0][0] <= is_press; end // ENTER

                                // Cursor keys
                                KEY_LEFT:      begin keys_s[3][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_RIGHT:     begin keys_s[4][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_DOWN:      begin keys_s[5][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_UP:        begin keys_s[6][0] <= is_press; keys_s[0][0] <= is_press; end
                                KEY_RCTRL:     begin keys_s[8][0] <= is_press; keys_s[0][0] <= is_press; end

                                // Other special keys sent as key combinations
                                KEY_KPSLASH:   begin keys_s[7][5] <= is_press; keys_s[0][0] <= is_press; end

                                default: ;
                            endcase
                        end // end if shift
                    end // end if extended
                end // end if keyb_data_s == X"AA" / X"E0" / X"F0"
        end // end if reset_i
    end // end always
endmodule
