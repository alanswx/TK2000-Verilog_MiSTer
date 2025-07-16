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
// PS/2 Keyboard scancodes
//

`ifndef KEYSCANS_VH
`define KEYSCANS_VH

    // Teclas com scancode simples (Simple scancode keys)
    localparam [7:0] KEY_ESC            = 8'h76;
    localparam [7:0] KEY_F1             = 8'h05;
    localparam [7:0] KEY_F2             = 8'h06;
    localparam [7:0] KEY_F3             = 8'h04;
    localparam [7:0] KEY_F4             = 8'h0C;
    localparam [7:0] KEY_F5             = 8'h03;
    localparam [7:0] KEY_F6             = 8'h0B;
    localparam [7:0] KEY_F7             = 8'h83;
    localparam [7:0] KEY_F8             = 8'h0A;
    localparam [7:0] KEY_F9             = 8'h01;
    localparam [7:0] KEY_F10            = 8'h09;
    localparam [7:0] KEY_F11            = 8'h78;
    localparam [7:0] KEY_F12            = 8'h07;

    localparam [7:0] KEY_BL             = 8'h0E;        // (en) ~ `   (pt-br) " '
    localparam [7:0] KEY_1              = 8'h16;
    localparam [7:0] KEY_2              = 8'h1E;
    localparam [7:0] KEY_3              = 8'h26;
    localparam [7:0] KEY_4              = 8'h25;
    localparam [7:0] KEY_5              = 8'h2E;
    localparam [7:0] KEY_6              = 8'h36;
    localparam [7:0] KEY_7              = 8'h3D;
    localparam [7:0] KEY_8              = 8'h3E;
    localparam [7:0] KEY_9              = 8'h46;
    localparam [7:0] KEY_0              = 8'h45;
    localparam [7:0] KEY_MINUS          = 8'h4E;        // - _
    localparam [7:0] KEY_EQUAL          = 8'h55;        // = +
    localparam [7:0] KEY_BACKSPACE      = 8'h66;

    localparam [7:0] KEY_TAB            = 8'h0D;
    localparam [7:0] KEY_Q              = 8'h15;
    localparam [7:0] KEY_W              = 8'h1D;
    localparam [7:0] KEY_E              = 8'h24;
    localparam [7:0] KEY_R              = 8'h2D;
    localparam [7:0] KEY_T              = 8'h2C;
    localparam [7:0] KEY_Y              = 8'h35;
    localparam [7:0] KEY_U              = 8'h3C;
    localparam [7:0] KEY_I              = 8'h43;
    localparam [7:0] KEY_O              = 8'h44;
    localparam [7:0] KEY_P              = 8'h4D;
    localparam [7:0] KEY_ACAG           = 8'h54;        // (en) [ {        (pt-br) acento_agudo `
    localparam [7:0] KEY_LCOLC          = 8'h5B;        // (en) ] }        (pt-br) [ {
    localparam [7:0] KEY_ENTER          = 8'h5A;

    localparam [7:0] KEY_CAPSLOCK       = 8'h58;
    localparam [7:0] KEY_A              = 8'h1C;
    localparam [7:0] KEY_S              = 8'h1B;
    localparam [7:0] KEY_D              = 8'h23;
    localparam [7:0] KEY_F              = 8'h2B;
    localparam [7:0] KEY_G              = 8'h34;
    localparam [7:0] KEY_H              = 8'h33;
    localparam [7:0] KEY_J              = 8'h3B;
    localparam [7:0] KEY_K              = 8'h42;
    localparam [7:0] KEY_L              = 8'h4B;
    localparam [7:0] KEY_CCEDIL         = 8'h4C;        // (en) ; :        (pt-br) c_cedilha
    localparam [7:0] KEY_TILDE          = 8'h52;        // (en) ' "        (pt-br) ~ ^
    localparam [7:0] KEY_RCOLC          = 8'h5D;        // (en) \ |        (pt-br) ]}

    localparam [7:0] KEY_LSHIFT         = 8'h12;
    localparam [7:0] KEY_LT             = 8'h61;        // (pt-br) \ |
    localparam [7:0] KEY_Z              = 8'h1A;
    localparam [7:0] KEY_X              = 8'h22;
    localparam [7:0] KEY_C              = 8'h21;
    localparam [7:0] KEY_V              = 8'h2A;
    localparam [7:0] KEY_B              = 8'h32;
    localparam [7:0] KEY_N              = 8'h31;
    localparam [7:0] KEY_M              = 8'h3A;
    localparam [7:0] KEY_COMMA          = 8'h41;        // , <
    localparam [7:0] KEY_POINT          = 8'h49;        // . >
    localparam [7:0] KEY_TWOPOINT       = 8'h4A;        // (en)            (pt-br) ; :
    localparam [7:0] KEY_SLASH          = 8'h51;        // / ?
    localparam [7:0] KEY_RSHIFT         = 8'h59;

    localparam [7:0] KEY_LCTRL          = 8'h14;
    localparam [7:0] KEY_LALT           = 8'h11;
    localparam [7:0] KEY_SPACE          = 8'h29;

    localparam [7:0] KEY_KP0            = 8'h70;        // Teclas keypad numerico
    localparam [7:0] KEY_KP1            = 8'h69;
    localparam [7:0] KEY_KP2            = 8'h72;
    localparam [7:0] KEY_KP3            = 8'h7A;
    localparam [7:0] KEY_KP4            = 8'h6B;
    localparam [7:0] KEY_KP5            = 8'h73;
    localparam [7:0] KEY_KP6            = 8'h74;
    localparam [7:0] KEY_KP7            = 8'h6C;
    localparam [7:0] KEY_KP8            = 8'h75;
    localparam [7:0] KEY_KP9            = 8'h7D;
    localparam [7:0] KEY_KPCOMMA        = 8'h71;        // ,
    localparam [7:0] KEY_KPPOINT        = 8'h6D;        // .
    localparam [7:0] KEY_KPPLUS         = 8'h79;        // +
    localparam [7:0] KEY_KPMINUS        = 8'h7B;        // -
    localparam [7:0] KEY_KPASTER        = 8'h7C;        // *

    localparam [7:0] KEY_NUMLOCK        = 8'h77;        // Num Lock
    localparam [7:0] KEY_SCROLL         = 8'h7E;        // Scroll Lock

    // Teclas com scancode extendido (E0 + scancode) (Extended scancode keys)
    localparam [7:0] KEY_WAKEUP         = 8'h5E;
    localparam [7:0] KEY_SLEEP          = 8'h3F;
    localparam [7:0] KEY_POWER          = 8'h37;
    localparam [7:0] KEY_INS            = 8'h70;
    localparam [7:0] KEY_DEL            = 8'h71;
    localparam [7:0] KEY_HOME           = 8'h6C;
    localparam [7:0] KEY_END            = 8'h69;
    localparam [7:0] KEY_PGUP           = 8'h7D;
    localparam [7:0] KEY_PGDOWN         = 8'h7A;
    localparam [7:0] KEY_UP             = 8'h75;
    localparam [7:0] KEY_DOWN           = 8'h72;
    localparam [7:0] KEY_LEFT           = 8'h6B;
    localparam [7:0] KEY_RIGHT          = 8'h74;
    localparam [7:0] KEY_RCTRL          = 8'h14;
    localparam [7:0] KEY_RALT           = 8'h11;
    localparam [7:0] KEY_KPENTER        = 8'h5A;
    localparam [7:0] KEY_KPSLASH        = 8'h4A;        // /
    localparam [7:0] KEY_PRINTSCR       = 8'h7C;
    localparam [7:0] KEY_LWIN           = 8'h1F;
    localparam [7:0] KEY_RWIN           = 8'h27;
    localparam [7:0] KEY_MENU           = 8'h2F;

`endif // KEYSCANS_VH
