`timescale 1ns / 1ps

module auto_thresh #(

    parameter [11:0] BIN_INIT      = 12'd128,
    parameter [7:0]  BIN_BIAS      = 8'd80,

    parameter [11:0] BIN_MIN       = 12'd24,

    parameter [11:0] BIN_MAX       = 12'd232,
    parameter [3:0]  BIN_SHIFT     = 4'd2,
    parameter [11:0] BIN_DEAD      = 12'd2,

    parameter [11:0] EDGE_INIT     = 12'd100,
    parameter [11:0] EDGE_MIN      = 12'd24,
    parameter [11:0] EDGE_MAX      = 12'd2040,
    parameter [3:0]  EDGE_SHIFT    = 4'd3,
    parameter [11:0] EDGE_DEAD     = 12'd12,
    parameter [3:0]  PERCENT_SHIFT    = 4'd0,

    parameter [3:0]  LO_PERCENT_SHIFT = 4'd0,

    parameter [3:0]  MAG_SHIFT     = 4'd3,
    parameter [11:0] EDGE_LO_INIT  = 12'd50,

    parameter [3:0]  NOISE_SHIFT   = 4'd2,

    parameter [3:0]  NOISE_K_SHIFT = 4'd1,

    parameter [3:0]  WARMUP_FRAMES = 4'd2
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_gray_de,
    input  wire [7:0]  I_gray,
    input  wire        I_mag_de,
    input  wire [11:0] I_mag,
    input  wire        I_vsync,
    input  wire        I_gray_vsync,
    output reg  [11:0] O_bin_thresh,
    output reg  [11:0] O_edge_thresh,
    output reg  [11:0] O_edge_thresh_lo,
    output reg [7:0] O_bin_target, O_bin_low, O_bin_high,
    output reg O_bin_valid, O_bin_seed,
    output reg [15:0] O_bin_updates,
    output reg [19:0] O_bin_pixels, O_bin_white
);

    localparam S_IDLE = 4'd0, S_MRD  = 4'd1, S_MACC = 4'd2,
               S_DIV1 = 4'd3, S_W1   = 4'd4, S_DIV2 = 4'd5,
               S_W2   = 4'd6, S_CALC = 4'd7, S_MCLR = 4'd8, S_WALL=4'd9;

    reg  vs_1d;
    reg  [3:0] warm;
    wire frame_start;
    reg gray_vs_d;
    wire gray_frame_start = I_gray_vsync & ~gray_vs_d;

    reg  [19:0] n_all, n_lo, f_n_all, f_n_lo;
    reg [19:0] n_white, f_n_white;
    reg  [27:0] s_all, s_lo, f_s_all, f_s_lo;
    reg [7:0] min_gray,max_gray,f_min_gray,f_max_gray;
    reg bin_seed;
    reg [3:0] bst;
    reg [7:0] bin_split;
    wire        gray_below;

    reg  [3:0]  smp;
    reg  [19:0] hist_m [0:255];
    reg  [1:0]  mst;
    reg  [7:0]  maddr;
    reg  [7:0]  mbin;
    reg  [19:0] mrd;
    reg  [19:0] n_mag, f_n_mag;
    reg  [19:0] n_nz,  f_n_nz;
    wire [7:0]  mag_bin, mrd_addr, hist_waddr;
    wire        m_sample, hist_we;
    wire [19:0] hist_wdata;

    reg  [3:0]  st;
    reg  [19:0] macc, mtarget, mtarget_lo, mtarget_med;
    reg  [11:0] edge_raw, edge_lo_raw, bin_raw;
    reg  [11:0] med_raw;
    reg         edge_hit, edge_lo_hit, bin_hit, med_hit;
    reg  [7:0]  mclr_bin;
    reg  [27:0] mu_lo;

    reg  dv_start, dv_busy, dv_busy_d;
    reg  [27:0] dv_q, dv_rem, dv_work, dv_b;
    reg  [5:0]  dv_cnt;
    wire [27:0] dv_a_sel, dv_b_sel, dv_shift;
    wire        dv_ge, dv_valid;

    wire [11:0] bin_tgt, edge_tgt, edge_lo_tgt;
    wire [11:0] b_next, e_next, lo_next;

    assign frame_start = I_vsync & ~vs_1d;

    assign gray_below  = (I_gray < bin_split);
    wire [19:0] class_min = ((f_n_all >> 7) == 0) ? 20'd1 : (f_n_all >> 7);
    wire class_degenerate = (f_n_lo < class_min) ||
                            ((f_n_all-f_n_lo) < class_min);
    wire flat_gray = ({1'b0,f_max_gray}-{1'b0,f_min_gray}) < 9'd8;
    wire [8:0] mean_midpoint = {1'b0,mu_lo[7:0]} + {1'b0,dv_q[7:0]};

    assign mag_bin     = I_mag >> MAG_SHIFT;

    assign mrd_addr    = (st != S_IDLE) ? mbin : maddr;

    assign m_sample    = I_mag_de && (smp == 4'd8) && (st == S_IDLE);

    assign hist_we     = (mst == 2'd2) || (st == S_MCLR);
    assign hist_waddr  = (st == S_MCLR) ? mclr_bin : maddr;
    assign hist_wdata  = (st == S_MCLR) ? 20'd0 : (mrd + 20'd1);

    assign dv_a_sel    = (bst==S_WALL) ? f_s_all :
                         (((bst == S_DIV1) || (bst == S_W1)) ? f_s_lo : (f_s_all - f_s_lo));
    assign dv_b_sel    = (bst==S_WALL) ? {8'd0,f_n_all} :
                         ((bst == S_DIV1) || (bst == S_W1)) ? {8'd0, f_n_lo}
                                       : ({8'd0, f_n_all} - {8'd0, f_n_lo});
    assign dv_shift    = {dv_rem[26:0], dv_work[27]};
    assign dv_ge       = (dv_shift >= dv_b);
    assign dv_valid    = dv_busy_d & ~dv_busy;

    wire [12:0] noise_floor_x = {1'b0, med_raw} << NOISE_K_SHIFT;
    wire [11:0] noise_floor   = (!med_hit || (NOISE_K_SHIFT == 4'd0)) ? 12'd0 :
                                ((noise_floor_x > {1'b0, EDGE_MAX}) ? EDGE_MAX
                                                                    : noise_floor_x[11:0]);
    wire [11:0] noise_floor_lo = noise_floor >> 1;

    wire [11:0] edge_lim = (edge_raw < EDGE_MIN) ? EDGE_MIN :
                           ((edge_raw > EDGE_MAX) ? EDGE_MAX : edge_raw);
    wire [11:0] lo_lim   = (edge_lo_raw < EDGE_MIN) ? EDGE_MIN :
                           ((edge_lo_raw > EDGE_MAX) ? EDGE_MAX : edge_lo_raw);

    wire [7:0] bin_span = dv_q[7:0] - mu_lo[7:0];
    wire [15:0] bin_scaled =
        (BIN_BIAS[0] ? {8'd0,bin_span}      : 16'd0) +
        (BIN_BIAS[1] ? {7'd0,bin_span,1'd0} : 16'd0) +
        (BIN_BIAS[2] ? {6'd0,bin_span,2'd0} : 16'd0) +
        (BIN_BIAS[3] ? {5'd0,bin_span,3'd0} : 16'd0) +
        (BIN_BIAS[4] ? {4'd0,bin_span,4'd0} : 16'd0) +
        (BIN_BIAS[5] ? {3'd0,bin_span,5'd0} : 16'd0) +
        (BIN_BIAS[6] ? {2'd0,bin_span,6'd0} : 16'd0) +
        (BIN_BIAS[7] ? {1'd0,bin_span,7'd0} : 16'd0);

    assign bin_tgt  = bin_hit ?
                      ((bin_raw  < BIN_MIN)  ? BIN_MIN  :
                      ((bin_raw  > BIN_MAX)  ? BIN_MAX  : bin_raw))  : O_bin_thresh;
    assign edge_tgt = edge_hit ?
                      ((noise_floor > edge_lim) ? noise_floor : edge_lim) : O_edge_thresh;
    assign edge_lo_tgt = edge_lo_hit ?
                      ((noise_floor_lo > lo_lim) ? noise_floor_lo : lo_lim) : O_edge_thresh_lo;

    assign b_next = (bin_tgt > O_bin_thresh + BIN_DEAD) ?
                    (O_bin_thresh + ((bin_tgt - O_bin_thresh) >> BIN_SHIFT) + 12'd1) :
                    ((O_bin_thresh > bin_tgt + BIN_DEAD) ?
                    (O_bin_thresh - ((O_bin_thresh - bin_tgt) >> BIN_SHIFT) - 12'd1) :
                     O_bin_thresh);
    assign e_next = (edge_tgt > O_edge_thresh + EDGE_DEAD) ?
                    (O_edge_thresh + ((edge_tgt - O_edge_thresh) >> EDGE_SHIFT) + 12'd1) :
                    ((O_edge_thresh > edge_tgt + EDGE_DEAD) ?
                    (O_edge_thresh - ((O_edge_thresh - edge_tgt) >> EDGE_SHIFT) - 12'd1) :
                     O_edge_thresh);
    assign lo_next = (edge_lo_tgt > O_edge_thresh_lo + EDGE_DEAD) ?
                     (O_edge_thresh_lo + ((edge_lo_tgt - O_edge_thresh_lo) >> EDGE_SHIFT) + 12'd1) :
                     ((O_edge_thresh_lo > edge_lo_tgt + EDGE_DEAD) ?
                     (O_edge_thresh_lo - ((O_edge_thresh_lo - edge_lo_tgt) >> EDGE_SHIFT) - 12'd1) :
                      O_edge_thresh_lo);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) vs_1d <= 1'b0;
        else          vs_1d <= I_vsync;
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) gray_vs_d<=0;
        else gray_vs_d<=I_gray_vsync;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) warm <= 4'd0;
        else if (frame_start && (warm != 4'hF)) warm <= warm + 4'd1;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            n_all <= 20'd0; s_all <= 28'd0; n_lo <= 20'd0; s_lo <= 28'd0;
            n_white<=0;
            min_gray<=255;max_gray<=0;
        end else if (gray_frame_start) begin
            n_all <= 20'd0; s_all <= 28'd0; n_lo <= 20'd0; s_lo <= 28'd0;
            n_white<=0;
            min_gray<=255;max_gray<=0;
        end else if (I_gray_de && !I_gray_vsync) begin
            n_all <= n_all + 20'd1;
            s_all <= s_all + {20'd0, I_gray};
            if(I_gray>=O_bin_thresh[7:0]) n_white<=n_white+20'd1;
            if(I_gray<min_gray)min_gray<=I_gray;
            if(I_gray>max_gray)max_gray<=I_gray;
            if (gray_below) begin
                n_lo <= n_lo + 20'd1;
                s_lo <= s_lo + {20'd0, I_gray};
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            f_n_all <= 20'd0; f_n_lo <= 20'd0; f_s_all <= 28'd0; f_s_lo <= 28'd0;
            f_n_white<=0;
            f_min_gray<=255;f_max_gray<=0;
        end else if (gray_frame_start) begin
            f_n_all <= n_all; f_s_all <= s_all; f_n_lo <= n_lo; f_s_lo <= s_lo;
            f_n_white<=n_white;
            f_min_gray<=min_gray;f_max_gray<=max_gray;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) smp <= 4'd0;
        else if (I_mag_de) smp <= smp + 4'd1;
    end

    always @(posedge I_clk) begin
        mrd <= hist_m[mrd_addr];
        if (hist_we) hist_m[hist_waddr] <= hist_wdata;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            mst <= 2'd0; maddr <= 8'd0; n_mag <= 20'd0; f_n_mag <= 20'd0;
            n_nz <= 20'd0; f_n_nz <= 20'd0;
        end else if (frame_start) begin
            mst <= 2'd0; n_mag <= 20'd0; f_n_mag <= n_mag;
            n_nz <= 20'd0; f_n_nz <= n_nz;
        end else if (st != S_IDLE) begin
            mst <= 2'd0;
        end else if (mst == 2'd0) begin
            if (m_sample) begin
                maddr <= mag_bin; mst <= 2'd1; n_mag <= n_mag + 20'd1;
                if (mag_bin != 8'd0) n_nz <= n_nz + 20'd1;
            end
        end else if (mst == 2'd1) begin
            mst <= 2'd2;
        end else begin
            mst <= 2'd0;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            dv_busy <= 1'b0; dv_busy_d <= 1'b0;
            dv_q <= 28'd0; dv_rem <= 28'd0; dv_work <= 28'd0; dv_b <= 28'd1;
            dv_cnt <= 6'd0;
        end else begin
            dv_busy_d <= dv_busy;
            if (dv_start) begin
                dv_work <= dv_a_sel;
                dv_b    <= (dv_b_sel == 28'd0) ? 28'd1 : dv_b_sel;
                dv_rem  <= 28'd0;
                dv_q    <= 28'd0;
                dv_cnt  <= 6'd28;
                dv_busy <= 1'b1;
            end else if (dv_busy) begin
                dv_rem  <= dv_ge ? (dv_shift - dv_b) : dv_shift;
                dv_q    <= {dv_q[26:0], dv_ge};
                dv_work <= {dv_work[26:0], 1'b0};
                dv_cnt  <= dv_cnt - 6'd1;
                if (dv_cnt == 6'd1) dv_busy <= 1'b0;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin
            bst<=S_IDLE;bin_split<=BIN_INIT[7:0];
            bin_raw<=BIN_INIT;bin_hit<=0;bin_seed<=0;mu_lo<=0;dv_start<=0;
            O_bin_thresh<=BIN_INIT;O_bin_target<=BIN_INIT[7:0];
            O_bin_low<=0;O_bin_high<=0;O_bin_valid<=0;O_bin_seed<=0;
            O_bin_updates<=0;O_bin_pixels<=0;O_bin_white<=0;
        end else begin
            dv_start<=0;
            case(bst)
            S_IDLE: if(gray_frame_start && warm>=WARMUP_FRAMES)begin
                bin_hit<=0;bin_seed<=0;bst<=S_DIV1;
            end
            S_DIV1: begin
                if(f_n_all==0)bst<=S_CALC;
                else if(flat_gray)begin

                    bin_raw<=BIN_INIT;bin_split<=BIN_INIT[7:0];
                    bin_hit<=1;bin_seed<=1;bst<=S_CALC;
                end else if(class_degenerate)begin

                    if(!dv_busy)begin dv_start<=1;bst<=S_WALL;end
                end else if(!dv_busy)begin dv_start<=1;bst<=S_W1;end
            end
            S_W1: if(dv_valid)begin mu_lo<=dv_q;bst<=S_DIV2;end
            S_DIV2: if(!dv_busy)begin dv_start<=1;bst<=S_W2;end
            S_W2: if(dv_valid)begin
                bin_split<=mean_midpoint[8:1];
                bin_raw<={4'd0,mu_lo[11:0]}+{8'd0,bin_scaled[15:8]};
                bin_hit<=1;bst<=S_CALC;
            end
            S_WALL: if(dv_valid)begin

                bin_split<=dv_q[7:0];bin_raw<=BIN_INIT;
                bin_hit<=1;bin_seed<=1;bst<=S_CALC;
            end
            S_CALC: begin
                O_bin_thresh<=b_next;
                O_bin_target<=bin_hit?bin_tgt[7:0]:O_bin_thresh[7:0];
                O_bin_valid<=bin_hit&&!bin_seed;O_bin_seed<=bin_hit&&bin_seed;
                O_bin_pixels<=f_n_all;O_bin_white<=f_n_white;
                O_bin_low<=(bin_hit&&!bin_seed)?mu_lo[7:0]:8'd0;
                O_bin_high<=(bin_hit&&!bin_seed)?dv_q[7:0]:8'd0;
                if(bin_hit)O_bin_updates<=O_bin_updates+16'd1;
                bst<=S_IDLE;
            end
            default:bst<=S_IDLE;
            endcase
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            st       <= S_IDLE;
            mbin     <= 8'd255;
            macc     <= 20'd0;
            mtarget  <= 20'd1;
            edge_raw    <= EDGE_INIT;
            edge_hit    <= 1'b0;
            edge_lo_raw <= EDGE_LO_INIT;
            edge_lo_hit <= 1'b0;
            mclr_bin <= 8'd0;
            O_edge_thresh    <= EDGE_INIT;
            O_edge_thresh_lo <= EDGE_LO_INIT;
            med_raw          <= 12'd0;
            med_hit          <= 1'b0;
            mtarget_med      <= 20'd1;
        end else begin
            case (st)

            S_IDLE: begin
                if (frame_start && (warm >= WARMUP_FRAMES)) begin
                    mbin     <= 8'd255;
                    macc     <= 20'd0;

                    mtarget  <= ((f_n_nz >> PERCENT_SHIFT) == 20'd0) ? 20'd1
                                                                     : (f_n_nz >> PERCENT_SHIFT);
                    mtarget_lo  <= ((f_n_nz >> LO_PERCENT_SHIFT) == 20'd0) ? 20'd1
                                                                           : (f_n_nz >> LO_PERCENT_SHIFT);

                    mtarget_med <= ((f_n_nz >> NOISE_SHIFT) == 20'd0) ? 20'd1
                                                                      : (f_n_nz >> NOISE_SHIFT);
                    edge_hit    <= 1'b0;
                    edge_lo_hit <= 1'b0;
                    med_hit     <= 1'b0;
                    st          <= S_MRD;
                end
            end

            S_MRD:  st <= (mbin == 8'd0) ? S_CALC : S_MACC;

            S_MACC: begin

                if (!med_hit && ((macc + mrd) >= mtarget_med)) begin
                    med_raw <= {4'd0, mbin} << MAG_SHIFT;
                    med_hit <= 1'b1;
                end
                if (!edge_hit && ((macc + mrd) >= mtarget)) begin
                    edge_raw    <= {4'd0, mbin} << MAG_SHIFT;
                    edge_hit    <= 1'b1;
                end
                if (!edge_lo_hit && ((macc + mrd) >= mtarget_lo)) begin
                    edge_lo_raw <= {4'd0, mbin} << MAG_SHIFT;
                    edge_lo_hit <= 1'b1;
                end
                if ((edge_hit && edge_lo_hit) || (mbin <= 8'd1)) begin
                    st <= S_CALC;
                end else begin
                    macc <= macc + mrd;
                    mbin <= mbin - 8'd1;
                    st   <= S_MRD;
                end
            end

            S_CALC: begin
                O_edge_thresh    <= e_next;
                O_edge_thresh_lo <= lo_next;
                mclr_bin         <= 8'd0;
                st               <= S_MCLR;
            end

            S_MCLR: begin
                if (mclr_bin == 8'd255) st <= S_IDLE;
                else                    mclr_bin <= mclr_bin + 8'd1;
            end

            default: st <= S_IDLE;
            endcase
        end
    end

endmodule
