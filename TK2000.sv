//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = { 2'b0,spk_s,spk_s,12'b0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_MIX = 0;

assign BUTTONS = 0;

wire led;
assign led = fd_disk_1 | fd_disk_2;
assign LED_USER  = led;
assign LED_DISK  = 0;
assign LED_POWER = 0;

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = 4; //(!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = 3; //(!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	//"TK2000;;",
	"Apple-II;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O2,TV Mode,NTSC,PAL;",
	"O34,Noise,White,Red,Green,Blue;",
	"O56,Display,Color,B&W,Green,Amber;",
	"-;",
	"S0,NIBDSKDO PO ;",
	"S1,NIBDSKDO PO ;",
	"OA,Disk Rom,On,Off;",
	"OB,Color Mode,On,Off;",
	"OC,VERILOG2,A,Left;",
	"-;",
	"R0,Reset;",
	"J,Fire 1,Fire 2;",
	"V,v",`BUILD_DATE 
};


wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire [15:0] joy1, joy2;

wire [31:0] sd_lba[2];
reg   [1:0] sd_rd;
reg   [1:0] sd_wr;
wire  [1:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din[2];
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;


wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;
reg 		ioctl_wait = 0;

//hps_io #(.CONF_STR(CONF_STR),.PS2DIV(1000),.VDNUM(2)) hps_io
hps_io #(.CONF_STR(CONF_STR),.VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	.joystick_0(joy1),
	.joystick_1(joy2),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	
	.ps2_key(ps2_key)
);


//wire clk_sys = clock_28_s;
wire clock_57_s;
wire clk_sys = clock_14_s;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clock_57_s),
	.outclk_1(clock_28_s),
	.outclk_2(clock_14_s),
	.locked(pll_locked_s)
);
    
wire reset = RESET | status[0] | buttons[1];


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire [7:0] video;


assign CLK_VIDEO = clock_57_s;
reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [2:0] div = 0;
	
	div <= div + 1'd1;
	ce_pix <=  &div ;
end

assign CE_PIXEL = ce_pix;


//-- Clocks
wire clock_28_s;      // Dobro para scandoubler
wire clock_14_s;      // Master
wire phi0_s;        // phase 0
wire phi1_s;        // phase 1
wire phi2_s;        // phase 2
wire clock_2M_s;       // Clock Q3
wire clock_dvi_s;

wire clk_kbd_s;
wire [2:0] div_s;


// Resets
wire pll_locked_s;
reg por_reset_s =1'b1 ;  //   : std_logic := '1';
wire reset_s;

// ROM
wire [13:0] rom_addr_s;
wire [7:0] rom_data_from_s;
//--  signal rom_oe_s         : std_logic;
//--  signal rom_we_s         : std_logic;

// RAM
wire [15:0] ram_addr_s;
wire [7:0] ram_data_to_s;
wire [7:0] ram_data_from_s;
wire ram_oe_s;
wire ram_we_s;
wire [15:0] ram_addr;
wire [7:0] ram_data;
wire ram_we;
  
// Keyboard
wire kbd_ctrl_s;
wire [7:0] kbd_rows_s;
wire [5:0] kbd_cols_s;

// Audio
wire spk_s;

// K7
wire cas_o_s;
//--  signal cas_motor_s      : std_logic_vector(1 downto 0);

// -- Video
wire [7:0] video_r_s;
wire [7:0] video_g_s ;
wire [7:0] video_b_s;
wire [7:0] video_ro_s;
wire [7:0] video_go_s;
wire [7:0] video_bo_s;
wire video_color_s ;
wire video_bit_s;
wire video_hsync_n_s ;
wire video_vsync_n_s;
wire video_blank_s  ;
wire video_hbl_s  ;
wire video_vbl_s   ;
wire video_ld194_s   ;
wire per_iosel_n_s;
wire per_devsel_n_s;
wire per_we_s;
wire [7:0] per_addr_s;
wire [7:0] per_data_from_s;
wire [7:0] per_data_to_s;  // Disk II
wire [9:0] image_num_s ;
wire [5:0] track_num_s;
wire [13:0] track_addr_s;
wire disk1_en_s;
wire disk2_en_s;
wire [13:0] track_ram_addr_s;
wire [7:0] track_ram_data_s;
wire track_ram_we_s;  // OSD
wire osd_pixel_s;
wire [4:0] osd_green_s;  // OSD byte signal
wire btn_up_s ;
wire btn_down_s  ;
wire [15:0] D_cpu_pc_s;  //
wire [3:0] color_index;
wire [1:0] scanlines_en_s;
wire [4:0] vga_r_s;
wire [4:0] vga_g_s;
wire [4:0] vga_b_s;
wire [4:0] osd_r_s;
wire [4:0] osd_g_s;
wire [4:0] osd_b_s;
wire [9:0] vga_x_s;
wire [9:0] vga_y_s;
reg [22:0] flash_clk = 1'b0;
wire [31:0] menu_status;
wire odd_line_s;
wire step_sound_s;
reg [5:0] kbd_joy_s;  // Data pump
reg pump_active_s = 1'b0  ;
wire sram_we_s ;

wire [18:0] sram_addr_s ;
wire [7:0] sram_data_s;
wire [18:0] disk_addr_s;
wire [7:0] disk_data_s ;
wire [7:0] pcm_out_s;  // HDMI
wire [9:0] tdms_r_s;
wire [9:0] tdms_g_s;
wire [9:0] tdms_b_s;
wire [3:0] tdms_p_s;
wire [3:0] tdms_n_s;  
// SDISKII
wire [3:0] motor_phase_s ;
wire drive_en_s;
wire rd_pulse_s;


tk2000 tk2000 (
	.clock_14_i(clock_14_s),
    .reset_i(reset_s),
    .CPU_WAIT(cpu_wait_fdd),
    // RAM
    .ram_addr_o(ram_addr_s),
    .ram_data_to_o(ram_data_to_s),
    .ram_data_from_i(ram_data_from_s),
    .ram_oe_o(ram_oe_s),
    .ram_we_o(ram_we_s),
    // ROM
    .rom_addr_o(rom_addr_s),
    .rom_data_from_i(rom_data_from_s),
    .rom_oe_o(/* open */),
    //rom_oe_s,
    .rom_we_o(/* open */),
    //rom_we_s,
    // Keyboard
    .kbd_rows_o(kbd_rows_s),
    .kbd_cols_i(kbd_joy_s),
    .kbd_ctrl_o(kbd_ctrl_s),
    // Audio
    .spk_o(spk_s),
    // Video
    .video_color_o(video_color_s),
    .video_bit_o(video_bit_s),
    .video_hsync_n_o(/* open */),
    .video_vsync_n_o(/* open */),
    .video_hbl_o(video_hbl_s),
    .video_vbl_o(video_vbl_s),
    .video_ld194_o(video_ld194_s),
    // Cassete
    .cas_i(1'b0),
    .cas_o(cas_o_s),
    .cas_motor_o(/* open */),
    //cas_motor_s,
    // LPT
    .lpt_stb_o(/* open */),
    .lpt_busy_i(1'b0),
    // Periferico
    .phi0_o(phi0_s),
    // fase 0 __|---|___|---
    .phi1_o(phi1_s),
    // fase 1 ---|___|---|___
    .phi2_o(phi2_s),
    // fase 2 ___|---|___|---
    .clock_2m_o(clock_2M_s),
    .read_write_o(per_we_s),
    .irq_n_i(1'b1),
    .nmi_n_i(1'b1),
    .dis_rom_i(~status[10]),
    // 1 enable peripheral
    .io_select_n_o(per_iosel_n_s),
    .dev_select_n_o(per_devsel_n_s),
    .per_addr_o(per_addr_s),
    .per_data_from_i(per_data_from_s),
    .per_data_to_o(per_data_to_s),
	 
	 .keyhack(status[12]),
	 
    // Debug
    .D_cpu_pc_o(D_cpu_pc_s)
	

	
);


keyboard #(.clkfreq_g(14000)) kb (
  	.clock_i	(clk_sys), //  --clock_28_s,
    .reset_i	(por_reset_s),
	 .ps2_key (ps2_key),
    .rows_i		(kbd_rows_s),
    .row_ctrl_i	(kbd_ctrl_s),
    .cols_o		(kbd_cols_s)
);




  //  JOYSTICK
  //
  //	on the TK2000 the joystick is mapped to the four arrow keys, and . and L for the two buttons
  //  when a joystick is pressed, just set the corresponding keymap
  always @(posedge clock_28_s) begin
    kbd_joy_s <= kbd_cols_s;
    //kbd_joy_s <= 6'b000000;
    if((kbd_rows_s[6] == 1'b1 && joy1_up_i == 1'b0) || (kbd_rows_s[5] == 1'b1 && joy1_down_i == 1'b0) || (kbd_rows_s[4] == 1'b1 && joy1_right_i == 1'b0) || (kbd_rows_s[3] == 1'b1 && joy1_left_i == 1'b0)) begin
      kbd_joy_s <= kbd_joy_s | 6'b000001;
    end
    if((kbd_rows_s[7] == 1'b1 && joy1_p6_i == 1'b0) /*|| (kbd_rows_s[6] == 1'b1 && joy1_p9_i == 1'b0)*/) begin
      kbd_joy_s <= kbd_joy_s | 6'b010000;
    end
    if( (kbd_rows_s[1] == 1'b1 && joy1_p9_i == 1'b0)) begin
      kbd_joy_s <= kbd_joy_s | 6'b100000;
    end
 
 //generate a slower clock for the keyboard
    div_s <= div_s + 1;
    clk_kbd_s <= div_s[1];
    // 7 mhz
  end
    
// ROM
tk2000_rom rom (
    .clock	(clock_28_s),
    .address(rom_addr_s),
    .q		(rom_data_from_s)
);

// 1 is monochrome
wire 	   COLOR_LINE_CONTROL = video_color_s |  (status[6] |  status[5]);  // Color or B&W mode

// VGA
vga_controller_appleii vga (
    .CLK_14M(clock_14_s),
    .VIDEO(video_bit_s),
    .COLOR_LINE(COLOR_LINE_CONTROL),
	.SCREEN_MODE(status[6:5]),
    .HBL(video_hbl_s),
    .VBL(video_vbl_s),
    .VGA_HS(video_hsync_n_s),
    .VGA_VS(video_vsync_n_s),
	.VGA_HBL(HBlank),
	.VGA_VBL(VBlank),
	 
    .VGA_R(video_r_s),
    .VGA_G(video_g_s),
    .VGA_B(video_b_s)
);
	
	assign VGA_HS	= video_hsync_n_s;
	assign VGA_VS	= video_vsync_n_s;
	assign VGA_R	= video_r_s;
	assign VGA_G	= video_g_s;
	assign VGA_B	= video_b_s;	 
//  assign VGA_DE = (video_blank_s);
   assign VGA_DE =  ~(VBlank | HBlank);





assign sd_rd = { sd_rd_fdd_b,sd_rd_fdd_a };
assign sd_wr = { sd_wr_fdd_b,sd_wr_fdd_a };
wire sd_rd_fdd_a;
wire sd_wr_fdd_a;
wire sd_rd_fdd_b;
wire sd_wr_fdd_b;


disk_ii disk(
    .CLK_14M(clock_14_s),
    .CLK_2M(clock_2M_s),	
    .PHASE_ZERO(phi0_s),
	 
    .IO_SELECT(~per_iosel_n_s),
    .DEVICE_SELECT(~per_devsel_n_s),
	 
    .RESET(reset_s),
    .A(per_addr_s),
    .D_IN(per_data_to_s),
    .D_OUT(per_data_from_s),
	 
	 
    .TRACK1(track1),
    .TRACK2(track2),
	 
    .D1_ACTIVE(fd_disk_1),
    .D2_ACTIVE(fd_disk_2),
    .ram_write_addr({track_sec, sd_buff_addr}),
    .ram_di(sd_buff_dout),
    .ram_we(sd_buff_wr & sd_ack[0]),
    .DISK_FD_READ_DISK(fd_read_disk),
   .DISK_FD_WRITE_DISK(fd_write_disk),
   .DISK_FD_TRACK_ADDR(fd_track_addr),
   .DISK_FD_DATA_IN(fd_data_in),
   .DISK_FD_DATA_OUT(fd_data_do)

    );




wire  [5:0] track1;
wire  [5:0] track2;
reg   [3:0] track_sec;
wire         cpu_wait_fdd = cpu_wait_fdd1|cpu_wait_fdd2;
wire         cpu_wait_fdd1;
wire         cpu_wait_fdd2;

wire	fd_write_disk;
wire	fd_read_disk;
wire [13:0] fd_track_addr;
wire [7:0] fd_data_in;
wire [7:0] fd_data_in1;
wire [7:0] fd_data_in2;
wire [7:0] fd_data_do;


assign fd_data_in = fd_disk_1 ? fd_data_in1 : fd_disk_2 ? fd_data_in2 : 8'h00;

wire fd_disk_1;
wire fd_disk_2;


track_loader #(.drive_num('d0)) track_loader_a
(
    .clk(clk_sys),
    .reset(reset_s),
    .active(fd_disk_1),
    .lba_fdd(sd_lba[0]),
    .track(track1),
    .img_mounted(img_mounted[0]),
    .img_size(img_size),
    .cpu_wait_fdd(cpu_wait_fdd1),
    .sd_ack(sd_ack[0]),
    .sd_rd(sd_rd_fdd_a),
    .sd_wr(sd_wr_fdd_a),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_wr(sd_buff_wr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[0]),
    .fd_track_addr(fd_track_addr),
    .fd_write_disk(fd_write_disk),
    .fd_data_do(fd_data_do),
    .fd_data_in(fd_data_in1)
);
track_loader #(.drive_num('d1)) track_loader_b
(
    .clk(clk_sys),
    .reset(reset_s),
    .active(fd_disk_2),
    .lba_fdd(sd_lba[1]),
    .track(track2),
    .img_mounted(img_mounted[1]),
    .img_size(img_size),
    .cpu_wait_fdd(cpu_wait_fdd2),
    .sd_ack(sd_ack[1]),
    .sd_rd(sd_rd_fdd_b),
    .sd_wr(sd_wr_fdd_b),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_wr(sd_buff_wr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[1]),
    .fd_track_addr(fd_track_addr),
    .fd_write_disk(fd_write_disk),
    .fd_data_do(fd_data_do),
    .fd_data_in(fd_data_in2)
);
`ifdef OFF

assign      sd_lba[0] = lba_fdd;
wire  [5:0] track;
reg   [3:0] track_sec;
reg         cpu_wait_fdd = 0;
reg  [31:0] lba_fdd;
reg       fd_write_pending = 0;

reg       fdd_mounted ;
wire [63:0] disk_size;

// when we write to the disk, we need to mark it dirty
reg floppy_track_dirty;


always @(posedge clk_sys) begin
        reg       wr_state;
        reg [5:0] cur_track;
        reg       old_ack ;
        reg [1:0] state;
		  
       if (img_mounted[0]) begin
               //disk_mounted <= img_size != 0;
					disk_size <= img_size;
       end

		  
		  
        old_ack <= sd_ack[0];
        fdd_mounted <= fdd_mounted | img_mounted[0];

        if (fd_write_disk)
        begin
                floppy_track_dirty<=1;
                // reset timer
        end

        if(dd_reset) begin
                state <= 0;
                cpu_wait_fdd <= 0;
                sd_rd[0] <= 0;
                fd_write_pending<=0;
                floppy_track_dirty<=0;
        end
        else case(state)
                2'b00:  // looking for a track change or a timeout
                if((cur_track != track) || (fdd_mounted && ~img_mounted[0])) begin


                        fdd_mounted <= 0;
                        if(disk_size) begin
                                if (floppy_track_dirty)
                                begin
                                        $display("THIS TRACK HAS CHANGES cur_track %x track %x",cur_track,track);
                                        track_sec <= 0;
                                        floppy_track_dirty<=0;
                                        lba_fdd <= 13 * cur_track;
                                        state <= 2'b01;
                                        sd_wr[0] <= 1;
                                        cpu_wait_fdd <= 1;
                                end
                                else
                                        state<=2'b10;
                        end
                end
                2'b01:  // write data
                begin
                        if(~old_ack & sd_ack[0]) begin
                                if(track_sec >= 12) sd_wr[0] <= 0;
                                lba_fdd <= lba_fdd + 1'd1;
                        end else if(old_ack & ~sd_ack[0]) begin
                                track_sec <= track_sec + 1'd1;
                                if(~sd_wr[0]) state <= 2'b10;
                        end
                end
                2'b10:  // start read
                begin
                        cur_track <= track;
                        track_sec <= 0;
                        lba_fdd <= 13 * track;
                        state <= 2'b11;
                        sd_rd[0] <= 1;
                        cpu_wait_fdd <= 1;
                end
                2'b11:  // read data
                begin
                        if(~old_ack & sd_ack[0]) begin
                                if(track_sec >= 12) sd_rd[0] <= 0;
                                lba_fdd <= lba_fdd + 1'd1;
                        end else if(old_ack & ~sd_ack[0]) begin
                                track_sec <= track_sec + 1'd1;
                                if(~sd_rd[0]) state <= 2'b0;
                                cpu_wait_fdd <= 0;
                        end
                end
        endcase
end
wire	fd_write_disk;
wire	fd_read_disk;
wire [13:0] fd_track_addr;
wire [7:0] fd_data_in;
wire [7:0] fd_data_do;

dpram #(14,8) floppy_dpram
(
	.clock_a(clk_sys),
	.address_a({track_sec, sd_buff_addr}),
	.wren_a(sd_buff_wr & sd_ack[0]),
	.data_a(sd_buff_dout),
	.q_a(sd_buff_din[0]),
	
	.clock_b(clk_sys),
	.address_b(fd_track_addr),
	.wren_b(fd_write_disk),
	.data_b(fd_data_do),
	.q_b(fd_data_in)
);

`endif

wire joy1_right_i  = ~joy1[0];
wire joy1_left_i   = ~joy1[1];
wire joy1_down_i   = ~joy1[2];
wire joy1_up_i     = ~joy1[3];
wire joy1_p6_i= ~joy1[4];
wire joy1_p9_i= ~joy1[5];

/*
wire joy2_right_i = motor_phase_s[3];
wire joy2_left_i = motor_phase_s[2];
wire joy2_down_i = motor_phase_s[1];
wire joy2_up_i = motor_phase_s[0];
wire joy2_p6_i = drive_en_s;

 //--    joy2_p9_i    <= rd_pulse_s;
*/
      
  assign scanlines_en_s = 2'b00;

 // Glue Logic
  // In the Apple ][, this was a 555 timer
  always @(posedge clock_14_s) begin
    reset_s <= por_reset_s |RESET |  buttons[1] | status[0];
	 /*
    if((btn_n_i[4] == 1'b0 && btn_n_i[3] == 1'b0) || menu_status[0] == 1'b1 || pump_active_s == 1'b1) begin
      por_reset_s <= 1'b1;
      flash_clk <= {23{1'b0}};
    end
    else*/ 
	 
	 if(buttons[1] || status[0] || RESET || pump_active_s == 1'b1) begin
      por_reset_s <= 1'b1;
      flash_clk <= {23{1'b0}};
    end
    else
	 begin
      if(flash_clk[22] == 1'b1) begin
        por_reset_s <= 1'b0;
      end
      flash_clk <= flash_clk + 1;
    end
  end

dpram  #( .addr_width_g(16),.data_width_g(8)) ram (
	.address_a	(ram_addr),
	.clock_a	(clock_28_s),
	.clock_b	(~clock_2M_s),
	.data_a		(ram_data),
	.q_a		(ram_data_from_s),
	.wren_a		(ram_we)
);

assign ram_we = por_reset_s == 1'b0 ? ram_we_s : 1'b1;
assign ram_data = por_reset_s == 1'b0 ? ram_data_to_s : 8'b00000000;
assign ram_addr = por_reset_s == 1'b0 ? ram_addr_s: 16'h3F4;//std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4

endmodule
