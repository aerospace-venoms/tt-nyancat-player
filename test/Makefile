# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v nyan_tables.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

ifeq ($(WAVES),1)
PLUSARGS += +waves
endif

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# ---- Audio: simulate at the real clock and render a WAV you can listen to ----
#   make wav                 -> ../out/nyan_rtl.wav (one loop)
#   make wav SLOTS=32 UI=2   -> first 32 16th notes, ui_in=2 (one octave down)
#   make wav GATES=yes       -> ../out/nyan_gl.wav from the gate-level netlist
SLOTS ?= 256
UI ?= 0
WAV_NAME = $(if $(filter yes,$(GATES)),nyan_gl,nyan_rtl)
WAV_SOURCES = $(filter-out $(PWD)/tb.v,$(VERILOG_SOURCES)) $(PWD)/wav_tb.v
WAV_ARGS = -I$(SRC_DIR) $(if $(filter yes,$(GATES)),-DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1)

wav:
	mkdir -p ../out $(SIM_BUILD)
	iverilog -g2012 $(WAV_ARGS) -s wav_tb -o $(SIM_BUILD)/wav_tb.vvp $(WAV_SOURCES)
	vvp -n $(SIM_BUILD)/wav_tb.vvp +slots=$(SLOTS) +ui=$(UI) +out=$(SIM_BUILD)/wav_samples.txt
	python3 wav.py $(SIM_BUILD)/wav_samples.txt ../out/$(WAV_NAME).wav

.PHONY: wav
