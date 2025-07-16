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
-- Apple ][ Timing logic
--
-- Stephen A. Edwards, sedwards@cs.columbia.edu
--
-- Taken more-or-less verbatim from the schematics in the
-- Apple ][ reference manual
--
-- This takes a 14.31818 MHz master clock and divides it down to generate
-- the various lower-frequency signals (e.g., 7M, phase 0, colorburst)
-- as well as horizontal and vertical blanking and sync signals for the video
-- and the video addresses.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timing_generator is
	port (
		clock_14_i			: in  std_logic;								-- 14.31818 MHz master clock
		clock_7_o			: out std_logic := '0';
		q3_o					: out std_logic := '0';						-- 2 MHz signal in phase with PHI0
		ras_n_o				: out std_logic := '0';
		cas_n_o				: out std_logic := '0';
		ax_o					: out std_logic := '0';
		phi0_o				: out std_logic := '0';						-- phase 0
		phi1_o				: out std_logic := '0';						-- phase 1
		phi2_o				: out std_logic := '0';						-- phase 1
		color_ref_o			: out std_logic := '0';						-- 3.579545 MHz colorburst

		page2_i				: in std_logic;

		video_addr_o		: out std_logic_vector(15 downto 0);
		h_count_o			: out std_logic_vector(6 downto 0);
		va_o					: out std_logic;								-- Character row address
		vb_o					: out std_logic;
		vc_o					: out std_logic;
		v_count_o			: out std_logic_vector(5 downto 0);
		hbl_o					: out std_logic;								-- Horizontal blanking
		vbl_o					: out std_logic;								-- Vertical blanking
		blank_o				: out std_logic;								-- Composite blanking
		ld194_o				: out std_logic								-- Load graph data
	);

end entity;

architecture rtl of timing_generator is

	signal H_s					: unsigned(6 downto 0) := "0000000";
	signal V_s					: unsigned(8 downto 0) := "011111010";
	signal video_addr_s		: unsigned(15 downto 0);
	signal COLOR_DELAY_N_s	: std_logic		:= '0';
	signal clk7_s				: std_logic		:= '0';
	signal q3_s					: std_logic		:= '0';
	signal ras_n_s				: std_logic		:= '0';
	signal cas_n_s				: std_logic		:= '0';
	signal ax_s					: std_logic		:= '0';
	signal phi0_s				: std_logic		:= '0';
	signal phi2_s				: std_logic		:= '0';
	signal color_ref_s		: std_logic		:= '0';
	signal hbl_s				: std_logic		:= '0';
	signal vbl_s				: std_logic		:= '0';
  
begin

	-- To generate the once-a-line hiccup: D1 pin 6
	COLOR_DELAY_N_s <= not (not color_ref_s and (not ax_s and not cas_n_s) and phi2_s and not H_s(6));

	-- The DRAM signal generator
	C2_74S195: process (clock_14_i)
	begin
		if rising_edge(clock_14_i) then
			if q3_s = '1' then			-- shift
				(q3_s, cas_n_s, ax_s, ras_n_s) <= unsigned'(cas_n_s, ax_s, ras_n_s, '0');
			else              		 	-- load
				(q3_s, cas_n_s, ax_s, ras_n_s) <= unsigned'(ras_n_s, ax_s, COLOR_DELAY_N_s, ax_s);
			end if;
		end if;
	end process;
  
	q3_o 		<= q3_s;
	ras_n_o	<= ras_n_s;
	cas_n_o	<= cas_n_s;
	ax_o		<= ax_s;

	-- The main clock signal generator
	B1_74S175 : process (clock_14_i)
	begin
		if rising_edge(clock_14_i) then
			color_ref_s <= clk7_s xor color_ref_s;
			clk7_s <= not clk7_s;
			phi2_s <= phi0_s;
			if ax_s = '1' then
				phi0_s <= not (q3_s xor phi2_s);  -- B1 pin 10
			end if;
		end if;
	end process;
  
	clock_7_o	<= clk7_s;
	phi0_o		<= phi0_s;
	phi1_o		<= not phi2_s;
	phi2_o		<= phi2_s;
	color_ref_o	<= color_ref_s;
	ld194_o		<= not (phi2_s and not ax_s and not cas_n_s and not clk7_s);

	-- Four four-bit presettable binary counters
	-- Seven-bit horizontal counter counts 0, 40, 41, ..., 7F (65 states)
	-- Nine-bit vertical counter counts $FA .. $1FF  (262 states)
	D11D12D13D14_74LS161 : process (clock_14_i)
	begin
		if rising_edge(clock_14_i) then
			-- True the cycle before the rising edge of LDPS_N: emulates
			-- the effects of using LDPS_N as the clock for the video counters
			if (phi2_s and not ax_s and ((q3_s and ras_n_s) or
					(not q3_s and COLOR_DELAY_N_s))) = '1' then
				if H_s(6) = '0' then
					H_s <= "1000000";
				else
					H_s <= H_s + 1;
					if H_s = "1111111" then
						V_s <= V_s + 1;
						if V_s = "111111111" then
							V_s <= "011111010";
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	h_count_o <= std_logic_vector(H_s);
	va_o <= V_s(0);
	vb_o <= V_s(1);
	vc_o <= V_s(2);
	v_count_o <= std_logic_vector(V_s(8 downto 3));

	hbl_s		<= not (H_s(5) or (H_s(3) and H_s(4)));
	vbl_s		<= V_s(6) and V_s(7);

	blank_o	<= hbl_s or vbl_s;
	hbl_o		<= hbl_s;
	vbl_o		<= vbl_s;

	-- Video address calculation
	video_addr_s(15)					<= page2_i;					-- 2000 ou A000
	video_addr_s(14 downto 13)		<= "01";
	video_addr_s(12 downto 10)		<= V_s(2 downto 0);
	video_addr_s(9 downto 7)		<= V_s(5 downto 3);
	video_addr_s(6 downto 3)		<= (not H_s(5) &     V_s(6) & H_s(4) & H_s(3)) +
                                 (    V_s(7) & not H_s(5) & V_s(7) &  '1') +
                                 (                     "000" & V_s(6));
	video_addr_s(2 downto 0)		<= H_s(2 downto 0);

	video_addr_o <= std_logic_vector(video_addr_s);
  
end rtl;
