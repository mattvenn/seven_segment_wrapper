`default_nettype none
`define MPRJ_IO_PADS 38

module seven_seg_wrapper #(
    parameter ADDR_BASE         = 32'h30000000,
    parameter ADDR_COMPARE      = 32'h30000004,
    // configure OEB so that when project is active the pins that you want as outputs are set low
    parameter OEB               = `MPRJ_IO_PADS'b11111111111111111111111000000011111111
)(
    // Wishbone Slave ports (WB MI A)
    input wire wb_clk_i,             // clock
    input wire wb_rst_i,             // reset
    input wire wbs_stb_i,            // strobe - wb_valid data
    input wire wbs_cyc_i,            // cycle - high when during a request
    input wire wbs_we_i,             // write enable
    input wire [3:0] wbs_sel_i,      // which byte to read/write
    input wire [31:0] wbs_dat_i,     // data in
    input wire [31:0] wbs_adr_i,     // address
    output wire wbs_ack_o,           // ack
    output wire [31:0] wbs_dat_o,    // data out

    // Logic Analyzer Signals - keep?
    /*
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oen,
    */

    // IOs - avoid using 0-7 as they are dual purpose and maybe connected to other things
    input  wire [`MPRJ_IO_PADS-1:0] io_in,
    output wire [`MPRJ_IO_PADS-1:0] io_out,
    output wire [`MPRJ_IO_PADS-1:0] io_oeb // active low!

);
    // friendly signal names
    wire clk = wb_clk_i;
    wire reset = wb_rst_i | wb_reset;

    wire [`MPRJ_IO_PADS-1:0] project_in, project_out;

    // if project is active, connect outputs
    reg active;

    // have a way of resetting project via wishbone
    reg wb_reset;

    // set all as output unless project is active
    assign io_oeb = active ? OEB : {`MPRJ_IO_PADS {1'b0}};

    // only connect outputs if this project is active
    assign io_out = active ? project_out : {`MPRJ_IO_PADS {1'b0}};
    // leave all inputs connected
    assign project_in = io_in;

    wire seven_seg_update = wb_valid & wb_wstrb & (wbs_adr_i == ADDR_COMPARE);
    `ifndef FORMAL
    // instantiate your module here, use clk, reset, project_in & project_out.
    seven_segment_seconds project (.clk(clk), .reset(reset), .led_out(project_out[14:8]), .compare_in(wbs_dat_i[23:0]), .update_compare(seven_seg_update));
    `endif
    

    // wishbone
    wire wb_valid;
    wire [3:0] wb_wstrb;
    reg [31:0] wbs_data_out;
    reg wbs_ack;
    assign wbs_ack_o = wbs_ack;
    assign wbs_dat_o = wbs_data_out;
    assign wb_valid = wbs_cyc_i && wbs_stb_i;
    assign wb_wstrb = wbs_sel_i & {4{wbs_we_i}};
    always @(posedge clk) begin
        // reset
        if(wb_rst_i) begin
            active <= 0;
            wbs_data_out <= 0;
            wbs_ack <= 0;
            wb_reset <= 1; // start in reset
        end else
        // writes
        if(wb_valid & (wb_wstrb > 0)) begin
            case(wbs_adr_i)
                ADDR_BASE: begin
                    if (wb_wstrb[0])
                        {wb_reset, active} <= wbs_dat_i[1:0];
                    wbs_ack <= 1;
                end
                ADDR_COMPARE: begin
                    wbs_ack <= 1;
                end
                // put any other write addresses here
            endcase

        end else
        // reads - allow to see which is currently selected
        if(wb_valid & wb_wstrb == 4'b0) begin
            case(wbs_adr_i)
                ADDR_BASE: begin
                    wbs_data_out[1:0] <= {wb_reset, active};
                    wbs_ack <= 1;
                end
                ADDR_COMPARE: begin
                    wbs_ack <= 1;
                end
                // put any other read addresses here
            endcase

        end else begin
            wbs_ack <= 0;
            wbs_data_out <= 32'b0;
        end
    end

    // simulation setup
    `ifdef COCOTB_SIM
        initial begin
            $dumpfile ("harness.vcd");
            $dumpvars (0, seven_seg_wrapper);
            #1;
        end
    `endif

    `ifdef FORMAL
        // mux works
        always @(posedge clk) begin
            if(active) begin
                // outs are connected
                assert(io_out == project_out);
                assert(io_oeb == OEB);
            end else begin
                assert(io_out == {`MPRJ_IO_PADS {1'b0}});
                assert(io_oeb == {`MPRJ_IO_PADS {1'b0}});
            end
        end
        // basic wishbone compliance
        reg f_past_valid = 0;
        always @(posedge clk) begin
            f_past_valid <= 1;
            assume(wb_rst_i == !f_past_valid);

        end

        // assume controller keeps cyc & strobe high until ack, data, wstrb and data stay stable
        always @(posedge clk) begin
            if(wb_rst_i)
                assume(!wbs_cyc_i);
            if(f_past_valid && $past(wb_valid)) begin
                // keep address & data stable
                assume($stable(wb_wstrb));
                assume($stable(wbs_adr_i));
                assume($stable(wbs_dat_i));

                // wait for ack
                if(!wbs_ack)
                    assume(wb_valid);
            end
        end

        // assert ack happens when writing to a known address
        always @(posedge clk) begin
            if(f_past_valid && $past(wb_valid) && !$past(wb_rst_i)) begin
                // reads & writes to project select address
                if($past(wbs_adr_i == ADDR_BASE))
                    assert(wbs_ack);
                if($past(wbs_adr_i == ADDR_COMPARE))
                    assert(wbs_ack);
            end
        end
    `endif
endmodule
`default_nettype wire
