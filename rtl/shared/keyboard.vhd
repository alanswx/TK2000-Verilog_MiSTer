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
		
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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

-- PS/2 scancode to TK2000 matrix conversion
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.keyscans.all;

entity keyboard is
	generic (
		clkfreq_g			: integer										-- This is the system clock value in kHz
	);
	port (
		clock_i				: in    std_logic;
		reset_i				: in    std_logic;
		-- PS/2 interface
		ps2_clk_io			: inout std_logic;
		ps2_data_io			: inout std_logic;
		-- Row input
		rows_i				: in    std_logic_vector(7 downto 0);
		row_ctrl_i			: in    std_logic;
		-- Column output
		cols_o				: out   std_logic_vector(5 downto 0);
		FKeys_o				: out   std_logic_vector(12 downto 1);
    	osd_o 	 : out std_logic_vector(7 downto 0)
	);
end entity;

--TK2000 matrix
--
--   col		5		4		3		2		1		0
-- row 8												CTRL
-- row 7		?/		.>		,<		M		N		RETURN
-- row 6		:;		L@		K^		J		H		(up)
-- row 5		P+		O=		I-		U		Y		(down)
-- row 4		0*		9)		8(		7'		6&		(->)
-- row 3		1!		2"		3#		4$		5%		(<-)
-- row 2		Q		W		E		R		T		SPACE
-- row 1		A		S		D		F		G		
-- row 0		Z		X		C		V		B		SHIFT
--

architecture rtl of keyboard is

	-- Interface to PS/2 block
	signal keyb_data_s		:   std_logic_vector(7 downto 0);
	signal keyb_valid_s		:   std_logic;
	signal osd_s    :   std_logic_vector(7 downto 0);

	-- Internal signals
	type key_matrix_t is array (8 downto 0) of std_logic_vector(5 downto 0);
	signal keys_s				: key_matrix_t;
	signal shift_s				: std_logic;
	signal release_s			: std_logic;
	signal extended_s			: std_logic;
	signal k1_s, k2_s, k3_s,
		k4_s, k5_s,	k6_s,
		k7_s, k8_s, k9_s		: std_logic_vector(5 downto 0);
	signal idata_s				: std_logic_vector(7 downto 0);
	signal idata_rdy_s		: std_logic                     := '0';

begin

  osd_o <= osd_s;
  
	-- PS/2 interface
	ps2 : entity work.ps2_iobase
	generic map (
		clkfreq_g		=> clkfreq_g
	)
	port map (
		enable_i			=> '1',
		clock_i			=> clock_i,
		reset_i			=> reset_i,
		ps2_data_io		=> ps2_data_io,
		ps2_clk_io		=> ps2_clk_io,
		data_rdy_i		=> idata_rdy_s,
		data_i			=> idata_s,
		send_rdy_o		=> open,
		data_rdy_o		=> keyb_valid_s,
		data_o			=> keyb_data_s
	);

	-- Mesclagem das linhas
	k1_s <= keys_s(0) when rows_i(0)  = '1' else (others => '0');
	k2_s <= keys_s(1) when rows_i(1)  = '1' else (others => '0');
	k3_s <= keys_s(2) when rows_i(2)  = '1' else (others => '0');
	k4_s <= keys_s(3) when rows_i(3)  = '1' else (others => '0');
	k5_s <= keys_s(4) when rows_i(4)  = '1' else (others => '0');
	k6_s <= keys_s(5) when rows_i(5)  = '1' else (others => '0');
	k7_s <= keys_s(6) when rows_i(6)  = '1' else (others => '0');
	k8_s <= keys_s(7) when rows_i(7)  = '1' else (others => '0');
	k9_s <= keys_s(8) when row_ctrl_i = '1' else (others => '0');

	cols_o <= k1_s or k2_s or k3_s or k4_s or k5_s or k6_s or k7_s or k8_s or k9_s;


	process (reset_i, clock_i)
		variable keyb_valid_edge_v	: std_logic_vector(1 downto 0)	:= "00";
		variable sendresp_v			: std_logic := '0';
	begin
		if reset_i = '1' then

			keyb_valid_edge_v	:= "00";
			release_s 			<= '1';
			extended_s 			<= '0';
			
			osd_s <= (others => '1');

			keys_s(0) <= (others => '0');
			keys_s(1) <= (others => '0');
			keys_s(2) <= (others => '0');
			keys_s(3) <= (others => '0');
			keys_s(4) <= (others => '0');
			keys_s(5) <= (others => '0');
			keys_s(6) <= (others => '0');
			keys_s(7) <= (others => '0');
			keys_s(8) <= (others => '0');

			FKeys_o <= (others => '0');

		elsif rising_edge(clock_i) then

			keyb_valid_edge_v := keyb_valid_edge_v(0) & keyb_valid_s;
			if keyb_valid_edge_v = "01" then
				if keyb_data_s = X"AA" then
					sendresp_v := '1';
				elsif keyb_data_s = X"E0" then
					-- Extended key code follows
					extended_s <= '1';
				elsif keyb_data_s = X"F0" then
					-- Release code follows
					release_s <= '0';
				else
					-- Cancel extended/release flags for next time
					release_s <= '1';
					extended_s <= '0';
					
					osd_s <= (others => '1');

					if extended_s = '0' then
					
						if keyb_data_s = KEY_F12 and release_s = '1' then
							osd_s(7 downto 5) <= "001"; -- OSD data pump command
						else
							osd_s(7 downto 5) <= "111"; -- release
						end if;
					
						-- Normal scancodes
						
						case keyb_data_s is
							when KEY_LSHIFT		=> shift_s <= release_s; -- Left shift
							when KEY_RSHIFT 		=> shift_s <= release_s; -- Right shift
							when others				=> null;
						end case;

						if shift_s = '0' then

							case keyb_data_s is
								
								when KEY_B 				=> keys_s(0)(1) <= release_s;                        -- B
								when KEY_V 				=> keys_s(0)(2) <= release_s;                        -- V
								when KEY_C 				=> keys_s(0)(3) <= release_s;                        -- C
								when KEY_X 				=> keys_s(0)(4) <= release_s;                        -- X
								when KEY_Z      		=> keys_s(0)(5) <= release_s;                        -- Z

								when KEY_G 				=> keys_s(1)(1) <= release_s;                        -- G
								when KEY_F 				=> keys_s(1)(2) <= release_s;                        -- F
								when KEY_D 				=> keys_s(1)(3) <= release_s;                        -- D
								when KEY_S 				=> keys_s(1)(4) <= release_s;                        -- S
								when KEY_A 				=> keys_s(1)(5) <= release_s;                        -- A

								when KEY_SPACE 		=> keys_s(2)(0) <= release_s;                        -- SPACE
								when KEY_T 				=> keys_s(2)(1) <= release_s;                        -- T
								when KEY_R 				=> keys_s(2)(2) <= release_s;                        -- R
								when KEY_E 				=> keys_s(2)(3) <= release_s;                        -- E
								when KEY_W 				=> keys_s(2)(4) <= release_s;                        -- W
								when KEY_Q 				=> keys_s(2)(5) <= release_s;                        -- Q

								when KEY_BACKSPACE	=> keys_s(3)(0) <= release_s;                        -- Backspace (<-)
								when KEY_5 				=> keys_s(3)(1) <= release_s;                        -- 5 %
								when KEY_4 				=> keys_s(3)(2) <= release_s;                        -- 4 $
								when KEY_3 				=> keys_s(3)(3) <= release_s;                        -- 3 #
								when KEY_2 				=> keys_s(3)(4) <= release_s;                        -- 2 @
								when KEY_1 				=> keys_s(3)(5) <= release_s;                        -- 1 !

								when KEY_6 				=> keys_s(4)(1) <= release_s;                        -- 6 ¨ 
								when KEY_7 				=> keys_s(4)(2) <= release_s;                        -- 7 &
								when KEY_8 				=> keys_s(4)(3) <= release_s;                        -- 8 *
								when KEY_9 				=> keys_s(4)(4) <= release_s;                        -- 9 (
								when KEY_0 				=> keys_s(4)(5) <= release_s;                        -- 0 )

								when KEY_Y 				=> keys_s(5)(1) <= release_s;                        -- Y
								when KEY_U 				=> keys_s(5)(2) <= release_s;                        -- U
								when KEY_I 				=> keys_s(5)(3) <= release_s;                        -- I
								when KEY_O 				=> keys_s(5)(4) <= release_s;                        -- O
								when KEY_P 				=> keys_s(5)(5) <= release_s;                        -- P

								when KEY_H 				=> keys_s(6)(1) <= release_s;                        -- H
								when KEY_J 				=> keys_s(6)(2) <= release_s;                        -- J
								when KEY_K 				=> keys_s(6)(3) <= release_s;                        -- K
								when KEY_L 				=> keys_s(6)(4) <= release_s;                        -- L
								when KEY_TWOPOINT		=> keys_s(6)(5) <= release_s; keys_s(0)(0) <= release_s; -- ; :	(Invertido, setar SHIFT)

								when KEY_ENTER			=> keys_s(7)(0) <= release_s;  	osd_s(4) <= not release_s;                      -- ENTER
								when KEY_N 				=> keys_s(7)(1) <= release_s;                        -- N
								when KEY_M 				=> keys_s(7)(2) <= release_s;                        -- M
								when KEY_COMMA			=> keys_s(7)(3) <= release_s;                        -- ,
								when KEY_KPCOMMA		=> keys_s(7)(3) <= release_s;                        -- ,
								when KEY_POINT			=> keys_s(7)(4) <= release_s;                        -- .
								when KEY_KPPOINT		=> keys_s(7)(4) <= release_s;                        -- .
								when KEY_SLASH			=> keys_s(7)(5) <= release_s; keys_s(0)(0) <= release_s; -- / ?	(Invertido, setar SHIFT)

								when KEY_KP0         => keys_s(4)(5) <= release_s;                        -- 0
								when KEY_KP1			=> keys_s(3)(5) <= release_s;                        -- 1
								when KEY_KP2			=> keys_s(3)(4) <= release_s;                        -- 2
								when KEY_KP3			=> keys_s(3)(3) <= release_s;                        -- 3
								when KEY_KP4			=> keys_s(3)(2) <= release_s;                        -- 4
								when KEY_KP5			=> keys_s(3)(1) <= release_s;                        -- 5
								when KEY_KP6			=> keys_s(4)(1) <= release_s;                        -- 6
								when KEY_KP7			=> keys_s(4)(2) <= release_s;                        -- 7
								when KEY_KP8			=> keys_s(4)(3) <= release_s;                        -- 8
								when KEY_KP9			=> keys_s(4)(4) <= release_s;                        -- 9

								when KEY_LCTRL 		=> keys_s(8)(0) <= release_s;                        -- Left CTRL

								-- Other special keys sent as key combinations
								when KEY_MINUS			=> keys_s(5)(3) <= release_s; keys_s(0)(0) <= release_s; -- - _ (SHIFT + I)
								when KEY_KPMINUS		=> keys_s(5)(3) <= release_s; keys_s(0)(0) <= release_s; -- -   (SHIFT + I)
								when KEY_BL				=> keys_s(4)(2) <= release_s; keys_s(0)(0) <= release_s; -- ' " (SHIFT + 7)
								when KEY_EQUAL			=> keys_s(5)(4) <= release_s; keys_s(0)(0) <= release_s; -- = + (SHIFT + O)
								when KEY_KPASTER		=> keys_s(4)(5) <= release_s; keys_s(0)(0) <= release_s; -- *   (SHIFT + 0)
								when KEY_KPPLUS		=> keys_s(5)(5) <= release_s; keys_s(0)(0) <= release_s; -- +   (SHIFT + P)
								
								-- Teclas para o FPGA e nao para o micro
								when KEY_F1				=> FKeys_o(1)	<= release_s;
								when KEY_F2				=> FKeys_o(2)	<= release_s;
								when KEY_F3				=> FKeys_o(3)	<= release_s;
								when KEY_F4				=> FKeys_o(4)	<= release_s;
								when KEY_F5				=> FKeys_o(5)	<= release_s;
								when KEY_F6				=> FKeys_o(6)	<= release_s;
								when KEY_F7				=> FKeys_o(7)	<= release_s;
								when KEY_F8				=> FKeys_o(8)	<= release_s;
								when KEY_F9				=> FKeys_o(9)	<= release_s;
								when KEY_F10			=> FKeys_o(10)	<= release_s;
								when KEY_F11			=> FKeys_o(11)	<= release_s;
								when KEY_F12			=> FKeys_o(12)	<= release_s;

								when others =>
									null;
							end case;

						else -- if shift = 0

							-- SHIFT apertado
							case keyb_data_s is
								
								when KEY_B 				=> keys_s(0)(1) <= release_s; keys_s(0)(0) <= release_s; -- B
								when KEY_V 				=> keys_s(0)(2) <= release_s; keys_s(0)(0) <= release_s; -- V
								when KEY_C 				=> keys_s(0)(3) <= release_s; keys_s(0)(0) <= release_s; -- C
								when KEY_X 				=> keys_s(0)(4) <= release_s; keys_s(0)(0) <= release_s; -- X
								when KEY_Z      		=> keys_s(0)(5) <= release_s; keys_s(0)(0) <= release_s; -- Z

								when KEY_G 				=> keys_s(1)(1) <= release_s; keys_s(0)(0) <= release_s; -- G
								when KEY_F 				=> keys_s(1)(2) <= release_s; keys_s(0)(0) <= release_s; -- F
								when KEY_D 				=> keys_s(1)(3) <= release_s; keys_s(0)(0) <= release_s; -- D
								when KEY_S 				=> keys_s(1)(4) <= release_s; keys_s(0)(0) <= release_s; -- S
								when KEY_A 				=> keys_s(1)(5) <= release_s; keys_s(0)(0) <= release_s; -- A

								when KEY_SPACE 		=> keys_s(2)(0) <= release_s; keys_s(0)(0) <= release_s; -- SPACE
								when KEY_T 				=> keys_s(2)(1) <= release_s; keys_s(0)(0) <= release_s; -- T
								when KEY_R 				=> keys_s(2)(2) <= release_s; keys_s(0)(0) <= release_s; -- R
								when KEY_E 				=> keys_s(2)(3) <= release_s; keys_s(0)(0) <= release_s; -- E
								when KEY_W 				=> keys_s(2)(4) <= release_s; keys_s(0)(0) <= release_s; -- W
								when KEY_Q 				=> keys_s(2)(5) <= release_s; keys_s(0)(0) <= release_s; -- Q

								when KEY_BACKSPACE	=> keys_s(3)(0) <= release_s; keys_s(0)(0) <= release_s; -- Backspace (<-)
								when KEY_5 				=> keys_s(3)(1) <= release_s; keys_s(0)(0) <= release_s; -- 5 %
								when KEY_4 				=> keys_s(3)(2) <= release_s; keys_s(0)(0) <= release_s; -- 4 $
								when KEY_3 				=> keys_s(3)(3) <= release_s; keys_s(0)(0) <= release_s; -- 3 #
								when KEY_2 				=> keys_s(6)(4) <= release_s; keys_s(0)(0) <= release_s; -- 2 @	(SHIFT + L)
								when KEY_1 				=> keys_s(3)(5) <= release_s; keys_s(0)(0) <= release_s; -- 1 !

--								when KEY_6 				=> keys(x)(x) <= release_s; keys(0)(0) <= release_s; -- 6 ¨  (nao existe)
								when KEY_7 				=> keys_s(4)(1) <= release_s; keys_s(0)(0) <= release_s; -- 7 &  (SHIFT + 6)
								when KEY_8 				=> keys_s(4)(5) <= release_s; keys_s(0)(0) <= release_s; -- 8 *  (SHIFT + 0)
								when KEY_9 				=> keys_s(4)(3) <= release_s; keys_s(0)(0) <= release_s; -- 9 (  (SHIFT + 8)
								when KEY_0 				=> keys_s(4)(4) <= release_s; keys_s(0)(0) <= release_s; -- 0 )  (SHIFT + 9)

								when KEY_Y 				=> keys_s(5)(1) <= release_s; keys_s(0)(0) <= release_s; -- Y
								when KEY_U 				=> keys_s(5)(2) <= release_s; keys_s(0)(0) <= release_s; -- U
								when KEY_I 				=> keys_s(5)(3) <= release_s; keys_s(0)(0) <= release_s; -- I
								when KEY_O 				=> keys_s(5)(4) <= release_s; keys_s(0)(0) <= release_s; -- O
								when KEY_P 				=> keys_s(5)(5) <= release_s; keys_s(0)(0) <= release_s; -- P

								when KEY_H 				=> keys_s(6)(1) <= release_s; keys_s(0)(0) <= release_s; -- H
								when KEY_J 				=> keys_s(6)(2) <= release_s; keys_s(0)(0) <= release_s; -- J
								when KEY_K 				=> keys_s(6)(3) <= release_s; keys_s(0)(0) <= release_s; -- K
								when KEY_L 				=> keys_s(6)(4) <= release_s; keys_s(0)(0) <= release_s; -- L
								when KEY_TWOPOINT		=> keys_s(6)(5) <= release_s;                        -- ; :		(Invertido, não setar SHIFT)

								when KEY_ENTER			=> keys_s(7)(0) <= release_s; keys_s(0)(0) <= release_s; -- ENTER
								when KEY_N 				=> keys_s(7)(1) <= release_s; keys_s(0)(0) <= release_s; -- N
								when KEY_M 				=> keys_s(7)(2) <= release_s; keys_s(0)(0) <= release_s; -- M
								when KEY_COMMA			=> keys_s(7)(3) <= release_s; keys_s(0)(0) <= release_s; -- , <
								when KEY_KPCOMMA		=> keys_s(7)(3) <= release_s;                        -- ,
								when KEY_POINT			=> keys_s(7)(4) <= release_s; keys_s(0)(0) <= release_s; -- . >
								when KEY_KPPOINT		=> keys_s(7)(4) <= release_s;                        -- .
								when KEY_SLASH			=> keys_s(7)(5) <= release_s;                        -- / ?		(Invertido, nao setar SHIFT)

								when KEY_KP0         => keys_s(4)(5) <= release_s;                        -- 0
								when KEY_KP1			=> keys_s(3)(5) <= release_s;                        -- 1
								when KEY_KP2			=> keys_s(3)(4) <= release_s;                        -- 2
								when KEY_KP3			=> keys_s(3)(3) <= release_s;                        -- 3
								when KEY_KP4			=> keys_s(3)(2) <= release_s;                        -- 4
								when KEY_KP5			=> keys_s(3)(1) <= release_s;                        -- 5
								when KEY_KP6			=> keys_s(4)(1) <= release_s;                        -- 6
								when KEY_KP7			=> keys_s(4)(2) <= release_s;                        -- 7
								when KEY_KP8			=> keys_s(4)(3) <= release_s;                        -- 8
								when KEY_KP9			=> keys_s(4)(4) <= release_s;                        -- 9

								when KEY_LCTRL 		=> keys_s(8)(0) <= release_s; keys_s(0)(0) <= release_s; -- Left CTRL

								-- Other special keys sent as key combinations
--								when KEY_MINUS			=> keys_s(x)(x) <= release_s; keys_s(0)(0) <= release_s; -- - _   (nao existe)
								when KEY_KPMINUS		=> keys_s(5)(3) <= release_s; keys_s(0)(0) <= release_s; -- -     (SHIFT + I)
								when KEY_BL				=> keys_s(3)(4) <= release_s; keys_s(0)(0) <= release_s; -- ' "   (SHIFT + 2)
								when KEY_EQUAL			=> keys_s(5)(5) <= release_s; keys_s(0)(0) <= release_s; -- = +   (SHIFT + P)
								when KEY_KPASTER		=> keys_s(4)(5) <= release_s; keys_s(0)(0) <= release_s; -- *     (SHIFT + 0)
								when KEY_KPPLUS		=> keys_s(5)(5) <= release_s; keys_s(0)(0) <= release_s; -- +     (SHIFT + P)
								when KEY_TILDE			=> keys_s(6)(3) <= release_s; keys_s(0)(0) <= release_s; -- ~ ^   (SHIFT + K)

								when others =>
									null;
							end case;


						end if;	-- shift = 0

					else -- if extended = 0
						-- Extended scancodes

						if shift_s = '0' then

							-- sem shift
							case keyb_data_s is

								when KEY_KPENTER 		=> keys_s(7)(0) <= release_s; osd_s(4) <= not release_s;                        -- ENTER

								-- Cursor keys
								when KEY_LEFT			=>	keys_s(3)(0) <= release_s; osd_s(2) <= not release_s;                       -- Left
								when KEY_RIGHT			=>	keys_s(4)(0) <= release_s; osd_s(3) <= not release_s;                       -- Right
								when KEY_DOWN			=>	keys_s(5)(0) <= release_s; osd_s(1) <= not release_s;                       -- Down
								when KEY_UP				=>	keys_s(6)(0) <= release_s; osd_s(0) <= not release_s;                       -- Up
								when KEY_RCTRL			=> keys_s(8)(0) <= release_s;                        -- Right CTRL

								-- Other special keys sent as key combinations
								when KEY_KPSLASH 		=> keys_s(7)(5) <= release_s; keys_s(0)(0) <= release_s; -- / (SHIFT + ?)

								when others =>
									null;

							end case;

						else -- if shift = 0

							-- com shift
							case keyb_data_s is

								when KEY_KPENTER 		=> keys_s(7)(0) <= release_s; keys_s(0)(0) <= release_s; -- ENTER

								-- Cursor keys
								when KEY_LEFT			=>	keys_s(3)(0) <= release_s; keys_s(0)(0) <= release_s; -- Left
								when KEY_RIGHT			=>	keys_s(4)(0) <= release_s; keys_s(0)(0) <= release_s; -- Right
								when KEY_DOWN			=>	keys_s(5)(0) <= release_s; keys_s(0)(0) <= release_s; -- Down
								when KEY_UP				=>	keys_s(6)(0) <= release_s; keys_s(0)(0) <= release_s; -- Up
								when KEY_RCTRL			=> keys_s(8)(0) <= release_s; keys_s(0)(0) <= release_s; -- Right CTRL

								-- Other special keys sent as key combinations
								when KEY_KPSLASH 		=> keys_s(7)(5) <= release_s; keys_s(0)(0) <= release_s; -- / (SHIFT + ?)

								when others =>
									null;

								end case;

						end if; -- if shift = 0

					end if; -- if extended = 0

				end if; -- keyb_data = xx

			else -- keyb_valid_edge = 01
				if sendresp_v = '1' then
					sendresp_v 	:= '0';
					idata_s		<= X"55";
					idata_rdy_s	<= '1';
				else
					idata_rdy_s	<= '0';
				end if;
			end if; -- keyb_valid_edge = 01

		end if; -- if risingedge

	end process;

end architecture;
