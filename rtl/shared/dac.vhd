--
-- Multicore 2 / Multicore 2+
--
-- Copyright (c) 2017-2020 - Victor Trucco
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
		
-------------------------------------------------------------------------------
--
-- Delta-Sigma DAC
--
-- $Id: dac.vhd,v 1.1 2006/11/29 14:17:19 arnim Exp $
--
-- Refer to Xilinx Application Note XAPP154.
--
-- This DAC requires an external RC low-pass filter:
--
--   dac_o 0---XXXXX---+---0 analog audio
--              2K2    |
--                    === 10n
--                     |
--                    GND
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity dac is

	generic (
		msbi_g	: integer := 7
	);
	port (
		clk_i		: in  std_logic;
		res_i		: in  std_logic;
		dac_i		: in  std_logic_vector(msbi_g downto 0);
		dac_o		: out std_logic
	);

end entity;

library ieee;
use ieee.numeric_std.all;

architecture rtl of dac is

  signal DACout_q      : std_logic;
  signal DeltaAdder_s,
         SigmaAdder_s,
         SigmaLatch_q,
         DeltaB_s      : unsigned(msbi_g+2 downto 0);

begin

  DeltaB_s(msbi_g+2 downto msbi_g+1) <= SigmaLatch_q(msbi_g+2) &
                                        SigmaLatch_q(msbi_g+2);
  DeltaB_s(msbi_g   downto        0) <= (others => '0');

  DeltaAdder_s <= unsigned('0' & '0' & dac_i) + DeltaB_s;

  SigmaAdder_s <= DeltaAdder_s + SigmaLatch_q;

  seq: process (clk_i, res_i)
  begin
    if res_i = '1' then
      SigmaLatch_q <= to_unsigned(2**(msbi_g+1), SigmaLatch_q'length);
      DACout_q     <= '0';

    elsif clk_i'event and clk_i = '1' then
      SigmaLatch_q <= SigmaAdder_s;
      DACout_q     <= SigmaLatch_q(msbi_g+2);
    end if;
  end process seq;

  dac_o <= DACout_q;

end architecture;
