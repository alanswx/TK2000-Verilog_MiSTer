#include <verilated.h>
#include "Vemu.h"

#include "imgui.h"
#include "implot.h"
#ifndef _MSC_VER
#include <stdio.h>
#include <SDL.h>
#include <SDL_opengl.h>
#else
#define WIN32
#include <dinput.h>
#endif

#include "sim_console.h"
#include "sim_bus.h"
#include "sim_blkdevice.h"
#include "sim_video.h"
#include "sim_audio.h"
#include "sim_input.h"
#include "sim_clock.h"

#define FMT_HEADER_ONLY
#include <fmt/core.h>


#include "../imgui/imgui_memory_editor.h"
#include "../imgui/ImGuiFileDialog.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <iterator>
#include <string>
#include <iomanip>
#include <thread>
#include <chrono>

using namespace std;

#define VERILATOR_MAJOR_VERSION (VERILATOR_VERSION_INTEGER / 1000000)

#if VERILATOR_MAJOR_VERSION >= 5
#define VERTOPINTERN top->rootp
#else
#define VERTOPINTERN top
#endif


// Simulation control
// ------------------
int initialReset = 48;
bool run_enable = 1;
int batchSize = 650000;
bool single_step = 0;
bool multi_step = 0;
int multi_step_amount = 1024;


bool stop_on_log_mismatch = 1;
bool debug_6502 = 1;
int cpu_sync;
long cpu_instruction_count;
int cpu_clock;
int cpu_clock_last;
const int ins_size = 48;
int ins_index = 0;
unsigned short ins_pc[ins_size];
unsigned char ins_in[ins_size];
unsigned long ins_ma[ins_size];
unsigned char ins_dbr[ins_size];
bool ins_formatted[ins_size];
std::string ins_str[ins_size];



// Debug GUI 
// ---------
const char* windowTitle = "Verilator Sim: TK2000";
const char* windowTitle_Control = "Simulation control";
const char* windowTitle_DebugLog = "Debug log";
const char* windowTitle_Video = "VGA output";
const char* windowTitle_Audio = "Audio output";
bool showDebugLog = true;
DebugConsole console;
MemoryEditor mem_edit;

// HPS emulator
// ------------
SimBus bus(console);
SimBlockDevice blockdevice(console);

// Input handling
// --------------
SimInput input(13, console);
const int input_right = 0;
const int input_left = 1;
const int input_down = 2;
const int input_up = 3;
const int input_a = 4;
const int input_b = 5;
const int input_x = 6;
const int input_y = 7;
const int input_l = 8;
const int input_r = 9;
const int input_select = 10;
const int input_start = 11;
const int input_menu = 12;

// Video
// -----
#define VGA_WIDTH 320
#define VGA_HEIGHT 240
#define VGA_ROTATE 0  // 90 degrees anti-clockwise
#define VGA_SCALE_X vga_scale
#define VGA_SCALE_Y vga_scale
SimVideo video(VGA_WIDTH, VGA_HEIGHT, VGA_ROTATE);
float vga_scale = 2.5;

// Verilog module
// --------------
Vemu* top = NULL;

vluint64_t main_time = 0;	// Current simulation time.
double sc_time_stamp() {	// Called by $time in Verilog.
	return main_time;
}

int clk_sys_freq = 24000000;
SimClock clk_sys(1);

int soft_reset=0;
vluint64_t soft_reset_time=0;

// Audio
// -----
//#define DISABLE_AUDIO
#ifndef DISABLE_AUDIO
SimAudio audio(clk_sys_freq, false);
#endif

enum instruction_type {
	formatted,
	implied,
	immediate,
	absolute,
	absoluteX,
	absoluteY,
	zeroPage,
	zeroPageX,
	zeroPageY,
	relative,
	relativeLong,
	accumulator,
	direct24,
	direct24X,
	direct24Y,
	indirect,
	indirectX,
	indirectY,
	longValue,
	longX,
	longY,
	stackmode,
	srcdst
};

enum operand_type {
	none,
	byte2,
	byte3
};

struct dasm_data
{
	unsigned short addr;
	const char* name;
};

struct dasm_data32
{
	unsigned long addr;
	const char* name;
};

std::vector<std::string> log_cpu;
long log_index;


bool writeLog(const char* line)
{
		// Write to cpu log
		log_cpu.push_back(line);
		std::string c_line = std::string(line);
		std::string c = "%6d  CPU > " + c_line;
		console.AddLog(c.c_str(), cpu_instruction_count);
		log_index++;

		return true;
#if 0
		// Compare with MAME log
		bool match = true;

		std::string c_line = std::string(line);
		std::string c = "%6d  CPU > " + c_line;
		//printf("%s (%x)\n",line,ins_in[0]); // this has the instruction number
		printf("%s\n",line);

		if (log_index < log_mame.size()) {
			std::string m_line = log_mame.at(log_index);
			std::string m = "%6d MAME > " + m_line;
			if (stop_on_log_mismatch && m_line != c_line) {
				console.AddLog("DIFF at %06d - %06x", cpu_instruction_count, ins_pc[0]);
				console.AddLog(m.c_str(), cpu_instruction_count);
				console.AddLog(c.c_str(), cpu_instruction_count);
				match = false;
			}
			else {
				console.AddLog(c.c_str(), cpu_instruction_count);
			}
		}
		else {
			console.AddLog(c.c_str(), cpu_instruction_count);
		}

		log_index++;
		return match;
	}
	return true;
#endif
}

void DumpInstruction() {

	std::string log = "{0:02X}:{1:04X}: ";
	const char* f = "";
	const char* sta;

	instruction_type type = implied;
	operand_type opType = none;

	std::string arg1 = "";
	std::string arg2 = "";

	switch (ins_in[0])
	{
	case 0x00: sta = "brk"; break;
	case 0x98: sta = "tya"; break;
	case 0xA8: sta = "tay"; break;
	case 0xAA: sta = "tax"; break;
	case 0x8A: sta = "txa"; break;
	case 0x9B: sta = "txy"; break;
	case 0x40: sta = "rti"; break;
	case 0x60: sta = "rts"; break;
	case 0x9A: sta = "txs"; break;
	case 0xBA: sta = "tsx"; break;
	case 0xBB: sta = "tyx"; break;
	case 0x0C: sta = "tsb"; type = absolute; opType = byte3; break;
	case 0x1B: sta = "tcs"; break;
	case 0x5B: sta = "tcd"; break;

	case 0x08: sta = "php"; break;
	case 0x0B: sta = "phd"; break;
	case 0x2B: sta = "pld"; break;
	case 0xAB: sta = "plb"; break;
	case 0x8B: sta = "phb"; break;
	case 0x4B: sta = "phk"; break;
	case 0x28: sta = "plp"; break;
	case 0xfb: sta = "xce"; break;

	case 0x18: sta = "clc"; break;
	case 0x58: sta = "cli"; break;
	case 0xB8: sta = "clv"; break;
	case 0xD8: sta = "cld"; break;

	case 0xE8: sta = "inx"; break;
	case 0xC8: sta = "iny"; break;
	case 0x1A: sta = "ina"; break;

	case 0x70: sta = "bvs"; type = relativeLong; break;
	case 0x80: sta = "bra"; type = relativeLong; break;

	case 0x38: sta = "sec"; break;
	case 0xe2: sta = "sep"; type = immediate;  break;
	case 0x78: sta = "sei"; break;
	case 0xF8: sta = "sed"; break;

	case 0x48: sta = "pha"; break;
	case 0xDA: sta = "phx"; break;
	case 0x5A: sta = "phy"; break;
	case 0x68: sta = "pla"; break;
	case 0xFA: sta = "plx"; break;
	case 0x7A: sta = "ply"; break;

	case 0xF4: sta = "pea"; type = absolute; break;
	case 0x62: sta = "per"; type = relativeLong; break;
	case 0xD4: sta = "pei"; type = zeroPage; break;

	case 0x0A: sta = "asl"; type = accumulator; break;
	case 0x06: sta = "asl"; type = zeroPage; break;
	case 0x16: sta = "asl"; type = zeroPageX; break;
	case 0x0E: sta = "asl"; type = absolute; break;
	case 0x1E: sta = "asl"; type = absoluteX; break;

	case 0x01: sta = "ora"; type = indirectX; break;
	case 0x03: sta = "ora"; type = stackmode; break;
	case 0x05: sta = "ora"; type = zeroPage; break;
	case 0x07: sta = "ora"; type = direct24; break;
	case 0x09: sta = "ora"; type = immediate; break;
	case 0x0D: sta = "ora"; type = absolute; opType = byte2; break;
	case 0x0F: sta = "ora"; type = longValue; opType = byte3; break;
	case 0x11: sta = "ora"; type = indirectY; break;
	case 0x15: sta = "ora"; type = zeroPageX; break;
	case 0x17: sta = "ora"; type = direct24Y; break;
	case 0x19: sta = "ora"; type = absoluteY; break;
	case 0x1D: sta = "ora"; type = absoluteX; break;
	case 0x1F: sta = "ora"; type = longX; break;

	case 0x43: sta = "eor"; type = stackmode; break;
	case 0x47: sta = "eor"; type = direct24; break;
	case 0x49: sta = "eor"; type = immediate; break;
	case 0x4d: sta = "eor"; type = absolute; break;
	case 0x45: sta = "eor"; type = zeroPage; break;
	case 0x55: sta = "eor"; type = zeroPageX; break;
	case 0x57: sta = "eor"; type = direct24Y; break;
	case 0x5d: sta = "eor"; type = absoluteX; break;
	case 0x59: sta = "eor"; type = absoluteY; break;
	case 0x41: sta = "eor"; type = indirectX; break;
	case 0x51: sta = "eor"; type = indirectY; break;

	case 0x23: sta = "and"; type = stackmode; break;
	case 0x25: sta = "and"; type = zeroPage; break;
	case 0x27: sta = "and"; type = direct24; break;
	case 0x29: sta = "and"; type = immediate; break;
	case 0x2D: sta = "and"; type = absolute; break;
	case 0x35: sta = "and"; type = zeroPageX; break;
	case 0x37: sta = "and"; type = direct24Y; break;
	case 0x39: sta = "and"; type = absoluteY; break;
	case 0x3D: sta = "and"; type = absoluteX; break;


	case 0xE1: sta = "sbc"; type = indirectX; break;
	case 0xE3: sta = "sbc"; type = stackmode; break;
	case 0xE5: sta = "sbc"; type = zeroPage; break;
	case 0xE7: sta = "sbc"; type = direct24; break;
	case 0xE9: sta = "sbc"; type = immediate; break;
	case 0xED: sta = "sbc"; type = absolute; break;
	case 0xF1: sta = "sbc"; type = indirectY; break;
	case 0xF5: sta = "sbc"; type = zeroPageX; break;
	case 0xF7: sta = "sbc"; type = direct24Y; break;
	case 0xF9: sta = "sbc"; type = absoluteY; break;
	case 0xFD: sta = "sbc"; type = absoluteX; break;

	case 0xC3: sta = "cmp"; type = stackmode; break;
	case 0xC5: sta = "cmp"; type = zeroPage; break;
	case 0xC7: sta = "cmp"; type = direct24; break;
	case 0xC9: sta = "cmp"; type = immediate; break;
	case 0xCD: sta = "cmp"; type = absolute; break;
	case 0xCF: sta = "cmp"; type = longValue; opType=byte3; break;
	case 0xD1: sta = "cmp"; type = indirectY; break;
	case 0xD5: sta = "cmp"; type = zeroPageX; break;
	case 0xD7: sta = "cmp"; type = direct24Y; break;
	case 0xD9: sta = "cmp"; type = absoluteY; break;
	case 0xDD: sta = "cmp"; type = absoluteX; break;
	case 0xDF: sta = "cmp"; type = longX; break;


	case 0xE0: sta = "cpx"; type = immediate; break;
	case 0xE4: sta = "cpx"; type = zeroPage; break;
	case 0xEC: sta = "cpx"; type = absolute; break;

	case 0xC0: sta = "cpy"; type = immediate; break;
	case 0xC4: sta = "cpy"; type = zeroPage; break;
	case 0xCC: sta = "cpy"; type = absolute; break;

	case 0xC2: sta = "rep"; type = immediate; break;

	case 0xA2: sta = "ldx"; type = immediate; break;
	case 0xA6: sta = "ldx"; type = zeroPage; break;
	case 0xB6: sta = "ldx"; type = zeroPageY; break;
	case 0xAE: sta = "ldx"; type = absolute; break;
	case 0xBE: sta = "ldx"; type = absoluteY; break;

	case 0xA0: sta = "ldy"; type = immediate; break;
	case 0xA4: sta = "ldy"; type = zeroPage; break;
	case 0xB4: sta = "ldy"; type = zeroPageX; break;
	case 0xAC: sta = "ldy"; type = absolute; break;
	case 0xBC: sta = "ldy"; type = absoluteX; break;

	case 0xA1: sta = "lda"; type = indirectX; break;
	case 0xA3: sta = "lda"; type = stackmode; break;
	case 0xA5: sta = "lda"; type = zeroPage; break;
	case 0xA7: sta = "lda"; type = direct24; break;
	case 0xA9: sta = "lda"; type = immediate; break;
	case 0xAD: sta = "lda"; type = absolute; opType = byte3; break;
	case 0xAF: sta = "lda"; type = longValue; opType=byte3; break;
	case 0xB1: sta = "lda"; type = indirectY; break;
	case 0xB2: sta = "lda"; type = indirect; break;
	case 0xB5: sta = "lda"; type = zeroPageX; break;
	case 0xB7: sta = "lda"; type = direct24Y; break;
	case 0xB9: sta = "lda"; type = absoluteY; break;
	case 0xBD: sta = "lda"; type = absoluteX; break;
	case 0xBF: sta = "lda"; type = longX; break;


	case 0x1C: sta = "trb"; type = absolute; break;

	case 0x81: sta = "sta"; type = indirectX; break;
	case 0x83: sta = "sta"; type = stackmode; break;
	case 0x85: sta = "sta"; type = zeroPage; break;
	case 0x87: sta = "sta"; type = direct24; break;
	case 0x8D: sta = "sta"; type = absolute; opType = byte3; break;
	case 0x8F: sta = "sta"; type = longValue; opType = byte3; break;
	case 0x91: sta = "sta"; type = indirectY; break;
	case 0x95: sta = "sta"; type = zeroPageX; break;
	case 0x97: sta = "sta"; type = direct24Y; break;
	case 0x99: sta = "sta"; type = absoluteY; break;
	case 0x9D: sta = "sta"; type = absoluteX; break;
	case 0x9F: sta = "sta"; type = longX; break;


	case 0x86: sta = "stx"; type = zeroPage; break;
	case 0x96: sta = "stx"; type = zeroPageY; break;
	case 0x8E: sta = "stx"; type = absolute; break;
	case 0x84: sta = "sty"; type = zeroPage; break;
	case 0x94: sta = "sty"; type = zeroPageX; break;
	case 0x8C: sta = "sty"; type = absolute; break;
	case 0x64: sta = "stz"; type = zeroPage;  break;
	case 0x9C: sta = "stz"; type = absolute;  opType = byte3; break;
	case 0x9E: sta = "stz"; type = absoluteX; break;

	case 0x63: sta = "adc"; type = stackmode; break;
	case 0x65: sta = "adc"; type = zeroPage; break;
	case 0x67: sta = "adc"; type = direct24; break;
	case 0x69: sta = "adc"; type = immediate; break;
	case 0x6D: sta = "adc"; type = absolute; break;
	case 0x75: sta = "adc"; type = zeroPageX; break;
	case 0x77: sta = "adc"; type = direct24Y; break;
	case 0x79: sta = "adc"; type = absoluteY; break;
	case 0x7D: sta = "adc"; type = absoluteX; break;

	case 0x3b: sta = "tsc"; break;
	case 0x7b: sta = "tdc"; break;

	case 0xC6: sta = "dec"; type = zeroPage;  break;
	case 0xD6: sta = "dec"; type = zeroPageX;  break;
	case 0xCE: sta = "dec"; type = absolute;  break;
	case 0xDE: sta = "dec"; type = absoluteX;  break;

	case 0x3A: sta = "dea"; break;
	case 0xCA: sta = "dex"; break;
	case 0x88: sta = "dey"; break;

	case 0xEB: sta = "xba"; break;

	case 0x24: sta = "bit"; type = zeroPage; break;
	case 0x2C: sta = "bit"; type = absolute; break;
	case 0x3C: sta = "bit"; type = absoluteX; break;
	case 0x89: sta = "bit"; type = immediate; break;

	case 0x30: sta = "bmi"; type = relativeLong; break;
	case 0x90: sta = "bcc"; type = relative; break;
	case 0xB0: sta = "bcs"; type = relative; break;
	case 0xD0: sta = "bne"; type = relative; break;
	case 0xF0: sta = "beq"; type = relative; break;
	case 0x50: sta = "bvc"; type = relative; break;
	case 0x10: sta = "bpl"; type = relative; break;

	case 0x26: sta = "rol"; type = zeroPage; break;
	case 0x2a: sta = "rol"; type = accumulator; break;
	case 0x2e: sta = "rol"; type = absolute ; break;
	case 0x3e: sta = "rol"; type = absoluteX; break;

	case 0x66: sta = "ror"; type = zeroPage; break;
	case 0x6a: sta = "ror"; type = accumulator; break;
	case 0x6e: sta = "ror"; type = absolute ; break;
	case 0x7e: sta = "ror"; type = absoluteX; break;

	case 0x46: sta = "lsr"; type = zeroPage; break;
	case 0x4A: sta = "lsr"; type = accumulator; break;
	case 0x4e: sta = "lsr"; type = absolute ; break;
	case 0x5e: sta = "lsr"; type = absoluteX; break;

	case 0x54: sta = "mvn"; type = srcdst; break;
	case 0x44: sta = "mvp"; type = srcdst; break;

	case 0xE6: sta = "inc"; type = zeroPage; break;
	case 0xF6: sta = "inc"; type = zeroPageX; break;
	case 0xEE: sta = "inc"; type = absolute; break;
	case 0xFE: sta = "inc"; type = absoluteX; break;

	case 0x20: sta = "jsr"; type = absolute; opType = byte3; break;
	case 0xFC: sta = "jsr"; type = absoluteX; break;

	case 0x22: sta = "jsl"; type = longValue; opType = byte3; break;

	case 0x4C: sta = "jmp"; type = absolute; break;
	case 0x5C: sta = "jmp"; type = longValue; opType=byte3; break;
	case 0x6C: sta = "jmp"; type = indirect; break;
	case 0x7C: sta = "jmp"; type = absoluteX; break;

	case 0x6B: sta = "rtl";  break;

	case 0xEA: sta = "nop";  break;

	default: sta = "???";  f = "\t\tPC={0:X} arg1={1:X} arg2={2:X} IN0={3:X} IN1={4:X} IN2={5:X} IN3={6:X} IN4={7:X} MA0={8:X} MA1={9:X} MA2={10:X} MA3={11:X} MA4={12:X}";
	}

	// replace out named values?

	if (ins_index > 1) {

		if (opType == byte3) {
			unsigned long operand = ins_in[1];
			operand |= (ins_in[2] << 8);
			operand |= (ins_in[3] << 16);

			if (ins_index <= 3) {
				operand = ins_in[1];
				operand |= (ins_in[2] << 8);
				operand |= (ins_dbr[1] << 16);
			}
			//console.AddLog("%d %x", ins_index, operand);

		}

		if (type != formatted && (opType == byte2 || (opType == byte3 && ins_index == 3))) {

			unsigned short operand = ins_in[1];
			if (ins_index > 2) {
				operand |= (ins_in[2] << 8);
			}

			int item = 0;
		}
	}


	f = "{2:s}";
	unsigned long relativeAddress = ins_ma[0] + ((signed char)ins_in[1]) + 2;
	if (sta == "per") {
		relativeAddress++; // I HATE THIS
	}
	unsigned char maHigh0 = (unsigned char)(ins_ma[0] >> 16) & 0xff;
	unsigned char maHigh1 = (unsigned char)(ins_ma[1] >> 16) & 0xff;

	signed char signedIn1 = ins_in[1];
	std::string signedIn1Formatted = signedIn1 < 0 ? fmt::format("-${0:x}", signedIn1 * -1) : fmt::format("${0:x}", signedIn1);

	switch (type) {
	case implied: f = ""; break;
	case formatted: arg1 = ins_str[1]; f = " {2:s}"; break;
	case immediate:
		if (ins_index == 3) {
			arg1 = fmt::format(" #${0:02x}{1:02x}", ins_in[2], ins_in[1]);
		}
		else {
			arg1 = fmt::format(" #${0:02x}", ins_in[1]);
		}
		break;
	case srcdst: arg1 = fmt::format(" ${0:02x}, ${1:02x}", ins_in[2], ins_in[1]); break;
	case absolute: arg1 = fmt::format(" ${0:02x}{1:02x}", ins_in[2], ins_in[1]); break;
	case absoluteX: arg1 = fmt::format(" ${0:02x}{1:02x},x", ins_in[2], ins_in[1]); break;
	case absoluteY: arg1 = fmt::format(" ${0:02x}{1:02x},y", ins_in[2], ins_in[1]); break;
	case zeroPage: arg1 = fmt::format(" ${0:02x}", ins_in[1]); break;
	case direct24: arg1 = fmt::format(" [${0:02x}]", ins_in[1]); break;
	case direct24X: arg1 = fmt::format(" [${0:02x}],x", ins_in[1]); break;
	case direct24Y: arg1 = fmt::format(" [${0:02x}],y", ins_in[1]); break;
	case zeroPageX: arg1 = fmt::format(" ${0:02x},x", ins_in[1]); break;
	case zeroPageY: arg1 = fmt::format(" ${0:02x},y", ins_in[1]); break;
	case indirect: arg1 = fmt::format(" (${0:04x})", ins_in[1]); break;
	case indirectX: arg1 = fmt::format(" (${0:02x}),x", ins_in[1]); break;
	case indirectY: arg1 = fmt::format(" (${0:02x}),y", ins_in[1]); break;
	case stackmode: arg1 = fmt::format(" ${0:x},s", ins_in[1]); break;
	case longValue: arg1 = fmt::format(" ${0:02x}{1:02x}{2:02x}", ins_in[3], ins_in[2], ins_in[1]); break;
	case longX: arg1 = fmt::format(" ${0:02x}{1:02x}{2:02x},x", ins_in[3], ins_in[2], ins_in[1]); break;
	case longY: arg1 = fmt::format(" ${0:02x}{1:02x}{2:02x},y", ins_in[3], ins_in[2], ins_in[1]); break;
		//case longX: arg1 = fmt::format(" ${0:02x}{1:02x}{2:02x},x", maHigh1, ins_in[2], ins_in[1]); break;
		//case longY: arg1 = fmt::format(" ${0:02x}{1:02x}{2:02x},y", maHigh1, ins_in[2], ins_in[1]); break;
	case accumulator: arg1 = "a"; break;
	case relative: arg1 = fmt::format(" {0:06x} ({1})", relativeAddress, signedIn1Formatted);		break;
	case relativeLong: arg1 = fmt::format(" {0:06x} ({1})", relativeAddress, signedIn1Formatted);		break;
	default: arg1 = "UNSUPPORTED TYPE!";
	}

	log.append(sta);
	log.append(f);
	log = fmt::format(log, maHigh0, (unsigned short)ins_pc[0], arg1);

	if (!writeLog(log.c_str())) {
	//	run_state = RunState::Stopped;
	}
	cpu_instruction_count++;
	//if (sta == "???") {
	//	console.AddLog(log.c_str());
	//	run_enable = 0;
	//}

}


// Reset simulation variables and clocks
void resetSim() {
	main_time = 0;
	top->reset = 1;
	clk_sys.Reset();
}

	//MSM6242B layout
void send_clock() {
	//printf("Update RTC %ld %d\n",main_time,send_clock_done);
	uint8_t rtc[8];
	
//	printf("Update RTC %ld %d\n",main_time,send_clock_done);
	
	time_t t;

	time(&t);

	struct tm tm;
        localtime_r(&t,&tm);

	
	rtc[0] = (tm.tm_sec % 10) | ((tm.tm_sec / 10) << 4);
	rtc[1] = (tm.tm_min % 10) | ((tm.tm_min / 10) << 4);
	rtc[2] = (tm.tm_hour % 10) | ((tm.tm_hour / 10) << 4);
	rtc[3] = (tm.tm_mday % 10) | ((tm.tm_mday / 10) << 4);

	rtc[4] = ((tm.tm_mon + 1) % 10) | (((tm.tm_mon + 1) / 10) << 4);
	rtc[5] = (tm.tm_year % 10) | (((tm.tm_year / 10) % 10) << 4);
	rtc[6] = tm.tm_wday;
	rtc[7] = 0x40;

	// 64:0
	 
	//top->RTC_l = 0;
	top->RTC_l = rtc[0] | rtc[1] << 8 | rtc[2] << 16 | rtc[3] << 24 ;
	printf("RTC: %x 0: %x",top->RTC_l,rtc[0]);
	top->RTC_h = rtc[4] | rtc[5] << 8 | rtc[6] << 16 | rtc[7] << 24 ;
	//t += t - mktime(gmtime(&t));
	top->RTC_toggle=~top->RTC_toggle;
	// 32:0
	//top->TIMESTAMP=t;//|0x01<<32;


}


int verilate() {

	if (!Verilated::gotFinish()) {
		if (soft_reset){
			fprintf(stderr,"soft_reset.. in gotFinish\n");
			top->soft_reset = 1;
			soft_reset=0;
			soft_reset_time=0;
			fprintf(stderr,"turning on %x\n",top->soft_reset);
		}
		if (clk_sys.IsRising()) {
			soft_reset_time++;
		}
		if (soft_reset_time==initialReset) {
			top->soft_reset = 0; 
			fprintf(stderr,"turning off %x\n",top->soft_reset);
			fprintf(stderr,"soft_reset_time %ld initialReset %x\n",soft_reset_time,initialReset);
		} 

		// Assert reset during startup
		if (main_time < initialReset) { top->reset = 1; }
		// Deassert reset after startup
		if (main_time == initialReset) { top->reset = 0; }

		// Clock dividers
		clk_sys.Tick();

		// Set system clock in core
		top->clk_sys = clk_sys.clk;

		// Simulate both edges of system clock
		if (clk_sys.clk != clk_sys.old) {
			if (clk_sys.IsRising() && *bus.ioctl_download!=1	) blockdevice.BeforeEval(main_time);
			if (clk_sys.clk) {
				input.BeforeEval();
				bus.BeforeEval();
			}
			top->eval();

			// Log 6502 instructions
			cpu_clock = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__Clk;
			bool cpu_reset = top->reset;
			if (cpu_clock != cpu_clock_last && cpu_reset == 0) {


				unsigned char en = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__Enable;
				if (en) {


			// AJS - put debugger here
			unsigned char vpa = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__VPA;
			unsigned char vda = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__VDA;
			//unsigned char vpb = VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__VPB;
			unsigned char din = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__DI;
			unsigned long addr = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__A;
			unsigned char nextstate = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__MCycle;
		if (VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__Enable)
		{	
			if (vpa && nextstate == 1) {
	
			if (ins_index > 0 && ins_pc[0] > 0) {
				DumpInstruction();
			}
			// Clear instruction cache
			ins_index = 0;
			for (int i = 0; i < ins_size; i++) {
				ins_in[i] = 0;
				ins_ma[i] = 0;
				ins_formatted[i] = false;
			}

			std::string log = fmt::format("{0:06d} > ", cpu_instruction_count);
			log.append(fmt::format("PC={0:04x} ", VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__PC));
			log.append(fmt::format("A={0:04x} ", VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__ABC));
			log.append(fmt::format("X={0:04x} ", VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__X));
			log.append(fmt::format("Y={0:04x} ", VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__Y));

			//log.append(fmt::format("M={0:x} ", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__MF));
			//log.append(fmt::format("E={0:x} ", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__EF));
			//log.append(fmt::format("D={0:04x} ", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__D));
			
			//ImGui::Text("D       0x%04X", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__D);
			//ImGui::Text("SP      0x%04X", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__SP);
			//ImGui::Text("DBR     0x%02X", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__DBR);
			//ImGui::Text("PBR     0x%02X", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__PBR);
			//ImGui::Text("PC      0x%04X", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__PC);
			//if (0x011B==VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__PC)
			//	log.append(fmt::format("D={0:04x} ", VERTOPINTERN->emu__DOT__top__DOT__core__DOT__cpu__DOT__SP));

			console.AddLog(log.c_str());
			}
					if ((vpa || vda) && !(vpa == 0 && vda == 1)) {
						ins_pc[ins_index] = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__PC;
						if (ins_pc[ins_index] > 0) {
							ins_in[ins_index] = din;
							ins_ma[ins_index] = addr;
							ins_dbr[ins_index] = VERTOPINTERN->emu__DOT__tk2000__DOT__cpu6502__DOT__DBR;
							//console.AddLog(fmt::format("! PC={0:06x} IN={1:02x} MA={2:06x} VPA={3:x} VDA={5:x} I={6:x}", ins_pc[ins_index], ins_in[ins_index], ins_ma[ins_index], vpa,  vda, ins_index).c_str());
					//		printf("PC: %x IN=%x MA=%x VPA=%x VDA=%x I=%x\n",ins_pc[ins_index],ins_in[ins_index], ins_ma[ins_index], vpa,  vda, ins_index);
							ins_index++;
							if (ins_index > ins_size - 1) { ins_index = 0; }
					//		printf("ins_index = %d\n",ins_index);
						}
					}
			}


			}
		}
			


			if (clk_sys.clk) { bus.AfterEval(); blockdevice.AfterEval(); }
		}
		
#ifndef DISABLE_AUDIO
		if (clk_sys.IsRising())
		{
			audio.Clock(top->AUDIO_L, top->AUDIO_R);
		}
#endif

		// Output pixels on rising edge of pixel clock
		if (clk_sys.IsRising() && top->CE_PIXEL ) {
			uint32_t colour = 0xFF000000 | top->VGA_B << 16 | top->VGA_G << 8 | top->VGA_R;
			video.Clock(top->VGA_HB, top->VGA_VB, top->VGA_HS, top->VGA_VS, colour);
		}

		if (clk_sys.IsRising()) {
			main_time++;
		}
		return 1;
	}

	// Stop verilating and cleanup
	top->final();
	delete top;
	exit(0);
	return 0;
}

unsigned char mouse_clock = 0;
unsigned char mouse_clock_reduce = 0;
unsigned char mouse_buttons = 0;
unsigned char mouse_x = 0;
unsigned char mouse_y = 0;

char spinner_toggle = 0;

int main(int argc, char** argv, char** env) {

	// Create core and initialise
	top = new Vemu();
	Verilated::commandArgs(argc, argv);

#ifdef WIN32
	// Attach debug console to the verilated code
	Verilated::setDebug(console);
#endif

	// Attach bus
	bus.ioctl_addr = &top->ioctl_addr;
	bus.ioctl_index = &top->ioctl_index;
	bus.ioctl_wait = &top->ioctl_wait;
	bus.ioctl_download = &top->ioctl_download;
	//bus.ioctl_upload = &top->ioctl_upload;
	bus.ioctl_wr = &top->ioctl_wr;
	bus.ioctl_dout = &top->ioctl_dout;
	//bus.ioctl_din = &top->ioctl_din;
	input.ps2_key = &top->ps2_key;

	// hookup blk device
	blockdevice.sd_lba[0] = &top->sd_lba[0];
	blockdevice.sd_lba[1] = &top->sd_lba[1];
	blockdevice.sd_lba[2] = &top->sd_lba[2];
	blockdevice.sd_rd = &top->sd_rd;
	blockdevice.sd_wr = &top->sd_wr;
	blockdevice.sd_ack = &top->sd_ack;
	blockdevice.sd_buff_addr= &top->sd_buff_addr;
	blockdevice.sd_buff_dout= &top->sd_buff_dout;
	blockdevice.sd_buff_din[0]= &top->sd_buff_din[0];
	blockdevice.sd_buff_din[1]= &top->sd_buff_din[1];
	blockdevice.sd_buff_din[2]= &top->sd_buff_din[2];
	blockdevice.sd_buff_wr= &top->sd_buff_wr;
	blockdevice.img_mounted= &top->img_mounted;
	blockdevice.img_readonly= &top->img_readonly;
	blockdevice.img_size= &top->img_size;

	send_clock();

#ifndef DISABLE_AUDIO
	audio.Initialise();
#endif

	// Set up input module
	input.Initialise();
#ifdef WIN32
	input.SetMapping(input_up, DIK_UP);
	input.SetMapping(input_right, DIK_RIGHT);
	input.SetMapping(input_down, DIK_DOWN);
	input.SetMapping(input_left, DIK_LEFT);
	input.SetMapping(input_a, DIK_Z); // A
	input.SetMapping(input_b, DIK_X); // B
	input.SetMapping(input_x, DIK_A); // X
	input.SetMapping(input_y, DIK_S); // Y
	input.SetMapping(input_l, DIK_Q); // L
	input.SetMapping(input_r, DIK_W); // R
	input.SetMapping(input_select, DIK_1); // Select
	input.SetMapping(input_start, DIK_2); // Start
	input.SetMapping(input_menu, DIK_M); // System menu trigger

#else
	input.SetMapping(input_up, SDL_SCANCODE_UP);
	input.SetMapping(input_right, SDL_SCANCODE_RIGHT);
	input.SetMapping(input_down, SDL_SCANCODE_DOWN);
	input.SetMapping(input_left, SDL_SCANCODE_LEFT);
	input.SetMapping(input_a, SDL_SCANCODE_A);
	input.SetMapping(input_b, SDL_SCANCODE_B);
	input.SetMapping(input_x, SDL_SCANCODE_X);
	input.SetMapping(input_y, SDL_SCANCODE_Y);
	input.SetMapping(input_l, SDL_SCANCODE_L);
	input.SetMapping(input_r, SDL_SCANCODE_E);
	input.SetMapping(input_start, SDL_SCANCODE_1);
	input.SetMapping(input_select, SDL_SCANCODE_2);
	input.SetMapping(input_menu, SDL_SCANCODE_M);
#endif
	// Setup video output
	if (video.Initialise(windowTitle) == 1) { return 1; }


        //bus.QueueDownload("floppy.nib",1,0);
	blockdevice.MountDisk("floppy.nib",0);
	//blockdevice.MountDisk("floppy2.nib",2);
	blockdevice.MountDisk("hd.hdv",1);

#ifdef WIN32
	MSG msg;
	ZeroMemory(&msg, sizeof(msg));
	while (msg.message != WM_QUIT)
	{
		if (PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
			continue;
		}
#else
	bool done = false;
	while (!done)
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			ImGui_ImplSDL2_ProcessEvent(&event);
			if (event.type == SDL_QUIT)
				done = true;
		}
#endif
		video.StartFrame();

		input.Read();


		// Draw GUI
		// --------
		ImGui::NewFrame();

		// Simulation control window
		ImGui::Begin(windowTitle_Control);
		ImGui::SetWindowPos(windowTitle_Control, ImVec2(0, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Control, ImVec2(500, 150), ImGuiCond_Once);
		if (ImGui::Button("Reset simulation")) { resetSim(); } ImGui::SameLine();
		if (ImGui::Button("Start running")) { run_enable = 1; } ImGui::SameLine();
		if (ImGui::Button("Stop running")) { run_enable = 0; } ImGui::SameLine();
		ImGui::Checkbox("RUN", &run_enable);
		//ImGui::PopItemWidth();
		ImGui::SliderInt("Run batch size", &batchSize, 1, 1750000);
		if (single_step == 1) { single_step = 0; }
		if (ImGui::Button("Single Step")) { run_enable = 0; single_step = 1; }
		ImGui::SameLine();
		if (multi_step == 1) { multi_step = 0; }
		if (ImGui::Button("Multi Step")) { run_enable = 0; multi_step = 1; }
		//ImGui::SameLine();
		ImGui::SliderInt("Multi step amount", &multi_step_amount, 8, 1024);
		if (ImGui::Button("Soft Reset")) { fprintf(stderr,"soft reset\n"); soft_reset=1; } ImGui::SameLine();

		ImGui::End();

		// Debug log window
		console.Draw(windowTitle_DebugLog, &showDebugLog, ImVec2(500, 700));
		ImGui::SetWindowPos(windowTitle_DebugLog, ImVec2(0, 160), ImGuiCond_Once);

		// Memory debug
		//ImGui::Begin("PGROM Editor");
		//mem_edit.DrawContents(top->emu__DOT__system__DOT__pgrom__DOT__mem, 32768, 0);
		//ImGui::End();
		//ImGui::Begin("CHROM Editor");
		//mem_edit.DrawContents(top->emu__DOT__system__DOT__chrom__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("WKRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__wkram__DOT__mem, 16384, 0);
		//ImGui::End();
		//ImGui::Begin("CHRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__chram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("FGCOLRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__fgcolram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("BGCOLRAM Editor");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__bgcolram__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spriteram__DOT__mem, 96, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Linebuffer RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritelbram__DOT__mem, 1024, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision Buffer RAM A");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__comet__DOT__spritecollisionbufferram_a__DOT__mem, 512, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision Buffer RAM B");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__comet__DOT__spritecollisionbufferram_b__DOT__mem, 512, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Collision RAM ");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritecollisionram__DOT__mem, 32, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite Debug RAM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spritedebugram__DOT__mem, 128000, 0);
		//ImGui::End();
		//ImGui::Begin("Palette ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__palrom__DOT__mem, 64, 0);
		//ImGui::End();
		//ImGui::Begin("Sprite ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__spriterom__DOT__mem, 2048, 0);
		//ImGui::End();
		//ImGui::Begin("Tilemap ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__tilemaprom__DOT__mem, 8192, 0);
		//ImGui::End();
		//ImGui::Begin("Tilemap RAM");
		//	mem_edit.DrawContents(&top->emu__DOT__system__DOT__tilemapram__DOT__mem, 768, 0);
		//ImGui::End();
		//ImGui::Begin("Sound ROM");
		//mem_edit.DrawContents(&top->emu__DOT__system__DOT__soundrom__DOT__mem, 64000, 0);
		//ImGui::End();

		int windowX = 550;
		int windowWidth = (VGA_WIDTH * VGA_SCALE_X) + 24;
		int windowHeight = (VGA_HEIGHT * VGA_SCALE_Y) + 90;

		// Video window
		ImGui::Begin(windowTitle_Video);
		ImGui::SetWindowPos(windowTitle_Video, ImVec2(windowX, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Video, ImVec2(windowWidth, windowHeight), ImGuiCond_Once);

		ImGui::SliderFloat("Zoom", &vga_scale, 1, 8); ImGui::SameLine();
		ImGui::SliderInt("Rotate", &video.output_rotate, -1, 1); ImGui::SameLine();
		ImGui::Checkbox("Flip V", &video.output_vflip);
		ImGui::Text("main_time: %ld frame_count: %d sim FPS: %f", main_time, video.count_frame, video.stats_fps);
		//ImGui::Text("pixel: %06d line: %03d", video.count_pixel, video.count_line);

		// Draw VGA output
		ImGui::Image(video.texture_id, ImVec2(video.output_width * VGA_SCALE_X, video.output_height * VGA_SCALE_Y));
		ImGui::End();

  if (ImGuiFileDialog::Instance()->Display("ChooseFileDlgKey"))
  {
    // action if OK
    if (ImGuiFileDialog::Instance()->IsOk())
    {
      std::string filePathName = ImGuiFileDialog::Instance()->GetFilePathName();
      std::string filePath = ImGuiFileDialog::Instance()->GetCurrentPath();
      // action
fprintf(stderr,"filePathName: %s\n",filePathName.c_str());
fprintf(stderr,"filePath: %s\n",filePath.c_str());
     bus.QueueDownload(filePathName, 1,0);
    }
   
    // close
    ImGuiFileDialog::Instance()->Close();
  }


#ifndef DISABLE_AUDIO

		ImGui::Begin(windowTitle_Audio);
		ImGui::SetWindowPos(windowTitle_Audio, ImVec2(windowX, windowHeight), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Audio, ImVec2(windowWidth, 250), ImGuiCond_Once);

		
		//float vol_l = ((signed short)(top->AUDIO_L) / 256.0f) / 256.0f;
		//float vol_r = ((signed short)(top->AUDIO_R) / 256.0f) / 256.0f;
		//ImGui::ProgressBar(vol_l + 0.5f, ImVec2(200, 16), 0); ImGui::SameLine();
		//ImGui::ProgressBar(vol_r + 0.5f, ImVec2(200, 16), 0);

		int ticksPerSec = (24000000 / 60);
		if (run_enable) {
			audio.CollectDebug((signed short)top->AUDIO_L, (signed short)top->AUDIO_R);
		}
		int channelWidth = (windowWidth / 2)  -16;
		ImPlot::CreateContext();
		if (ImPlot::BeginPlot("Audio - L", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_l, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImGui::SameLine();
		if (ImPlot::BeginPlot("Audio - R", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_r, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImPlot::DestroyContext();
		ImGui::End();
#endif

		video.UpdateTexture();


		// Pass inputs to sim

		top->menu = input.inputs[input_menu];

		top->joystick_0 = 0;
		for (int i = 0; i < input.inputCount; i++)
		{
			if (input.inputs[i]) { top->joystick_0 |= (1 << i); }
		}
		top->joystick_1 = top->joystick_0;

		/*top->joystick_analog_0 += 1;
		top->joystick_analog_0 -= 256;*/
		//top->paddle_0 += 1;
		//if (input.inputs[0] || input.inputs[1]) {
		//	spinner_toggle = !spinner_toggle;
		//	top->spinner_0 = (input.inputs[0]) ? 16 : -16;
		//	for (char b = 8; b < 16; b++) {
		//		top->spinner_0 &= ~(1UL << b);
		//	}
		//	if (spinner_toggle) { top->spinner_0 |= 1UL << 8; }
		//}

		mouse_buttons = 0;
		mouse_x = 0;
		mouse_y = 0;
		if (input.inputs[input_left]) { mouse_x = -2; }
		if (input.inputs[input_right]) { mouse_x = 2; }
		if (input.inputs[input_up]) { mouse_y = 2; }
		if (input.inputs[input_down]) { mouse_y = -2; }

		if (input.inputs[input_a]) { mouse_buttons |= (1UL << 0); }
		if (input.inputs[input_b]) { mouse_buttons |= (1UL << 1); }

		unsigned long mouse_temp = mouse_buttons;
		mouse_temp += (mouse_x << 8);
		mouse_temp += (mouse_y << 16);
		if (mouse_clock) { mouse_temp |= (1UL << 24); }
		mouse_clock = !mouse_clock;

		top->ps2_mouse = mouse_temp;
		top->ps2_mouse_ext = mouse_x + (mouse_buttons << 8);

		// Run simulation
		if (run_enable) {
			for (int step = 0; step < batchSize; step++) { verilate(); }
		}
		else {
			if (single_step) { verilate(); }
			if (multi_step) {
				for (int step = 0; step < multi_step_amount; step++) { verilate(); }
			}
		}
	}

	// Clean up before exit
	// --------------------

#ifndef DISABLE_AUDIO
	audio.CleanUp();
#endif 
	video.CleanUp();
	input.CleanUp();

	return 0;
}
