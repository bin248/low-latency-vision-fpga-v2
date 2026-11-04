`timescale 1ns / 1ps

module gauss3x3 (
    input  wire       I_clk,
    input  wire       I_de,

    input  wire [7:0] P00, P01, P02,
    input  wire [7:0] P10, P11, P12,
    input  wire [7:0] P20, P21, P22,

    output reg        O_de,
    output reg  [7:0] O_y
);

    wire [11:0] sum = P00 + {P01, 1'b0} + P02
                    + {P10, 1'b0} + {P11, 2'b0} + {P12, 1'b0}
                    + P20 + {P21, 1'b0} + P22;

    always @(posedge I_clk) begin
        O_y  <= sum[11:4];
        O_de <= I_de;
    end
endmodule
