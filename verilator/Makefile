V = verilator
COSIM = n

TOP = --top-module emu
RTL = ../rtl
V_INC = +incdir+$(RTL) 

#V_DEFINE = +define+debug=1 +define+SIMULATION=1   -CFLAGS "-I../sim/imgui -I../sim/vinc -I../sim/ -O3"  --timescale-override 1ps/1ps -Wno-TIMESCALEMOD  \
	-I../rtl \
	-I../rtl/tv80
V_DEFINE = +define+debug=1 +define+SIMULATION=1   -CFLAGS "-I../sim/imgui  -I../sim/ -O3 -I/opt/homebrew/include/"  --timescale-override 1ps/1ps -Wno-TIMESCALEMOD  \
	-I../rtl \
	-I../rtl/tv80
#V_DEFINE = +define+debug=1 +define+SIMULATION=1   -CFLAGS "-g -I../sim/imgui -I../sim/vinc -I../sim/"  --timescale-override 1ps/1ps -Wno-TIMESCALEMOD  \
	-I../rtl \
	-I../rtl/tv80

#V_DEFINE += --converge-limit 2000 -Wno-WIDTH -Wno-IMPLICIT -Wno-MODDUP -Wno-UNSIGNED -Wno-CASEINCOMPLETE -Wno-CASEX -Wno-SYMRSVDWORD -Wno-COMBDLY -Wno-INITIALDLY -Wno-BLKANDNBLK -Wno-UNOPTFLAT -Wno-SELRANGE -Wno-CMPCONST -Wno-CASEOVERLAP -Wno-PINMISSING -Wno-MULTIDRIVEN
#V_DEFINE += --threads 8  # this slows it way down
V_DEFINE += 

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), Darwin) #APPLE
	ECHO_MESSAGE = "Mac OS X"
	LIBS += -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo `sdl2-config --libs`
	LIBS += -L/usr/local/lib -L/opt/local/lib

	CXXFLAGS += `sdl2-config --cflags` -Iimgui -I/opt/homebrew/include/
	CXXFLAGS += -I/usr/local/include -I/opt/local/include 
	CFLAGS = $(CXXFLAGS) -Iimgui
endif

ifeq ($(UNAME_S), Linux) #LINUX
	ECHO_MESSAGE = "Linux"
	LIBS += -lGL -ldl `sdl2-config --libs`

	CXXFLAGS += `sdl2-config --cflags` -Iimgui 
	CFLAGS = $(CXXFLAGS)
endif

ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
	ECHO_MESSAGE = "MinGW"
	LIBS += -lgdi32 -lopengl32 -limm32 `pkg-config --static --libs sdl2`

	CXXFLAGS += `pkg-config --cflags sdl2` 
	CFLAGS = $(CXXFLAGS) 
endif 
 
CFLAGS += $(CC_OPT) $(CC_DEFINE) -Iimgui 
LDFLAGS = $(LIBS)
EXE = ./obj_dir/Vemu
V_OPT = -O3 --x-assign fast --x-initial fast --noassert 
CC_OPT = -O3

V_SRC = \
        sim.v \
	$(RTL)/t65/t65_alu.v  $(RTL)/t65/t65_mcode.v  $(RTL)/t65/t65_pack.v  $(RTL)/t65/t65.v \
	$(RTL)/tk2000.v \
	$(RTL)/timing_generator.sv \
	$(RTL)/keyboard.sv \
	$(RTL)/keyscans.vh \
	$(RTL)/peripheral/disk_ii.v \
	$(RTL)/peripheral/drive_ii.v \
	$(RTL)/peripheral/floppy_track.sv \
	$(RTL)/rom.v \
	$(RTL)/bram.sv \
	$(RTL)/video/video_generator.sv \
	$(RTL)/video/vga_controller_appleii.v



C_SRC = \
	sim_main.cpp  \
	sim/sim_bus.cpp sim/sim_blkdevice.cpp sim/sim_clock.cpp sim/sim_console.cpp sim/sim_video.cpp sim/sim_console.cpp sim/sim_input.cpp  sim/sim_audio.cpp \
	sim/imgui/imgui_impl_sdl.cpp sim/imgui/imgui_impl_opengl2.cpp sim/imgui/imgui_draw.cpp sim/imgui/imgui_widgets.cpp sim/imgui/imgui_tables.cpp sim/imgui/imgui.cpp sim/imgui/ImGuiFileDialog.cpp sim/imgui/implot.cpp sim/imgui/implot_items.cpp

VOUT = obj_dir/Vemu.cpp

all: $(EXE)

$(VOUT): $(V_SRC)  Makefile
	$V -cc $(V_OPT) -LDFLAGS "$(LDFLAGS) " -exe  --Mdir ./obj_dir $(V_DEFINE) $(V_INC) $(TOP) -CFLAGS $(CFLAGS) $(V_SRC) $(C_SRC)

$(EXE): $(VOUT) $(C_SRC)
#	(cd obj_dir; make OPT="-fauto-inc-dec -fdce -fdefer-pop -fdse -ftree-ccp -ftree-ch -ftree-fre -ftree-dce -ftree-dse" -f Vemu.mk)
	(cd obj_dir; make -f Vemu.mk)

fast:
	(cd obj_dir; rm -f *.o ; make OPT="-fcompare-elim -fcprop-registers -fguess-branch-probability -fauto-inc-dec -fif-conversion2 -fif-conversion -fipa-pure-const -fdce -fipa-profile -fipa-reference -fmerge-constants -fsplit-wide-types -fdefer-pop -fdse -ftree-ccp -ftree-ch -ftree-fre -ftree-dce -ftree-dse -ftree-builtin-call-dce -ftree-copyrename -ftree-dominator-opts -ftree-forwprop -ftree-phiprop -ftree-sra -ftree-pta -ftree-ter -funit-at-a-time -ftree-bit-ccp -falign-functions  -falign-jumps -falign-loops  -falign-labels -fcaller-saves -fcrossjumping -fcse-follow-jumps -fcse-skip-blocks -fdelete-null-pointer-checks -fdevirtualize -fexpensive-optimizations -fgcse  -fgcse-lm -finline-small-functions -findirect-inlining -fipa-sra -foptimize-sibling-calls -fpartial-inlining -fpeephole2 -fregmove -freorder-blocks  -freorder-functions -frerun-cse-after-loop -fsched-interblock  -fsched-spec -fschedule-insns -fschedule-insns2 -fstrict-aliasing -fstrict-overflow -ftree-switch-conversion -ftree-pre -ftree-vrp" -f Vemu.mk)

clean:
	rm -f obj_dir/*
