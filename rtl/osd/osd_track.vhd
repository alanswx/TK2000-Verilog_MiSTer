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
		
-- (C)EMARD
-- LICENSE=BSD

-- display 64-bit binary-to-hex conversion
-- on VGA-synchronous OSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity osd_track is
generic (
  C_digits: integer := 16; -- number of hex digits to show
  C_resolution_x: integer := 640
);
port (
  clk_pixel: in std_logic := '0'; -- VGA pixel clock 25 MHz
  vsync, fetch_next: std_logic;
  probe_in: in std_logic_vector(4*C_digits-1 downto 0) := (others => '0'); -- test: x"0123456789ABCDEF"
  osd_out: out std_logic
);
end;

architecture Behavioral of osd_track is
    --component char_rom is
    --Port
    --(
    --  clock: in STD_LOGIC;
    --  addr: in STD_LOGIC_VECTOR(11 downto 0);
    --  data: out STD_LOGIC_VECTOR(7 downto 0)
    --);
    --end component;

    -- OSD
    signal R_osd_x, R_osd_y: std_logic_vector(10 downto 0); -- 2048x2048 max
    --signal R_osd_counter: std_logic_vector(20 downto 0); -- pixel counter
    signal S_char_data: std_logic_vector(7 downto 0);
    signal S_char_addr: integer;
    signal R_osd_out: std_logic;
    signal S_osd_pixel: std_logic;
    signal S_ascii: std_logic_vector(7 downto 0) := x"41";
    signal S_nibble: std_logic_vector(3 downto 0);
    signal R_xpix: integer range 0 to 5 := 0;
    signal R_xcol: integer range 0 to C_digits-1 := 0;
begin
    -- S_char_addr <= (others => '0') when R_xpix = 5 else conv_std_logic_vector(5*R_xcol + R_xpix, 12);
    S_nibble <= probe_in(4*(C_digits-1-R_xcol)+3 downto 4*(C_digits-1-R_xcol));
    -- S_ascii <= S_nibble + x"30" when S_nibble < 10 else S_nibble + x"41" - x"0A";
    -- ascii*5 -> char ROM address, R_xpix=5 outputs 0 for 1-pixel wide inter-char spacer
    -- address 5*0x10 is space (between chars)
    -- S_char_addr <= x"50" when R_xpix = 5 else conv_std_logic_vector(5*conv_integer(S_nibble) + R_xpix, 8);
    S_char_addr <= 16*5 when R_xpix = 5 else 5*conv_integer(S_nibble) + R_xpix;
    inst_charrom: entity work.char_rom
    port map
    (
      clock => clk_pixel,
      addr => S_char_addr,
      data(6 downto 0) => S_char_data(6 downto 0)
    );

    S_osd_pixel <= '1' when S_char_data(conv_integer(R_osd_y(3 downto 1)))='1' else '0'; -- doublesize y -> .. downto 1
    process(clk_pixel)
    begin
      if rising_edge(clk_pixel) then
		
        if vsync = '1' then
		  
				R_osd_y <= (others => '0');
				R_xpix <= 0;
				R_xcol <= 0;
				
        else
		  
				 if fetch_next='1' then
				 
						if R_osd_x = C_resolution_x - 1 then
						
						  R_xpix <= 0;
						  R_xcol <= 0;
						  R_osd_x <= (others => '0');
						  R_osd_y <= R_osd_y+1;
						  
						else
						
						  if R_osd_x(0) = '0' then -- doublesize x
						  
								 if R_xpix = 5 then
									R_xpix <= 0;
									R_xcol <= R_xcol + 1;
								 else
									R_xpix <= R_xpix + 1;
								 end if;
							 
						  end if;
						  
						  R_osd_x <= R_osd_x+1;
						  
						end if;
						
						if R_osd_x > C_digits*6*2 + 503 and R_osd_x < C_digits*6*2 + 528 and R_osd_y >= 368 and R_osd_y < 384 then
				  --    if R_osd_x < C_digits*6*2 and R_osd_y > 96 and  R_osd_y < 112 then --define a posição X e Y que vai aparecer o OSD
						  R_osd_out <= S_osd_pixel;
						else
						 R_osd_out <= '0';
					  end if;
					  
				end if;
        end if;
		  
      end if;
    end process;
	 
    osd_out <= R_osd_out;
	 
end Behavioral;
