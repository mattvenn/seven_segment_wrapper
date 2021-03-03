# cocotb setup
PROJ_SOURCES = wrapper.v test/dump_wrapper.v seven-segment-seconds/seven_segment_seconds.v
export COCOTB_REDUCED_LOG_FMT=1

test_wrapper:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -DMPRJ_IO_PADS=38 -s wrapped_seven_segment -s dump -g2012 $(PROJ_SOURCES)
	MODULE=test.test vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

show_wrapper:
	gtkwave wrapper.vcd wrapper.gtkw

formal:
	sby -f properties.sby

clean:
	rm -rf *vcd properties
