module color_enhance #(
    parameter signed [10:0] SATURATION_Q8 = 11'sd486
) (
    input  wire        I_clk   ,
    input  wire        I_rst_n ,
    input  wire        I_tvalid,
    input  wire        I_tuser ,
    input  wire        I_tlast ,
    input  wire [95:0] I_tdata ,

    output reg         O_tvalid,
    output reg         O_tuser ,
    output reg         O_tlast ,
    output reg  [95:0] O_tdata
);

    wire [7:0] r_out [0:3];
    wire [7:0] g_out [0:3];
    wire [7:0] b_out [0:3];

    genvar k;
    generate
    for (k = 0; k < 4; k = k + 1) begin : px_gen

        wire [7:0] r_in = I_tdata[k*24 + 23 -: 8];
        wire [7:0] g_in = I_tdata[k*24 + 15 -: 8];
        wire [7:0] b_in = I_tdata[k*24 +  7 -: 8];

        wire [15:0] r16={8'd0,r_in}, g16={8'd0,g_in}, b16={8'd0,b_in};
        wire [15:0] ry=(r16<<6)+(r16<<3)+(r16<<2);
        wire [15:0] gy=(g16<<7)+(g16<<4)+(g16<<2)+(g16<<1);
        wire [15:0] by=(b16<<5)-(b16<<1);
        wire [15:0] y_sum=ry+gy+by;
        wire [7:0]  y     = y_sum[15:8];

        wire signed [8:0] dr = $signed({1'b0, r_in}) - $signed({1'b0, y});
        wire signed [8:0] dg = $signed({1'b0, g_in}) - $signed({1'b0, y});
        wire signed [8:0] db = $signed({1'b0, b_in}) - $signed({1'b0, y});

        if (SATURATION_Q8 == 11'sd320) begin : g_saturation_125

            wire signed [9:0] rn=$signed({2'b00,r_in})+($signed({dr[8],dr})>>>2);
            wire signed [9:0] gn=$signed({2'b00,g_in})+($signed({dg[8],dg})>>>2);
            wire signed [9:0] bn=$signed({2'b00,b_in})+($signed({db[8],db})>>>2);
            assign r_out[k]=rn[9] ? 8'd0 : (rn>10'sd255 ? 8'd255 : rn[7:0]);
            assign g_out[k]=gn[9] ? 8'd0 : (gn>10'sd255 ? 8'd255 : gn[7:0]);
            assign b_out[k]=bn[9] ? 8'd0 : (bn>10'sd255 ? 8'd255 : bn[7:0]);
        end else begin : g_general_saturation

        wire signed [19:0] dr_s = dr * SATURATION_Q8;
        wire signed [19:0] dg_s = dg * SATURATION_Q8;
        wire signed [19:0] db_s = db * SATURATION_Q8;

        wire signed [9:0] dr_enh = dr_s >>> 8;
        wire signed [9:0] dg_enh = dg_s >>> 8;
        wire signed [9:0] db_enh = db_s >>> 8;

        wire signed [10:0] r_new = $signed({3'b000, y}) + dr_enh;
        wire signed [10:0] g_new = $signed({3'b000, y}) + dg_enh;
        wire signed [10:0] b_new = $signed({3'b000, y}) + db_enh;

        assign r_out[k] = (r_new < 11'sd0) ? 8'd0 : ((r_new > 11'sd255) ? 8'd255 : r_new[7:0]);
        assign g_out[k] = (g_new < 11'sd0) ? 8'd0 : ((g_new > 11'sd255) ? 8'd255 : g_new[7:0]);
        assign b_out[k] = (b_new < 11'sd0) ? 8'd0 : ((b_new > 11'sd255) ? 8'd255 : b_new[7:0]);
        end
    end
    endgenerate

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tvalid <= 1'b0;
            O_tuser  <= 1'b0;
            O_tlast  <= 1'b0;
            O_tdata  <= 96'd0;
        end else begin
            O_tvalid <= I_tvalid;
            O_tuser  <= I_tuser ;
            O_tlast  <= I_tlast ;
            O_tdata  <= I_tvalid ? {
                            r_out[3], g_out[3], b_out[3],
                            r_out[2], g_out[2], b_out[2],
                            r_out[1], g_out[1], b_out[1],
                            r_out[0], g_out[0], b_out[0]
                        } : 96'd0;
        end
    end

endmodule
