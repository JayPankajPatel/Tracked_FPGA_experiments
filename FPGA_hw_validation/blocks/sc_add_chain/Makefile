MICROARCH_LIB ?= $(HOME)/Repos/Microarch_Lib
export MICROARCH_LIB
HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export HWB_GEN_DIR := $(HERE)/gen
SIM ?= verilator
TOPLEVEL_LANG := verilog
M := $(MICROARCH_LIB)/blocks
TB := $(M)/stochastic/verif/tb
VERILOG_SOURCES := $(M)/basic/rtl/counter.sv $(M)/stochastic/rtl/galois_lfsr.sv $(M)/stochastic/rtl/binary_stochastic_converter.sv \
  $(M)/stochastic/rtl/stochastic_binary_converter.sv $(M)/stochastic/rtl/stochastic_adder.sv $(TB)/test_b_add_s_integration/top.sv
VERILOG_INCLUDE_DIRS := $(MICROARCH_LIB)/common/rtl
COCOTB_TOPLEVEL := top
COCOTB_TEST_MODULES := record
COMPILE_ARGS += -sv -j 0 -Wno-WIDTHTRUNC -GWIDTH=8 -GINIT_SEED_A=1 -GINIT_SEED_B=204
EXTRA_ARGS += --trace
export PYTHONPATH := $(HERE):$(HERE)/../../verif:$(MICROARCH_LIB)/common/verif:$(PYTHONPATH)
include $(shell cocotb-config --makefiles)/Makefile.sim
