`timescale 1ns / 1ps
/*============================================================================
	Aznable (custom 8-bit computer system) - Verilator emu module

	Author: Jim Gregory - https://github.com/JimmyStones/
	Version: 1.1
	Date: 2021-10-17

	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
===========================================================================*/

module emu (

	input clk_sys,
	input reset,
	input soft_reset,
	input menu,
	
	input [31:0] joystick_0,
	input [31:0] joystick_1,
	input [31:0] joystick_2,
	input [31:0] joystick_3,
	input [31:0] joystick_4,
	input [31:0] joystick_5,
	
	input [15:0] joystick_l_analog_0,
	input [15:0] joystick_l_analog_1,
	input [15:0] joystick_l_analog_2,
	input [15:0] joystick_l_analog_3,
	input [15:0] joystick_l_analog_4,
	input [15:0] joystick_l_analog_5,
	
	input [15:0] joystick_r_analog_0,
	input [15:0] joystick_r_analog_1,
	input [15:0] joystick_r_analog_2,
	input [15:0] joystick_r_analog_3,
	input [15:0] joystick_r_analog_4,
	input [15:0] joystick_r_analog_5,

	input [7:0] paddle_0,
	input [7:0] paddle_1,
	input [7:0] paddle_2,
	input [7:0] paddle_3,
	input [7:0] paddle_4,
	input [7:0] paddle_5,

	input [8:0] spinner_0,
	input [8:0] spinner_1,
	input [8:0] spinner_2,
	input [8:0] spinner_3,
	input [8:0] spinner_4,
	input [8:0] spinner_5,

	// ps2 alternative interface.
	// [8] - extended, [9] - pressed, [10] - toggles with every press/release
	input [10:0] ps2_key,

	// [24] - toggles with every event
	input [24:0] ps2_mouse,
	input [15:0] ps2_mouse_ext, // 15:8 - reserved(additional buttons), 7:0 - wheel movements

	// [31:0] - seconds since 1970-01-01 00:00:00, [32] - toggle with every change
	input [32:0] timestamp,

	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	
	output VGA_HS,
	output VGA_VS,
	output VGA_HB,
	output VGA_VB,

	output CE_PIXEL,
	
	output	[15:0]	AUDIO_L,
	output	[15:0]	AUDIO_R,
	
	input			ioctl_download,
	input			ioctl_wr,
	input [24:0]		ioctl_addr,
	input [7:0]		ioctl_dout,
	input [7:0]		ioctl_index,
	output reg		ioctl_wait=1'b0,

	output [31:0] 		sd_lba[3],
	output [9:0] 		sd_rd,
	output [9:0] 		sd_wr,
	input [9:0] 		sd_ack,
	input [8:0] 		sd_buff_addr,
	input [7:0] 		sd_buff_dout,
	output [7:0] 		sd_buff_din[3],
	input 			sd_buff_wr,
	input [9:0] 		img_mounted,
	input 			img_readonly,

	input [63:0] 		img_size,

	input [31:0]		RTC_l,
	input [31:0]		RTC_h,
	input 			RTC_toggle,
	input [32:0]		TIMESTAMP



);
wire [15:0] joystick_a0 =  joystick_l_analog_0;

wire [64:0] RTC = {  RTC_toggle, RTC_h,RTC_l};

wire UART_CTS;
wire UART_RTS;
wire UART_RXD;
wire UART_TXD;
wire UART_DTR;
wire UART_DSR;

wire CLK_VIDEO = clk_sys;

wire  [7:0] pdl  = {~paddle_0[7], paddle_0[6:0]};
wire [15:0] joys = joystick_a0;
wire [15:0] joya = {joys[15:8], joys[7:0]};
wire  [5:0] joyd = joystick_0[5:0] & {2'b11, {2{~|joys[7:0]}}, {2{~|joys[15:8]}}};

assign AUDIO_L = {audio_l,6'b0};
assign AUDIO_R = {audio_r,6'b0};
wire [9:0] audio_l, audio_r;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg div ;
	
	div <= ~div;
	ce_pix <=  &div ;
end
wire [15:0] hdd_sector;

assign sd_lba[1] = {16'b0,hdd_sector};

assign CE_PIXEL=ce_pix;
wire led;
wire hbl,vbl;
wire fd_write;
wire	fd_write_disk;
wire	fd_read_disk;
wire [13:0] fd_track_addr;
wire [7:0] fd_data_in;
wire [7:0] fd_data_in1;
wire [7:0] fd_data_in2;
wire [7:0] fd_data_do;

always @(posedge clk_sys) begin
	//if (soft_reset) $display("soft_reset %x",soft_reset);
end


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

assign clock_28_s = clk_sys;
assign clock_14_s = clk_sys;



// Resets
wire pll_locked_s;
reg por_reset_s =1'b1 ;  //   : std_logic := '1';
reg reset_s;

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
    .dis_rom_i(1'b1),
    // 1 enable peripheral
    .io_select_n_o(per_iosel_n_s),
    .dev_select_n_o(per_devsel_n_s),
    .per_addr_o(per_addr_s),
    .per_data_from_i(per_data_from_s),
    .per_data_to_o(per_data_to_s)
	 
);


keyboard #(.clkfreq_g(14000)) kb (
  	.clock_i	(clk_sys), //  --clock_28_s,
    .reset_i	(por_reset_s),
	 .ps2_key (ps2_key),
    .rows_i		(kbd_rows_s),
    .row_ctrl_i	(kbd_ctrl_s),
    .cols_o		(kbd_cols_s)
);

wire joy1_right_i  = ~joystick_0[0];
wire joy1_left_i   = ~joystick_0[1];
wire joy1_down_i   = ~joystick_0[2];
wire joy1_up_i     = ~joystick_0[3];
wire joy1_p6_i= ~joystick_0[4];
wire joy1_p9_i= ~joystick_0[5];


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
    //div_s <= div_s + 1;
    //clk_kbd_s <= div_s[1];
    // 7 mhz
  end
   
  assign scanlines_en_s = 2'b00;

 // Glue Logic
  // In the Apple ][, this was a 555 timer
  always @(posedge clock_14_s) begin
    reset_s <= por_reset_s |reset   ;
	 /*
    if((btn_n_i[4] == 1'b0 && btn_n_i[3] == 1'b0) || menu_status[0] == 1'b1 || pump_active_s == 1'b1) begin
      por_reset_s <= 1'b1;
      flash_clk <= {23{1'b0}};
    end
    else*/ 
	 
	 if( reset || pump_active_s == 1'b1) begin
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
/*
dpram  #( .addr_width_g(16),.data_width_g(8)) ram (
	.address_a	(ram_addr),
	.clock_a	(clock_28_s),
	.clock_b	(~clock_2M_s),
	.data_a		(ram_data),
	.q_a		(ram_data_from_s),
	.wren_a		(ram_we)
);
*/
bram #(8,16) ram 
(
        .clock_a(clock_28_s),
        .address_a(ram_addr),
        .wren_a(ram_we),
        .data_a(ram_data),
        .q_a(ram_data_from_s),
        
        .clock_b(clk_sys),
        .address_b(),
        .wren_b(),
        .data_b(),
        .q_b()
);
        


assign ram_we = por_reset_s == 1'b0 ? ram_we_s : 1'b1;
assign ram_data = por_reset_s == 1'b0 ? ram_data_to_s : 8'b00000000;
assign ram_addr = por_reset_s == 1'b0 ? ram_addr_s: 16'h3F4;//std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4

 
// ROM
/*
tk2000_rom rom (
    .clock	(clock_28_s),
    .address(rom_addr_s),
    .q		(rom_data_from_s)
);
*/
   rom #(8,14,"ROMs/TK2000/tk2000.hex") roms (
	   .clock(clock_28_s),
	   .ce(1'b1),
	   .a(rom_addr_s),
	   .data_out(rom_data_from_s)
   );  


// 1 is monochrome
wire 	   COLOR_LINE_CONTROL = video_color_s | 1'b0/* (status[6] |  status[5])*/;  // Color or B&W mode

// VGA
vga_controller_appleii vga (
    .CLK_14M(clock_14_s),
    .VIDEO(video_bit_s),
    .COLOR_LINE(COLOR_LINE_CONTROL),
    .SCREEN_MODE(2'b00/*status[6:5]*/),
    .HBL(video_hbl_s),
    .VBL(video_vbl_s),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_HBL(VGA_HB),
    .VGA_VBL(VGA_VB),
	 
    .VGA_R(video_r_s),
    .VGA_G(video_g_s),
    .VGA_B(video_b_s)
);
	
//	assign VGA_HS	= video_hsync_n_s;
//	assign VGA_VS	= video_vsync_n_s;
	assign VGA_R	= video_r_s;
	assign VGA_G	= video_g_s;
	assign VGA_B	= video_b_s;	 
   //assign VGA_DE =  ~(VBlank | HBlank);



wire  [5:0] track1;
wire  [5:0] track2;
reg   [3:0] track_sec;
wire         cpu_wait_fdd = cpu_wait_fdd1|cpu_wait_fdd2;
wire         cpu_wait_fdd1;
wire         cpu_wait_fdd2;




wire TRACK1_RAM_BUSY;
wire [12:0] TRACK1_RAM_ADDR;
wire [7:0] TRACK1_RAM_DI;
wire [7:0] TRACK1_RAM_DO;
wire TRACK1_RAM_WE;
wire [5:0] TRACK1;

wire TRACK2_RAM_BUSY;
wire [12:0] TRACK2_RAM_ADDR;
wire [7:0] TRACK2_RAM_DI;
wire [7:0] TRACK2_RAM_DO;
wire TRACK2_RAM_WE;
wire [5:0] TRACK2;



disk_ii disk(
    .CLK_14M(clock_14_s),
    .CLK_2M(clock_2M_s),	
    .PHASE_ZERO(phi0_s),
	 
    .IO_SELECT(~per_iosel_n_s),
    .DEVICE_SELECT(~per_devsel_n_s),
	 
    .RESET(reset_s),
    .DISK_READY(DISK_READY),
	 
    .A(per_addr_s),
    .D_IN(per_data_to_s),
    .D_OUT(per_data_from_s),
    .D1_ACTIVE(fd_disk_1),
    .D2_ACTIVE(fd_disk_2),
	 
	  //-- track buffer interface for disk 1  -- TODO
    .TRACK1(TRACK1),
    .TRACK1_ADDR(TRACK1_RAM_ADDR),
    .TRACK1_DO(TRACK1_RAM_DO),
    .TRACK1_DI(TRACK1_RAM_DI),
    .TRACK1_WE(TRACK1_RAM_WE),
    .TRACK1_BUSY(TRACK1_RAM_BUSY),
    //-- track buffer interface for disk 2  -- TODO
    .TRACK2(TRACK2),
    .TRACK2_ADDR(TRACK2_RAM_ADDR),
    .TRACK2_DO(TRACK2_RAM_DO),
    .TRACK2_DI(TRACK2_RAM_DI),
    .TRACK2_WE(TRACK2_RAM_WE),
    .TRACK2_BUSY(TRACK2_RAM_BUSY)


    );




wire fd_disk_1;
wire fd_disk_2;

wire [1:0] DISK_READY;
reg [1:0] DISK_CHANGE;
reg [1:0]disk_mount;



always @(posedge clk_sys) begin
	if (img_mounted[0]) begin
		disk_mount[0] <= img_size != 0;
		DISK_CHANGE[0] <= ~DISK_CHANGE[0];
		//disk_protect <= img_readonly;
	end
end
always @(posedge clk_sys) begin
	if (img_mounted[1]) begin
		disk_mount[1] <= img_size != 0;
		DISK_CHANGE[1] <= ~DISK_CHANGE[1];
		//disk_protect <= img_readonly;
	end
end
floppy_track floppy_track_1
(
   .clk(clk_sys),
	.reset(reset_s),
	
	.ram_addr(TRACK1_RAM_ADDR),
	.ram_di(TRACK1_RAM_DI),
	.ram_do(TRACK1_RAM_DO),
	.ram_we(TRACK1_RAM_WE),

	
	.track (TRACK1),
	.busy  (TRACK1_RAM_BUSY),
   .change(DISK_CHANGE[0]),
   .mount (img_mounted[0]),
   .ready  (DISK_READY[0]),
   .active (fd_disk_1),

   .sd_buff_addr (sd_buff_addr),
   .sd_buff_dout (sd_buff_dout),
   .sd_buff_din  (sd_buff_din[0]),
   .sd_buff_wr   (sd_buff_wr),

   .sd_lba       (sd_lba[0] ),
   .sd_rd        (sd_rd[0]),
   .sd_wr       ( sd_wr[0]),
   .sd_ack       (sd_ack[0])	
);

floppy_track floppy_track_2
(
   .clk(clk_sys),
	.reset(reset_s),

	.ram_addr(TRACK2_RAM_ADDR),
	.ram_di(TRACK2_RAM_DI),
	.ram_do(TRACK2_RAM_DO),
	.ram_we(TRACK2_RAM_WE),
	
	.track (TRACK2),
	.busy  (TRACK2_RAM_BUSY),
   .change(DISK_CHANGE[1]),
   .mount (disk_mount[1]),
   .ready  (DISK_READY[1]),
   .active (fd_disk_2),

   .sd_buff_addr (sd_buff_addr),
   .sd_buff_dout (sd_buff_dout),
   .sd_buff_din  (sd_buff_din[1]),
   .sd_buff_wr   (sd_buff_wr),

   .sd_lba       (sd_lba[1] ),
   .sd_rd        (sd_rd[1]),
   .sd_wr       ( sd_wr[1]),
   .sd_ack       (sd_ack[1])	
);


/*

wire D1_ACTIVE,D2_ACTIVE;
wire TRACK1_RAM_BUSY;
wire [12:0] TRACK1_RAM_ADDR;
wire [7:0] TRACK1_RAM_DI;
wire [7:0] TRACK1_RAM_DO;
wire TRACK1_RAM_WE;
wire [5:0] TRACK1;

wire TRACK2_RAM_BUSY;
wire [12:0] TRACK2_RAM_ADDR;
wire [7:0] TRACK2_RAM_DI;
wire [7:0] TRACK2_RAM_DO;
wire TRACK2_RAM_WE;
wire [5:0] TRACK2;

wire [1:0] DISK_READY;
reg [1:0] DISK_CHANGE;
reg [1:0]disk_mount;



floppy_track floppy_track_1
(
   .clk(clk_sys),
	.reset(reset),

	.ram_addr(TRACK1_RAM_ADDR),
	.ram_di(TRACK1_RAM_DI),
	.ram_do(TRACK1_RAM_DO),
	.ram_we(TRACK1_RAM_WE),

	.track (TRACK1),
	.busy  (TRACK1_RAM_BUSY),
   .change(DISK_CHANGE[0]),
   .mount (disk_mount[0]),
   .ready  (DISK_READY[0]),
   .active (D1_ACTIVE),

   .sd_buff_addr (sd_buff_addr),
   .sd_buff_dout (sd_buff_dout),
   .sd_buff_din  (sd_buff_din[0]),
   .sd_buff_wr   (sd_buff_wr),

   .sd_lba       (sd_lba[0] ),
   .sd_rd        (sd_rd[0]),
   .sd_wr       ( sd_wr[0]),
   .sd_ack       (sd_ack[0])	
);


floppy_track floppy_track_2
(
   .clk(clk_sys),
	.reset(reset),

	.ram_addr(TRACK2_RAM_ADDR),
	.ram_di(TRACK2_RAM_DI),
	.ram_do(TRACK2_RAM_DO),
	.ram_we(TRACK2_RAM_WE),

	.track (TRACK2),
	.busy  (TRACK2_RAM_BUSY),
   .change(DISK_CHANGE[1]),
   .mount (disk_mount[1]),
   .ready  (DISK_READY[1]),
   .active (D2_ACTIVE),

   .sd_buff_addr (sd_buff_addr),
   .sd_buff_dout (sd_buff_dout),
   .sd_buff_din  (sd_buff_din[2]),
   .sd_buff_wr   (sd_buff_wr),

   .sd_lba       (sd_lba[2] ),
   .sd_rd        (sd_rd[2]),
   .sd_wr       ( sd_wr[2]),
   .sd_ack       (sd_ack[2])	
);
*/

wire fd_busy;
wire sd_busy;
reg ch1_rd;
always @(posedge CLK_VIDEO) begin
	reg state;
	ch1_rd<=0;
	
	if (~fd_busy & fd_read_disk)
		ch1_rd <=1;
end

	



/* verilator lint_on PINMISSING */

// Debug defines
`define DEBUG_SIMULATION


endmodule 

