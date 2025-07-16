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
-- A VGA line-doubler for an Apple ][
--
-- Stephen A. Edwards, sedwards@cs.columbia.edu
--
--
-- FIXME: This is all wrong
--
-- The Apple ][ uses a 14.31818 MHz master clock.  It outputs a new
-- horizontal line every 65 * 14 + 2 = 912 14M cycles.  The extra two
-- are from the "extended cycle" used to keep the 3.579545 MHz
-- colorburst signal in sync.  Of these, 40 * 14 = 560 are active video.
--
-- In graphics mode, the Apple effectively generates 140 four-bit pixels
-- output serially (i.e., with 3.579545 MHz pixel clock).  In text mode,
-- it generates 280 one-bit pixels (i.e., with a 7.15909 MHz pixel clock).
--
-- We capture 140 four-bit nibbles for each line and interpret them in
-- one of the two modes.  In graphics mode, each is displayed as a
-- single pixel of one of 16 colors.  In text mode, each is displayed
-- as two black or white pixels.
-- 
-- The VGA display is nominally 640 X 480, but we use a 14.31818 MHz
-- dot clock.  To stay in sync with the Apple, we generate a new line
-- every 912 / 2 = 456 14M cycles= 31.8 us, a 31.4 kHz horizontal
-- refresh rate.  Of these, 280 will be active video.
--
-- One set of suggested VGA timings:
--
--          ______________________          ________
-- ________|        VIDEO         |________| VIDEO
--     |-C-|----------D-----------|-E-|
-- __   ______________________________   ___________
--   |_|                              |_|
--   |B|
--   |---------------A----------------|
--
-- A = 31.77 us	 Scanline time
-- B =  3.77 us  Horizontal sync time
-- C =  1.89 us  Back porch
-- D = 25.17 us  Active video
-- E =  0.94 us  Front porch
--
-- We use A = 456 / 14.31818 MHz = 31.84 us
--        B =  54 / 14.31818 MHz =  3.77 us
--        C = 106 / 14.31818 MHz =  7.40 us
--        D = 280 / 14.31818 MHz = 19.56 us
--        E =  16 / 14.31818 MHz =  1.12 us
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_controller is
	port (
		clock_28_i		: in  std_logic;	     -- 14.31818 MHz master clock

		video_i			: in  std_logic;         -- from the Apple video generator
		color_i			: in  std_logic;
		hbl_i				: in  std_logic;
		vbl_i				: in  std_logic;
		ld194_i			: in  std_logic;
		color_type_i	: in  std_logic;
    
		vga_hs_n_o		: out std_logic;             -- Active low
		vga_vs_n_o		: out std_logic;             -- Active low
		VGA_HBL    : out std_logic;
		VGA_VBL    : out std_logic;
		vga_blank_n_o	: out std_logic;
		vga_r_o			: out std_logic_vector(7 downto 0);
		vga_g_o			: out std_logic_vector(7 downto 0);
		vga_b_o			: out std_logic_vector(7 downto 0);
		vga_odd_line_o	: out std_logic;
		color_index 	: out std_logic_vector(3 downto 0)
	);
  
end entity;

architecture rtl of vga_controller is

	type basis_color_t is array(0 to 3) of unsigned(7 downto 0);
	-- TK2000 (green, blue, cyan, red)
	constant basis_r1_c : basis_color_t := ( X"50", X"37", X"08", X"70" );
	constant basis_g1_c : basis_color_t := ( X"38", X"94", X"2C", X"07" );
	constant basis_b1_c : basis_color_t := ( X"38", X"10", X"B0", X"07" );	
	
	-- Apple 2        (vermelho, azul, verde, verde-escuro)
	--  			   red,      blue, green, dark green	
	constant basis_r2_c : basis_color_t := ( X"88", X"38", X"07", X"38" );
	constant basis_g2_c : basis_color_t := ( X"22", X"24", X"67", X"52" );
	constant basis_b2_c : basis_color_t := ( X"2C", X"A0", X"2C", X"07" );	
	
	constant basis_c : basis_color_t := ( X"01", X"02", X"04", X"08" );

	signal ram_write_addr_s			: unsigned(10 downto 0);
	signal ram_we_s					: std_logic;
	signal ram_read_addr_s			: unsigned(10 downto 0);
	signal ram_data_out_s			: std_logic;
  
	signal data_in_s					: std_logic_vector(0 downto 0);
	signal data_out_s					: std_logic_vector(0 downto 0);

	signal shift_reg_s				: unsigned(5 downto 0);  -- Last six pixels

	signal last_hbl_s					: std_logic;
	signal hcount_s					: unsigned(10 downto 0);
	signal hcount2_s					: unsigned(10 downto 0);
	signal vcount_s					: unsigned(5 downto 0);
	signal even_line_s				: std_logic;
	signal hactive_s					: std_logic;
	signal hactive_early1_s			: std_logic;
	signal hactive_early2_s			: std_logic;

	constant VGA_SCANLINE_c			: integer := 456*2; -- Must be 456*2 (set by the Apple)
  
	constant VGA_HSYNC_c				: integer := 54 * 2;
	constant VGA_BACK_PORCH_c		: integer := 66 * 2;
	constant VGA_ACTIVE_c			: integer := 282 * 2;
	constant VGA_FRONT_PORCH_c		: integer := 54 * 2;

	-- VGA_HSYNC + VGA_BACK_PORCH + VGA_ACTIVE + VGA_FRONT_PORCH = VGA_SCANLINE

	constant VBL_TO_VSYNC_c			: integer := 33;
	constant VGA_VSYNC_LINES_c		: integer := 3;

	signal VGA_VS_I_s, VGA_HS_I_s	: std_logic;

	signal video_active_s			: std_logic;
	signal vbl_delayed_s				: std_logic;
	signal vbl_delayed2_s			: std_logic;
	signal hbl_delayed_s				: std_logic;
	signal color_line_delayed_1_s	: std_logic;
	signal color_line_delayed_2_s	: std_logic;

	signal vga_odd_line_s			: std_logic;
begin

	line_storage : entity work.dpram
	generic map (
		addr_width_g	=> 11,
		data_width_g	=> 1
	)
	port map (
		clock_a	=> clock_28_i,
		address_a	=> std_logic_vector(ram_write_addr_s),
		data_a	=> data_in_s,
		wren_a		=> ram_we_s,
		clock_b	=> clock_28_i,
		address_b	=> std_logic_vector(ram_read_addr_s),
		data_b	=> data_out_s
	);

  delay_hbl : process (clock_28_i)
  begin
    if rising_edge(clock_28_i) then
      if ld194_i = '0' then
        hbl_delayed_s <= hbl_i;
      end if;
    end if;
  end process;

  hcount_vcount_control : process (clock_28_i)
  begin
    if rising_edge(clock_28_i) then
	 
			if last_hbl_s = '1' and hbl_delayed_s = '0' then  -- Falling edge
			
				  color_line_delayed_2_s <= color_line_delayed_1_s;
				  color_line_delayed_1_s <= color_i;
				  hcount_s <= (others => '0');
				  vbl_delayed2_s <= vbl_delayed_s;
				  vbl_delayed_s <= vbl_i;
				  
				  if vbl_delayed_s = '1' then
						even_line_s <= '0';
						vcount_s <= vcount_s + 1;
				  else
						vcount_s <= (others => '0');
						even_line_s <= not even_line_s;
				  end if;
			  
			else
			
					hcount_s <= hcount_s + 1;
			  
			end if;
			
			last_hbl_s <= hbl_delayed_s;
			
    end if;
  end process hcount_vcount_control;

  sync_gen : process (clock_28_i)
  begin
    if rising_edge(clock_28_i) then
	 
			if hcount_s = VGA_ACTIVE_c + VGA_FRONT_PORCH_c or hcount_s = VGA_SCANLINE_c + VGA_ACTIVE_c + VGA_FRONT_PORCH_c then
					VGA_HS_I_s <= '0';
					vga_odd_line_s <= not vga_odd_line_s;
			elsif hcount_s = VGA_ACTIVE_c + VGA_FRONT_PORCH_c + VGA_HSYNC_c or hcount_s = VGA_SCANLINE_c + VGA_ACTIVE_c + VGA_FRONT_PORCH_c + VGA_HSYNC_c then
					VGA_HS_I_s <= '1';
			end if;

			hactive_s <= hactive_early1_s;
			hactive_early1_s <= hactive_early2_s;

			if hcount_s = VGA_SCANLINE_c - 1 or hcount_s = VGA_SCANLINE_c + VGA_SCANLINE_c - 1 then
					hactive_early2_s <= '1';
			elsif hcount_s = VGA_ACTIVE_c or 
					hcount_s = VGA_ACTIVE_c + VGA_SCANLINE_c then
					hactive_early2_s <= '0';
			end if;

		  if vcount_s = VBL_TO_VSYNC_c then
					VGA_VS_I_s <= '0';
					vga_odd_line_s <= '0';
			elsif vcount_s = VBL_TO_VSYNC_c + VGA_VSYNC_LINES_c then
					VGA_VS_I_s <= '1';
			end if;
			
    end if;
  end process sync_gen;
  
  vga_hs_n_o <= VGA_HS_I_s;
  vga_vs_n_o <= VGA_VS_I_s;
  vga_odd_line_o <= vga_odd_line_s;

  hcount2_s <= hcount_s - VGA_SCANLINE_c;

  ram_read_addr_s <=
    even_line_s & hcount_s(9 downto 0) when hcount_s < VGA_SCANLINE_c else
    even_line_s & hcount2_s(9 downto 0);

  shifter: process (clock_28_i)
  begin
    if rising_edge(clock_28_i) then
      shift_reg_s <= ram_data_out_s & shift_reg_s(5 downto 1);
    end if;
  end process;
  
  ram_write_addr_s <= (not even_line_s) & hcount_s(10 downto 1);
  ram_we_s <= '1' when hcount_s(0) = '1' else '0';

  video_active_s <= hactive_s and not vbl_delayed2_s;

	pixel_generator: process (clock_28_i)
		variable r_v, g_v, b_v : unsigned(7 downto 0); 
		variable color_v : unsigned(7 downto 0); 
		variable basis_r_v, basis_g_v, basis_b_v : basis_color_t;
	begin
		if rising_edge(clock_28_i) then
		
			r_v := X"00";
			g_v := X"00";
			b_v := X"00";
			color_index <= "0000";
			color_v := X"00";
			
			if color_type_i = '0' then
				basis_r_v := basis_r1_c;
				basis_g_v := basis_g1_c;
				basis_b_v := basis_b1_c;
			else
				basis_r_v := basis_r2_c;
				basis_g_v := basis_g2_c;
				basis_b_v := basis_b2_c;
			end if;

			
			
			if video_active_s = '1' then

				if color_line_delayed_2_s = '1' then  -- Monochrome mode

					if shift_reg_s(2) = '1' then
						r_v := X"FF"; g_v := X"FF"; b_v := X"FF";
						color_index <= "1111";
					end if;

				elsif shift_reg_s(0) = shift_reg_s(4) and shift_reg_s(1) = shift_reg_s(5) then

					-- Tint of adjacent pixels is consistent : display the color

 					if shift_reg_s(1) = '1' then
 						r_v := r_v + basis_r_v(to_integer(hcount_s + 1));
 						g_v := g_v + basis_g_v(to_integer(hcount_s + 1));
 						b_v := b_v + basis_b_v(to_integer(hcount_s + 1));
						color_v := color_v + basis_c(to_integer(hcount_s + 1));
						
 					end if;
 					if shift_reg_s(2) = '1' then
 						r_v := r_v + basis_r_v(to_integer(hcount_s + 2));
 						g_v := g_v + basis_g_v(to_integer(hcount_s + 2));
 						b_v := b_v + basis_b_v(to_integer(hcount_s + 2));
						color_v := color_v + basis_c(to_integer(hcount_s + 2));
 					end if;
 					if shift_reg_s(3) = '1' then
 						r_v := r_v + basis_r_v(to_integer(hcount_s + 3));
 						g_v := g_v + basis_g_v(to_integer(hcount_s + 3));
 						b_v := b_v + basis_b_v(to_integer(hcount_s + 3));
						color_v := color_v + basis_c(to_integer(hcount_s + 3));
 					end if;
 					if shift_reg_s(4) = '1' then
 						r_v := r_v + basis_r_v(to_integer(hcount_s));
 						g_v := g_v + basis_g_v(to_integer(hcount_s));
 						b_v := b_v + basis_b_v(to_integer(hcount_s));
						color_v := color_v + basis_c(to_integer(hcount_s));
 					end if;
					
					

					color_index <= std_logic_vector(color_v(3 downto 0));
			
					
--					color_index <= std_logic_vector(shift_reg_s(4 downto 1));
					
--					if (hcount_s(0) = '0') then
--						color_index(3) <= (shift_reg_s(0));
--						color_index(2) <= (shift_reg_s(1));
--						color_index(1) <= (shift_reg_s(2));
--						color_index(0) <= (shift_reg_s(3));
--					else
--						color_index(3) <= (shift_reg_s(2));
--						color_index(2) <= (shift_reg_s(3));
--						color_index(1) <= (shift_reg_s(4));
--						color_index(0) <= (shift_reg_s(5));
--					
--					end if;

				else

					-- Tint is changing: display only black, gray, or white

					case shift_reg_s(3 downto 2) is
						when "11"        => r_v := X"FF"; g_v := X"FF"; b_v := X"FF"; color_index <= "1111";
						when "01" | "10" => r_v := X"80"; g_v := X"80"; b_v := X"80"; color_index <= "1010";
						when others      => r_v := X"00"; g_v := X"00"; b_v := X"00"; color_index <= "0000";
					end case;

				end if;	

			end if;
			
			if hcount_s < 8 or (hcount_s >= 900 and hcount_s <= 919) then --crop some out-screen pixels
				color_index <= "0000";
			end if;

			vga_r_o <= std_logic_vector(b_v);
			vga_g_o <= std_logic_vector(g_v);
			vga_b_o <= std_logic_vector(r_v);
 
		end if;
	end process pixel_generator;

	data_in_s(0) <= video_i;
	ram_data_out_s <= data_out_s(0);

	vga_blank_n_o	<= video_active_s;
VGA_VBL <= vbl_delayed_s;
VGA_HBL <= hbl_delayed_s;

end rtl;
