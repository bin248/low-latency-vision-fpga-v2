`timescale 1ns / 1ps

module rgb2gray (
    input  wire        I_clk,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output reg  [7:0]  O_y,
    output reg         O_de
);
    wire [7:0] r = I_rgb[23:16];
    wire [7:0] g = I_rgb[15:8];
    wire [7:0] b = I_rgb[7:0];

    wire [15:0] r77  = (r<<6) + (r<<3) + (r<<2) + r;
    wire [15:0] g150 = (g<<7) + (g<<4) + (g<<2) + (g<<1);
    wire [15:0] b29  = (b<<4) + (b<<3) + (b<<2) + b;
    wire [15:0] ysum = r77 + g150 + b29;

    always @(posedge I_clk) begin
        O_y  <= ysum[15:8];
        O_de <= I_de;
    end
endmodule
