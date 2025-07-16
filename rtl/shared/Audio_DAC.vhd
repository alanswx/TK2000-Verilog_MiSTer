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
-- Copyright (c) 2016 - Fabio Belavenuto & Victor Trucco
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
-- Abstracao do audio para Delta-Sigma DAC
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity Audio_DAC is
	port (
		clock_i	: in    std_logic;
		reset_i	: in    std_logic;
		ear_i		: in    std_logic;
		mic_i		: in    std_logic;
		spk_i		: in    std_logic;
		step_i   :in std_logic;
		dac_r_o	: out   std_logic;
		dac_l_o	: out   std_logic;
		pcm_out_o: out std_logic_vector(7 downto 0)
	);
end entity;

architecture Behavior of Audio_DAC is

	signal pcm_out_s			: std_logic_vector(7 downto 0);
	signal spk_s				: std_logic_vector(7 downto 0);
	signal mic_s				: std_logic_vector(7 downto 0);
	signal ear_s				: std_logic_vector(7 downto 0);
	signal step_s				: std_logic_vector(7 downto 0);
	constant spk_volume_c	: std_logic_vector(7 downto 0) := "01000000";
	constant mic_volume_c	: std_logic_vector(7 downto 0) := "00010000";
	constant ear_volume_c	: std_logic_vector(7 downto 0) := "00000100";
	constant step_volume_c	: std_logic_vector(7 downto 0) := "10000000";

begin

	

	audioL : entity work.dac
	generic map (
		msbi_g	=> 7
	)
	port map (
		clk_i		=> clock_i,
		res_i		=> reset_i,
		dac_i		=> pcm_out_s,
		dac_o		=> dac_l_o
	);

	audioR : entity work.dac
	generic map (
		msbi_g	=> 7
	)
	port map (
		clk_i		=> clock_i,
		res_i		=> reset_i,
		dac_i		=> pcm_out_s,
		dac_o		=> dac_r_o
	);

	spk_s <= spk_volume_c when spk_i = '1' else (others => '0');
	mic_s <= mic_volume_c when mic_i = '1' else (others => '0');
	ear_s <= ear_volume_c when ear_i = '1' else (others => '0');
	step_s <= step_volume_c when step_i = '1' else (others => '0');

	pcm_out_s <= std_logic_vector(
						unsigned(spk_s) + 
						unsigned(mic_s) + 
						unsigned(ear_s) +
						unsigned(step_s)
					);
					
	pcm_out_o <= pcm_out_s;

end architecture;