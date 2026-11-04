`timescale 1ns / 1ps

module edge_detect #(
    parameter IMG_WIDTH   = 1280,
    parameter IMG_HEIGHT  = 720,
    parameter AW          = 11,
    parameter LINE_CYCLE  = 1650,
    parameter HYST_STAGES = 3,

    parameter AUTO_THRESH     = 1'b1,
    parameter [7:0] BIN_BIAS = 8'd80,
    parameter BIN_DIAG_EN = 1'b1,
    parameter NR_BUILD = 0,
    parameter EDGE_SHAPE_FIX = 1'b1,
    parameter BIN_REFINE_EN = 1'b1,
    parameter [7:0] BIN_REFINE_CMIN = 8'd8,
    parameter BIN_BORDER_RAW  = 1'b0,
    parameter BIN_MAJORITY_EN = 1'b0,

    parameter NBR_FILTER_EN   = 1'b1,
    parameter [3:0] NBR_MIN   = 4'd1,

    parameter [3:0] NBR4_MIN  = 4'd1,
    parameter [3:0] POST_KEEP = 4'd3,
    parameter BRIDGE_EN       = 1'b1,
    parameter BIN_LOCAL_EN    = 1'b0,

    parameter [3:0] BIN_C_SHIFT  = 4'd4,

    parameter       BIN_C_REL_EN = 1'b1,
    parameter [7:0] LOC_SHIFT = 8'd6,
    parameter [7:0] LOC_ADD   = 8'd16,
    parameter [3:0] LOC_SCALE = 4'd3,

    parameter [3:0] LOC_FLOOR_SHIFT = 4'd1,

    parameter [3:0] CHROMA_SEL_SHIFT    = 4'd1,

    parameter [3:0] CHROMA_MARGIN_SHIFT = 4'd2,

    parameter       DIR_CONSIST_EN      = 1'b1

)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [23:0] I_rgb,
    input wire [1:0] I_blue_mask,
    input  wire        I_de,
    input  wire        I_vsync,
    input  wire [1:0]  I_mode,
    input  wire [1:0]  I_style,
    input  wire [11:0] I_thresh,
    input  wire [11:0] I_bin_thresh,
    input  wire [15:0] I_dbg_exp,
    input  wire [7:0]  I_dbg_gain, I_dbg_luma, I_dbg_target,
    input  wire [19:0] I_dbg_pixels,
    input  wire        I_dbg_valid, I_dbg_cfg, I_dbg_busy,
    input  wire [15:0] I_dbg_writes,
    input  wire [15:0] I_dbg_read_exp, I_dbg_read_gain, I_dbg_expected_gain,
    input  wire I_dbg_read_valid, I_dbg_write_ack, I_dbg_comm_error, I_dbg_read_match,
    input  wire [15:0] I_dbg_read_count,
    input  wire [8:0] I_dbg_nr_diag,
    output wire [2:0]  O_color_led,
    output wire [23:0] O_rgb,
    output wire        O_de,
    output wire        O_vsync
);
    localparam FIXED_ROWS = 7;

    localparam WIN_ROWS   = FIXED_ROWS + HYST_STAGES;
    localparam MEDIAN_EXTRA = 4;

    localparam PIPE_EXTRA = WIN_ROWS*2 + 5 + MEDIAN_EXTRA;
    localparam DELAY_CYC  = WIN_ROWS*LINE_CYCLE + WIN_ROWS*3 + 5 + MEDIAN_EXTRA;
    localparam [11:0] BLANK_ROWS = WIN_ROWS;

    localparam [11:0] BORDER     = BLANK_ROWS + HYST_STAGES;
    localparam        HLAST      = HYST_STAGES - 1;

    wire [7:0] y;  wire y_de;
    rgb2gray u_rgb2gray (
        .I_clk(I_clk), .I_de(I_de), .I_rgb(I_rgb), .O_y(y), .O_de(y_de));

    wire [7:0] c;  wire c_de;
    rgb2chroma u_rgb2chroma (
        .I_clk(I_clk), .I_de(I_de), .I_rgb(I_rgb), .O_c(c), .O_de(c_de));

    wire [15:0] yc = {c, y};
    wire        yc_de = y_de;

    wire w1_de;
    wire [15:0] w1_00,w1_01,w1_02,w1_10,w1_11,w1_12,w1_20,w1_21,w1_22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(16)) u_win1 (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(yc_de), .I_data(yc), .O_de(w1_de),
        .W00(w1_00), .W01(w1_01), .W02(w1_02),
        .W10(w1_10), .W11(w1_11), .W12(w1_12),
        .W20(w1_20), .W21(w1_21), .W22(w1_22));

    wire [7:0] y1, c1;  wire m1_de;
    median3x3 u_medianY (
        .I_clk(I_clk), .I_de(w1_de),
        .P00(w1_00[7:0]),  .P01(w1_01[7:0]),  .P02(w1_02[7:0]),
        .P10(w1_10[7:0]),  .P11(w1_11[7:0]),  .P12(w1_12[7:0]),
        .P20(w1_20[7:0]),  .P21(w1_21[7:0]),  .P22(w1_22[7:0]),
        .O_de(m1_de), .O_med(y1));
    median3x3 u_medianC (
        .I_clk(I_clk), .I_de(w1_de),
        .P00(w1_00[15:8]), .P01(w1_01[15:8]), .P02(w1_02[15:8]),
        .P10(w1_10[15:8]), .P11(w1_11[15:8]), .P12(w1_12[15:8]),
        .P20(w1_20[15:8]), .P21(w1_21[15:8]), .P22(w1_22[15:8]),
        .O_de(         ), .O_med(c1));

    wire [15:0] yc1 = {c1, y1};

    wire w2_de;
    wire [15:0] w2_00,w2_01,w2_02,w2_10,w2_11,w2_12,w2_20,w2_21,w2_22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(16)) u_win2 (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(m1_de), .I_data(yc1), .O_de(w2_de),
        .W00(w2_00), .W01(w2_01), .W02(w2_02),
        .W10(w2_10), .W11(w2_11), .W12(w2_12),
        .W20(w2_20), .W21(w2_21), .W22(w2_22));

    wire [7:0] y2, c2;  wire y2_de;
    median3x3 u_medianY2 (
        .I_clk(I_clk), .I_de(w2_de),
        .P00(w2_00[7:0]),  .P01(w2_01[7:0]),  .P02(w2_02[7:0]),
        .P10(w2_10[7:0]),  .P11(w2_11[7:0]),  .P12(w2_12[7:0]),
        .P20(w2_20[7:0]),  .P21(w2_21[7:0]),  .P22(w2_22[7:0]),
        .O_de(y2_de), .O_med(y2));
    median3x3 u_medianC2 (
        .I_clk(I_clk), .I_de(w2_de),
        .P00(w2_00[15:8]), .P01(w2_01[15:8]), .P02(w2_02[15:8]),
        .P10(w2_10[15:8]), .P11(w2_11[15:8]), .P12(w2_12[15:8]),
        .P20(w2_20[15:8]), .P21(w2_21[15:8]), .P22(w2_22[15:8]),
        .O_de(         ), .O_med(c2));

    wire [15:0] yc2 = {c2, y2};

    reg [7:0] bin_gray_pipe [0:2];
    reg [14:0] bin_vs_pipe;
    integer bgi;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            for (bgi=0;bgi<3;bgi=bgi+1) bin_gray_pipe[bgi]<=0;
            bin_vs_pipe<=0;
        end else begin
            bin_gray_pipe[0]<=w2_11[7:0];
            bin_gray_pipe[1]<=bin_gray_pipe[0];
            bin_gray_pipe[2]<=bin_gray_pipe[1];
            bin_vs_pipe<={bin_vs_pipe[13:0],I_vsync};
        end
    end
    wire [7:0] bin_gray=bin_gray_pipe[2];
    wire bin_gray_vs=bin_vs_pipe[14];

    localparam BIN_STAT_BORDER=4;
    reg [11:0] bin_stat_x,bin_stat_y;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin bin_stat_x<=0;bin_stat_y<=0;end
        else if(bin_gray_vs)begin bin_stat_x<=0;bin_stat_y<=0;end
        else if(y2_de)begin
            if(bin_stat_x==IMG_WIDTH-1)begin
                bin_stat_x<=0;bin_stat_y<=bin_stat_y+12'd1;
            end else bin_stat_x<=bin_stat_x+12'd1;
        end
    end
    wire bin_stat_de=y2_de && !bin_gray_vs &&
        (bin_stat_x>=BIN_STAT_BORDER) && (bin_stat_x<IMG_WIDTH-BIN_STAT_BORDER) &&
        (bin_stat_y>=BIN_STAT_BORDER) && (bin_stat_y<IMG_HEIGHT-BIN_STAT_BORDER);

    wire w3_de;
    wire [15:0] w3_00,w3_01,w3_02,w3_10,w3_11,w3_12,w3_20,w3_21,w3_22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(16)) u_win3 (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(y2_de), .I_data(yc2), .O_de(w3_de),
        .W00(w3_00), .W01(w3_01), .W02(w3_02),
        .W10(w3_10), .W11(w3_11), .W12(w3_12),
        .W20(w3_20), .W21(w3_21), .W22(w3_22));

    wire [11:0] magY, magC;  wire mag_de;
    wire signed [11:0] gxY, gyY;
    wire signed [11:0] gxC, gyC;
    sobel_edge u_sobelY (
        .I_clk(I_clk), .I_de(w3_de),
        .P00(w3_00[7:0]),  .P01(w3_01[7:0]),  .P02(w3_02[7:0]),
        .P10(w3_10[7:0]),  .P11(w3_11[7:0]),  .P12(w3_12[7:0]),
        .P20(w3_20[7:0]),  .P21(w3_21[7:0]),  .P22(w3_22[7:0]),
        .O_de(mag_de), .O_mag(magY), .O_gx(gxY), .O_gy(gyY));
    sobel_edge u_sobelC (
        .I_clk(I_clk), .I_de(w3_de),
        .P00(w3_00[15:8]), .P01(w3_01[15:8]), .P02(w3_02[15:8]),
        .P10(w3_10[15:8]), .P11(w3_11[15:8]), .P12(w3_12[15:8]),
        .P20(w3_20[15:8]), .P21(w3_21[15:8]), .P22(w3_22[15:8]),
        .O_de(         ), .O_mag(magC), .O_gx(gxC), .O_gy(gyC));

    wire [11:0] magC_s = magC - (magC >> CHROMA_SEL_SHIFT);

    wire [11:0] magY_m = magY + (magY >> CHROMA_MARGIN_SHIFT);
    wire use_chroma = (magC_s > magY_m);
    wire [11:0] mag = use_chroma ? magC_s : magY;

    wire signed [11:0] gx_sel = use_chroma ? gxC : gxY;
    wire signed [11:0] gy_sel = use_chroma ? gyC : gyY;

    wire [11:0] axY = gx_sel[11] ? (~gx_sel + 12'd1) : gx_sel;
    wire [11:0] ayY = gy_sel[11] ? (~gy_sel + 12'd1) : gy_sel;

    wire [13:0] ax2 = {axY, 1'b0};
    wire [13:0] ay2 = {ayY, 1'b0};
    wire [13:0] ax5 = {axY, 2'b00} + axY;
    wire [13:0] ay5 = {ayY, 2'b00} + ayY;
    wire        d_horiz  = (ay5 <= ax2);
    wire        d_vert   = (ax5 <= ay2);
    wire        same_sgn = (gx_sel[11] == gy_sel[11]);
    wire [1:0]  dirq = d_horiz ? 2'd0 : (d_vert ? 2'd2 : (same_sgn ? 2'd1 : 2'd3));

    wire w4n_de;
    wire [13:0] w4n_00,w4n_01,w4n_02,w4n_10,w4n_11,w4n_12,w4n_20,w4n_21,w4n_22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(14)) u_win_nms (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(mag_de), .I_data({dirq, mag}), .O_de(w4n_de),
        .W00(w4n_00), .W01(w4n_01), .W02(w4n_02),
        .W10(w4n_10), .W11(w4n_11), .W12(w4n_12),
        .W20(w4n_20), .W21(w4n_21), .W22(w4n_22));

    wire [11:0] nms_c  = w4n_11[11:0];
    wire [1:0]  nms_dc = w4n_11[13:12];

    wire keep_h  = (EDGE_SHAPE_FIX ? (nms_c > w4n_10[11:0]) : (nms_c >= w4n_10[11:0])) && (nms_c >= w4n_12[11:0]);
    wire keep_v  = (EDGE_SHAPE_FIX ? (nms_c > w4n_01[11:0]) : (nms_c >= w4n_01[11:0])) && (nms_c >= w4n_21[11:0]);
    wire keep_45 = (EDGE_SHAPE_FIX ? (nms_c > w4n_00[11:0]) : (nms_c >= w4n_00[11:0])) && (nms_c >= w4n_22[11:0]);
    wire keep_135= (EDGE_SHAPE_FIX ? (nms_c > w4n_02[11:0]) : (nms_c >= w4n_02[11:0])) && (nms_c >= w4n_20[11:0]);
    wire nms_keep = (nms_dc == 2'd0) ? keep_h  :
                    (nms_dc == 2'd2) ? keep_v  :
                    (nms_dc == 2'd1) ? keep_45 : keep_135;

    wire [1:0] dir_a = (nms_dc == 2'd0) ? w4n_10[13:12] :
                       (nms_dc == 2'd2) ? w4n_01[13:12] :
                       (nms_dc == 2'd1) ? w4n_00[13:12] :
                                          w4n_02[13:12];
    wire [1:0] dir_b = (nms_dc == 2'd0) ? w4n_12[13:12] :
                       (nms_dc == 2'd2) ? w4n_21[13:12] :
                       (nms_dc == 2'd1) ? w4n_22[13:12] :
                                          w4n_20[13:12];
    wire nms_dir_ok = (dir_a == nms_dc) | (dir_b == nms_dc);
    wire nms_keep_f = nms_keep & (DIR_CONSIST_EN ? nms_dir_ok : 1'b1);

    wire [11:0] mag_nms = nms_keep_f ? nms_c : 12'd0;
    wire        nms_de  = w4n_de;

    wire [11:0] auto_bin_thresh;
    wire [11:0] auto_edge_thresh;
    wire [11:0] auto_edge_thresh_lo;
    wire [7:0] bin_dbg_target, bin_dbg_low, bin_dbg_high;
    wire bin_dbg_valid,bin_dbg_seed;
    wire [15:0] bin_dbg_updates;
    wire [19:0] bin_dbg_pixels, bin_dbg_white;
    auto_thresh #(.BIN_BIAS(BIN_BIAS)) u_auto_thresh (
        .I_clk            ( I_clk               ),
        .I_rst_n          ( I_rst_n             ),
        .I_gray_de        ( bin_stat_de         ),
        .I_gray           ( bin_gray            ),
        .I_mag_de         ( nms_de              ),
        .I_mag            ( mag_nms             ),
        .I_vsync          ( I_vsync             ),
        .I_gray_vsync     ( bin_gray_vs         ),
        .O_bin_thresh     ( auto_bin_thresh     ),
        .O_edge_thresh    ( auto_edge_thresh    ),
        .O_edge_thresh_lo ( auto_edge_thresh_lo ),
        .O_bin_target(bin_dbg_target), .O_bin_low(bin_dbg_low), .O_bin_high(bin_dbg_high),
        .O_bin_valid(bin_dbg_valid), .O_bin_seed(bin_dbg_seed), .O_bin_updates(bin_dbg_updates),
        .O_bin_pixels(bin_dbg_pixels), .O_bin_white(bin_dbg_white)
    );

    wire [11:0] bin_lthr;
    wire [11:0] bin_lthr_hi;

    wire [4:0]  bin_c_min = 5'd0;
    local_bin #(
        .IMG_WIDTH ( IMG_WIDTH ),
        .AW        ( AW         ),
        .WIN_SHIFT ( 8'd8       ),
        .T_SHIFT   ( 4'd3       ),
        .C_SHIFT   ( BIN_C_SHIFT ),
        .C_REL_EN  ( BIN_C_REL_EN )
    ) u_local_bin (
        .I_clk        ( I_clk        ),
        .I_rst_n      ( I_rst_n      ),
        .I_de         ( y2_de        ),
        .I_vsync      ( I_vsync      ),
        .I_gray       ( bin_gray     ),
        .I_c_min      ( bin_c_min    ),
        .O_thresh     ( bin_lthr     ),
        .O_thresh_hi  ( bin_lthr_hi  )
    );

    wire [11:0] hi_thresh  = AUTO_THRESH ? auto_edge_thresh : I_thresh;
    wire [11:0] lo_thresh  = AUTO_THRESH ? ((auto_edge_thresh_lo > auto_edge_thresh)
                                            ? auto_edge_thresh : auto_edge_thresh_lo)
                                         : {1'b0, I_thresh[11:1]};
    wire [11:0] bin_thresh = AUTO_THRESH ? auto_bin_thresh  : I_bin_thresh;

    localparam integer LOC_WIN = 1 << LOC_SHIFT;
    (* dsp_style = "no" *) reg [LOC_WIN*12-1:0] mag_dl;
    always @(posedge I_clk) begin
        if (nms_de) mag_dl <= {mag_dl[LOC_WIN*12-13:0], mag_nms};
    end
    wire [11:0] mag_old = mag_dl[LOC_WIN*12-1 -: 12];

    reg  [17:0] mag_sum;
    (* dsp_style = "no" *)
    wire [17:0] mag_sum_nxt = mag_sum + {6'd0, mag_nms} - {6'd0, mag_old};

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)    mag_sum <= 18'd0;
        else if (nms_de) mag_sum <= mag_sum_nxt;
    end
    wire [11:0] mag_lmean = mag_sum_nxt >> LOC_SHIFT;

    wire [14:0] loc_est   = {3'd0, mag_lmean} << LOC_SCALE;
    wire [14:0] loc_raw   = loc_est + {7'd0, LOC_ADD};
    wire [14:0] loc_floor = {3'd0, hi_thresh} >> LOC_FLOOR_SHIFT;
    wire [14:0] loc_thr   = (loc_raw < loc_floor) ? loc_floor : loc_raw;
    wire [11:0] thr_used  = (loc_thr < {3'd0, hi_thresh}) ? loc_thr[11:0] : hi_thresh;

    reg [11:0] thr_used_r;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) thr_used_r <= 12'd0;
        else          thr_used_r <= thr_used;
    end

    wire strong = (mag_nms >= thr_used_r);
    wire weak   = (mag_nms >= lo_thresh);

    wire [HYST_STAGES:0] hyst_de;
    wire [27*HYST_STAGES-1:0] hyst_win;
    wire [HYST_STAGES:0] hyst_sd;

    assign hyst_de[0] = nms_de;
    assign hyst_sd[0] = 1'b0;

    wire [3*HYST_STAGES-1:0] hyst_din;
    assign hyst_din[2:0] = {strong, strong, weak};
    genvar gi1, gi2, ci;
    generate
        for (gi1 = 1; gi1 < HYST_STAGES; gi1 = gi1 + 1) begin : g_hyst_din
            assign hyst_din[3*gi1 +: 3] = { hyst_sd[gi1],
                                            hyst_win[27*(gi1-1) + 13],
                                            hyst_win[27*(gi1-1) + 12] };
        end
    endgenerate

    generate
        for (gi2 = 0; gi2 < HYST_STAGES; gi2 = gi2 + 1) begin : g_hyst
            wire [2:0] h00,h01,h02,h10,h11,h12,h20,h21,h22;
            win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(3)) u_hyst (
                .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(hyst_de[gi2]),
                .I_data(hyst_din[3*gi2 +: 3]), .O_de(hyst_de[gi2+1]),
                .W00(h00), .W01(h01), .W02(h02),
                .W10(h10), .W11(h11), .W12(h12),
                .W20(h20), .W21(h21), .W22(h22));
            assign hyst_win[27*gi2 +: 27] = {h00,h01,h02,h10,h11,h12,h20,h21,h22};
            assign hyst_sd[gi2+1] = |{h00[2], h01[2], h02[2], h10[2], h11[2],
                                      h12[2], h20[2], h21[2], h22[2]};
        end
    endgenerate

    wire conn_raw = hyst_win[27*HLAST + 13] |
                    (hyst_win[27*HLAST + 12] & hyst_sd[HYST_STAGES]);

    wire [8:0] hlast_edge;
    genvar gi3;
    generate
        for (gi3 = 0; gi3 < 9; gi3 = gi3 + 1) begin : g_nbr
            assign hlast_edge[gi3] = hyst_win[27*HLAST + 3*gi3 + 1] |
                                     hyst_win[27*HLAST + 3*gi3 + 0];
        end
    endgenerate

    wire [3:0] nbr_cnt = {3'd0, hlast_edge[0]} + {3'd0, hlast_edge[1]} + {3'd0, hlast_edge[2]}
                       + {3'd0, hlast_edge[3]} + {3'd0, hlast_edge[4]} + {3'd0, hlast_edge[5]}
                       + {3'd0, hlast_edge[6]} + {3'd0, hlast_edge[7]} + {3'd0, hlast_edge[8]};

    wire [3:0] nbr_other = nbr_cnt - {3'd0, hlast_edge[4]};

    wire [3:0] nbr4_cnt = {3'd0, hlast_edge[1]} + {3'd0, hlast_edge[3]}
                        + {3'd0, hlast_edge[5]} + {3'd0, hlast_edge[7]};
    wire       nbr_ok    = (nbr_other >= NBR_MIN) && (nbr4_cnt >= NBR4_MIN);

    wire ln_h  = hlast_edge[3] & hlast_edge[5];
    wire ln_v  = hlast_edge[1] & hlast_edge[7];
    wire ln_d1 = hlast_edge[0] & hlast_edge[8];
    wire ln_d2 = hlast_edge[2] & hlast_edge[6];
    wire is_line = ln_h | ln_v | ln_d1 | ln_d2;

    wire br_h  = hlast_edge[3] & hlast_edge[5];
    wire br_v  = hlast_edge[1] & hlast_edge[7];
    wire br_d1 = hlast_edge[0] & hlast_edge[8];
    wire br_d2 = hlast_edge[2] & hlast_edge[6];
    wire bridge = ~hlast_edge[4] & (br_h | br_v | br_d1 | br_d2);

    wire conn = (NBR_FILTER_EN ? (conn_raw & (nbr_ok | is_line)) : conn_raw)
                | (!EDGE_SHAPE_FIX & BRIDGE_EN & bridge);

    wire dil_de, ero_de;
    wire d00,d01,d02,d10,d11,d12,d20,d21,d22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(1)) u_morph_dil (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(hyst_de[HYST_STAGES]),
        .I_data(conn), .O_de(dil_de),
        .W00(d00), .W01(d01), .W02(d02),
        .W10(d10), .W11(d11), .W12(d12),
        .W20(d20), .W21(d21), .W22(d22));

    wire [3:0] gap_neighbors={3'd0,d00}+{3'd0,d01}+{3'd0,d02}+{3'd0,d10}+
        {3'd0,d12}+{3'd0,d20}+{3'd0,d21}+{3'd0,d22};
    wire gap_pair=(d10&&d12)||(d01&&d21)||(d00&&d22)||(d02&&d20);
    wire gap_only=(gap_neighbors==2) && gap_pair;
    wire dil = EDGE_SHAPE_FIX ? (d11 | (BRIDGE_EN && gap_only)) :
        (d11 | d00 | d01 | d02 | d10 | d12 | d20 | d21 | d22);

    wire e00,e01,e02,e10,e11,e12,e20,e21,e22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(1)) u_morph_ero (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(dil_de),
        .I_data(dil), .O_de(ero_de),
        .W00(e00), .W01(e01), .W02(e02),
        .W10(e10), .W11(e11), .W12(e12),
        .W20(e20), .W21(e21), .W22(e22));

    wire ero = EDGE_SHAPE_FIX ? e11 :
        (e11 & e00 & e01 & e02 & e10 & e12 & e20 & e21 & e22);

    wire f_de;
    wire f00,f01,f02,f10,f11,f12,f20,f21,f22;
    win3x3 #(.WIDTH(IMG_WIDTH), .AW(AW), .DW(1)) u_morph_post (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_de(ero_de), .I_data(ero), .O_de(f_de),
        .W00(f00), .W01(f01), .W02(f02),
        .W10(f10), .W11(f11), .W12(f12),
        .W20(f20), .W21(f21), .W22(f22));
    wire [3:0] fcnt = {3'd0,f00} + {3'd0,f01} + {3'd0,f02}
                    + {3'd0,f10} + {3'd0,f11} + {3'd0,f12}
                    + {3'd0,f20} + {3'd0,f21} + {3'd0,f22};

    wire edge_conn = f11 & (fcnt >= POST_KEEP);

    reg edge_r;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) edge_r <= 1'b0;
        else          edge_r <= edge_conn;
    end

    reg [AW-1:0] ccol;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)     ccol <= {AW{1'b0}};
        else if (!I_de)   ccol <= {AW{1'b0}};
        else              ccol <= (ccol == IMG_WIDTH-1) ? {AW{1'b0}} : ccol + 1'b1;
    end

    wire [26*(WIN_ROWS+1)-1:0] cline;
    assign cline[25:0]={I_blue_mask,I_rgb};
    generate
        for(ci=0;ci<WIN_ROWS;ci=ci+1)begin:g_cdelay
            line_delay #(.WIDTH(IMG_WIDTH),.AW(AW),.DW(26)) u_cd(
                .I_clk(I_clk),.I_we(I_de),.I_addr(ccol),
                .I_din(cline[26*ci+:26]),.O_dout(cline[26*(ci+1)+:26]));
        end
    endgenerate
    reg [25:0] cpipe[0:PIPE_EXTRA-1];
    integer pi;
    always @(posedge I_clk)begin
        cpipe[0]<=cline[26*WIN_ROWS+:26];
        for(pi=1;pi<PIPE_EXTRA;pi=pi+1)cpipe[pi]<=cpipe[pi-1];
    end
    wire [23:0] color_out=cpipe[PIPE_EXTRA-1][23:0];
    wire [1:0] blue_masks=cpipe[PIPE_EXTRA-1][25:24];

    wire [1:0] tmg_dly;
    delay_line #(.W(2), .N(DELAY_CYC), .AW(15)) u_tmg_dly (
        .I_clk(I_clk), .I_din({I_vsync, I_de}), .O_dout(tmg_dly));
    wire o_vsync_dly = tmg_dly[1];
    wire o_de_dly    = tmg_dly[0];

    reg [11:0] row_cnt;
    reg        ode_1d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            row_cnt <= 12'd0;
            ode_1d  <= 1'b0;
        end else begin
            ode_1d <= o_de_dly;
            if (o_vsync_dly)
                row_cnt <= 12'd0;
            else if (!o_de_dly & ode_1d)
                row_cnt <= row_cnt + 12'd1;
        end
    end

    reg [11:0] col_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)      col_cnt <= 12'd0;
        else if (o_de_dly) col_cnt <= col_cnt + 12'd1;
        else               col_cnt <= 12'd0;
    end

    wire edge_blank = (row_cnt < BORDER) ||
                      (row_cnt >= (IMG_HEIGHT - BORDER)) ||
                      (col_cnt < BORDER);

    wire [23:0] edge_rgb = (edge_r && !edge_blank) ? 24'hFFFFFF : 24'h000000;

    localparam BIN_REFINE_CYC = BIN_REFINE_EN ? (4*LINE_CYCLE+8+4) : 0;
    localparam BIN_FILTER_CYC = 2*LINE_CYCLE + 12 + MEDIAN_EXTRA + BIN_REFINE_CYC;
    localparam BIN_ALIGN_CYC  = DELAY_CYC - BIN_FILTER_CYC;
    localparam [14:0] BIN_ALIGN_LAST = BIN_ALIGN_CYC - 1;

    wire [3:0] bin_cnt =
          {3'd0, (w2_00[7:0] >= bin_thresh[7:0])} + {3'd0, (w2_01[7:0] >= bin_thresh[7:0])} +
          {3'd0, (w2_02[7:0] >= bin_thresh[7:0])} + {3'd0, (w2_10[7:0] >= bin_thresh[7:0])} +
          {3'd0, (w2_11[7:0] >= bin_thresh[7:0])} + {3'd0, (w2_12[7:0] >= bin_thresh[7:0])} +
          {3'd0, (w2_20[7:0] >= bin_thresh[7:0])} + {3'd0, (w2_21[7:0] >= bin_thresh[7:0])} +
          {3'd0, (w2_22[7:0] >= bin_thresh[7:0])};
    reg [2:0] bin_major_pipe;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) bin_major_pipe<=0;
        else bin_major_pipe<={bin_major_pipe[1:0],(bin_cnt>=4'd5)};
    end
    wire bin_major = BIN_MAJORITY_EN ? bin_major_pipe[2]
                                     : (bin_gray >= bin_thresh[7:0]);

    wire bin_local = ({4'd0, bin_gray} < bin_lthr) || ({4'd0, bin_gray} > bin_lthr_hi);
    wire bin_base = BIN_LOCAL_EN ? bin_local : bin_major;
    wire bin_pix,bin_pixel_warm;
    generate if(BIN_REFINE_EN)begin:g_bin_refine
        bin_local_refine #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),
            .LINE_CYCLE(LINE_CYCLE),.AW(AW),.C_MIN(BIN_REFINE_CMIN)) u_refine(
            .I_clk(I_clk),.I_rst_n(I_rst_n),.I_de(y2_de),.I_vsync(bin_gray_vs),
            .I_gray(bin_gray),.I_global(bin_base),.O_pixel(bin_pix),.O_warm(bin_pixel_warm));
    end else begin:g_bin_global
        assign bin_pix=bin_base;
        assign bin_pixel_warm=1'b1;
    end endgenerate

    reg [1:0] bin_align_mem [0:BIN_ALIGN_CYC-1];
    localparam BIN_ALIGN_AW=(BIN_ALIGN_CYC>1)?$clog2(BIN_ALIGN_CYC):1;
    reg [BIN_ALIGN_AW-1:0] bin_align_wr;
    reg [1:0] bin_align_q;
    reg bin_align_filled,bin_align_valid;
    wire bin_filtered_major=bin_align_q[0];
    wire bin_align_ready=bin_align_valid&&bin_align_q[1];
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            bin_align_wr       <= 15'd0;
            bin_align_filled   <= 1'b0;
            bin_align_valid    <= 1'b0;
        end else begin
            bin_align_wr <= (bin_align_wr == BIN_ALIGN_LAST) ? 15'd0
                                                            : bin_align_wr + 15'd1;
            if (bin_align_wr == BIN_ALIGN_LAST)
                bin_align_filled <= 1'b1;
            bin_align_valid <= bin_align_filled;
        end
    end

    always @(posedge I_clk) begin
        if (I_rst_n) begin
            bin_align_q <= bin_align_mem[bin_align_wr];
            bin_align_mem[bin_align_wr] <= {bin_pixel_warm,bin_pix};
        end
    end

    wire [15:0] bin_sum  = color_out[23:16]*8'd77 + color_out[15:8]*8'd150 + color_out[7:0]*8'd29;
    wire bin_filter_border = (row_cnt < BLANK_ROWS + 2) ||
                             (row_cnt >= IMG_HEIGHT - BLANK_ROWS - 2) ||
                             (col_cnt < BLANK_ROWS + 2) ||
                             (col_cnt >= IMG_WIDTH - BLANK_ROWS - 2);
    wire bin_border_raw = bin_filter_border && BIN_BORDER_RAW;
    wire bin_out = (!bin_align_ready || bin_border_raw)
                   ? (bin_sum[15:8] >= bin_thresh[7:0]) : bin_filtered_major;
    wire [23:0] bin_rgb  = bin_out ? 24'hFFFFFF : 24'h000000;

    wire edge_mode = (I_mode == 2'd1);
    wire bin_mode  = (I_mode == 2'd2);

    wire        color_mode = (I_mode == 2'd3)&&!I_style[1];
    wire        c_box_any;
    wire [23:0] c_box_rgb;
    wire [5:0]  c_ok;
    wire [11:0] c_shape;
    wire        c_lbl_px;
    wire [1:0]  c_lbl_col;

    wire [1:0] post_rg;
    wire green_strong;
    color_post_rg_threshold u_post_rg(.I_rgb(color_out),.O_mask(post_rg),
                                    .O_green_strong(green_strong));
    wire [2:0] color_weak={blue_masks[0],post_rg};
    wire [2:0] color_strong={blue_masks[1],green_strong,post_rg[0]};
    wire [47:0] color_overflow,color_pruned;
    wire [119:0] color_area;
    wire [65:0] color_x0,color_x1;
    wire [59:0] color_y0,color_y1;
    wire color_frame_update;
    color_detect #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),.CLEANUP(1)) u_color_detect (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_vsync(o_vsync_dly),.I_de(o_de_dly),
        .I_x(col_cnt),.I_y(row_cnt),.I_weak(color_weak),.I_strong(color_strong),
        .O_box_rgb(c_box_rgb),.O_box_any(c_box_any),.O_ok(c_ok),.O_shape(c_shape),
        .O_lbl_px(c_lbl_px),.O_lbl_col(c_lbl_col),.O_overflow(color_overflow),.O_pruned(color_pruned),
        .O_area(color_area),.O_x0(color_x0),.O_x1(color_x1),.O_y0(color_y0),.O_y1(color_y1),.O_update(color_frame_update));
    color_led_status u_color_led_status(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_enable(color_mode),
        .I_update(color_frame_update),.I_valid(c_ok),.O_led(O_color_led));

    wire [23:0] c_lbl_rgb = (c_lbl_col == 2'd0) ? 24'hFF0000 :
                            (c_lbl_col == 2'd1) ? 24'h00FF00 : 24'h0000FF;

    wire [23:0] color_sel = (color_mode && c_lbl_px) ? c_lbl_rgb :
                            (color_mode && c_box_any) ? c_box_rgb : color_out;
    wire [23:0] styled_rgb;
    wire [119:0] oil_rows;
    genvar oil_row;
    generate for(oil_row=0;oil_row<5;oil_row=oil_row+1)begin:g_oil_tap
        assign oil_rows[oil_row*24+:24]=cline[26*(WIN_ROWS-oil_row)+:24];
    end endgenerate
    wire [23:0] oil_result;
    oil_pixel5 u_oil(.I_clk(I_clk),.I_rst_n(I_rst_n),.I_rows(oil_rows),.I_clear(!I_de),.O_rgb(oil_result));
    localparam OIL_DELAY=PIPE_EXTRA-5;
    reg [23:0] oil_pipe[0:OIL_DELAY-1];
    integer oi;
    always @(posedge I_clk)begin
        oil_pipe[0]<=oil_result;
        for(oi=1;oi<OIL_DELAY;oi=oi+1)oil_pipe[oi]<=oil_pipe[oi-1];
    end
    wire oil_border=(row_cnt<BORDER+4)||(row_cnt>=IMG_HEIGHT-BORDER-4)||
        (col_cnt<BORDER+4)||(col_cnt>=IMG_WIDTH-BORDER-4);
    assign styled_rgb=(I_style[0]&&!oil_border)?oil_pipe[OIL_DELAY-1]:color_out;
    wire [23:0] sel_rgb = edge_mode ? edge_rgb :
                          bin_mode  ? bin_rgb  : color_mode ? color_sel : styled_rgb;

    wire [2:0] caption_mode=(I_mode==0&&I_style[0])?3'd4:
                            (I_mode==3&&I_style[1])?3'd5:{1'b0,I_mode};

    wire osd_px, osd_region;
    osd_text u_osd_text (
        .I_x      ( col_cnt    ),
        .I_y      ( row_cnt    ),
        .I_mode   ( caption_mode ),
        .O_pixel  ( osd_px     ),
        .O_region ( osd_region )
    );

    wire dbg_px, dbg_region;
    osd_ae_debug #(.IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .NR_BUILD(NR_BUILD)) u_osd_ae_debug (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_vsync(o_vsync_dly),
        .I_x(col_cnt), .I_y(row_cnt),
        .I_nr_diag(I_dbg_nr_diag),
        .I_exp(I_dbg_exp), .I_gain(I_dbg_gain),
        .I_luma(I_dbg_luma), .I_target(I_dbg_target), .I_pixels(I_dbg_pixels),
        .I_valid(I_dbg_valid), .I_cfg(I_dbg_cfg), .I_busy(I_dbg_busy),
        .I_writes(I_dbg_writes),
        .I_read_exp(I_dbg_read_exp), .I_read_gain(I_dbg_read_gain),
        .I_expected_gain(I_dbg_expected_gain), .I_read_count(I_dbg_read_count),
        .I_read_valid(I_dbg_read_valid), .I_write_ack(I_dbg_write_ack),
        .I_comm_error(I_dbg_comm_error), .I_read_match(I_dbg_read_match),
        .O_pixel(dbg_px), .O_region(dbg_region)
    );
    wire bin_dbg_px, bin_dbg_region;
    osd_bin_debug #(.IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)) u_osd_bin_debug (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_vsync(o_vsync_dly),
        .I_x(col_cnt), .I_y(row_cnt), .I_thresh(bin_thresh[7:0]),
        .I_target(bin_dbg_target), .I_low(bin_dbg_low), .I_high(bin_dbg_high),
        .I_valid(bin_dbg_valid), .I_seed(bin_dbg_seed), .I_updates(bin_dbg_updates), .I_bias(BIN_BIAS),
        .I_pixels(bin_dbg_pixels), .I_white(bin_dbg_white),
        .O_pixel(bin_dbg_px), .O_region(bin_dbg_region)
    );
    assign O_rgb   = (BIN_DIAG_EN && bin_dbg_region) ? (bin_dbg_px ? 24'hFFFFFF : 24'h000000) :
                    dbg_region ? (dbg_px ? 24'hFFFFFF : 24'h000000) :
                    osd_region ?
                                 (osd_px ? 24'hFFFFFF : 24'h000000) : sel_rgb;
    assign O_de    = o_de_dly;
    assign O_vsync = o_vsync_dly;

endmodule

module oil_pixel5(
    input wire I_clk,I_rst_n,
    input wire [119:0] I_rows,
    input wire I_clear,
    output reg [23:0] O_rgb
);
    wire [11:0] px[0:24];
    genvar row;
    generate for(row=0;row<5;row=row+1)begin:g_row
        wire [11:0] quant={I_rows[row*24+20+:4],I_rows[row*24+12+:4],I_rows[row*24+4+:4]};
        wire [11:0] aligned;
        if(row==0)begin:g_direct
            assign aligned=quant;
        end else begin:g_align
            reg [11:0] delay_[0:row-1];integer j;
            always @(posedge I_clk)begin
                delay_[0]<=quant;
                for(j=1;j<row;j=j+1)delay_[j]<=delay_[j-1];
            end
            assign aligned=delay_[row-1];
        end
        assign px[row*5]=aligned;
    end endgenerate
    reg [2:0] col_count[0:3];
    reg [6:0] col_r[0:3],col_g[0:3],col_b[0:3];
    reg [2:0] old_count[0:19];
    reg [6:0] old_r[0:19],old_g[0:19],old_b[0:19];
    reg [4:0] count[0:3];
    reg [8:0] sum_r[0:3],sum_g[0:3],sum_b[0:3];
    reg [2:0] filled;
    integer r,k;reg [5:0] lum;
    reg [2:0] nc;reg [6:0] nr,ng,nb;

    always @(posedge I_clk)begin
        for(k=0;k<4;k=k+1)begin
            nc=0;nr=0;ng=0;nb=0;
            for(r=0;r<5;r=r+1)begin
                lum={2'd0,px[r*5][11:8]}+{1'b0,px[r*5][7:4],1'b0}+{2'd0,px[r*5][3:0]};
                if(lum[5:4]==k)begin
                    nc=nc+1'b1;nr=nr+px[r*5][11:8];ng=ng+px[r*5][7:4];nb=nb+px[r*5][3:0];
                end
            end
            col_count[k]<=nc;col_r[k]<=nr;col_g[k]<=ng;col_b[k]<=nb;
        end
    end
    integer b,j;

    always @(posedge I_clk)begin
        for(b=0;b<4;b=b+1)begin
            for(j=4;j>0;j=j-1)begin
                old_count[b*5+j]<=old_count[b*5+j-1];
                old_r[b*5+j]<=old_r[b*5+j-1];old_g[b*5+j]<=old_g[b*5+j-1];old_b[b*5+j]<=old_b[b*5+j-1];
            end
            old_count[b*5]<=col_count[b];old_r[b*5]<=col_r[b];old_g[b*5]<=col_g[b];old_b[b*5]<=col_b[b];
        end
        if(!I_rst_n||I_clear)begin
            filled<=0;
            for(b=0;b<4;b=b+1)begin count[b]<=0;sum_r[b]<=0;sum_g[b]<=0;sum_b[b]<=0;end
        end else begin
            if(filled<5)filled<=filled+1'b1;
            for(b=0;b<4;b=b+1)begin
                count[b]<=count[b]+col_count[b]-((filled==5)?old_count[b*5+4]:3'd0);
                sum_r[b]<=sum_r[b]+col_r[b]-((filled==5)?old_r[b*5+4]:7'd0);
                sum_g[b]<=sum_g[b]+col_g[b]-((filled==5)?old_g[b*5+4]:7'd0);
                sum_b[b]<=sum_b[b]+col_b[b]-((filled==5)?old_b[b*5+4]:7'd0);
            end
        end
    end
    wire c01=count[1]>count[0],c23=count[3]>count[2];
    wire [1:0] w01=c01?2'd1:2'd0,w23=c23?2'd3:2'd2;
    wire [1:0] winner=(count[w23]>count[w01])?w23:w01;
    reg [4:0] selected_count;
    reg [8:0] selected_r,selected_g,selected_b;

    always @(posedge I_clk)begin
        selected_count<=count[winner];
        selected_r<=sum_r[winner];selected_g<=sum_g[winner];selected_b<=sum_b[winner];
    end
    reg [4:0] divisor_d;
    always @(posedge I_clk) divisor_d<=selected_count;
    genvar channel;
    generate for(channel=0;channel<3;channel=channel+1)begin:g_mean
        wire [8:0] value=(channel==0)?selected_b:(channel==1)?selected_g:selected_r;
        wire [8:0] n8={1'b0,selected_count,3'b000};
        wire [8:0] n4={2'b00,selected_count,2'b00};
        wire q3=(value>=n8);
        wire [8:0] rem8=q3?value-n8:value;
        wire q2=(rem8>=n4);
        wire [8:0] rem4=q2?rem8-n4:rem8;
        reg [6:0] remainder_d;
        reg [1:0] upper_d;

        always @(posedge I_clk)begin
            remainder_d<=rem4[6:0];upper_d<={q3,q2};
        end
        wire [6:0] n2={1'b0,divisor_d,1'b0};
        wire q1=(remainder_d>=n2);
        wire [6:0] rem2=q1?remainder_d-n2:remainder_d;
        wire q0=(rem2>={2'b00,divisor_d});
        wire [3:0] mean=(divisor_d==0)?4'd0:{upper_d,q1,q0};

        always @(posedge I_clk)begin
            if(!I_rst_n)O_rgb[channel*8+:8]<=0;
            else O_rgb[channel*8+:8]<={mean,mean};
        end
    end endgenerate
endmodule

module color_blue_threshold(
    input wire [23:0] I_rgb,
    output wire O_weak,O_strong
);
    wire [8:0] r={1'b0,I_rgb[23:16]},g={1'b0,I_rgb[15:8]},b={1'b0,I_rgb[7:0]};
    wire [10:0] lum4={2'd0,r}+{1'd0,g,1'b0}+{2'd0,b};
    wire [8:0] y=lum4[10:2];
    wire [8:0] hi=(r>g)?((r>b)?r:b):((g>b)?g:b);
    wire [8:0] lo=(r<g)?((r<b)?r:b):((g<b)?g:b);
    wire [8:0] sat=hi-lo;
    wire weak_base=(y>=9'd12)&&(sat>=9'd8)&&(sat>=(hi>>3));
    wire strong_base=(y>=9'd20)&&(sat>=9'd16)&&(sat>=(hi>>2));
    wire [8:0] blue_gap=((hi>>2)>9'd10)?(hi>>2):9'd10;
    wire [8:0] blue_core=(hi>>2)+(hi>>3);
    wire [8:0] blue_strong_gap=(blue_core>9'd12)?blue_core:9'd12;
    assign O_weak=weak_base&&(y>=9'd16)&&(b>r+blue_gap)&&(b>g+blue_gap);
    assign O_strong=O_weak&&strong_base&&(b>r+blue_strong_gap)&&(b>g+blue_strong_gap);
endmodule

module color_post_rg_threshold(
    input wire [23:0] I_rgb,
    output wire [1:0] O_mask,
    output wire O_green_strong
);
    wire [8:0] r={1'b0,I_rgb[23:16]},g={1'b0,I_rgb[15:8]},b={1'b0,I_rgb[7:0]};
    assign O_mask[0]=(r>g+9'd40)&&(r>b+9'd40)&&(r>9'd60);

    assign O_mask[1]=(g>=r+9'd20)&&(g>=b+9'd20)&&(g>=9'd36);
    assign O_green_strong=(g>=r+9'd24)&&(g>=b+9'd24)&&(g>=9'd44);
endmodule

module color_candidate_bank #(
    parameter [19:0] MIN_AREA=200,MIN_STRONG=32,
    parameter [10:0] MIN_W=8,
    parameter [9:0] MIN_H=8,
    parameter MIN_FILL_SHIFT=0
)(
    input wire I_clk,I_rst_n,I_release,I_done,
    input wire [10:0] I_x0,I_x1,
    input wire [9:0] I_y0,I_y1,
    input wire [19:0] I_area,I_strong,
    input wire [1:0] I_track_valid,
    input wire [21:0] I_tx0,I_tx1,
    input wire [19:0] I_ty0,I_ty1,
    output reg [3:0] O_ok,
    output reg [43:0] O_x0,O_x1,
    output reg [39:0] O_y0,O_y1,
    output reg [79:0] O_area,
    output reg [15:0] O_pruned
);
    wire fill_ok;
    generate if(MIN_FILL_SHIFT!=0)begin:g_fill
        wire [11:0] w={1'b0,I_x1}-{1'b0,I_x0}+12'd1;
        wire [10:0] h={1'b0,I_y1}-{1'b0,I_y0}+11'd1;
        wire [22:0] box_area=w*h;
        assign fill_ok=({3'd0,I_area}<<MIN_FILL_SHIFT)>=box_area;
    end else begin:g_no_fill
        assign fill_ok=1'b1;
    end endgenerate
    wire eligible=fill_ok&&(I_area>=MIN_AREA)&&(I_strong>=MIN_STRONG)&&(I_strong>=(I_area>>3))&&
        ({1'b0,I_x1}-{1'b0,I_x0}+12'd1>={1'b0,MIN_W})&&
        ({1'b0,I_y1}-{1'b0,I_y0}+11'd1>={1'b0,MIN_H});
    wire priority_new=(I_track_valid[0]&&(I_x0<=I_tx1[10:0])&&(I_x1>=I_tx0[10:0])&&
        (I_y0<=I_ty1[9:0])&&(I_y1>=I_ty0[9:0]))||
        (I_track_valid[1]&&(I_x0<=I_tx1[21:11])&&(I_x1>=I_tx0[21:11])&&
        (I_y0<=I_ty1[19:10])&&(I_y1>=I_ty0[19:10]));
    reg [3:0] priority_old;
    function [19:0] area_at;
        input [79:0] words;
        input [1:0] index_;
        begin case(index_)
            2'd0:area_at=words[0+:20];
            2'd1:area_at=words[20+:20];
            2'd2:area_at=words[40+:20];
            2'd3:area_at=words[60+:20];
            default:area_at=20'bx;
        endcase end
    endfunction
    reg [1:0] destination;
    reg free_slot;

    wire [20:0] rank0={priority_old[0],O_area[0+:20]};
    wire [20:0] rank1={priority_old[1],O_area[20+:20]};
    wire [20:0] rank2={priority_old[2],O_area[40+:20]};
    wire [20:0] rank3={priority_old[3],O_area[60+:20]};
    wire pair01=(rank1<rank0),pair23=(rank3<rank2);
    wire [20:0] low01=pair01?rank1:rank0;
    wire [20:0] low23=pair23?rank3:rank2;
    wire [1:0] weakest=(low23<low01)?{1'b1,pair23}:{1'b0,pair01};
    integer j,slot;
    always @*begin
        destination=weakest;free_slot=0;
        for(j=3;j>=0;j=j-1)if(!O_ok[j])begin destination=j;free_slot=1;end
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin O_ok<=0;O_x0<=0;O_x1<=0;O_y0<=0;O_y1<=0;O_area<=0;priority_old<=0;O_pruned<=0;end
        else if(I_release)O_ok<=0;
        else if(I_done&&eligible)begin
            if(!free_slot&&O_pruned!=16'hffff)O_pruned<=O_pruned+1'b1;
            if(free_slot||({priority_new,I_area}>{priority_old[destination],area_at(O_area,destination)}))begin
                for(slot=0;slot<4;slot=slot+1)if(destination==slot)begin
                O_ok[slot]<=1;priority_old[slot]<=priority_new;
                O_x0[slot*11+:11]<=I_x0;O_x1[slot*11+:11]<=I_x1;
                O_y0[slot*10+:10]<=I_y0;O_y1[slot*10+:10]<=I_y1;
                O_area[slot*20+:20]<=I_area;
                end
            end
        end
    end
endmodule

module color_led_status(
    input wire I_clk,I_rst_n,I_enable,I_update,
    input wire [5:0] I_valid,
    output reg [2:0] O_led
);
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)O_led<=3'b000;
        else if(!I_enable)O_led<=3'b000;
        else if(I_update)O_led<={|I_valid[5:4],|I_valid[3:2],|I_valid[1:0]};
    end
endmodule

module color_tracks4 #(
    parameter [10:0] SMOOTH_DEAD=8,SMOOTH_STEP=24,
    parameter [1:0] HOLD_FRAMES=3
)(
    input wire I_clk,I_rst_n,I_start,
    input wire [131:0] I_x0,I_x1,
    input wire [119:0] I_y0,I_y1,
    input wire [239:0] I_area,
    input wire [11:0] I_ok,
    output reg [65:0] O_x0,O_x1,O_bx0,O_bx1,
    output reg [59:0] O_y0,O_y1,O_by0,O_by1,
    output reg [119:0] O_area,
    output reg [5:0] O_ok,
    output reg O_update
);
    function [10:0] pick11_12;
        input [131:0] words;
        input [3:0] index_;
        begin case(index_)
            4'd0:pick11_12=words[0+:11];
            4'd1:pick11_12=words[11+:11];
            4'd2:pick11_12=words[22+:11];
            4'd3:pick11_12=words[33+:11];
            4'd4:pick11_12=words[44+:11];
            4'd5:pick11_12=words[55+:11];
            4'd6:pick11_12=words[66+:11];
            4'd7:pick11_12=words[77+:11];
            4'd8:pick11_12=words[88+:11];
            4'd9:pick11_12=words[99+:11];
            4'd10:pick11_12=words[110+:11];
            4'd11:pick11_12=words[121+:11];
            default:pick11_12=11'bx;
        endcase end
    endfunction
    function [9:0] pick10_12;
        input [119:0] words;
        input [3:0] index_;
        begin case(index_)
            4'd0:pick10_12=words[0+:10];
            4'd1:pick10_12=words[10+:10];
            4'd2:pick10_12=words[20+:10];
            4'd3:pick10_12=words[30+:10];
            4'd4:pick10_12=words[40+:10];
            4'd5:pick10_12=words[50+:10];
            4'd6:pick10_12=words[60+:10];
            4'd7:pick10_12=words[70+:10];
            4'd8:pick10_12=words[80+:10];
            4'd9:pick10_12=words[90+:10];
            4'd10:pick10_12=words[100+:10];
            4'd11:pick10_12=words[110+:10];
            default:pick10_12=10'bx;
        endcase end
    endfunction
    function [19:0] pick20_12;
        input [239:0] words;
        input [3:0] index_;
        begin case(index_)
            4'd0:pick20_12=words[0+:20];
            4'd1:pick20_12=words[20+:20];
            4'd2:pick20_12=words[40+:20];
            4'd3:pick20_12=words[60+:20];
            4'd4:pick20_12=words[80+:20];
            4'd5:pick20_12=words[100+:20];
            4'd6:pick20_12=words[120+:20];
            4'd7:pick20_12=words[140+:20];
            4'd8:pick20_12=words[160+:20];
            4'd9:pick20_12=words[180+:20];
            4'd10:pick20_12=words[200+:20];
            4'd11:pick20_12=words[220+:20];
            default:pick20_12=20'bx;
        endcase end
    endfunction
    function [10:0] pick11_6;
        input [65:0] words;
        input [2:0] index_;
        begin case(index_)
            3'd0:pick11_6=words[0+:11];
            3'd1:pick11_6=words[11+:11];
            3'd2:pick11_6=words[22+:11];
            3'd3:pick11_6=words[33+:11];
            3'd4:pick11_6=words[44+:11];
            3'd5:pick11_6=words[55+:11];
            default:pick11_6=11'bx;
        endcase end
    endfunction
    function [9:0] pick10_6;
        input [59:0] words;
        input [2:0] index_;
        begin case(index_)
            3'd0:pick10_6=words[0+:10];
            3'd1:pick10_6=words[10+:10];
            3'd2:pick10_6=words[20+:10];
            3'd3:pick10_6=words[30+:10];
            3'd4:pick10_6=words[40+:10];
            3'd5:pick10_6=words[50+:10];
            default:pick10_6=10'bx;
        endcase end
    endfunction
    localparam IDLE=0,DIST=1,ENUM=2,MAP=3,NEW=4,LOAD=5,EDGE=6,PUBLISH=7;
    reg [3:0] state;
    reg [1:0] color;
    reg [2:0] dc,choice0,choice1,assignment0,assignment1,new_cursor;
    reg [2:0] best0,best1;
    reg dt,track;
    reg [1:0] status[0:5],lost[0:5];
    reg [12:0] distance[0:7];
    reg [7:0] allowed;
    reg [2:0] best_matches;
    reg [14:0] best_cost;
    reg fresh0,fresh1;

    wire single_green=(color==2'd1);
    reg [19:0] new_green_area;
    wire [3:0] ci={color,dc[1:0]};
    wire [2:0] ti={color,dt},t0={color,1'b0},t1={color,1'b1};
    wire [3:0] candidate_address=(state==DIST)?ci:
        (state==NEW)?{color,new_cursor[1:0]}:
        {color,(track?assignment1[1:0]:assignment0[1:0])};
    wire [10:0] candidate_x0=pick11_12(I_x0,candidate_address);
    wire [10:0] candidate_x1=pick11_12(I_x1,candidate_address);
    wire [9:0] candidate_y0=pick10_12(I_y0,candidate_address);
    wire [9:0] candidate_y1=pick10_12(I_y1,candidate_address);
    wire [19:0] candidate_area=pick20_12(I_area,candidate_address);
    wire [11:0] cx={1'b0,candidate_x0}+{1'b0,candidate_x1};
    wire [11:0] tx={1'b0,pick11_6(O_bx0,ti)}+{1'b0,pick11_6(O_bx1,ti)};
    wire [10:0] cy={1'b0,candidate_y0}+{1'b0,candidate_y1};
    wire [10:0] ty={1'b0,pick10_6(O_by0,ti)}+{1'b0,pick10_6(O_by1,ti)};
    wire [11:0] dx=(cx>tx)?cx-tx:tx-cx;
    wire [10:0] dy=(cy>ty)?cy-ty:ty-cy;
    wire [10:0] cw=candidate_x1-candidate_x0+11'd1;
    wire [10:0] ch={1'b0,candidate_y1}-{1'b0,candidate_y0}+11'd1;
    wire [10:0] tw=pick11_6(O_bx1,ti)-pick11_6(O_bx0,ti)+11'd1;
    wire [10:0] th={1'b0,pick10_6(O_by1,ti)}-{1'b0,pick10_6(O_by0,ti)}+11'd1;
    wire [10:0] dw=(cw>tw)?cw-tw:tw-cw,dh=(ch>th)?ch-th:th-ch;
    wire [10:0] size_max=(tw>th)?tw:th;
    wire [10:0] gate_px=(size_max<64)?11'd32:(size_max>256)?11'd128:(size_max>>1);
    wire [12:0] movement={1'b0,dx}+{2'd0,dy};
    wire [12:0] cost=movement+{2'd0,dw}+{2'd0,dh};
    wire admissible=(!single_green||!dt)&&I_ok[ci]&&(status[ti]!=0)&&(movement<={1'b0,gate_px,1'b0})&&
        ({1'b0,cw,1'b0}>={2'd0,tw})&&({2'd0,cw}<={1'b0,tw,1'b0})&&
        ({1'b0,ch,1'b0}>={2'd0,th})&&({2'd0,ch}<={1'b0,th,1'b0});
    wire c0ok=(choice0==4)||allowed[{1'b0,choice0[1:0]}];
    wire c1ok=(choice1==4)||allowed[{1'b1,choice1[1:0]}];
    wire [2:0] matches=((choice0<4)?((status[t0]==2)?3'd3:3'd1):3'd0)+
                       ((choice1<4)?((status[t1]==2)?3'd3:3'd1):3'd0);
    wire [14:0] total_cost=((choice0<4)?{2'd0,distance[{1'b0,choice0[1:0]}]}:15'd0)+
                           ((choice1<4)?{2'd0,distance[{1'b1,choice1[1:0]}]}:15'd0);
    wire [2:0] selected=track?assignment1:assignment0;
    wire [3:0] source={color,selected[1:0]};
    wire [2:0] target={color,track};
    wire fresh=track?fresh1:fresh0;
    reg [1:0] edge_index;
    reg [10:0] sx0,sx1;
    reg [9:0] sy0,sy1;
    reg [10:0] old_edge,new_edge;
    always @*begin
        case(edge_index)
        0:begin old_edge=pick11_6(O_x0,target);new_edge=candidate_x0;end
        1:begin old_edge=pick11_6(O_x1,target);new_edge=candidate_x1;end
        2:begin old_edge={1'b0,pick10_6(O_y0,target)};new_edge={1'b0,candidate_y0};end
        default:begin old_edge={1'b0,pick10_6(O_y1,target)};new_edge={1'b0,candidate_y1};end
        endcase
    end
    wire [10:0] delta=(new_edge>old_edge)?new_edge-old_edge:old_edge-new_edge;

    wire [10:0] smooth_step=(delta>SMOOTH_STEP)?SMOOTH_STEP:delta;
    wire [10:0] smooth=(delta<=SMOOTH_DEAD)?old_edge:
        (new_edge>old_edge)?old_edge+smooth_step:old_edge-smooth_step;
    wire [10:0] edge_value=(fresh||status[target]!=2)?new_edge:smooth;
    integer j,slot;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            state<=IDLE;color<=0;dc<=0;dt<=0;track<=0;choice0<=4;choice1<=4;assignment0<=4;assignment1<=4;
            best0<=4;best1<=4;best_matches<=0;best_cost<=15'h7fff;allowed<=0;
            new_cursor<=0;fresh0<=0;fresh1<=0;edge_index<=0;sx0<=0;sx1<=0;sy0<=0;sy1<=0;
            new_green_area<=0;
            O_x0<=0;O_x1<=0;O_y0<=0;O_y1<=0;O_bx0<=0;O_bx1<=0;O_by0<=0;O_by1<=0;
            O_area<=0;O_ok<=0;O_update<=0;
            for(j=0;j<6;j=j+1)begin status[j]<=0;lost[j]<=0;end
            for(j=0;j<8;j=j+1)distance[j]<=0;
        end else begin
            O_update<=0;
            if(I_start)begin color<=0;dc<=0;dt<=0;state<=DIST;end
            else case(state)
            DIST:begin
                distance[{dt,dc[1:0]}]<=cost;allowed[{dt,dc[1:0]}]<=admissible;
                if(dc==3)begin
                    dc<=0;
                    if(!dt)dt<=1;
                    else begin
                        choice0<=0;choice1<=0;best0<=4;best1<=4;
                        best_matches<=0;best_cost<=15'h7fff;state<=ENUM;
                    end
                end else dc<=dc+1'b1;
            end
            ENUM:begin
                if(c0ok&&c1ok&&((choice0==4)||(choice1==4)||(choice0!=choice1))&&
                   ((matches>best_matches)||((matches==best_matches)&&(total_cost<best_cost))))begin
                    best0<=choice0;best1<=choice1;best_matches<=matches;best_cost<=total_cost;
                end
                if(choice1==4)begin choice1<=0;if(choice0==4)state<=MAP;else choice0<=choice0+1'b1;end
                else choice1<=choice1+1'b1;
            end
            MAP:begin
                assignment0<=best0;assignment1<=best1;fresh0<=0;fresh1<=0;
                new_green_area<=0;new_cursor<=0;state<=NEW;
            end
            NEW:begin
                if(I_ok[{color,new_cursor[1:0]}]&&(assignment0!=new_cursor)&&(assignment1!=new_cursor))begin
                    if(((assignment0==4)&&((status[t0]!=2)||(lost[t0]==HOLD_FRAMES)))||
                       (single_green&&fresh0&&(candidate_area>new_green_area)))begin
                        assignment0<=new_cursor;fresh0<=1;
                        if(single_green)new_green_area<=candidate_area;
                    end else if(!single_green&&(assignment1==4)&&((status[t1]!=2)||(lost[t1]==HOLD_FRAMES)))begin
                        assignment1<=new_cursor;fresh1<=1;
                    end
                end
                if(new_cursor==3)begin track<=0;state<=LOAD;end else new_cursor<=new_cursor+1'b1;
            end
            LOAD:begin edge_index<=0;state<=EDGE;end
            EDGE:begin
                case(edge_index)
                0:sx0<=edge_value;1:sx1<=edge_value;2:sy0<=edge_value[9:0];3:sy1<=edge_value[9:0];
                endcase
                if(edge_index==3)state<=PUBLISH;else edge_index<=edge_index+1'b1;
            end
            PUBLISH:begin
                for(slot=0;slot<6;slot=slot+1)if(target==slot)begin
                if(slot==3)begin

                    status[slot]<=0;lost[slot]<=0;O_ok[slot]<=0;O_area[slot*20+:20]<=0;
                end else if(selected<4)begin
                    lost[slot]<=0;status[slot]<=fresh?2'd1:2'd2;O_ok[slot]<=!fresh;
                    O_bx0[slot*11+:11]<=candidate_x0;O_bx1[slot*11+:11]<=candidate_x1;
                    O_by0[slot*10+:10]<=candidate_y0;O_by1[slot*10+:10]<=candidate_y1;
                    O_area[slot*20+:20]<=candidate_area;
                    O_x0[slot*11+:11]<=(sx0<=sx1)?sx0:candidate_x0;
                    O_x1[slot*11+:11]<=(sx0<=sx1)?sx1:candidate_x1;
                    O_y0[slot*10+:10]<=(sy0<=sy1)?sy0:candidate_y0;
                    O_y1[slot*10+:10]<=(sy0<=sy1)?sy1:candidate_y1;
                end else if(status[slot]==2&&lost[slot]<HOLD_FRAMES)lost[slot]<=lost[slot]+1'b1;
                else begin status[slot]<=0;lost[slot]<=0;O_ok[slot]<=0;O_area[slot*20+:20]<=0;end
                end
                if(!track)begin track<=1;state<=LOAD;end
                else if(color==2)begin O_update<=1;state<=IDLE;end
                else begin color<=color+1'b1;dc<=0;dt<=0;state<=DIST;end
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule

module color_detect #(
    parameter IMG_WIDTH=1280,IMG_HEIGHT=720,
    parameter [19:0] MIN_AREA=200,
    parameter [11:0] BORDER=12,
    parameter CLEANUP=0
)(
    input wire I_clk,I_rst_n,I_vsync,I_de,
    input wire [11:0] I_x,I_y,
    input wire [2:0] I_weak,I_strong,
    output wire [23:0] O_box_rgb,
    output wire O_box_any,
    output wire [5:0] O_ok,
    output wire [11:0] O_shape,
    output wire O_lbl_px,
    output wire [1:0] O_lbl_col,
    output wire [47:0] O_overflow,
    output wire [47:0] O_pruned,
    output wire [119:0] O_area,
    output wire [65:0] O_x0,O_x1,
    output wire [59:0] O_y0,O_y1,
    output wire O_update
);
    wire inb=(I_x>=BORDER)&&(I_x<IMG_WIDTH-BORDER)&&(I_y>=BORDER)&&(I_y<IMG_HEIGHT-BORDER);
    wire [131:0] cx0,cx1;
    wire [119:0] cy0,cy1;
    wire [239:0] ca;
    wire [11:0] cv;
    wire [65:0] bx0,bx1;
    wire [59:0] by0,by1;
    wire [2:0] frame_done;
    wire release_bank;
    assign O_update=release_bank;
    wire [2:0] shared_done;
    wire shared_frame_done;
    wire [10:0] shared_x0,shared_x1;
    wire [9:0] shared_y0,shared_y1;
    wire [19:0] shared_area,shared_strong;
    assign frame_done={3{shared_frame_done}};
    color_candidates_shared #(.BLUE_RUN_FILTER(1),.GREEN_RUN_FILTER(1),
        .SPATIAL_CORE(CLEANUP),.IMG_WIDTH(IMG_WIDTH)) u_shared_candidates(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_vsync(I_vsync),.I_de(I_de),.I_x(I_x),.I_y(I_y),
        .I_weak(I_weak&{3{inb}}),.I_strong(I_strong&{3{inb}}),
        .O_done(shared_done),.O_frame_done(shared_frame_done),
        .O_x0(shared_x0),.O_x1(shared_x1),.O_y0(shared_y0),.O_y1(shared_y1),
        .O_area(shared_area),.O_strong(shared_strong),.O_overflow(O_overflow));
    genvar c;
    generate for(c=0;c<3;c=c+1)begin:g_color
        wire done;wire [10:0] x0,x1;wire [9:0] y0,y1;wire [19:0] area,strong;
        assign done=shared_done[c];
        assign x0=shared_x0;assign x1=shared_x1;assign y0=shared_y0;assign y1=shared_y1;
        assign area=shared_area;assign strong=shared_strong;
        color_candidate_bank #(.MIN_AREA(MIN_AREA),.MIN_FILL_SHIFT((CLEANUP&&(c==2))?3:0)) u_bank(
            .I_clk(I_clk),.I_rst_n(I_rst_n),.I_release(release_bank),.I_done(done),
            .I_x0(x0),.I_x1(x1),.I_y0(y0),.I_y1(y1),.I_area(area),.I_strong(strong),
            .I_track_valid(O_ok[c*2+:2]),.I_tx0(bx0[c*22+:22]),.I_tx1(bx1[c*22+:22]),
            .I_ty0(by0[c*20+:20]),.I_ty1(by1[c*20+:20]),
            .O_ok(cv[c*4+:4]),.O_x0(cx0[c*44+:44]),.O_x1(cx1[c*44+:44]),
            .O_y0(cy0[c*40+:40]),.O_y1(cy1[c*40+:40]),.O_area(ca[c*80+:80]),.O_pruned(O_pruned[c*16+:16]));
    end endgenerate
    color_tracks4 u_tracks(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(&frame_done),
        .I_x0(cx0),.I_x1(cx1),.I_y0(cy0),.I_y1(cy1),.I_area(ca),.I_ok(cv),
        .O_x0(O_x0),.O_x1(O_x1),.O_y0(O_y0),.O_y1(O_y1),
        .O_bx0(bx0),.O_bx1(bx1),.O_by0(by0),.O_by1(by1),.O_area(O_area),.O_ok(O_ok),.O_update(release_bank));
    assign O_shape=12'hfff;

    reg display_blank;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)display_blank<=1'b0;
        else if(I_vsync)display_blank<=1'b1;
        else if(I_de)display_blank<=1'b0;
    end
    osd_color_label #(.XMAX(IMG_WIDTH),.YMAX(IMG_HEIGHT)) u_color_label(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_update(release_bank),
        .I_frame_blank(display_blank),.I_de(I_de),
        .I_x(I_x),.I_y(I_y),.I_ok(O_ok),
        .I_x0(O_x0),.I_x1(O_x1),.I_y0(O_y0),.I_y1(O_y1),
        .O_pixel(O_lbl_px),.O_color(O_lbl_col),.O_box_any(O_box_any),.O_box_rgb(O_box_rgb));

endmodule

module color_run_extract #(
    parameter STRONG_RUN_FILTER=0,
    parameter [3:0] WEAK_BRIDGE=0,
    parameter [3:0] MIN_CORE_STREAK=0
)(
    input wire I_clk,I_rst_n,I_vsync,I_de,I_weak,I_strong,
    input wire [11:0] I_x,I_y,
    output reg O_emit,
    output reg [10:0] O_x0,O_x1,
    output reg [9:0] O_y,
    output reg [11:0] O_area,O_strong
);
    reg vs_d,active;
    reg [1:0] gap;
    reg [10:0] x0,x1;
    reg [9:0] y;
    reg [11:0] area,strong_count;
    reg [10:0] strong_x1;
    reg [11:0] supported_area;
    reg [3:0] weak_span;
    reg [3:0] core_streak,peak_streak;
    wire [3:0] next_streak=(core_streak==15)?4'd15:core_streak+1'b1;
    wire weak_break=(WEAK_BRIDGE!=0)&&active&&(strong_count!=0)&&I_de&&
        !I_strong&&(weak_span>=WEAK_BRIDGE);

    wire run_supported=(strong_count>=12'd2)&&
        ({strong_count,2'b00}>={2'b00,supported_area})&&
        ((MIN_CORE_STREAK==0)||(peak_streak>=MIN_CORE_STREAK));
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            vs_d<=0;active<=0;gap<=0;x0<=0;x1<=0;y<=0;area<=0;strong_count<=0;
            strong_x1<=0;supported_area<=0;
            weak_span<=0;
            core_streak<=0;peak_streak<=0;
            O_emit<=0;O_x0<=0;O_x1<=0;O_y<=0;O_area<=0;O_strong<=0;
        end else begin
            vs_d<=I_vsync;O_emit<=0;
            if(I_de&&I_weak)begin
                if(!active)begin
                    core_streak<=I_strong?4'd1:4'd0;
                    peak_streak<=I_strong?4'd1:4'd0;
                end else if(I_strong)begin
                    core_streak<=next_streak;
                    if(next_streak>peak_streak)peak_streak<=next_streak;
                end else core_streak<=0;
            end else core_streak<=0;
            if(I_strong||!active)weak_span<=0;
            else if(I_de&&(strong_count!=0)&&weak_span!=15)weak_span<=weak_span+1'b1;
            if(I_vsync&&!vs_d)begin active<=0;gap<=0;weak_span<=0;end
            else if(weak_break)begin

                O_emit<=run_supported;O_x0<=x0;O_x1<=strong_x1;O_y<=y;
                O_area<=supported_area;O_strong<=strong_count;
                active<=0;gap<=0;weak_span<=0;
            end
            else if(I_de&&I_weak)begin
                gap<=0;active<=1;x1<=I_x[10:0];y<=I_y[9:0];
                if(!active)begin x0<=I_x[10:0];area<=1;strong_count<={11'd0,I_strong};end
                else begin area<=area+1'b1;strong_count<=strong_count+{11'd0,I_strong};end
                if(STRONG_RUN_FILTER&&I_strong)begin
                    strong_x1<=I_x[10:0];
                    if(!active||strong_count==0)begin

                        x0<=I_x[10:0];area<=1;supported_area<=1;
                    end else supported_area<=area+1'b1;
                end
            end else if(active)begin
                if(!I_de||gap==2)begin
                    O_emit<=!STRONG_RUN_FILTER||run_supported;

                    O_x0<=x0;O_x1<=STRONG_RUN_FILTER?strong_x1:x1;O_y<=y;
                    O_area<=STRONG_RUN_FILTER?supported_area:area;O_strong<=strong_count;
                    active<=0;gap<=0;
                end else gap<=gap+1'b1;
            end
        end
    end
endmodule

module color_core_support #(parameter WIDTH=1280)(
    input wire I_clk,I_rst_n,I_de,I_vsync,
    input wire [11:0] I_x,I_y,
    input wire [2:0] I_weak,I_strong,
    output wire O_de,O_vsync,
    output wire [11:0] O_x,O_y,
    output wire [2:0] O_weak,O_strong
);
    wire [5:0] a,b,c,d,e,f,g,h,i;
    win3x3 #(.WIDTH(WIDTH),.AW(11),.DW(6)) window(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_de(I_de),.I_data({I_strong,I_weak}),.O_de(),
        .W00(a),.W01(b),.W02(c),.W10(d),.W11(e),.W12(f),.W20(g),.W21(h),.W22(i));
    reg [2:0] de_pipe,vs_pipe;
    reg [11:0] xp[0:2],yp[0:2];
    integer n;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            de_pipe<=0;vs_pipe<=0;
            for(n=0;n<3;n=n+1)begin xp[n]<=0;yp[n]<=0;end
        end else begin
            de_pipe<={de_pipe[1:0],I_de};vs_pipe<={vs_pipe[1:0],I_vsync};
            xp[0]<=I_x;yp[0]<=I_y;
            for(n=1;n<3;n=n+1)begin xp[n]<=xp[n-1];yp[n]<=yp[n-1];end
        end
    end
    assign O_de=de_pipe[2]&&(xp[2]>=2)&&(yp[2]>=2);
    assign O_vsync=vs_pipe[2];
    assign O_x=xp[2]-12'd1;assign O_y=yp[2]-12'd1;
    wire [3:0] red_weak_votes={3'd0,a[0]}+{3'd0,b[0]}+{3'd0,c[0]}+
        {3'd0,d[0]}+{3'd0,e[0]}+{3'd0,f[0]}+
        {3'd0,g[0]}+{3'd0,h[0]}+{3'd0,i[0]};
    assign O_weak[0]=O_de&&e[0]&&(red_weak_votes>=5);
    wire [3:0] green_weak_votes={3'd0,a[1]}+{3'd0,b[1]}+{3'd0,c[1]}+
        {3'd0,d[1]}+{3'd0,e[1]}+{3'd0,f[1]}+
        {3'd0,g[1]}+{3'd0,h[1]}+{3'd0,i[1]};
    assign O_weak[1]=O_de&&e[1]&&(green_weak_votes>=5);
    assign O_weak[2]=O_de&&e[2];
    genvar k;
    generate for(k=0;k<3;k=k+1)begin:g_votes
        wire [3:0] votes={3'd0,a[k+3]}+{3'd0,b[k+3]}+{3'd0,c[k+3]}+
            {3'd0,d[k+3]}+{3'd0,e[k+3]}+{3'd0,f[k+3]}+
            {3'd0,g[k+3]}+{3'd0,h[k+3]}+{3'd0,i[k+3]};
        assign O_strong[k]=O_de&&e[k+3]&&(votes>=5);
    end endgenerate
endmodule

module color_candidates_shared #(
    parameter BLUE_RUN_FILTER=0,GREEN_RUN_FILTER=0,
    parameter SPATIAL_CORE=0,IMG_WIDTH=1280
)(
    input wire I_clk,I_rst_n,I_vsync,I_de,
    input wire [11:0] I_x,I_y,
    input wire [2:0] I_weak,I_strong,
    output reg [2:0] O_done,
    output reg O_frame_done,
    output reg [10:0] O_x0,O_x1,
    output reg [9:0] O_y0,O_y1,
    output reg [19:0] O_area,O_strong,
    output reg [47:0] O_overflow
);
    wire D_de,D_vsync;
    wire [11:0] D_x,D_y;
    wire [2:0] D_weak,D_strong;
    generate if(SPATIAL_CORE)begin:g_spatial
        color_core_support #(.WIDTH(IMG_WIDTH)) support(
            .I_clk(I_clk),.I_rst_n(I_rst_n),.I_de(I_de),.I_vsync(I_vsync),
            .I_x(I_x),.I_y(I_y),.I_weak(I_weak),.I_strong(I_strong),
            .O_de(D_de),.O_vsync(D_vsync),.O_x(D_x),.O_y(D_y),
            .O_weak(D_weak),.O_strong(D_strong));
    end else begin:g_raw
        assign D_de=I_de;assign D_vsync=I_vsync;assign D_x=I_x;assign D_y=I_y;
        assign D_weak=I_weak;assign D_strong=I_strong;
    end endgenerate
    wire [2:0] emitted;
    wire [55:0] incoming[0:2];
    wire [55:0] head[0:2];
    wire [2:0] nonempty,next_nonempty;
    reg [1:0] turn,selected_color;
    reg available;
    reg merging,scanning,flushing,vs_d,de_d;
    reg [1:0] active_color;
    reg [3:0] remaining;
    reg [1:0] destination;
    reg [55:0] active_run;
    reg [3:0] scan;
    reg [9:0] row_y,retired_row;
    reg [1:0] drain;
    wire rise=D_vsync&&!vs_d;

    wire process_run=available&&!merging;
    wire pop=process_run;
    genvar c;
    generate for(c=0;c<3;c=c+1)begin:g_fifo
          color_run_extract #(.STRONG_RUN_FILTER((BLUE_RUN_FILTER&&(c==2))||
                                             (GREEN_RUN_FILTER&&(c==1))),
                            .WEAK_BRIDGE((GREEN_RUN_FILTER&&(c==1))?4'd8:4'd0),
                            .MIN_CORE_STREAK(SPATIAL_CORE?((c==2)?4'd8:(c==1)?4'd3:4'd0):4'd0)) run_extract(
            .I_clk(I_clk),.I_rst_n(I_rst_n),.I_vsync(D_vsync),.I_de(D_de),
            .I_x(D_x),.I_y(D_y),.I_weak(D_weak[c]),.I_strong(D_strong[c]),.O_emit(emitted[c]),
            .O_x0(incoming[c][55:45]),.O_x1(incoming[c][44:34]),.O_y(incoming[c][33:24]),
            .O_area(incoming[c][23:12]),.O_strong(incoming[c][11:0]));
        (* ram_style="dram" *) reg [55:0] data[0:15];
        reg [3:0] wr,rd;
        reg [4:0] count;
        wire take=pop&&(selected_color==c);
        assign head[c]=data[rd];
        assign nonempty[c]=count!=0;

        assign next_nonempty[c]=(count==0)?emitted[c]:
            (count==1)?(!take||emitted[c]):1'b1;
        always @(posedge I_clk)if(emitted[c])data[wr]<=incoming[c];
        always @(posedge I_clk or negedge I_rst_n)begin
            if(!I_rst_n)begin wr<=0;rd<=0;count<=0;end
            else begin
                if(emitted[c])wr<=wr+1'b1;
                if(take)rd<=rd+1'b1;
                case({emitted[c],take})
                2'b10:count<=count+1'b1;
                2'b01:count<=count-1'b1;
                default:begin end
                endcase
            end
        end
        // synthesis translate_off
        always @(posedge I_clk)if(I_rst_n&&emitted[c]&&count==16&&!take)
            $fatal(1,"Color run FIFO overflow");
        // synthesis translate_on
    end endgenerate
    wire [1:0] next_turn=process_run?
        ((selected_color==2)?2'd0:selected_color+2'd1):turn;
    reg [1:0] next_selected;
    always @*begin
        next_selected=next_turn;
        case(next_turn)
        0:if(next_nonempty[0])next_selected=0;
          else if(next_nonempty[1])next_selected=1;else if(next_nonempty[2])next_selected=2;
        1:if(next_nonempty[1])next_selected=1;
          else if(next_nonempty[2])next_selected=2;else if(next_nonempty[0])next_selected=0;
        2:if(next_nonempty[2])next_selected=2;
          else if(next_nonempty[0])next_selected=0;else if(next_nonempty[1])next_selected=1;
        default:next_selected=0;
        endcase
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin available<=0;selected_color<=0;end
        else begin available<=|next_nonempty;selected_color<=next_selected;end
    end

    localparam RECORD=114,WORD=456;
    reg [11:0] used;
    wire retire=!merging&&!available&&scanning&&!rise&&!(|emitted);
    wire [1:0] memory_color=merging?active_color:available?selected_color:(scan<12?scan[3:2]:2'd0);
    wire [WORD-1:0] old_word;
    wire [3:0] color_used=used[memory_color*4+:4];
    wire [55:0] event_run=merging?active_run:head[selected_color];
    wire [10:0] ex0=event_run[55:45],ex1=event_run[44:34];
    wire [9:0] ey=event_run[33:24];
    wire [11:0] ea=event_run[23:12],es=event_run[11:0];
    reg [3:0] hit;
    reg [1:0] free_index,first_hit;
    reg free_found;
    reg [113:0] record_tmp;
    integer h;
    always @*begin
        hit=0;free_index=0;first_hit=0;free_found=0;record_tmp=0;
        for(h=3;h>=0;h=h-1)begin
            if(!color_used[h])begin free_index=h;free_found=1;end
            record_tmp=old_word[h*RECORD+:RECORD];
            if(color_used[h]&&
                (((ey==record_tmp[49:40])&&({1'b0,ex0}<={1'b0,record_tmp[60:50]}+12'd1)&&
                    ({1'b0,ex1}+12'd1>={1'b0,record_tmp[71:61]}))||
                 (({1'b0,ey}>{1'b0,record_tmp[49:40]})&&
                  ({1'b0,ey}<={1'b0,record_tmp[49:40]}+11'd4)&&
                  ({1'b0,ex0}<={1'b0,record_tmp[60:50]}+12'd3)&&
                  ({1'b0,ex1}+12'd3>={1'b0,record_tmp[71:61]}))||

                 (({1'b0,ey}>{1'b0,record_tmp[49:40]}+11'd4)&&
                  ({1'b0,ey}<={1'b0,record_tmp[49:40]}+11'd12)&&
                  ({1'b0,ex0}<={1'b0,record_tmp[60:50]})&&
                  ({1'b0,ex1}>={1'b0,record_tmp[71:61]}))))hit[h]=1;
            if(hit[h])first_hit=h;
        end
    end
    reg [3:0] fold_bits;
    reg [1:0] fold_index;
    integer k;
    always @*begin
        fold_bits=merging?remaining:hit;
        fold_index=0;
        for(k=3;k>=0;k=k-1)if(fold_bits[k])fold_index=k;
    end
    wire [3:0] after_fold=fold_bits&~(4'b0001<<fold_index);
    function [113:0] record_at;
        input [455:0] words;
        input [1:0] index_;
        begin case(index_)
            2'd0:record_at=words[0+:114];
            2'd1:record_at=words[114+:114];
            2'd2:record_at=words[228+:114];
            2'd3:record_at=words[342+:114];
            default:record_at=114'bx;
        endcase end
    endfunction
    wire [113:0] folded_record=record_at(old_word,fold_index);
    reg [10:0] ax0,ax1,al0,al1,mx0,mx1,ml0,ml1;
    reg [9:0] ay0,ay1,my0,my1;
    reg [19:0] aa,ass,ma,ms;
    always @*begin
        mx0=merging?ax0:ex0;mx1=merging?ax1:ex1;
        my0=merging?ay0:ey;my1=merging?ay1:ey;
        ml0=merging?al0:ex0;ml1=merging?al1:ex1;
        ma=merging?aa:{8'd0,ea};ms=merging?ass:{8'd0,es};
        if(|fold_bits)begin
            if(folded_record[113:103]<mx0)mx0=folded_record[113:103];
            if(folded_record[102:92]>mx1)mx1=folded_record[102:92];
            if(folded_record[91:82]<my0)my0=folded_record[91:82];
            if(folded_record[81:72]>my1)my1=folded_record[81:72];
            ma=ma+folded_record[39:20];ms=ms+folded_record[19:0];
            if(folded_record[49:40]==ey)begin
                if(folded_record[71:61]<ml0)ml0=folded_record[71:61];
                if(folded_record[60:50]>ml1)ml1=folded_record[60:50];
            end
        end
    end
    wire accepted=merging||(|hit)||((ea>=3)&&free_found);
    wire commit=(merging||process_run)&&accepted&&!(|after_fold);
    wire [1:0] commit_index=merging?destination:(|hit)?first_hit:free_index;
    reg [3:0] merged_hits;
    wire [3:0] clear_hits=merging?merged_hits:hit;

    genvar bank;
    generate for(bank=0;bank<4;bank=bank+1)begin:g_record_bank
        (* ram_style="dram" *) reg [RECORD-1:0] data[0:2];
        assign old_word[bank*RECORD+:RECORD]=data[memory_color];
        always @(posedge I_clk)
            if(commit&&(commit_index==bank))
                data[memory_color]<={mx0,mx1,my0,my1,ml0,ml1,ey,ma,ms};
    end endgenerate
    wire [113:0] retired_record=record_at(old_word,scan[1:0]);
    wire retire_valid=(scan<12)&&color_used[scan[1:0]]&&
        (flushing||({1'b0,retired_row}>={1'b0,retired_record[49:40]}+11'd13));
    integer n,t;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            turn<=0;merging<=0;scanning<=0;flushing<=0;vs_d<=0;de_d<=0;
            active_color<=0;remaining<=0;destination<=0;active_run<=0;scan<=0;
            row_y<=0;retired_row<=0;drain<=0;used<=0;merged_hits<=0;
            ax0<=0;ax1<=0;ay0<=0;ay1<=0;al0<=0;al1<=0;aa<=0;ass<=0;
            O_done<=0;O_frame_done<=0;O_x0<=0;O_x1<=0;O_y0<=0;O_y1<=0;
            O_area<=0;O_strong<=0;O_overflow<=0;
        end else begin
            vs_d<=D_vsync;de_d<=D_de;O_done<=0;O_frame_done<=0;
            if(D_de)row_y<=D_y[9:0];
            if(de_d&&!D_de&&!rise&&!scanning)begin scanning<=1;scan<=0;retired_row<=row_y;end
            if(rise)begin scanning<=1;flushing<=1;scan<=0;drain<=0;end
            if(process_run)begin
                turn<=selected_color==2?2'd0:selected_color+1'b1;
                if(accepted&&(|after_fold))begin
                    merging<=1;active_color<=selected_color;active_run<=event_run;
                    remaining<=after_fold;destination<=first_hit;merged_hits<=hit;
                    ax0<=mx0;ax1<=mx1;ay0<=my0;ay1<=my1;
                    al0<=ml0;al1<=ml1;aa<=ma;ass<=ms;
                end
                if(!accepted&&ea>=3)for(n=0;n<3;n=n+1)
                    if(selected_color==n&&O_overflow[n*16+:16]!=16'hffff)
                        O_overflow[n*16+:16]<=O_overflow[n*16+:16]+1'b1;
            end else if(merging)begin
                if(|after_fold)begin
                    remaining<=after_fold;ax0<=mx0;ax1<=mx1;ay0<=my0;ay1<=my1;
                    al0<=ml0;al1<=ml1;aa<=ma;ass<=ms;
                end else merging<=0;
            end else if(retire)begin
                if(scan<12)begin
                    if(retire_valid)begin
                        O_done<=3'b001<<memory_color;
                        O_x0<=retired_record[113:103];O_x1<=retired_record[102:92];
                        O_y0<=retired_record[91:82];O_y1<=retired_record[81:72];
                        O_area<=retired_record[39:20];O_strong<=retired_record[19:0];
                    end
                    scan<=scan+1'b1;
                end else begin
                    scanning<=0;
                    if(flushing)begin flushing<=0;drain<=2;end
                end
            end
            if(commit)for(n=0;n<3;n=n+1)if(memory_color==n)
                for(t=0;t<4;t=t+1)begin
                    if(commit_index==t)used[n*4+t]<=1;
                    else if(clear_hits[t])used[n*4+t]<=0;
                end
            if(retire&&retire_valid)for(n=0;n<3;n=n+1)if(memory_color==n)
                for(t=0;t<4;t=t+1)if(scan[1:0]==t)used[n*4+t]<=0;
            if(drain!=0)begin drain<=drain-1'b1;if(drain==1)O_frame_done<=1;end
        end
    end
endmodule
