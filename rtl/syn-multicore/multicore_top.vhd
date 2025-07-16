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
-- TK2000 project
--
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
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
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity multicore_top is
    port (
    -- Clocks
        clock_50_i          : in    std_logic;

        -- Buttons
        btn_n_i             : in    std_logic_vector(4 downto 1);

        -- SRAMs (AS7C34096)
        sram_addr_o         : out   std_logic_vector(18 downto 0)   := (others => '0');
        sram_data_io        : inout std_logic_vector(7 downto 0)    := (others => 'Z');
        sram_we_n_o         : out   std_logic                               := '1';
        sram_oe_n_o         : out   std_logic                               := '1';
        
        -- SDRAM    (H57V256)
        SDRAM_A         : out std_logic_vector(12 downto 0);
        SDRAM_DQ            : inout std_logic_vector(15 downto 0);

        SDRAM_BA            : out std_logic_vector(1 downto 0);
        SDRAM_DQMH          : out std_logic;
        SDRAM_DQML          : out std_logic;    

        SDRAM_nRAS          : out std_logic;
        SDRAM_nCAS          : out std_logic;
        SDRAM_CKE           : out std_logic;
        SDRAM_CLK           : out std_logic;
        SDRAM_nCS           : out std_logic;
        SDRAM_nWE           : out std_logic;
    
        -- PS2
        ps2_clk_io          : inout std_logic                               := 'Z';
        ps2_data_io         : inout std_logic                               := 'Z';
        ps2_mouse_clk_io  : inout std_logic                             := 'Z';
        ps2_mouse_data_io : inout std_logic                             := 'Z';

        -- SD Card
        sd_cs_n_o           : out   std_logic                               := 'Z';
        sd_sclk_o           : out   std_logic                               := 'Z';
        sd_mosi_o           : out   std_logic                               := 'Z';
        sd_miso_i           : in    std_logic;

        -- Joysticks
        joy1_up_i           : in    std_logic;
        joy1_down_i         : in    std_logic;
        joy1_left_i         : in    std_logic;
        joy1_right_i        : in    std_logic;
        joy1_p6_i           : in    std_logic;
        joy1_p9_i           : in    std_logic;
        joyX_p7_o           : out   std_logic                               := '1';       
        
        -- joystick 2 as SDISKII 
        joy2_up_i           : out    std_logic;
        joy2_down_i         : out    std_logic;
        joy2_left_i         : out    std_logic;
        joy2_right_i        : out    std_logic;
        joy2_p6_i           : out    std_logic;
        joy2_p9_i           : out    std_logic;


        -- Audio
        AUDIO_L             : out   std_logic                               := '0';
        AUDIO_R             : out   std_logic                               := '0';
        ear_i                   : in    std_logic;
        mic_o                   : out   std_logic                               := '0';

        -- VGA
        VGA_R               : out   std_logic_vector(4 downto 0)    := (others => '0');
        VGA_G               : out   std_logic_vector(4 downto 0)    := (others => '0');
        VGA_B               : out   std_logic_vector(4 downto 0)    := (others => '0');
        VGA_HS      : out   std_logic                               := '1';
        VGA_VS      : out   std_logic                               := '1';

        -- HDMI
        tmds_o              : out   std_logic_vector(7 downto 0)    := (others => '0');

        --STM32
        stm_rx_o                : out std_logic     := 'Z'; -- stm RX pin, so, is OUT on the slave
        stm_tx_i                : in  std_logic     := 'Z'; -- stm TX pin, so, is IN on the slave
        stm_rst_o           : out std_logic     := 'Z'; -- '0' to hold the microcontroller reset line, to free the SD card
        
        stm_a15_io          : inout std_logic;
        stm_b8_io           : inout std_logic       := 'Z';
        stm_b9_io           : inout std_logic       := 'Z';
        
        SPI_SCK         : inout std_logic       := 'Z';
        SPI_DO          : inout std_logic       := 'Z';
        SPI_DI          : inout std_logic       := 'Z';
        SPI_SS2         : inout std_logic       := 'Z'
        
    );
end entity;

architecture behavior of multicore_top is

    function to_slv(s: string) return std_logic_vector is 
        constant ss: string(1 to s'length) := s; 
        variable answer: std_logic_vector(1 to 8 * s'length); 
        variable p: integer; 
        variable c: integer; 
    begin 
        for i in ss'range loop
            p := 8 * i;
            c := character'pos(ss(i));
            answer(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
        end loop; 
        return answer; 
    end function; 
     
    constant CONF_STR       : string := 

        "S,NIB,Load *.NIB;"& 
        "O3,Drive step sound,Off,On;"&
        "OAB,Scanlines,Off,25%,50%,75%;"&
        "T1,Soft Reset;"&
        "T0,Hard Reset;"& 
        ".";

    type config_array is array(natural range 15 downto 0) of std_logic_vector(7 downto 0);
  
    component osd is
        generic
        (
            STRLEN       : integer := 0;
            OSD_X_OFFSET : std_logic_vector(9 downto 0) := (others=>'0');
            OSD_Y_OFFSET : std_logic_vector(9 downto 0) := (others=>'0');
            OSD_COLOR    : std_logic_vector(2 downto 0) := (others=>'0')
        );
        port
        (
            -- OSDs pixel clock, should be synchronous to cores pixel clock to
            -- avoid jitter.
            pclk        : in std_logic;

            -- SPI interface
            sck     : in std_logic;
            ss          : in std_logic;
            sdi     : in std_logic;
            sdo     : out std_logic;

            -- VGA signals coming from core
            red_in  : in std_logic_vector(4 downto 0);
            green_in : in std_logic_vector(4 downto 0);
            blue_in     : in std_logic_vector(4 downto 0);
            hs_in       : in std_logic;
            vs_in       : in std_logic;
            
            -- VGA signals going to video connector
            red_out : out std_logic_vector(4 downto 0);
            green_out: out std_logic_vector(4 downto 0);
            blue_out    : out std_logic_vector(4 downto 0);
            hs_out  : out std_logic;
            vs_out  : out std_logic;
            
            -- external data in to the microcontroller
            data_in     : in std_logic_vector(7 downto 0);
            conf_str : in std_logic_vector( (CONF_STR'length * 8)-1 downto 0);
            menu_in : in std_logic;
            status  : out std_logic_vector(31 downto 0);
            mc_ack  : out std_logic;
            reset   : in std_logic;
            
            -- data pump to sram
            pump_active_o   : out std_logic := '0';
            sram_a_o        : out std_logic_vector(18 downto 0);
            sram_d_o        : out std_logic_vector(7 downto 0);
            sram_we_n_o     : out std_logic := '1';
            
            config_buffer_o: out config_array
        );
        end component;

    component video
        generic (
        SD_HCNT_WIDTH: integer := 9;
        COLOR_DEPTH  : integer := 6
        );
        port (
        clk_sys     : in std_logic;

        scanlines   : in std_logic_vector(1 downto 0);
        ce_divider  : in std_logic := '0';
        scandoubler_disable : in std_logic;

        HSync       : in std_logic;
        VSync       : in std_logic;
        R           : in std_logic_vector(COLOR_DEPTH-1 downto 0);
        G           : in std_logic_vector(COLOR_DEPTH-1 downto 0);
        B           : in std_logic_vector(COLOR_DEPTH-1 downto 0);

        VGA_HS      : out std_logic;
        VGA_VS      : out std_logic;
        VGA_R       : out std_logic_vector(5 downto 0);
        VGA_G       : out std_logic_vector(5 downto 0);
        VGA_B       : out std_logic_vector(5 downto 0)
        );
    end component video;

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
  
    -- Clocks
    signal clock_28_s           : std_logic;        -- Dobro para scandoubler
    signal clock_14_s           : std_logic;        -- Master
    signal phi0_s               : std_logic;        -- phase 0
    signal phi1_s               : std_logic;        -- phase 1
    signal phi2_s               : std_logic;        -- phase 2
    signal clock_2M_s           : std_logic;        -- Clock Q3
    signal clock_dvi_s          : std_logic;

    signal clk_kbd_s            : std_logic;
    signal div_s                : std_logic_vector(2 downto 0) := "000";


    -- Resets
    signal pll_locked_s     : std_logic;
    signal por_reset_s      : std_logic := '1';
    signal reset_s              : std_logic;

    -- ROM
    signal rom_addr_s           : std_logic_vector(13 downto 0);
    signal rom_data_from_s  : std_logic_vector(7 downto 0);
--  signal rom_oe_s         : std_logic;
--  signal rom_we_s         : std_logic;

    -- RAM
    signal ram_addr_s           : std_logic_vector(15 downto 0);
    signal ram_data_to_s        : std_logic_vector(7 downto 0);
    signal ram_data_from_s  : std_logic_vector(7 downto 0);
    signal ram_oe_s         : std_logic;
    signal ram_we_s         : std_logic;
    signal ram_addr         : std_logic_vector(24 downto 0);
    signal ram_data         : std_logic_vector(7 downto 0);
    signal ram_we               : std_logic;
        
    -- Keyboard
    signal kbd_ctrl_s           : std_logic;
    signal kbd_rows_s           : std_logic_vector(7 downto 0);
    signal kbd_cols_s           : std_logic_vector(5 downto 0);
    signal FKeys_s              : std_logic_vector(12 downto 1);
    signal osd_s                : std_logic_vector(7 downto 0);

    -- Audio
    signal spk_s                : std_logic;

    -- K7
    signal cas_o_s              : std_logic;
--  signal cas_motor_s      : std_logic_vector(1 downto 0);

    -- Video
    signal video_r_s            : std_logic_vector(7 downto 0);
    signal video_g_s            : std_logic_vector(7 downto 0);
    signal video_b_s            : std_logic_vector(7 downto 0);
    signal video_ro_s           : std_logic_vector(7 downto 0);
    signal video_go_s           : std_logic_vector(7 downto 0);
    signal video_bo_s           : std_logic_vector(7 downto 0);
    signal video_color_s        : std_logic;
    signal video_bit_s      : std_logic;
    signal video_hsync_n_s  : std_logic;
    signal video_vsync_n_s  : std_logic;
    signal video_blank_s        : std_logic;
    signal video_hbl_s      : std_logic;
    signal video_vbl_s      : std_logic;
    signal video_ld194_s        : std_logic;

    -- Periferico
    signal per_iosel_n_s        : std_logic;
    signal per_devsel_n_s   : std_logic;
    signal per_we_s         : std_logic;
    signal per_addr_s           : std_logic_vector(7 downto 0);
    signal per_data_from_s  : std_logic_vector(7 downto 0)  := (others => '0');
    signal per_data_to_s        : std_logic_vector(7 downto 0);

    -- Disk II
    signal image_num_s      : unsigned(9 downto 0)              := (others => '0');
    signal track_num_s      : unsigned(5 downto 0);
    signal track_addr_s     : unsigned(13 downto 0);
    signal disk1_en_s           : std_logic;
    signal disk2_en_s           : std_logic;
    signal track_ram_addr_s : unsigned(13 downto 0);
    signal track_ram_data_s : unsigned(7 downto 0);
    signal track_ram_we_s   : std_logic;


    -- OSD
    signal osd_visible_s        : std_logic                             := '1';
   signal osd_pixel_s       : std_logic;
   signal osd_green_s       : std_logic_vector(4 downto 0);                             -- OSD byte signal
   signal btn_up_s          : std_logic := '1'; 
   signal btn_down_s            : std_logic := '1'; 
    signal timer_osd_s      : unsigned(21 downto 0)             := (others => '1');

    -- Debug
    signal D_cpu_pc_s           : std_logic_vector(15 downto 0);
    
    
    --
    signal color_index  : std_logic_vector(3 downto 0);
    signal scanlines_en_s : std_logic_vector(1 downto 0);
    
   signal vga_r_s       : std_logic_vector(4 downto 0); 
   signal vga_g_s       : std_logic_vector(4 downto 0); 
   signal vga_b_s       : std_logic_vector(4 downto 0); 

   signal osd_r_s       : std_logic_vector(4 downto 0); 
   signal osd_g_s       : std_logic_vector(4 downto 0); 
   signal osd_b_s       : std_logic_vector(4 downto 0); 
    
    signal vga_x_s      : std_logic_vector(9 downto 0);
    signal vga_y_s      : std_logic_vector(9 downto 0);
    signal flash_clk : unsigned(22 downto 0) := (others => '0');
    signal menu_status : std_logic_vector(31 downto 0); 
    signal mc_ack : std_logic := '0';
    signal odd_line_s : std_logic;
    
    signal step_sound_s : std_logic;
    signal kbd_joy_s : std_logic_vector(5 downto 0);    
        
    -- Data pump
    signal pump_active_s    : std_logic                             := '0';
    signal sram_we_s    : std_logic                             := '1';
    signal sram_addr_s  : std_logic_vector (18 downto 0) := (others=>'1');
    signal sram_data_s  : std_logic_vector (7 downto 0) := (others=>'0');
    signal disk_addr_s  : std_logic_vector (18 downto 0) := (others=>'0');
    signal disk_data_s  : std_logic_vector (7 downto 0) := (others=>'0');    

    signal pcm_out_s    : std_logic_vector (7 downto 0);
    
    -- HDMI
    signal tdms_r_s         : std_logic_vector( 9 downto 0);
    signal tdms_g_s         : std_logic_vector( 9 downto 0);
    signal tdms_b_s         : std_logic_vector( 9 downto 0);
    signal tdms_p_s         : std_logic_vector( 3 downto 0);
    signal tdms_n_s         : std_logic_vector( 3 downto 0);

    -- SDISKII
    signal motor_phase_s : std_logic_vector (3 downto 0) := (others=>'0');
    signal drive_en_s    : std_logic;
    signal rd_pulse_s    : std_logic;

begin

    -- PLL
    pll: work.pll1
    port map (
        inclk0      => clock_50_i,
        c0              => clock_28_s,
        c1              => clock_14_s,
        c2              => clock_dvi_s,
        locked      => pll_locked_s
    );
    
    
    


    -- TK2000
    tk2000_inst: work.tk2000
    port map (
        clock_14_i          => clock_14_s,
        reset_i             => reset_s,
        -- RAM
        ram_addr_o          => ram_addr_s,
        ram_data_to_o       => ram_data_to_s,
        ram_data_from_i => ram_data_from_s,
        ram_oe_o                => ram_oe_s,
        ram_we_o                => ram_we_s,
        -- ROM
        rom_addr_o          => rom_addr_s,
        rom_data_from_i => rom_data_from_s,
        rom_oe_o                => open,--rom_oe_s,
        rom_we_o                => open,--rom_we_s,
        -- Keyboard
        kbd_rows_o          => kbd_rows_s,
        kbd_cols_i          => kbd_joy_s,
        kbd_ctrl_o          => kbd_ctrl_s,
        -- Audio
        spk_o                   => spk_s,
        -- Video
        video_color_o       => video_color_s,
        video_bit_o         => video_bit_s,
        video_hsync_n_o => open,
        video_vsync_n_o => open,
        video_hbl_o         => video_hbl_s,
        video_vbl_o         => video_vbl_s,
        video_ld194_o       => video_ld194_s,
        -- Cassete
        cas_i                   => ear_i,
        cas_o                   => cas_o_s,
        cas_motor_o         => open,--cas_motor_s,
        -- LPT
        lpt_stb_o           => open,
        lpt_busy_i          => '0',
        -- Periferico
        phi0_o              => phi0_s,                  -- fase 0 __|---|___|---
        phi1_o              => phi1_s,                  -- fase 1 ---|___|---|___
        phi2_o              => phi2_s,                  -- fase 2 ___|---|___|---
        clock_2m_o          => clock_2M_s,
        read_write_o        => per_we_s,
        irq_n_i             => '1',
        nmi_n_i             => '1',
        dis_rom_i           => '1',                     -- 1 enable peripheral
        io_select_n_o       => per_iosel_n_s,
        dev_select_n_o      => per_devsel_n_s,
        per_addr_o          => per_addr_s,
        per_data_from_i => per_data_from_s,
        per_data_to_o       => per_data_to_s,
        -- Debug
        D_cpu_pc_o          => D_cpu_pc_s
    );

    -- Keyboard
    kb: work.keyboard
    generic map (
        clkfreq_g           => 7000 --28000
    )
    port map (
        clock_i             => clk_kbd_s, --clock_28_s,
        reset_i             => por_reset_s,
        ps2_clk_io          => ps2_clk_io,
        ps2_data_io         => ps2_data_io,
        rows_i              => kbd_rows_s,
        row_ctrl_i          => kbd_ctrl_s,
        cols_o              => kbd_cols_s,
        FKeys_o             => FKeys_s,
        osd_o               => osd_s
    );
    
    
    process (clock_28_s)
    begin
        if rising_edge(clock_28_s) then
            
            kbd_joy_s <= kbd_cols_s;
            
            if (kbd_rows_s(6) = '1' and joy1_up_i = '0')
            or (kbd_rows_s(5) = '1' and joy1_down_i = '0')
            or (kbd_rows_s(4) = '1' and joy1_right_i = '0')
            or (kbd_rows_s(3) = '1' and joy1_left_i = '0')
            then            
                kbd_joy_s <= kbd_joy_s or "000001";
            end if;
            
            if (kbd_rows_s(7) = '1' and joy1_p6_i = '0')
            or (kbd_rows_s(7) = '1' and joy1_p9_i = '0')
            then            
                kbd_joy_s <= kbd_joy_s or "010000";
            end if;
            
            --generate a slower clock for the keyboard
            div_s <= div_s + 1;
            clk_kbd_s <= div_s(1); -- 7 mhz
        end if;
    end process;
    
    -- Audio
    audioout: entity work.Audio_DAC
    port map (
        clock_i => clock_14_s,
        reset_i => reset_s,
        spk_i       => spk_s,
        mic_i       => cas_o_s,
        ear_i       => ear_i,
        step_i   => step_sound_s and menu_status(3),
        dac_r_o => AUDIO_R,
        dac_l_o => AUDIO_L,
        pcm_out_o => pcm_out_s
    );
    
    -- ROM
    rom: entity work.tk2000_rom
    port map (
        clock       => clock_28_s,
        address => rom_addr_s,
        q           => rom_data_from_s
    );

    -- VGA
    vga : work.vga_controller
    port map (
        clock_28_i      => clock_28_s,
        video_i         => video_bit_s,
        color_i         => video_color_s,
        hbl_i               => video_hbl_s,
        vbl_i               => video_vbl_s,
        ld194_i         => video_ld194_s,
        color_type_i    => '1',
        vga_hs_n_o      => video_hsync_n_s,
        vga_vs_n_o      => video_vsync_n_s,
        vga_blank_n_o   => video_blank_s,
        vga_r_o         => video_r_s,
        vga_g_o         => video_g_s,
        vga_b_o         => video_b_s,
        
        vga_odd_line_o => odd_line_s,
        
        color_index     => color_index
    );


    disk : entity work.disk_ii
    port map (
        CLK_14M         => clock_14_s,
        CLK_2M          => clock_2M_s,
        PRE_PHASE_ZERO  => phi0_s,
        
        IO_SELECT       => not per_iosel_n_s,
        DEVICE_SELECT   => not per_devsel_n_s,
        
        RESET               => reset_s,
        A                   => unsigned(per_addr_s),
        D_IN                => unsigned(per_data_to_s),
        std_logic_vector(D_OUT) => per_data_from_s,
        
        TRACK               => track_num_s,
        TRACK_ADDR      => track_addr_s,
        D1_ACTIVE       => disk1_en_s,
        D2_ACTIVE       => disk2_en_s,
        
        ram_write_addr  => track_ram_addr_s,
        ram_di          => track_ram_data_s,
        ram_we          => track_ram_we_s,
        step_sound_o    => step_sound_s,

        --------------------------------------------------------------------------------
        motor_phase_o  => motor_phase_s,
        drive_en_o     => drive_en_s,
        rd_pulse_o     => rd_pulse_s 
    );


    joy2_right_i <= motor_phase_s(3);
    joy2_left_i  <= motor_phase_s(2);
    joy2_down_i  <= motor_phase_s(1);
    joy2_up_i    <= motor_phase_s(0);

    joy2_p6_i    <= drive_en_s;
 --    joy2_p9_i    <= rd_pulse_s;


    
    image_ctrl : work.image_controller 
      port map(
      
            -- System Interface -------------------------------------------------------
            CLK_14M         => clock_14_s,
            reset           => reset_s,   
      
             -- SRAM Interface ---------------------------------------------------------
             buffer_addr_i  => disk_addr_s, 
             buffer_data_i  => disk_data_s,
             
             -- Track buffer Interface -------------------------------------------------
             unsigned(ram_write_addr)  => track_ram_addr_s(12 downto 0),    -- out
             unsigned(ram_di)          => track_ram_data_s,     -- out
             ram_we                         => track_ram_we_s,      -- out
             track                      => track_num_s,
             image                      => (others=>'0')

      );
      
      -- Track Number overlay for the green channel
        osd_inst: entity work.osd_track
        generic map (                                   
        C_digits            => 2,                       -- number of hex digits to show
        C_resolution_x  => 565

        )
        port map (
            clk_pixel       => clock_28_s,
            vsync               => not video_vsync_n_s, -- positive sync
            fetch_next      => video_blank_s,           -- '1' when video_active
            probe_in            => "00" & std_logic_vector(track_num_s),
            osd_out         => osd_pixel_s
        );

        
        osd_green_s     <= (others => (osd_pixel_s and osd_visible_s));
        
    -- OSD timer
    process (clock_2M_s)
    begin
        if rising_edge(clock_2M_s) then
            if disk1_en_s = '1' or disk1_en_s = '1' then
                timer_osd_s     <= (others => '1');
                osd_visible_s   <= '1';
            elsif timer_osd_s > 0 then
                timer_osd_s     <= timer_osd_s - 1;
                osd_visible_s   <= '1';
            else
                osd_visible_s   <= '0';
            end if;
            
        end if;
    end process;


    
      
      scanlines_en_s <= menu_status(11 downto 10);
    

--  sdcard_interface : entity work.spi_controller
--  port map (
--      CLK_14M        => clock_14_s,
--      RESET          => reset_s,
--      CS_N           => sd_cs_n_o,
--      MOSI           => sd_mosi_o,
--      MISO           => sd_miso_i,
--      SCLK           => sd_sclk_o,
--      track          => track_num_s,
--      image          => image_num_s,
--      ram_write_addr => track_ram_addr_s,
--      ram_di         => track_ram_data_s,
--      ram_we         => track_ram_we_s
--  );
--

    -- Glue Logic

      -- In the Apple ][, this was a 555 timer
  power_on : process(clock_14_s)
  begin
         if rising_edge(clock_14_s) then
                reset_s <=  por_reset_s or not btn_n_i(3) or menu_status(1);

                if (btn_n_i(4) = '0' and btn_n_i(3) = '0')  or menu_status(0) = '1' or pump_active_s = '1' then
                      por_reset_s <= '1';
                      flash_clk <= (others=>'0');
                else
                      if flash_clk(22) = '1' then
                            por_reset_s <= '0';
                      end if;
                         
                      flash_clk <= flash_clk + 1;
                end if;
            
         end if;
  end process;
  
    --por_reset_s   <= '1' when pll_locked_s = '0' or (btn_n_i(2) = '0' and btn_n_i(4) = '0')                               else '0';
    --reset_s       <= '1' when por_reset_s = '1'  or (btn_n_i(3) = '0' and btn_n_i(4) = '0') or FKeys_s(4) = '1'   else '0';

    -- RAM
    --ram_data_from_s   <= sram_data_io;

--  process (clock_28_s, por_reset_s, ram_addr_s, ram_we_s, ram_oe_s, ram_data_to_s)
--  begin
--  if rising_edge(clock_28_s) then  
--      if por_reset_s = '1' then
--          sram_addr_o     <= "000" & X"03F4";
--          ram_addr            <= "000000000" & X"03F4"; 
----            sram_we_n_o     <= '0';
----            sram_oe_n_o     <= '0';
--          sram_data_io    <= X"00";
--          ram_data        <= x"00";
--          ram_we          <= '1';
--      else
--          sram_addr_o     <= "000" & ram_addr_s;
--          ram_addr            <= "000000000" & ram_addr_s;
----            sram_we_n_o     <= not ram_we_s;
----            sram_oe_n_o     <= not ram_oe_s;
--          ram_we          <= ram_we_s;
--          if ram_we_s = '1' then
--              sram_data_io    <= ram_data_to_s;
--              ram_data <= ram_data_to_s;
--          else
--              sram_data_io    <= (others => 'Z');
--              ram_data <= (others => 'Z');
--          end if;
--      end if;
--  end if;
--  end process;


  ram_we   <= ram_we_s when por_reset_s = '0' else '1';
  ram_addr <= "000000000" & std_logic_vector(ram_addr_s) when por_reset_s = '0' else std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4
  ram_data   <= std_logic_vector(ram_data_to_s) when por_reset_s = '0' else "00000000";
    
    SDRAM_CLK <=  not clock_28_s;

    SDRAM_CKE <= '1';

  sdram_inst : sdram
    port map( 
     
                  sd_data => SDRAM_DQ,
              sd_addr => SDRAM_A,
              sd_dqm(1) => SDRAM_DQMH,
              sd_dqm(0) => SDRAM_DQML,
              sd_cs => SDRAM_nCS,
              sd_ba => SDRAM_BA,
              sd_we => SDRAM_nWE,
              sd_ras => SDRAM_nRAS,
              sd_cas => SDRAM_nCAS,
                  
              clk => clock_28_s,
              clkref => not clock_2M_s,
              init => not pll_locked_s,
                  
              din => ram_data,
              addr => ram_addr,
              we => ram_we,
              dout(7 downto 0) => ram_data_from_s,
              aux => '0'
    );
  
    
    
    

    -- K7
    mic_o       <= cas_o_s;

    
        -- Index => RGB 
    process (clock_28_s)
        variable vga_col_v  : integer range 0 to 15;
        variable vga_rgb_v  : std_logic_vector(15 downto 0);
        variable vga_r_v        : std_logic_vector( 3 downto 0);
        variable vga_g_v        : std_logic_vector( 3 downto 0);
        variable vga_b_v        : std_logic_vector( 3 downto 0);
        type ram_t is array (natural range 0 to 15) of std_logic_vector(15 downto 0);
        constant rgb_c : ram_t := (
        
            -- Original Apple II palette
        
                --  0 - 0x00 00 00 - Black
                --  1 - 0x90 17 40 - Red
                --  2 - 0x40 2c a5 - Dark Blue
                --  3 - 0xd0 43 e5 - Purple
                --  4 - 0x00 69 40 - Dark Green
                --  5 - 0x80 80 80 - Gray 1
                --  6 - 0x2f 95 e5 - Medium Blue
                --  7 - 0xbf ab ff - Light Blue
                --  8 - 0x40 54 00 - Brown
                --  9 - 0xd0 6a 1a - Orange
                -- 10 - 0x80 80 80 - Gray 2 
                -- 11 - 0xff 96 bf - Pink
                -- 12 - 0x2f bc 1a - Light Green
                -- 13 - 0xbf d3 5a - Yellow
                -- 14 - 0x6f e8 bf - Aqua
                -- 15 - 0xff ff ff - White
                
                        --      RG0B
                0  => X"0000",
                1  => X"9104",
                2  => X"420A",
                3  => X"D405",
                4  => X"0604",
                5  => X"8808",
                6  => X"290E",
                7  => X"BA0F",
                8  => X"4500",
                9  => X"D601",
                10 => X"8808",
                11 => X"F90B",
                12 => X"2B01",
                13 => X"BD05",
                14 => X"6E0B",
                15 => X"FF0F"

                
        );
    begin
        if rising_edge(clock_28_s) then
            vga_col_v := to_integer(unsigned(color_index));
            vga_rgb_v := rgb_c(vga_col_v);
            
            if scanlines_en_s = "01" then --25% = 1/2 + 1/4
                    vga_r_s <= ('0' & (vga_rgb_v(15 downto 12))) + ("00" & (vga_rgb_v(15 downto 13)));
                    vga_g_s <= ('0' & (vga_rgb_v(11 downto  8))) + ("00" & (vga_rgb_v(11 downto  9))) or osd_green_s;
                    vga_b_s <= ('0' & (vga_rgb_v( 3 downto  0))) + ("00" & (vga_rgb_v( 3 downto  1)));

            elsif scanlines_en_s = "10" then -- 50%
                    vga_r_s <= '0' & vga_rgb_v(15 downto 12);
                    vga_g_s <= '0' & vga_rgb_v(11 downto  8) or osd_green_s;
                    vga_b_s <= '0' & vga_rgb_v( 3 downto  0);
                    
            elsif scanlines_en_s = "11" then -- 75%
                    vga_r_s <= "00" & vga_rgb_v(15 downto 13);
                    vga_g_s <= "00" & vga_rgb_v(11 downto  9) or osd_green_s;
                    vga_b_s <= "00" & vga_rgb_v( 3 downto  1);
            end if;
            
            if  scanlines_en_s = "00" or odd_line_s = '0' then 
                    vga_r_s <= vga_rgb_v(15 downto 12) & vga_rgb_v(12);
                    vga_g_s <= vga_rgb_v(11 downto  8) & vga_rgb_v(8) or osd_green_s;
                    vga_b_s <= vga_rgb_v( 3 downto  0) & vga_rgb_v(0);
            end if;
        
            
            
        end if;
    end process;

    
     osd1 : osd 
    generic map
    (
        STRLEN => CONF_STR'length,
        OSD_COLOR => "001", -- RGB
        OSD_X_OFFSET => "0000010010", -- 18
        OSD_Y_OFFSET => "0000001111"  -- 15
    )
    port map
    (
        pclk        => clock_28_s,

        -- spi for OSD
        sdi        => SPI_DI,
        sck        => SPI_SCK,
        ss         => SPI_SS2,
        sdo        => SPI_DO,
        
        red_in     => vga_r_s, --video_r_s(7 downto 3), --vga_r_s,
        green_in   => vga_g_s, --video_g_s(7 downto 3), --vga_g_s,
        blue_in    => vga_b_s, --video_b_s(7 downto 3), --vga_b_s,
        hs_in      => video_hsync_n_s,
        vs_in      => video_vsync_n_s,

        red_out    => osd_r_s,
        green_out  => osd_g_s,
        blue_out   => osd_b_s,
        hs_out     => VGA_HS,
        vs_out     => VGA_VS,

        data_in     => osd_s,
        conf_str    => to_slv(CONF_STR),
        menu_in     => '0',
        status      => menu_status,
        mc_ack      => mc_ack,
        reset       => reset_s,
        
        pump_active_o   => pump_active_s,
        sram_a_o        => sram_addr_s,
        sram_d_o        => sram_data_s,
        sram_we_n_o     => sram_we_s,
        config_buffer_o => open
    );
    
    sram_addr_o   <= sram_addr_s when pump_active_s = '1' else disk_addr_s;
    sram_data_io  <= sram_data_s when pump_active_s = '1' else (others=>'Z');
    disk_data_s   <= sram_data_io;
   sram_oe_n_o   <= '0'; 
    sram_we_n_o   <= sram_we_s;
    

        -- HDMI
        hdmi: entity work.hdmi
        generic map (
            FREQ    => 28571429,    -- pixel clock frequency 
            FS      => 48000,       -- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
            CTS => 28571,       -- CTS = Freq(pixclk) * N / (128 * Fs)
            N       => 6144         -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
        ) 
        port map (
            I_CLK_PIXEL     => clock_28_s,
            I_R             => osd_r_s & osd_r_s(4 downto 2),
            I_G             => osd_g_s & osd_g_s(4 downto 2),
            I_B             => osd_b_s & osd_b_s(4 downto 2),
            I_BLANK         => not video_blank_s,
            I_HSYNC         => video_hsync_n_s,
            I_VSYNC         => video_vsync_n_s,
            -- PCM audio
            I_AUDIO_ENABLE  => '1',
            I_AUDIO_PCM_L   => "00" & pcm_out_s & "000000",
            I_AUDIO_PCM_R   => "00" & pcm_out_s & "000000",
            -- TMDS parallel pixel synchronous outputs (serialize LSB first)
            O_RED               => tdms_r_s,
            O_GREEN         => tdms_g_s,
            O_BLUE          => tdms_b_s
        );

        hdmio: entity work.hdmi_out_altera
        port map (
            clock_pixel_i       => clock_28_s,
            clock_tdms_i        => clock_dvi_s,
            red_i                   => tdms_r_s,
            green_i             => tdms_g_s,
            blue_i              => tdms_b_s,
            tmds_out_p          => tdms_p_s,
            tmds_out_n          => tdms_n_s
        );



        tmds_o(7)   <= tdms_p_s(2); -- 2+       
        tmds_o(6)   <= tdms_n_s(2); -- 2-       
        tmds_o(5)   <= tdms_p_s(1); -- 1+           
        tmds_o(4)   <= tdms_n_s(1); -- 1-       
        tmds_o(3)   <= tdms_p_s(0); -- 0+       
        tmds_o(2)   <= tdms_n_s(0); -- 0-   
        tmds_o(1)   <= tdms_p_s(3); -- CLK+ 
        tmds_o(0)   <= tdms_n_s(3); -- CLK- 
        
        VGA_R <= osd_r_s;
        VGA_G <= osd_g_s;
        VGA_B <= osd_b_s;

end architecture;