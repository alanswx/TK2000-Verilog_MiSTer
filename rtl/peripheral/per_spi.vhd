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
-- fase 0		___|----|____|----|____|-----
-- fase 1		----|____|----|____|----|____
-- fase 2		____|----|____|----|____|----
-- Clock Q3		--|_|--|_|--|_|--|_|--|_|--|_
-- R/W da CPU	
-- Address bus	---------X---------X---------
-- Dados capt	---O---------O---------O-----
-- CPU Dout		-------O-X-------O-X-------O-
-- IO & DevSel	---------X---------X---------
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity per_spi is
	port (
		por_i					: in  std_logic;
		reset_i				: in  std_logic;
		clock_i				: in  std_logic;
		clock_q3_i			: in  std_logic;
		phi0_i				: in  std_logic;
		addr_i				: in  std_logic_vector(7 downto 0);
		data_i				: in  std_logic_vector(7 downto 0);
		data_o				: out std_logic_vector(7 downto 0);
		read_write_i		: in  std_logic;							-- 1 = write
		dev_sel_n_i			: in  std_logic;							-- $C09x
		-- IPL
		key_opt_i			: in  std_logic;
		ipl_o					: out std_logic;
		reset_o				: out std_logic;
		-- SD card interface
		spi_cs_n_o			: out std_logic;
		spi_sclk_o			: out std_logic;
		spi_mosi_o			: out std_logic;
		spi_miso_i			: in  std_logic;
		-- Debug
		debug_o				: out std_logic_vector(7 downto 0)
	);
end entity;

architecture Behavior of per_spi is

	signal sck_delayed_s	: std_logic;
	signal counter_s		: unsigned(3 downto 0);
	signal acc_edge_s		: std_logic_vector(1 downto 0);
	-- Shift register has an extra bit because we write on the
	-- falling edge and read on the rising edge
	signal shift_r			: std_logic_vector(8 downto 0);
	signal data_r			: std_logic_vector(7 downto 0);
	signal busy_s			: std_logic;
	signal status_s		: std_logic_vector(7 downto 0);
	signal ipl_s			: std_logic								:= '0';
	signal reset_cnt_s	: unsigned(7 downto 0);

begin

	-- Leitura das portas
	data_o	<= status_s			when dev_sel_n_i = '0' and read_write_i = '0' and addr_i = X"90"  else
				   data_r			when dev_sel_n_i = '0' and read_write_i = '0' and addr_i = X"91"  else
				   (others => '1');

	--------------------------------------------------
	-- Essa parte lida com a porta SPI por hardware --
	--      Implementa um SPI Master Mode 0         --
	--------------------------------------------------

	status_s	<= (0 => busy_s, 1 => key_opt_i, others => '0');
	busy_s	<= '1' when counter_s /= "1111"	else '0';

	process(por_i, clock_q3_i)
	begin
		if por_i = '1' then
			ipl_s			<= '1';
			debug_o		<= (others => '0');
			reset_o 		<= '0';
			reset_cnt_s	<= (others => '0');
			spi_cs_n_o	<= '1';
		elsif falling_edge(clock_q3_i) then
			if phi0_i = '1' and dev_sel_n_i = '0' and read_write_i = '1' then
				if addr_i = X"90" then
					spi_cs_n_o	<= data_i(0);
				elsif addr_i = X"97" and ipl_s = '1' then
					ipl_s		<= '0';
					reset_cnt_s	<= (others => '1');
				elsif addr_i = X"9F" then
					debug_o	<= data_i;
				end if;
			end if;
			if reset_cnt_s = 0 then
				reset_o <= '0';
			else
				reset_o <= '1';
				reset_cnt_s <= reset_cnt_s - 1;
			end if;
		end if;
	end process;

	ipl_o <= ipl_s;
	
	-- SD card outputs from clock divider and shift register
	spi_sclk_o  <= sck_delayed_s;
	spi_mosi_o  <= shift_r(8);

	-- Atrasa SCK para dar tempo do bit mais significativo mudar de estado e acertar MOSI antes do SCK
	process (clock_i, reset_i)
	begin
		if reset_i = '1' then
			sck_delayed_s <= '0';
		elsif rising_edge(clock_i) then
			sck_delayed_s <= not counter_s(0);
		end if;
	end process;

	-- SPI write
	process(clock_i, reset_i)
		variable access_v	: std_logic;
	begin		
		if reset_i = '1' then
			shift_r		<= (others => '1');
			data_r		<= (others => '1');
			counter_s	<= "1111"; -- Idle
		elsif rising_edge(clock_i) then
			if counter_s = "1111" then
				data_r		<= shift_r(7 downto 0);		-- Store previous shift register value in input register
				shift_r(8)	<= '1';							-- MOSI repousa em '1'

				-- Detectar escrita na porta 91
				acc_edge_s	<= acc_edge_s(0) & access_v;
				if clock_q3_i = '0' and phi0_i = '0' and dev_sel_n_i = '0' and addr_i = X"91" then
					access_v	:= '1';
				else
					access_v	:= '0';
				end if;

				-- Idle - check for a bus access
				if acc_edge_s = "01" then	-- rising edge
					-- Write loads shift register with data
					-- Read loads it with all 1s
					if read_write_i = '0' then
						shift_r <= (others => '1');								-- Uma leitura seta 0xFF para enviar e dispara a transmissão
					else
						shift_r <= data_i & '1';									-- Uma escrita seta o valor a enviar e dispara a transmissão
					end if;
					counter_s <= "0000"; -- Initiates transfer
				end if;
			else
				counter_s <= counter_s + 1;										-- Transfer in progress

				if sck_delayed_s = '0' then
					shift_r(0)	<= spi_miso_i;										-- Input next bit on rising edge
				else
					shift_r		<= shift_r(7 downto 0) & '1';					-- Output next bit on falling edge
				end if;
			end if;
		end if;
	end process;

end architecture;