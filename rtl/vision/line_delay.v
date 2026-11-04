`timescale 1ns / 1ps

module line_delay #(
    parameter WIDTH = 1280,
    parameter      AW = 11,
    parameter      DW = 8
)(
    input  wire          I_clk,
    input  wire          I_we,
    input  wire [AW-1:0] I_addr,
    input  wire [DW-1:0] I_din,
    output reg  [DW-1:0] O_dout
);
    reg [DW-1:0] mem [0:WIDTH-1];

    always @(posedge I_clk) begin
        if (I_we)
            mem[I_addr] <= I_din;
        O_dout <= mem[I_addr];
    end
endmodule
