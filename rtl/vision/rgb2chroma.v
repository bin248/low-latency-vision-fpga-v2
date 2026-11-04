`timescale 1ns / 1ps

module rgb2chroma (
    input  wire        I_clk,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output reg  [7:0]  O_c,
    output reg         O_de
);
    wire [8:0] d = {1'b0, I_rgb[23:16]} - {1'b0, I_rgb[7:0]} + 9'd256;

    always @(posedge I_clk) begin
        O_c  <= d[8:1];
        O_de <= I_de;
    end
endmodule
