`timescale 1ns / 1ps

module sobel_edge (
    input  wire              I_clk,
    input  wire              I_de,

    input  wire [7:0]        P00, P01, P02,
    input  wire [7:0]        P10, P11, P12,
    input  wire [7:0]        P20, P21, P22,

    output reg               O_de,
    output reg  [11:0]       O_mag,
    output reg  signed [11:0] O_gx,
    output reg  signed [11:0] O_gy
);
    wire [9:0] gx_pos = P02 + {P12, 1'b0} + P22;
    wire [9:0] gx_neg = P00 + {P10, 1'b0} + P20;
    wire [9:0] gy_pos = P20 + {P21, 1'b0} + P22;
    wire [9:0] gy_neg = P00 + {P01, 1'b0} + P02;

    wire signed [11:0] gx = $signed({2'b00, gx_pos}) - $signed({2'b00, gx_neg});
    wire signed [11:0] gy = $signed({2'b00, gy_pos}) - $signed({2'b00, gy_neg});

    wire [11:0] ax = gx[11] ? (~gx + 12'd1) : gx;
    wire [11:0] ay = gy[11] ? (~gy + 12'd1) : gy;
    wire [11:0] mag = ax + ay;

    always @(posedge I_clk) begin
        O_mag <= mag;
        O_gx  <= gx;
        O_gy  <= gy;
        O_de  <= I_de;
    end
endmodule
