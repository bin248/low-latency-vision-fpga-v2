`timescale 1ns / 1ps

module delay_line #(
    parameter W  = 2,
    parameter N  = 4966,
    parameter AW = 13
)(
    input  wire         I_clk,
    input  wire [W-1:0] I_din,
    output reg  [W-1:0] O_dout
);
    reg [W-1:0]  mem [0:N-1];
    reg [AW-1:0] wr;
    wire [AW-1:0] last = N - 1;

    always @(posedge I_clk) begin
        mem[wr] <= I_din;
        wr      <= (wr == last) ? {AW{1'b0}} : wr + 1'b1;
        O_dout  <= mem[wr];
    end
endmodule
