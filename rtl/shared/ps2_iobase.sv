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
// Title       : MC613
// Project     : PS2 Basic Protocol
// Details     : www.ic.unicamp.br/~corte/mc613/
//               www.computer-engineering.org/ps2protocol/
///////////////////////////////////////////////////////////////////////////////
// File        : ps2_base.v
// Author      : Thiago Borges Abdnur (VHDL to Verilog conversion by Google Gemini)
// Company     : IC - UNICAMP
// Last update : 2025/07/15 (Converted)
///////////////////////////////////////////////////////////////////////////////
// Description:
// PS2 basic control
///////////////////////////////////////////////////////////////////////////////

module ps2_iobase #(
    parameter integer clkfreq_g = 100_000 // Default to 100 MHz if not specified, adjust as needed
) (
    input wire  enable_i,      // Enable
    input wire  clock_i,       // system clock (same frequency as defined in 'clkfreq' generic)
    input wire  reset_i,       // Reset when '1'
    inout wire  ps2_data_io,   // PS2 data pin
    inout wire  ps2_clk_io,    // PS2 clock pin
    input wire  data_rdy_i,    // Rise this to signal data is ready to be sent to device
    input wire  [7:0] data_i,  // Data to be sent to device
    output wire send_rdy_o,    // '1' if data can be sent to device (wait for this before rising 'iData_rdy')
    output wire data_rdy_o,    // '1' when data from device has arrived
    output wire [7:0] data_o   // Data from device
);

    localparam integer CLKSSTABLE = clkfreq_g / 150; // Use localparam for constants derived from parameters

    reg [7:0] sdata;
    reg [7:0] hdata; // VHDL 'hdata' was signal, so 'reg' in Verilog for sequential assignment
    reg sigtrigger;
    reg parchecked;
    reg sigsending;
    reg sigsendend;
    reg sigclkreleased;
    reg sigclkheld;

    // Output assignments
    assign data_rdy_o = enable_i && parchecked;
    assign data_o     = sdata;

    // Bidirectional PS/2 pins (tri-state buffer logic)
    // The VHDL defines them as 'inout', but the internal logic implies
    // when they should be driven as outputs.
    // Assuming 'ps2_iobase' only controls ps2_clk_io and ps2_data_io when sending.
    // If external module controls them based on sigclkreleased/sigclkheld,
    // then these would remain 'wire' and controlled externally.
    // Based on the VHDL structure, the direction control happens outside this block
    // by connecting it to a top-level tri-state buffer.
    // This conversion focuses on the internal logic, assuming the top-level handles physical IO.
    // If 'ps2_clk_io' and 'ps2_data_io' need to be actively driven as outputs *from this module*,
    // then `inout wire` ports would need `assign` statements with tri-state conditions.
    // However, the original VHDL ports `ps2_data_io : in std_logic;` and `ps2_clk_io : in std_logic;`
    // within the entity for receiving data imply they are read from, and only implicitly driven
    // by the PS/2 protocol itself (device pulling low), or by *another* module when transmitting.
    // Given the current VHDL, this module only *reads* ps2_clk_io and ps2_data_io for receiving.
    // For *sending*, the VHDL doesn't explicitly drive 'ps2_data_io' out.
    // This seems to be a common PS/2 controller design where the clock/data lines are
    // passively pulled high (open-drain) and either the host or device pulls them low.
    // The 'sigclkreleased' and 'sigclkheld' are *indicators* of clock state, not drivers.
    // The `data_i` and `data_rdy_i` are for this module to *send* data TO the PS/2 device.
    // This typically means this module will control the data line and pull the clock line.
    // For PS/2, the device *normally* clocks the data out on `ps2_clk_io` falling edge.
    // For host-to-device communication, the host must first pull `ps2_clk_io` low for 100us,
    // then pull `ps2_data_io` low, then release `ps2_clk_io`. This isn't explicitly shown
    // as driving `ps2_data_io` or `ps2_clk_io` as outputs directly within this VHDL,
    // but implied by the protocol.

    // Given the VHDL's input declaration for ps2_data_io and ps2_clk_io,
    // and the use of sigclkreleased/sigclkheld as internal signals,
    // it suggests the actual physical tri-state drivers are *outside* this module.
    // However, the port definitions for ps2_clk_io and ps2_data_io are 'inout'.
    // If this module is meant to directly control them, we need `assign` statements for tri-stating.
    // Let's assume the VHDL implied ps2_clk_io and ps2_data_io are only read for input.
    // If they were to be driven, the logic would need to be:
    // assign ps2_data_io = (enable_output_data_line) ? data_to_drive : 1'bz;
    // assign ps2_clk_io = (enable_output_clock_line) ? clock_to_drive : 1'bz;
    // This module's logic `sigclkheld` and `sigclkreleased` are flags, not direct drivers.
    // So, for direct translation, `ps2_data_io` and `ps2_clk_io` are treated as inputs for the internal logic.

    // -------------------------------------------------------------------------
    // Trigger for state change to eliminate noise
    // -------------------------------------------------------------------------
    always @(posedge clock_i or posedge reset_i) begin
        integer fcount; // declared as reg for sequential block
        integer rcount; // declared as reg for sequential block
        if (reset_i == 1'b1) begin
            fcount = 0;
            rcount = 0;
            sigtrigger <= 1'b0;
        end else if (enable_i == 1'b1) begin
            // Falling edge noise (ps2_clk_io going low)
            if (ps2_clk_io == 1'b0) begin
                rcount = 0;
                if (fcount >= CLKSSTABLE) begin
                    sigtrigger <= 1'b1;
                end else begin
                    fcount = fcount + 1;
                end
            // Rising edge noise (ps2_clk_io going high)
            end else if (ps2_clk_io == 1'b1) begin
                fcount = 0;
                if (rcount >= CLKSSTABLE) begin
                    sigtrigger <= 1'b0;
                end else begin
                    rcount = rcount + 1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Data reception from PS/2 device
    // -------------------------------------------------------------------------
    always @(posedge sigtrigger or posedge reset_i or posedge sigsending) begin
        integer count; // declared as reg for sequential block (state counter)
        if (reset_i == 1'b1 || sigsending == 1'b1) begin // sigsending is a reset condition here
            sdata <= 8'b0;
            parchecked <= 1'b0;
            count = 0;
        end else begin // rising_edge(sigtrigger)
            if (count == 0) begin
                // Idle state, check for start bit (0) only
                // and don't start counting bits until we get it
                if (ps2_data_io == 1'b0) begin
                    // This is a start bit
                    count = count + 1;
                end
            end else begin
                // Running. 8-bit data comes in LSb first followed by
                // a single stop bit (1)
                if (count < 9) begin
                    sdata[count - 1] <= ps2_data_io;
                end
                if (count == 9) begin // Parity bit
                    // Calculate XOR sum for parity checking
                    if ((~ (sdata[0] ^ sdata[1] ^ sdata[2] ^ sdata[3] ^ sdata[4] ^ sdata[5] ^ sdata[6] ^ sdata[7])) == ps2_data_io) begin
                        parchecked <= 1'b1;
                    end else begin
                        parchecked <= 1'b0;
                    end
                end
                count = count + 1;
                if (count == 11) begin // Stop bit (bit 10) received, end of frame
                    count = 0;
                    parchecked <= 1'b0; // Reset for next frame
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Edge triggered send register (controls when to start sending)
    // -------------------------------------------------------------------------
    always @(posedge data_rdy_i or posedge reset_i or posedge sigsendend) begin
        if (reset_i == 1'b1 || sigsendend == 1'b1) begin // sigsendend is a reset condition
            sigsending <= 1'b0;
        end else begin // rising_edge(data_rdy_i)
            sigsending <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Wait for at least 11ms before allowing to send again (send_rdy_o)
    // -------------------------------------------------------------------------
    always @(posedge clock_i or posedge reset_i or posedge sigsending) begin
        integer countclk; // declared as reg for sequential block
        if (reset_i == 1'b1) begin
            send_rdy_o <= 1'b1;
            countclk = 0;
        end else if (sigsending == 1'b1) begin // Reset when sending starts
            send_rdy_o <= 1'b0;
            countclk = 0;
        end else begin // sigsending is 0
            if (countclk == (11 * clkfreq_g)) begin
                send_rdy_o <= 1'b1;
            end else begin
                countclk = countclk + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Host input data register (data to be sent)
    // -------------------------------------------------------------------------
    always @(posedge data_rdy_i or posedge reset_i or posedge sigsendend) begin
        if (reset_i == 1'b1 || sigsendend == 1'b1) begin
            hdata <= 8'b0;
        end else begin // rising_edge(data_rdy_i)
            hdata <= data_i;
        end
    end

    // -------------------------------------------------------------------------
    // PS2 clock control (for host sending)
    // -------------------------------------------------------------------------
    always @(posedge clock_i or posedge reset_i or posedge sigsendend or posedge sigsending or negedge enable_i) begin
        localparam integer US100CNT = clkfreq_g / 10; // For 100us delay (100us * clkfreq_g kHz = 0.1 * clkfreq_g clocks)
        integer count; // declared as reg for sequential block
        if (enable_i == 1'b0 || reset_i == 1'b1 || sigsendend == 1'b1) begin
            sigclkreleased <= 1'b1;
            sigclkheld     <= 1'b0;
            count          = 0;
        end else if (sigsending == 1'b1) begin // Only count when sending is active
            if (count < US100CNT + 50) begin // Delay for pulling clock low
                count          = count + 1;
                sigclkreleased <= 1'b0; // Clock is still low
                sigclkheld     <= 1'b0; // Not yet in the held state
            end else if (count < US100CNT + 100) begin // Clock held low phase
                count          = count + 1;
                sigclkreleased <= 1'b0; // Still low
                sigclkheld     <= 1'b1; // Clock is held low
            end else begin // Release clock after hold
                sigclkreleased <= 1'b1; // Clock released (pulled high)
                sigclkheld     <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sending control (actual data shift out)
    // -------------------------------------------------------------------------
    always @(posedge sigtrigger or posedge reset_i or posedge sigsending or posedge enable_i or posedge sigclkheld or posedge sigclkreleased) begin
        integer count;
        if (enable_i == 1'b0 || reset_i == 1'b1 || sigsending == 1'b0) begin
            sigsendend <= 1'b0;
            count      = 0;
        end else if (sigclkheld == 1'b1) begin
            sigsendend <= 1'b0;
            count      = 0;
        end else if (sigclkreleased == 1'b1 && sigsending == 1'b1 && sigtrigger == 1'b1) begin 
             // VHDL `rising_edge(sigtrigger)` means `sigtrigger` goes from 0 to 1
             // Verilog `posedge sigtrigger` is the equivalent
            if (count >= 0 && count < 8) begin // Data bits (0-7)
                // This logic from VHDL is a bit unusual. It sets sigsendend based on 'count'.
                // The actual driving of ps2_data_io should be here, based on 'hdata' bits.
                // The VHDL doesn't explicitly assign ps2_data_io in this process.
                // This implies that 'sigsendend' is a flag, and the actual PS/2 data line
                // driving is done outside this process/module based on 'hdata' and the flags.
                sigsendend <= 1'b0;
            end
            if (count == 8) begin // Parity bit
                sigsendend <= 1'b0;
            end
            if (count == 9) begin // Stop bit
                sigsendend <= 1'b0;
            end
            if (count == 10) begin // End of transmission (after stop bit)
                sigsendend <= 1'b1; // Signal completion
                count      = 0;
            end
            count = count + 1;
        end
    end

    // Missing actual PS/2 data/clock line driving logic.
    // The VHDL doesn't explicitly show `ps2_data_io <= ...` or `ps2_clk_io <= ...`
    // within the architecture, besides the port declarations being 'inout'.
    // In a complete PS/2 driver, you would typically have:
    // assign ps2_clk_io  = (host_pulls_clk_low_condition) ? 1'b0 : 1'bz;
    // assign ps2_data_io = (host_pulls_data_low_condition) ? 1'b0 : 1'bz;
    // where `host_pulls_clk_low_condition` would involve `sigsending`, `sigclkheld`, etc.
    // and `host_pulls_data_low_condition` would involve `sigsending`, `hdata[bit_idx]`, etc.
    // The current VHDL's `ps2_data_io : in std_logic` in the port list is only for receiving data.
    // The VHDL processes are mostly about *state machine flags* for PS/2 communication,
    // not directly driving the IOs in this specific module.
    // If this module is intended to be the full PS/2 driver, then the `inout` ports are
    // misleadingly used for VHDL input-only connections.
    // Assuming this is just the *logic* for state control, and another higher-level module
    // will implement the actual tri-state drivers based on these signals.

endmodule
