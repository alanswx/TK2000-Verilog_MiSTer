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

entity per_test1 is
	port (
		reset_i				: in  std_logic;
		clock_14m_i			: in  std_logic;
		clock_q3_i			: in  std_logic;
		phi0_i				: in  std_logic;
		addr_i				: in  std_logic_vector(7 downto 0);
		data_i				: in  std_logic_vector(7 downto 0);
		data_o				: out std_logic_vector(7 downto 0);
		read_write_i		: in  std_logic;							-- 1 = write
		io_sel_n_i			: in  std_logic;							-- $C1xx
		dev_sel_n_i			: in  std_logic;							-- $C09x
		--
		dados1_o				: out std_logic_vector(7 downto 0);
		dados2_o				: out std_logic_vector(7 downto 0);
		dados1_i				: in  std_logic_vector(7 downto 0)
	);
end entity;

architecture Behavior of per_test1 is

	signal dados1_q	: std_logic_vector(7 downto 0);
	signal dados2_q	: std_logic_vector(7 downto 0);

begin

	-- process dev_sel_n
	process (reset_i, clock_q3_i)
	begin
		if reset_i = '1' then
			dados1_q		<= (others => '0');
			dados2_q		<= (others => '0');
		elsif falling_edge(clock_q3_i) then
			if phi0_i = '1' and dev_sel_n_i = '0' and read_write_i = '1' then
				if addr_i = X"90" then
					dados1_q	<= data_i;
				elsif addr_i = X"91" then
					dados2_q	<= data_i;
				end if;
			end if; -- phi0_i and dev_sel_n_i
		end if; -- rising_edge
	end process;

	dados1_o <= dados1_q;
	dados2_o	<= dados2_q;

	data_o	<= --rom_data_s	when io_sel_n_i = '0'	else
					dados1_q			when dev_sel_n_i = '0' and read_write_i = '0' and addr_i = X"90"	else
					dados2_q			when dev_sel_n_i = '0' and read_write_i = '0' and addr_i = X"91"	else
					dados1_i			when dev_sel_n_i = '0' and read_write_i = '0' and addr_i = X"92"	else
					(others => '1');

end architecture;