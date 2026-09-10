# cocotb testbench for the Simon Says MPW top level (RTL and gate level).
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = simon.v sound_gen.v score.v galois_lfsr.v simon_tick_gen.v simon_game.v inverter.v ring_osc.v clock_divider_stage.v simon_mpw_top.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation of the ECC (ICS55) netlist:
SIM_BUILD = sim_build/gl
COMPILE_ARGS += -DGL_TEST -Dfunctional
ICS55_STDCELL ?= $(shell $(PWD)/../scripts/pdk_path.sh stdcell)
VERILOG_SOURCES += $(ICS55_STDCELL)/ics55_LLSC_H7CR/verilog/ics55_LLSC_H7CR.v
VERILOG_SOURCES += $(ICS55_STDCELL)/ics55_LLSC_H7CL/verilog/ics55_LLSC_H7CL.v
# copied in by scripts/harden.sh (dist/<design>.v)
ICS55_MODELS = $(ICS55_STDCELL)/ics55_LLSC_H7CR/verilog/ics55_LLSC_H7CR.v $(ICS55_STDCELL)/ics55_LLSC_H7CL/verilog/ics55_LLSC_H7CL.v
# the ECC netlist has split vector ports: wrap it with the RTL port list
VERILOG_SOURCES += $(PWD)/gate_level_netlist_renamed.v $(PWD)/gl_wrapper.v
# filler / tap / decap cells have no simulation models: stub them
VERILOG_SOURCES += $(PWD)/gl_stubs.v
# gate-level simulation: the full game suite runs in a few minutes with Icarus


endif

VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb
COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim

# rule must follow the cocotb include so that `sim` stays the default goal
$(PWD)/gl_stubs.v: $(PWD)/gate_level_netlist.v
	python3 $(PWD)/../scripts/gl_stubs.py $< $@ $(ICS55_MODELS)
$(PWD)/gate_level_netlist_renamed.v $(PWD)/gl_wrapper.v: $(PWD)/gate_level_netlist.v
	python3 $(PWD)/../scripts/gl_wrapper.py $< $(SRC_DIR)/simon_mpw_top.v simon_mpw_top $(PWD)
