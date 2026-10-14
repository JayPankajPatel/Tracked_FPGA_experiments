# Record vectors from simulation:  pixi run --manifest-path $MICROARCH_LIB/pixi.toml make
# Overrides: make UPTO=1000
MICROARCH_LIB ?= $(HOME)/Repos/Microarch_Lib
export MICROARCH_LIB
HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
UPTO ?= 100

export HWB_GEN_DIR := $(HERE)/gen

SIM ?= verilator
TOPLEVEL_LANG := verilog
VERILOG_SOURCES := $(MICROARCH_LIB)/blocks/basic/rtl/counter.sv
VERILOG_INCLUDE_DIRS := $(MICROARCH_LIB)/common/rtl
COCOTB_TOPLEVEL := counter
COCOTB_TEST_MODULES := record
COMPILE_ARGS += -sv -j 0 -GUPTO=$(UPTO)
EXTRA_ARGS += --trace
export PYTHONPATH := $(HERE):$(HERE)/../../verif:$(MICROARCH_LIB)/common/verif:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim
