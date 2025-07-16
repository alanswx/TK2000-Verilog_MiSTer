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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tk2000 is
	port (
		clock_14_i			: in   std_logic								:= '0';
		reset_i				: in   std_logic								:= '0';
		CPU_WAIT       		: in std_logic;
		-- RAM da CPU
		ram_addr_o			: out  std_logic_vector(15 downto 0)	:= (others => '0');
		ram_data_to_o		: out  std_logic_vector(7 downto 0)		:= (others => '0');
		ram_data_from_i		: in   std_logic_vector(7 downto 0)		:= (others => '0');
		ram_oe_o			: out  std_logic								:= '0';
		ram_we_o			: out  std_logic								:= '0';
		-- ROM
		rom_addr_o			: out  std_logic_vector(13 downto 0)	:= (others => '0');
		rom_data_from_i		: in   std_logic_vector(7 downto 0)		:= (others => '0');
		rom_oe_o			: out  std_logic								:= '0';
		rom_we_o			: out  std_logic								:= '0';
		-- Keyboard
		kbd_rows_o			: out  std_logic_vector(7 downto 0)		:= (others => '0');
		kbd_cols_i			: in   std_logic_vector(5 downto 0)		:= (others => '0');
		kbd_ctrl_o			: out  std_logic;
		keyhack : in std_logic;
		-- Audio
		spk_o				: out  std_logic								:= '0';
		-- Video
		video_color_o		: out  std_logic								:= '0';
		video_bit_o			: out  std_logic								:= '0';
		video_hsync_n_o		: out  std_logic								:= '0';
		video_vsync_n_o		: out  std_logic								:= '0';
		video_hbl_o			: out  std_logic								:= '0';
		video_vbl_o			: out  std_logic								:= '0';
		video_ld194_o		: out  std_logic								:= '0';
		-- Cassette
		cas_i				: in   std_logic								:= '0';
		cas_o				: out  std_logic								:= '0';
		cas_motor_o			: out  std_logic_vector(1 downto 0)		:= (others => '0');
		-- LPT
		lpt_stb_o			: out  std_logic								:= '0';
		lpt_busy_i			: in   std_logic								:= '0';
		-- Periferico
		phi0_o				: out  std_logic								:= '0';
		phi1_o				: out  std_logic								:= '0';
		phi2_o				: out  std_logic								:= '0';
		clock_2m_o			: out  std_logic								:= '0';
		read_write_o		: out  std_logic								:= '0';
		irq_n_i				: in   std_logic								:= '0';
		nmi_n_i				: in   std_logic								:= '0';
		dis_rom_i			: in   std_logic								:= '0';					-- Se 1 desabilita ROM ou RAM em $C1xx
		io_select_n_o		: out  std_logic								:= '1';					-- Sai 0 se dis_rom=1 e acesso em $C1xx
		dev_select_n_o		: out  std_logic								:= '1';					-- Sai 0 se acesso em $C09x
		per_addr_o			: out  std_logic_vector(7 downto 0)		:= (others => '0');				-- Address bus
		per_data_from_i		: in   std_logic_vector(7 downto 0)		:= (others => '0');
		per_data_to_o		: out  std_logic_vector(7 downto 0)		:= (others => '0');
		-- Debug
		D_cpu_pc_o			: out  std_logic_vector(15 downto 0)	:= (others => '0')

 
);
end entity;

architecture behavior of tk2000 is

 component sdram is
    port( sd_data : inout std_logic_vector(15 downto 0);
          sd_addr : out std_logic_vector(12 downto 0);
          sd_dqm : out std_logic_vector(1 downto 0);
          sd_ba : out std_logic_vector(1 downto 0);
          sd_cs : out std_logic;
          sd_we : out std_logic;
          sd_ras : out std_logic;
          sd_cas : out std_logic;
          init : in std_logic;
          clk : in std_logic;
          clkref : in std_logic;
          din : in std_logic_vector(7 downto 0);
          dout : out std_logic_vector(15 downto 0);
          aux : in std_logic;
          addr : in std_logic_vector(24 downto 0);
          we : in std_logic
    );
  end component;

--	signal reset_n				: std_logic;
	signal clock_7_s			: std_logic;
	signal clock_q3_s			: std_logic;

	-- CPU
	signal cpu_clock_s		: std_logic;
	signal cpu_addr_s			: std_logic_vector(23 downto 0);
--	signal cpu_addr_s			: std_logic_vector(15 downto 0);
	signal cpu_di_s			: std_logic_vector(7 downto 0);
	signal cpu_dout_s			: std_logic_vector(7 downto 0);
--	signal cpu_nmi_n_s		: std_logic;
--	signal cpu_irq_n_s		: std_logic;
	signal cpu_we_s			: std_logic;
	
	-- ROM
	signal rom_cs_s			: std_logic;

	-- RAM
	signal ram_cs_s			: std_logic;
--	signal cpu_d_latch_s		: std_logic_vector(7 downto 0);
	signal video_d_latch_s	: std_logic_vector(7 downto 0);
	signal ram_bank1_s		: std_logic;
	signal ram_bank2_s		: std_logic_vector(1 downto 0);
	signal ram_pre_wr_en_s	: std_logic;
	signal ram_write_en_s	: std_logic;
	signal ram_read_en_s		: std_logic;

	-- TemporizaÃ§Ã£o
	signal t_ras_n_s			: std_logic;
	signal t_cas_n_s			: std_logic;
	signal t_ax_s				: std_logic;
	signal t_phi0_s			: std_logic;
	signal t_phi1_s			: std_logic;
	signal t_phi2_s			: std_logic;

	-- VÃ­deo
	signal video_addr_s		: std_logic_vector(15 downto 0);
	signal video_hbl_s		: std_logic;
	signal video_vbl_s		: std_logic;
	signal video_blank_s		: std_logic;
	signal video_hcount_s	: std_logic_vector(6 downto 0);
	signal video_va_s			: std_logic;
	signal video_vb_s			: std_logic;
	signal video_vc_s			: std_logic;
	signal video_vcount_s	: std_logic_vector(5 downto 0);
	signal video_ld194_s		: std_logic;
--	signal video_colorref_s	: std_logic;

	-- I/O e Soft-switches
	signal softswitches_s	: std_logic_vector(7 downto 0) := "00000000";
	signal softswitch_cs_s	: std_logic;
	signal ss_color_s			: std_logic;
	signal ss_motorA_s		: std_logic;
	signal ss_page2_s			: std_logic;
	signal ss_motorB_s		: std_logic;
	signal ss_lpt_stb_s		: std_logic;
	signal ss_romram_s		: std_logic;
	signal ss_ctrl_s			: std_logic;
	signal kbd_data_s			: std_logic_vector(7 downto 0);
	signal io_sel_n_s			: std_logic;
	signal dev_sel_n_s		: std_logic;

	-- Keyboard
	signal kbd_o_cs_s			: std_logic;
	signal kbd_i_cs_s			: std_logic;

	-- Audio
	signal speaker_cs_s		: std_logic;
	signal speaker_s			: std_logic								:= '0';

	signal r_w_n : std_logic;

	
	-- Cassete
	signal cas_o_cs_s			: std_logic;
	signal cas_o_s				: std_logic								:= '0';

	

begin
  cpu6502 : entity work.T65
    port map (
      mode     => "00",
      clk      => cpu_clock_s,
      enable   => not CPU_WAIT,
      res_n    => not reset_i,

      Rdy      => '1',
      Abort_n  => '1',
      SO_n     => '1',

      IRQ_n    => irq_n_i,
      NMI_n    => nmi_n_i,
      R_W_n    => r_w_n,
      A        => cpu_addr_s,
      DI       => cpu_di_s,
      DO       => cpu_dout_s
    );

	 cpu_we_s<=not r_w_n;
	
--	cpu: entity work.cpu6502
--	generic map (
--		pipelineOpcode 	=> false,
--		pipelineAluMux 	=> false,
--		pipelineAluOut 	=> false
--	)
--	port map (
--		reset								=> reset_i,
--		clk								=> cpu_clock_s,
--      enable   =>not CPU_WAIT,
--		di									=> unsigned(cpu_di_s),
--		std_logic_vector(do)			=> cpu_dout_s,
--		std_logic_vector(addr)		=> cpu_addr_s,
--		we									=> cpu_we_s,
--		nmi_n								=> nmi_n_i,
--		irq_n								=> irq_n_i,
--		so_n								=> '1',
--
--		debugOpcode						=> open,
--		std_logic_vector(debugPc)	=> D_cpu_pc_o,
--		debugA							=> open,
--		debugX							=> open,
--		debugY							=> open,
--		debugS							=> open
--	);


	-- Temporizacoes
	timing: entity work.timing_generator
	port map (
		clock_14_i				=> clock_14_i,
		clock_7_o				=> clock_7_s,
		q3_o						=> clock_q3_s,
		ras_n_o					=> t_ras_n_s,
		cas_n_o					=> t_cas_n_s,
		ax_o						=> t_ax_s,
		phi0_o					=> t_phi0_s,
		phi1_o					=> t_phi1_s,
		phi2_o					=> t_phi2_s,
		color_ref_o				=> open,--video_colorref_s,
		page2_i					=> ss_page2_s,
		video_addr_o			=> video_addr_s,
		h_count_o				=> video_hcount_s,
		va_o						=> video_va_s,
		vb_o						=> video_vb_s,
		vc_o						=> video_vc_s,
		v_count_o				=> video_vcount_s,
		hbl_o						=> video_hbl_s,
		vbl_o						=> video_vbl_s,
		blank_o					=> video_blank_s,
		ld194_o					=> video_ld194_s
	);

	-- Gerador de Video
	video: entity work.video_generator
	port map (
		CLK_14M				=> clock_14_i,
		CLK_7M				=> clock_7_s,
		AX						=> t_ax_s,
		CAS_N					=> t_cas_n_s,
		H_count				=> video_hcount_s,
		VA						=> video_va_s,
		VB						=> video_vb_s,
		VC						=> video_vc_s,
		V_count				=> video_vcount_s,
		HBL					=> video_hbl_s,
		VBL					=> video_vbl_s,
		BLANK					=> video_blank_s,
		DL						=> video_d_latch_s,
		LD194					=> video_ld194_s,
		VIDEO					=> video_bit_o,
		hsync_n				=> video_hsync_n_o,
		vsync_n				=> video_vsync_n_o
	);

	-- CPU
	cpu_clock_s	<= t_phi1_s;

	-- Reset
--	reset_n		<= not reset;

	-- ROM (16K)
	rom_addr_o	<= cpu_addr_s(13 downto 0);
--	rom_oe_o		<= '1'		when rom_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '0' and t_ras_n_s = '0'		else '0';
--	rom_we_o		<= '1'		when rom_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '1' and t_ras_n_s = '0'		else '0';
	rom_oe_o		<= '1'		when rom_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '0' and clock_q3_s = '0'		else '0';
	rom_we_o		<= '1'		when rom_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '1' and clock_q3_s = '0'		else '0';

	-- RAM
	-- Endereco da RAM
	process (cpu_addr_s, t_phi1_s, video_addr_s)
	begin
		if t_phi1_s = '1' then
			ram_addr_o	<= video_addr_s;
		else
			ram_addr_o	<= cpu_addr_s(15 downto 0);
		end if;
	end process;

	ram_oe_o		<= '1' 	when ((ram_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '0') or t_phi1_s = '1' ) and clock_q3_s = '0' else '0';
	ram_we_o		<= '1' 	when   ram_cs_s = '1' and t_phi1_s = '0' and cpu_we_s = '1'                      and clock_q3_s = '0' else '0';

	-- Latch video RAM data on the rising edge of RAS
	process (clock_14_i)
	begin
		if rising_edge(clock_14_i) then
--			if t_ax_s = '1' and t_cas_n_s = '0' and t_ras_n_s = '0' then
			if t_ax_s = '1' and t_cas_n_s = '1' and t_ras_n_s = '1' then
				if t_phi1_s = '1' then
					video_d_latch_s <= ram_data_from_i;
				end if;
			end if;
		end if;
	end process;

	-- CPU
	ram_data_to_o	<= cpu_dout_s;
	per_data_to_o	<= cpu_dout_s;
	cpu_di_s			<=
							ram_data_from_i	when ram_cs_s = '1'		else
							kbd_data_s			when kbd_i_cs_s = '1'	else
							rom_data_from_i	when rom_cs_s = '1'		else
							per_data_from_i   when dis_rom_i = '1' else "00000000";									-- periferico

	kbd_data_s		<= cas_i & lpt_busy_i & kbd_cols_i;
	--kbd_data_s		<= '0'  & '0' & "100000" when keyhack = '0' else '0'  & '0' & "000000" ;

	-- Perifericos
	read_write_o	<= cpu_we_s;
	phi0_o			<= t_phi0_s;
	phi1_o			<= t_phi1_s;
	phi2_o			<= t_phi2_s;
	clock_2m_o		<= clock_q3_s;
	per_addr_o		<= cpu_addr_s(7 downto 0);
	io_select_n_o	<= io_sel_n_s;-- or t_phi1_s;		-- ativo somente quando phi1 for 0
	dev_select_n_o	<= dev_sel_n_s;-- or t_phi1_s;	-- ativo somente quando phi1 for 0

	-- Address Decoder
	process (cpu_addr_s, dis_rom_i, ss_romram_s)
	begin
		ram_cs_s				<= '0';
		kbd_o_cs_s			<= '0';
		kbd_i_cs_s			<= '0';
		cas_o_cs_s			<= '0';
		speaker_cs_s		<= '0';
		softswitch_cs_s	<= '0';
		dev_sel_n_s			<= '1';
		io_sel_n_s			<= '1';
		rom_cs_s				<= '0';

		case cpu_addr_s(15 downto 14) is
			when "00" | "01" | "10"	=>									-- 0000-BFFF = RAM
				ram_cs_s	<= '1';
			when "11" =>													-- C000-FFFF:

				case cpu_addr_s(13 downto 12) is
					when "00" =>											-- C000-CFFF:

						case cpu_addr_s(11 downto 8) is	
							when x"0" =>									-- C000-C0FF:

								case cpu_addr_s(7 downto 4) is
									when x"0" =>							-- C000-C00F = KBD OUT
										kbd_o_cs_s   <= '1';
									when x"1" =>							-- C010-C01F = KBD IN
										kbd_i_cs_s   <= '1';
									when x"2" =>							-- C020-C02F = K7 out
										cas_o_cs_s   <= '1';
									when x"3" =>							-- C030-C03F = Speaker Toggle
										speaker_cs_s <= '1';
									when x"4" =>							-- C040-C04F = ?
										null;
									when x"5" =>							-- C050-C05F = Soft Switches
										softswitch_cs_s <= '1';
									when x"6" =>							-- C060-C06F = ?
										null;
									when x"7" =>							-- C070-C07F = ?
										null;
									when x"8" =>							-- C080-C08F = Saturn 128K
--										ram_bank1		<= cpu_addr_s(3);
-- ram_bank2
--										ram_pre_wr_en	<= cpu_addr_s(0) and not cpu_we;
--										ram_write_en	<= cpu_addr_s(0) and ram_pre_wr_en and not cpu_we;
--										ram_read_en		<= not (cpu_addr_s(0) xor cpu_addr_s(1));

									when x"9" =>							-- C090-C09F = null / periferico
										dev_sel_n_s	<= '0';
									when x"A" | x"B" | x"C" |			-- C0A0-C0FF = null
										  x"D" | x"E" | x"F" =>
										null;
									when others =>
										null;                
								end case;

							when x"1" =>									-- C100 - C1FF = ROM / RAM / periferico
								if dis_rom_i = '0' then
									if ss_romram_s = '0' then
										rom_cs_s <= '1';
									else
										ram_cs_s <= '1';
									end if;
								else
									io_sel_n_s <= '0';
								end if;
							when x"2" | x"3" | x"4" | 					-- C200 - C7FF = ROM / RAM
							     x"5" | x"6" | x"7" =>
								if ss_romram_s = '0' then
									rom_cs_s <= '1';
								else
									ram_cs_s <= '1';
								end if;
							when x"8" | x"9" | x"A" |					-- C800 - CFFF = ROM / RAM
							     x"B" | x"C" | x"D" | x"E" | x"F" =>
								if ss_romram_s = '0' then
									rom_cs_s <= '1';
								else
									ram_cs_s <= '1';
								end if;
							when others =>
								null;
						end case;

					when "01" | "10" | "11" =>							-- D000 - FFFF = ROM
						if ss_romram_s = '0' then
							rom_cs_s <= '1';
						else
							ram_cs_s <= '1';
						end if;
					when others =>
						null;
				end case;

			when others =>
				null;

		end case;
	end process;

	-- Keyboard
	process (reset_i, clock_q3_s)
	begin
		if reset_i = '1' then
			kbd_rows_o <= (others => '0');
		elsif rising_edge(clock_q3_s) then
			if t_phi0_s = '1' and kbd_o_cs_s = '1' then
				kbd_rows_o	<= cpu_dout_s;
			end if;
		end if;
	end process;

	-- Soft Switches
	process (reset_i, clock_q3_s)
	begin
		if reset_i = '1' then
			softswitches_s <= (others => '0');
		elsif rising_edge(clock_q3_s) then
			if t_phi0_s = '1' and softswitch_cs_s = '1' then
				softswitches_s(TO_INTEGER(unsigned(cpu_addr_s(3 downto 1)))) <= cpu_addr_s(0);
			end if;
		end if;
	end process;

	ss_color_s		<= softswitches_s(0);	-- C050/51
	ss_motorA_s		<= softswitches_s(1);	-- C052/53
	ss_page2_s		<= softswitches_s(2);	-- C054/55
	ss_motorB_s		<= softswitches_s(3);	-- C056/57
	ss_lpt_stb_s	<= softswitches_s(4);	-- C058/59
	ss_romram_s		<= softswitches_s(5);	-- C05A/5B
	-- (6) ??
	ss_ctrl_s		<= softswitches_s(7);	-- C05E/5F

	video_color_o	<= ss_color_s;
	cas_motor_o		<= ss_motorB_s & ss_motorA_s;
	lpt_stb_o		<= ss_lpt_stb_s;
	kbd_ctrl_o	 	<= ss_ctrl_s;
	video_hbl_o		<= video_hbl_s;
	video_vbl_o		<= video_vbl_s;
	video_ld194_o	<= video_ld194_s;

	-- Speaker
	process (clock_q3_s)
	begin
		if rising_edge(clock_q3_s) then
			if t_phi0_s = '1' and speaker_cs_s = '1' then
				speaker_s <= not speaker_s;
			end if;
		end if;
	end process;

	spk_o <= speaker_s;

	-- Cassette
	process (clock_q3_s)
	begin
		if rising_edge(clock_q3_s) then
			if t_phi0_s = '1' and cas_o_cs_s = '1' then
				cas_o_s <= not cas_o_s;
			end if;
		end if;
	end process;
	
	cas_o <= cas_o_s;

-- Debug
--
-- +-------------+-------------+ D000
-- |   BANCO A   |   BANCO B   |
-- |     4K      |     4K      |
-- |             |             |
-- +-------------+-------------+ E000
-- |                           |
-- |            8K             |
-- |                           |
-- +---------------------------+ FFFF
--
-- Pag. 122 manual tecnico

end architecture;
