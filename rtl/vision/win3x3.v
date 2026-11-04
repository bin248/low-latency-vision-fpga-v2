`timescale 1ns / 1ps

module win3x3 #(
    parameter WIDTH = 1280,
    parameter      AW = 11,
    parameter      DW = 8
)(
    input  wire          I_clk,
    input  wire          I_rst_n,
    input  wire          I_de,
    input  wire [DW-1:0] I_data,

    output reg           O_de,
    output reg  [DW-1:0] W00, W01, W02,
    output reg  [DW-1:0] W10, W11, W12,
    output reg  [DW-1:0] W20, W21, W22
);

    reg [AW-1:0] col;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            col <= {AW{1'b0}};
        else if (!I_de)
            col <= {AW{1'b0}};
        else
            col <= (col == WIDTH-1) ? {AW{1'b0}} : col + 1'b1;
    end

    reg          de_d1, de_d2, de_d3;
    reg [AW-1:0] col_d1, col_d2;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            de_d1 <= 1'b0; de_d2 <= 1'b0; de_d3 <= 1'b0;
            col_d1 <= {AW{1'b0}}; col_d2 <= {AW{1'b0}};
        end else begin
            de_d1  <= I_de;
            de_d2  <= de_d1;
            de_d3  <= de_d2;
            col_d1 <= col;
            col_d2 <= col_d1;
        end
    end

    wire [DW-1:0] d1, d2;
    line_delay #(.WIDTH(WIDTH), .AW(AW), .DW(DW)) u_ld1 (
        .I_clk(I_clk), .I_we(I_de),  .I_addr(col),    .I_din(I_data), .O_dout(d1));
    line_delay #(.WIDTH(WIDTH), .AW(AW), .DW(DW)) u_ld2 (
        .I_clk(I_clk), .I_we(de_d1), .I_addr(col_d1), .I_din(d1),     .O_dout(d2));

    reg [DW-1:0] cur_d1, cur_d2, d1_d1;
    always @(posedge I_clk) begin
        cur_d1 <= I_data;
        cur_d2 <= cur_d1;
        d1_d1  <= d1;
    end
    wire [DW-1:0] cur = cur_d2;
    wire [DW-1:0] r1  = d1_d1;
    wire [DW-1:0] r2  = d2;

    reg [DW-1:0] sc0, sc1;
    reg [DW-1:0] s10, s11;
    reg [DW-1:0] s20, s21;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            sc0 <= {DW{1'b0}}; sc1 <= {DW{1'b0}};
            s10 <= {DW{1'b0}}; s11 <= {DW{1'b0}};
            s20 <= {DW{1'b0}}; s21 <= {DW{1'b0}};
        end else if (de_d2) begin
            sc0 <= cur;  sc1 <= sc0;
            s10 <= r1;   s11 <= s10;
            s20 <= r2;   s21 <= s20;
        end
    end

    wire at_col0 = (col_d2 == {AW{1'b0}});
    wire at_col1 = (col_d2 == {{(AW-1){1'b0}}, 1'b1});
    wire [DW-1:0] w00, w01, w02, w10, w11, w12, w20, w21, w22;

    assign w22 = cur;
    assign w21 = at_col0 ? cur : sc0;
    assign w20 = at_col0 ? cur : (at_col1 ? sc0 : sc1);

    assign w12 = r1;
    assign w11 = at_col0 ? r1 : s10;
    assign w10 = at_col0 ? r1 : (at_col1 ? s10 : s11);

    assign w02 = r2;
    assign w01 = at_col0 ? r2 : s20;
    assign w00 = at_col0 ? r2 : (at_col1 ? s20 : s21);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_de <= 1'b0;
            W00 <= {DW{1'b0}}; W01 <= {DW{1'b0}}; W02 <= {DW{1'b0}};
            W10 <= {DW{1'b0}}; W11 <= {DW{1'b0}}; W12 <= {DW{1'b0}};
            W20 <= {DW{1'b0}}; W21 <= {DW{1'b0}}; W22 <= {DW{1'b0}};
        end else begin
            O_de <= de_d3;
            W00 <= w00; W01 <= w01; W02 <= w02;
            W10 <= w10; W11 <= w11; W12 <= w12;
            W20 <= w20; W21 <= w21; W22 <= w22;
        end
    end

endmodule
