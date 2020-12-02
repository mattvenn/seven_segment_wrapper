# cocotb setup
MODULE = test
TOPLEVEL = seven_seg_wrapper
PROJ_SOURCES = seven-segment-seconds/seven_segment_seconds.v

VERILOG_SOURCES = project_wrapper.v $(PROJ_SOURCES)

include $(shell cocotb-config --makefiles)/Makefile.sim

formal:
	sby -f properties.sby

clean::
	rm -rf *vcd properties
