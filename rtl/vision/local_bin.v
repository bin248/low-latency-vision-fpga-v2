`timescale 1ns / 1ps

module local_bin #(
    parameter IMG_WIDTH       = 1280,
    parameter AW              = 11,
    parameter [7:0] WIN_SHIFT = 8'd8,

    parameter [3:0] T_SHIFT   = 4'd3,
    parameter [7:0] C_DIFF    = 8'd16,

    parameter [3:0] C_SHIFT  = 4'd4,
    parameter       C_REL_EN = 1'b1
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_de,
    input  wire        I_vsync,
    input  wire [7:0]  I_gray,
    input  wire [4:0]  I_c_min,
    output wire [11:0] O_thresh,
    output wire [11:0] O_thresh_hi
);

    localparam integer WIN = 1 << WIN_SHIFT;

    (* dsp_style = "no" *) reg [WIN*8-1:0] dl;
    always @(posedge I_clk) begin
        if (I_de) dl <= {dl[WIN*8-9:0], I_gray};
    end
    wire [7:0] old_pix = dl[WIN*8-1 -: 8];

    reg  [AW-1:0] col;
    reg  [7:0]    v0;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)     begin col <= {AW{1'b0}}; v0 <= 8'd0; end
        else if (!I_de)   col <= {AW{1'b0}};
        else begin
            col <= (col == IMG_WIDTH-1) ? {AW{1'b0}} : col + 1'b1;
            if (col == {AW{1'b0}}) v0 <= I_gray;
        end
    end
    wire [7:0] old_eff = (col < WIN) ? v0 : old_pix;

    reg  [16:0] hsum;
    wire [7:0]  old_eff_w = old_eff;

    (* dsp_style = "no" *)
    wire [16:0] hsum_nxt  = hsum + {9'd0, I_gray} - {9'd0, old_eff_w};
    wire [16:0] hsum_load = {9'd0, I_gray} << WIN_SHIFT;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)     hsum <= 17'd0;
        else if (I_vsync) hsum <= 17'd0;
        else if (I_de)    hsum <= (col == {AW{1'b0}}) ? hsum_load : hsum_nxt;
    end

    wire [16:0] sum_now = I_de ? ((col == {AW{1'b0}}) ? hsum_load : hsum_nxt) : hsum;
    wire [11:0] lmean   = sum_now >> WIN_SHIFT;

    wire [11:0] c_rel = lmean >> C_SHIFT;
    wire [11:0] c_min = {7'd0, I_c_min};
    wire [11:0] c_eff = C_REL_EN ? ((c_rel > c_min) ? c_rel : c_min)
                                 : {4'd0, C_DIFF};

    assign O_thresh    = (lmean > c_eff) ? (lmean - c_eff) : 12'd0;
    assign O_thresh_hi = (lmean < 12'd4095 - c_eff) ? (lmean + c_eff) : 12'd4095;

endmodule

module bin_local_refine #(
    parameter IMG_WIDTH=1280,
    parameter IMG_HEIGHT=720,
    parameter LINE_CYCLE=1650,
    parameter AW=11,
    parameter [7:0] C_MIN=8'd8
)(
    input wire I_clk,I_rst_n,I_de,I_vsync,
    input wire [7:0] I_gray,
    input wire I_global,
    output reg O_pixel,
    output reg O_warm
);
    localparam ROWS=8, COLS=16;
    localparam PIXELS=IMG_WIDTH*ROWS;
    localparam PAW=$clog2(PIXELS);

    localparam CENTER_CYC=4*LINE_CYCLE;
    localparam CAW=$clog2(CENTER_CYC);

    reg [AW-1:0] x;
    reg [11:0] y;
    reg [PAW-1:0] pixel_addr;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin x<=0;y<=0;pixel_addr<=0;end
        else if(I_vsync)begin x<=0;y<=0;pixel_addr<=0;end
        else if(I_de)begin
            if(x==IMG_WIDTH-1)begin x<=0;y<=y+12'd1;end
            else x<=x+1'b1;
            pixel_addr<=(pixel_addr==PIXELS-1)?0:pixel_addr+1'b1;
        end
    end

    reg [7:0] pixel_mem[0:PIXELS-1];
    reg [10:0] column_mem[0:IMG_WIDTH-1];
    wire [PAW-1:0] old_addr=(y<ROWS)?{{(PAW-AW){1'b0}},x}:pixel_addr;
    reg [7:0] old_pixel1,gray1;
    reg [10:0] old_column1;
    reg [AW-1:0] x1;
    reg de1,first_row1,ready1;
    always @(posedge I_clk)begin
        old_pixel1<=pixel_mem[old_addr];
        old_column1<=column_mem[x];
        if(I_rst_n && I_de && !I_vsync)pixel_mem[pixel_addr]<=I_gray;
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin gray1<=0;x1<=0;de1<=0;first_row1<=0;ready1<=0;end
        else begin
            gray1<=I_gray;x1<=x;de1<=I_de&&!I_vsync;first_row1<=y==0;
            ready1<=I_de&&!I_vsync&&(y>=ROWS)&&(y<IMG_HEIGHT)&&
                    (x>=COLS)&&(x<IMG_WIDTH);
        end
    end
    wire [11:0] vertical_next=first_row1?{1'b0,gray1,3'b000}:
        ({1'b0,old_column1}+{4'd0,gray1}-{4'd0,old_pixel1});
    reg [10:0] vertical2;
    reg [AW-1:0] x2;
    reg de2,ready2;
    always @(posedge I_clk)begin
        if(I_rst_n && de1)column_mem[x1]<=vertical_next[10:0];
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin vertical2<=0;x2<=0;de2<=0;ready2<=0;end
        else begin vertical2<=vertical_next[10:0];x2<=x1;de2<=de1;ready2<=ready1;end
    end

    reg [COLS*11-1:0] horizontal_history;
    reg [10:0] first_column;
    reg [15:0] horizontal_sum;
    wire [10:0] leaving_column=(x2<COLS)?first_column:horizontal_history[COLS*11-1 -: 11];
    wire [16:0] horizontal_next=(x2==0)?{2'b00,vertical2,4'b0000}:
        ({1'b0,horizontal_sum}+{6'd0,vertical2}-{6'd0,leaving_column});
    reg [7:0] mean3;
    reg ready3;
    always @(posedge I_clk)begin
        if(de2)horizontal_history<={horizontal_history[COLS*11-12:0],vertical2};
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin first_column<=0;horizontal_sum<=0;mean3<=0;ready3<=0;end
        else begin
            if(de2)begin
                if(x2==0)first_column<=vertical2;
                horizontal_sum<=horizontal_next[15:0];
                mean3<=horizontal_next[14:7];
            end
            ready3<=ready2;
        end
    end

    reg [8:0] center_mem[0:CENTER_CYC-1];
    reg [CAW-1:0] center_wr;
    reg center_filled,warm1,warm2,warm3;
    reg [8:0] right_word,center2,center3;
    reg [159:0] reference_history;
    wire [9:0] center_word=reference_history[79 -: 10];
    wire [7:0] left_word=reference_history[157 -: 8];
    reg [127:0] vertical_history;
    reg [7:0] left2,right2,top2,bottom2,left3,right3,top3,bottom3;
    reg [7:0] near_left2,near_right2,near_left3,near_right3;
    always @(posedge I_clk)begin
        if(I_rst_n)begin
            center_mem[center_wr]<={I_global,I_gray};
            right_word<=center_mem[center_wr];
        end
        reference_history<={reference_history[149:0],warm1,right_word};
        vertical_history<={vertical_history[111:0],gray1,old_pixel1};
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            center_wr<=0;center_filled<=0;
            warm1<=0;warm2<=0;warm3<=0;center2<=0;center3<=0;
            left2<=0;right2<=0;top2<=0;bottom2<=0;
            left3<=0;right3<=0;top3<=0;bottom3<=0;
            near_left2<=0;near_right2<=0;near_left3<=0;near_right3<=0;
        end else begin
            if(center_wr==CENTER_CYC-1)begin center_wr<=0;center_filled<=1;end
            else center_wr<=center_wr+1'b1;
            warm1<=center_filled;warm2<=center_word[9];warm3<=warm2;
            center2<=center_word[8:0];center3<=center2;
            left2<=left_word;right2<=right_word[7:0];
            top2<=vertical_history[119 -: 8];bottom2<=vertical_history[127 -: 8];
            near_left2<=reference_history[117 -: 8];
            near_right2<=reference_history[37 -: 8];
            left3<=left2;right3<=right2;top3<=top2;bottom3<=bottom2;
            near_left3<=near_left2;near_right3<=near_right2;
        end
    end
    wire [7:0] c_relative={4'd0,mean3[7:4]};
    wire [7:0] contrast=(c_relative>C_MIN)?c_relative:C_MIN;
    wire locally_bright={1'b0,center3[7:0]}>({1'b0,mean3}+{1'b0,contrast});
    wire locally_dark=({1'b0,center3[7:0]}+{1'b0,contrast})<{1'b0,mean3};

    wire bright_h=({1'b0,center3[7:0]}>({1'b0,left3}+{1'b0,contrast}))&&
                  ({1'b0,center3[7:0]}>({1'b0,right3}+{1'b0,contrast}));
    wire bright_v=({1'b0,center3[7:0]}>({1'b0,top3}+{1'b0,contrast}))&&
                  ({1'b0,center3[7:0]}>({1'b0,bottom3}+{1'b0,contrast}));
    wire bright_near=({1'b0,center3[7:0]}>({1'b0,near_left3}+{1'b0,contrast}))&&
                     ({1'b0,center3[7:0]}>({1'b0,near_right3}+{1'b0,contrast}));
    wire [8:0] dark_limit={1'b0,center3[7:0]}+{1'b0,contrast};
    wire dark_h=(dark_limit<{1'b0,left3})&&(dark_limit<{1'b0,right3});
    wire dark_v=(dark_limit<{1'b0,top3})&&(dark_limit<{1'b0,bottom3});
    wire dark_near=(dark_limit<{1'b0,near_left3})&&(dark_limit<{1'b0,near_right3});

    wire [8:0] strong_c={contrast,1'b0};
    wire strong_bright_h=({1'b0,center3[7:0]}>({1'b0,left3}+strong_c))&&
                         ({1'b0,center3[7:0]}>({1'b0,right3}+strong_c));
    wire strong_bright_v=({1'b0,center3[7:0]}>({1'b0,top3}+strong_c))&&
                         ({1'b0,center3[7:0]}>({1'b0,bottom3}+strong_c));
    wire strong_bright_near=({1'b0,center3[7:0]}>({1'b0,near_left3}+strong_c))&&
                            ({1'b0,center3[7:0]}>({1'b0,near_right3}+strong_c));
    wire [8:0] strong_dark_limit={1'b0,center3[7:0]}+strong_c;
    wire strong_dark_h=(strong_dark_limit<{1'b0,left3})&&(strong_dark_limit<{1'b0,right3});
    wire strong_dark_v=(strong_dark_limit<{1'b0,top3})&&(strong_dark_limit<{1'b0,bottom3});
    wire strong_dark_near=(strong_dark_limit<{1'b0,near_left3})&&(strong_dark_limit<{1'b0,near_right3});
    wire correct_bright=(locally_bright&&(bright_h||bright_v||bright_near))||
                        strong_bright_h||strong_bright_v||strong_bright_near;
    wire correct_dark=(locally_dark&&(dark_h||dark_v||dark_near))||
                      strong_dark_h||strong_dark_v||strong_dark_near;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin O_pixel<=0;O_warm<=0;end
        else begin
            O_warm<=warm3;
            O_pixel<=!warm3?1'b0:
                (ready3&&correct_bright&&!correct_dark)?1'b1:
                (ready3&&correct_dark&&!correct_bright)?1'b0:center3[8];
        end
    end
endmodule
