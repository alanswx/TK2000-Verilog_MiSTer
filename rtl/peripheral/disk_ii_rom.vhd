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
		
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity disk_ii_rom is
 port (
   addr : in  unsigned(7 downto 0);
   clk  : in  std_logic;
   dout : out unsigned(7 downto 0));
end disk_ii_rom;

architecture rtl of disk_ii_rom is
  type rom_array is array(0 to 255) of unsigned(7 downto 0);

  constant ROM : rom_array := (
     X"a2", X"20", X"a0", X"00", X"a2", X"03", X"86", X"3c",
     X"8a", X"0a", X"24", X"3c", X"f0", X"10", X"05", X"3c",
     X"49", X"ff", X"29", X"7e", X"b0", X"08", X"4a", X"d0",
     X"fb", X"98", X"9d", X"56", X"03", X"c8", X"e8", X"10",
     X"e5", X"20", X"58", X"ff", X"ba", X"bd", X"00", X"01",
     X"0a", X"0a", X"0a", X"0a", X"85", X"2b", X"aa", X"bd",
     X"8e", X"c0", X"bd", X"8c", X"c0", X"bd", X"8a", X"c0",
     X"bd", X"89", X"c0", X"a0", X"50", X"bd", X"80", X"c0",
     X"98", X"29", X"03", X"0a", X"05", X"2b", X"aa", X"bd",
     X"81", X"c0", X"a9", X"56", X"20", X"a8", X"fc", X"88",
     X"10", X"eb", X"85", X"26", X"85", X"3d", X"85", X"41",
     X"a9", X"08", X"85", X"27", X"18", X"08", X"bd", X"8c",
     X"c0", X"10", X"fb", X"49", X"d5", X"d0", X"f7", X"bd",
     X"8c", X"c0", X"10", X"fb", X"c9", X"aa", X"d0", X"f3",
     X"ea", X"bd", X"8c", X"c0", X"10", X"fb", X"c9", X"96",
     X"f0", X"09", X"28", X"90", X"df", X"49", X"ad", X"f0",
     X"25", X"d0", X"d9", X"a0", X"03", X"85", X"40", X"bd",
     X"8c", X"c0", X"10", X"fb", X"2a", X"85", X"3c", X"bd",
     X"8c", X"c0", X"10", X"fb", X"25", X"3c", X"88", X"d0",
     X"ec", X"28", X"c5", X"3d", X"d0", X"be", X"a5", X"40",
     X"c5", X"41", X"d0", X"b8", X"b0", X"b7", X"a0", X"56",
     X"84", X"3c", X"bc", X"8c", X"c0", X"10", X"fb", X"59",
     X"d6", X"02", X"a4", X"3c", X"88", X"99", X"00", X"03",
     X"d0", X"ee", X"84", X"3c", X"bc", X"8c", X"c0", X"10",
     X"fb", X"59", X"d6", X"02", X"a4", X"3c", X"91", X"26",
     X"c8", X"d0", X"ef", X"bc", X"8c", X"c0", X"10", X"fb",
     X"59", X"d6", X"02", X"d0", X"87", X"a0", X"00", X"a2",
     X"56", X"ca", X"30", X"fb", X"b1", X"26", X"5e", X"00",
     X"03", X"2a", X"5e", X"00", X"03", X"2a", X"91", X"26",
     X"c8", X"d0", X"ee", X"e6", X"27", X"e6", X"3d", X"a5",
     X"3d", X"cd", X"00", X"08", X"a6", X"2b", X"90", X"db",
     X"4c", X"01", X"08", X"00", X"00", X"00", X"00", X"00");

begin

process (clk)
  begin
    if rising_edge(clk) then
      dout <= ROM(TO_INTEGER(addr));
    end if;
  end process;

end rtl;
