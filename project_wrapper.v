`default_nettype none
`define MPRJ_IO_PADS 38

module project_wrapper #(
    parameter ADDR_BASE = 32'h30000000,
    // configure OEB so that when project is active the pins that you want as outputs are set low
    parameter OEB       = `MPRJ_IO_PADS'h0 
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
    wire reset = wb_rst_i;

    wire [`MPRJ_IO_PADS-1:0] project_in, project_out;

    // if project is active, connect outputs
    reg active;

    // set all as input unless project is active
    assign io_oeb = active ? OEB : {`MPRJ_IO_PADS {1'b1}};

    // only connect outputs if this project is active
    assign io_out = active ? project_out : {`MPRJ_IO_PADS {1'b0}};
    // leave all inputs connected
    assign project_in = io_in;

    // instantiate your module here, use clk, reset, project_in & project_out.







    

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
        if(reset) begin
            active <= 0;
            wbs_data_out <= 0;
            wbs_ack <= 0;
        end else
        // writes
        if(wb_valid & (wb_wstrb > 0)) begin
            case(wbs_adr_i)
                ADDR_BASE: begin
                    if (wb_wstrb[0])
                        active <= wbs_dat_i[0];
                    wbs_ack <= 1;
                end
                // put any other write addresses here
            endcase

        end else
        // reads - allow to see which is currently selected
        if(wb_valid & wb_wstrb == 4'b0) begin
            case(wbs_adr_i)
                ADDR_BASE: begin
                    wbs_data_out[0] <= active;
                    wbs_ack <= 1;
                end
                // put any other read addresses here
            endcase

        end else begin
            wbs_ack <= 0;
            wbs_data_out <= 32'b0;
        end
    end
endmodule
`default_nettype wire
