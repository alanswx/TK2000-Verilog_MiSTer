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
-- Apple ][ Video Generation Logic
--
-- Stephen A. Edwards, sedwards@cs.columbia.edu
--
-- This takes data from memory and various mode switches to produce the
-- serial one-bit video data stream.
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_generator is
	port (
		CLK_14M			: in   std_logic;								-- 14.31818 MHz master clock
		CLK_7M			: in   std_logic;
		AX					: in   std_logic;
		CAS_N				: in   std_logic;
		H_count			: in   std_logic_vector(6 downto 0);
		VA					: in   std_logic;
		VB					: in   std_logic;
		VC					: in   std_logic;
		V_count			: in   std_logic_vector(5 downto 0);
		HBL				: in   std_logic;
		VBL				: in   std_logic;
		BLANK				: in   std_logic;
		DL					: in   std_logic_vector(7 downto 0);	-- Data from RAM
		LD194				: in   std_logic;
		VIDEO				: out  std_logic;
		hsync_n			: out  std_logic;
		vsync_n			: out  std_logic
	);
end entity;

architecture rtl of video_generator is

  signal blank_delayed		: std_logic;
  signal video_sig			: std_logic;							-- output of B10 p5
  signal graph_shiftreg		: std_logic_vector(7 downto 0);
  signal pixel_d7				: std_logic;
  signal hires_delayed		: std_logic;							-- A11 p9
 
begin


	A8A10_74LS194 : process (CLK_14M)
	begin
		if rising_edge(CLK_14M) then
			if LD194 = '0' then
				pixel_d7 <= DL(7);
			end if;
		end if;
	end process;

	-- A pair of four-bit universal shift registers that either
	-- shift the whole byte (hires mode) or rotate the two nibbles (lores mode)
	B4B9_74LS194 : process (CLK_14M)
	begin
		if rising_edge(CLK_14M) then
			if LD194 = '0' then
				graph_shiftreg <= DL;
			else
				if CLK_7M = '0' then
					graph_shiftreg <= graph_shiftreg(4) & graph_shiftreg(7 downto 1);
				end if;
			end if;
		end if;
	end process;

	-- Synchronize BLANK to LD194
	A10_74LS194: process (CLK_14M)
	begin
		if rising_edge(CLK_14M) then
			if LD194 = '0' then
				blank_delayed <= BLANK;
			end if;
		end if;
	end process;

	-- Shift hires pixels by one 14M cycle to get orange and blue
	A11_74LS74 : process (CLK_14M)
	begin
		if rising_edge(CLK_14M) then
			hires_delayed <= graph_shiftreg(0);
		end if;
	end process;  

	-- Video output mux and flip-flop
	A9B10_74LS151 : process (CLK_14M)
	begin
		if rising_edge(CLK_14M) then
			if blank_delayed = '1' then
				video_sig <= '0';
			else
				if pixel_d7 = '0' then
					video_sig <= graph_shiftreg(0); 		-- . x x .
				else
					video_sig <= hires_delayed;			--  . x x .
				end if;
			end if;
		end if;
	end process;

  VIDEO <= video_sig;
  
  hsync_n 	<= HBL nand H_count(3);
  vsync_n	<= not (VBL and 
	((not (VC nor V_count(0)))	nor V_count(1)) and V_count(2));

	-- Cores:
	-- 0,3 = 00 00 00
	--   1 = 2F B8 1F
	--   2 = C8 47 E4
	-- 4,7 = F5 FA FF
	--   5 = C7 70 28
	--   6 = 30 8F E3
	
end architecture;
