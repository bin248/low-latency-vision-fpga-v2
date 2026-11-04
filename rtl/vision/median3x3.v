`timescale 1ns / 1ps

module median3x3 (
    input  wire       I_clk,
    input  wire       I_de,
    input  wire [7:0] P00, P01, P02,
    input  wire [7:0] P10, P11, P12,
    input  wire [7:0] P20, P21, P22,
    output reg        O_de,
    output reg  [7:0] O_med
);
    function [7:0] fmin(input [7:0] a, input [7:0] b);
        begin fmin = (a < b) ? a : b; end
    endfunction

    function [7:0] fmax(input [7:0] a, input [7:0] b);
        begin fmax = (a > b) ? a : b; end
    endfunction

    function [7:0] fmed3(input [7:0] a, input [7:0] b, input [7:0] c);
        reg [7:0] lo, hi;
        begin
            lo = fmin(a, b);
            hi = fmax(a, b);
            fmed3 = (c < lo) ? lo : ((c > hi) ? hi : c);
        end
    endfunction

    reg [7:0] c0mn, c0mx, c0md;
    reg [7:0] c1mn, c1mx, c1md;
    reg [7:0] c2mn, c2mx, c2md;
    reg de_col, de_merge;
    reg [7:0] min_of_min, max_of_max, med_of_med;
    wire [7:0] med9       = fmed3(min_of_min, med_of_med, max_of_max);

    always @(posedge I_clk) begin
        c0mn <= fmin(fmin(P00, P10), P20);
        c0mx <= fmax(fmax(P00, P10), P20);
        c0md <= fmed3(P00, P10, P20);
        c1mn <= fmin(fmin(P01, P11), P21);
        c1mx <= fmax(fmax(P01, P11), P21);
        c1md <= fmed3(P01, P11, P21);
        c2mn <= fmin(fmin(P02, P12), P22);
        c2mx <= fmax(fmax(P02, P12), P22);
        c2md <= fmed3(P02, P12, P22);
        de_col <= I_de;

        min_of_min <= fmax(fmax(c0mn, c1mn), c2mn);
        max_of_max <= fmin(fmin(c0mx, c1mx), c2mx);
        med_of_med <= fmed3(c0md, c1md, c2md);
        de_merge <= de_col;

        O_med <= med9;
        O_de  <= de_merge;
    end
endmodule
