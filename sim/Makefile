# =============================================================================
# Makefile for I2C Slave / AXI4-Stream UVM Verification Environment
# Default simulator: Synopsys VCS (edit SIM_CMD section to switch tools)
# =============================================================================

TOP        := tb_top
RTL_DIR    := ../rtl
TB_DIR     := ../tb
SRC_DIR    := $(TB_DIR)/src
INC_DIR    := $(TB_DIR)/include

INCDIRS    := +incdir+$(SRC_DIR) +incdir+$(INC_DIR)

RTL_FILES  := $(RTL_DIR)/i2c_slave.v
TB_FILES   := $(TB_DIR)/tb_top.sv

TEST       ?= write_test
SEED       ?= 1

# -----------------------------------------------------------------------
# VCS
# -----------------------------------------------------------------------
vcs:
	vcs -full64 -sverilog -ntb_opts uvm-1.2 $(INCDIRS) \
		$(RTL_FILES) $(TB_FILES) -o simv -timescale=1ns/1ps
	./simv +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED)

# -----------------------------------------------------------------------
# Questa / ModelSim
# -----------------------------------------------------------------------
questa:
	vlib work
	vlog -sv $(INCDIRS) +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv \
		$(RTL_FILES) $(TB_FILES)
	vsim -c work.$(TOP) +UVM_TESTNAME=$(TEST) -sv_seed $(SEED) -do "run -all; quit"

# -----------------------------------------------------------------------
# Xcelium
# -----------------------------------------------------------------------
xrun:
	xrun -uvm -sv $(INCDIRS) $(RTL_FILES) $(TB_FILES) \
		+UVM_TESTNAME=$(TEST) -seed $(SEED)

clean:
	rm -rf simv* csrc *.log *.vcd *.vpd work transcript DVEfiles \
	       xcelium.d *.shm *.key ucli.key AN.DB
