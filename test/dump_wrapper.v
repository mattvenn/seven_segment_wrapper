`timescale 1ns/1ns
module dump();
    initial begin
        $dumpfile ("wrapper.vcd");
        $dumpvars (0, wrapped_seven_segment);
        #1;
    end
endmodule
