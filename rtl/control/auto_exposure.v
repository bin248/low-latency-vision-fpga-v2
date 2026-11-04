`timescale 1ns / 1ps

module auto_exposure #(
    parameter IMG_WIDTH    = 1280,
    parameter IMG_HEIGHT   = 720,
    parameter [11:0] TARGET_LUMA = 12'd130,
    parameter [15:0] AE_INIT     = 16'd1400,
    parameter [15:0] AE_MIN      = 16'd16,
    parameter [15:0] AE_MAX      = 16'd3980,
    parameter [7:0]  AG_INIT     = 8'd24,
    parameter [7:0]  AG_MIN      = 8'd16,
    parameter [7:0]  AG_MAX      = 8'd112,
    parameter [3:0]  FRAME_DIV   = 4'd3,

    parameter [7:0] HIGH_HOLD_LUMA = 8'd200,
    parameter [7:0] HIGH_TRIP_LUMA = 8'd224,
    parameter [7:0] HIGH_SEVERE_LUMA = 8'd240
)(
    input  wire        I_clk,
    input  wire        I_rst_n,

    input  wire        I_de,
    input  wire        I_vsync,
    input  wire [23:0] I_rgb,

    input  wire        I_cam_cfg_done,
    input  wire        I_ae_cfg_done,

    output reg         O_ae_req,
    output reg  [15:0] O_ae,
    output reg  [7:0]  O_ag,

    output reg  [7:0]  O_mean_luma,
    output reg        O_luma_valid,
    output reg [19:0] O_frame_pixels,
    output wire [7:0] O_target_luma,
    output wire       O_cam_ready,
    output wire       O_write_busy,
    output reg [15:0] O_write_count
);

    wire [15:0] luma_sum = I_rgb[23:16] * 8'd77
                         + I_rgb[15:8]  * 8'd150
                         + I_rgb[7:0]   * 8'd29;
    wire [7:0] luma = luma_sum[15:8];

    reg [11:0] meter_x, meter_y;
    reg de_prev;
    wire in_center = (meter_x >= IMG_WIDTH/4) &&
                     (meter_x < IMG_WIDTH-IMG_WIDTH/4) &&
                     (meter_y >= IMG_HEIGHT/4) &&
                     (meter_y < IMG_HEIGHT-IMG_HEIGHT/4);
    reg [7:0] sample_luma;
    reg sample_center, sample_de, sample_vsync;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            meter_x <= 12'd0;
            meter_y <= 12'd0;
            de_prev <= 1'b0;
            sample_luma <= 8'd0;
            sample_center <= 1'b0;
            sample_de <= 1'b0;
            sample_vsync <= 1'b0;
        end else begin
            sample_luma <= luma;
            sample_center <= in_center;
            sample_de <= I_de;
            sample_vsync <= I_vsync;
            de_prev <= I_de;
            if (I_vsync) begin
                meter_x <= 12'd0;
                meter_y <= 12'd0;
            end else if (I_de) begin
                meter_x <= (meter_x == IMG_WIDTH-1) ? 12'd0
                                                     : meter_x + 12'd1;
            end else begin
                meter_x <= 12'd0;
                if (de_prev)
                    meter_y <= meter_y + 12'd1;
            end
        end
    end

    reg [31:0] acc;
    reg [19:0] pixel_count;
    reg [31:0] meter_acc;
    reg [21:0] meter_pixels;
    reg [21:0] highlight_near, highlight_high, highlight_severe;
    wire [21:0] sample_weight = sample_center ? 22'd4 : 22'd1;
    wire [31:0] weighted_luma = sample_center ? {22'd0, sample_luma, 2'b00}
                                              : {24'd0, sample_luma};
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            acc         <= 32'd0;
            pixel_count <= 20'd0;
            meter_acc <= 32'd0;
            meter_pixels <= 22'd0;
            highlight_near <= 22'd0;
            highlight_high <= 22'd0;
            highlight_severe <= 22'd0;
        end else if (sample_vsync) begin
            acc         <= 32'd0;
            pixel_count <= 20'd0;
            meter_acc <= 32'd0;
            meter_pixels <= 22'd0;
            highlight_near <= 22'd0;
            highlight_high <= 22'd0;
            highlight_severe <= 22'd0;
        end else if (sample_de) begin
            acc         <= acc + {24'd0, sample_luma};
            pixel_count <= pixel_count + 20'd1;
            meter_acc <= meter_acc + weighted_luma;
            meter_pixels <= meter_pixels + sample_weight;
            if (sample_luma >= HIGH_HOLD_LUMA)
                highlight_near <= highlight_near + sample_weight;
            if (sample_luma >= HIGH_TRIP_LUMA)
                highlight_high <= highlight_high + sample_weight;
            if (sample_luma >= HIGH_SEVERE_LUMA)
                highlight_severe <= highlight_severe + sample_weight;
        end
    end

    reg vs_1d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            vs_1d <= 1'b0;
        else
            vs_1d <= sample_vsync;
    end
    wire frame_end = sample_vsync & ~vs_1d;

    reg [31:0] dbg_rem;
    reg [31:0] dbg_den;
    reg [7:0] dbg_quot;
    reg [2:0] dbg_bit;
    reg dbg_div_busy;
    wire [31:0] dbg_trial = dbg_den << dbg_bit;
    wire dbg_take = (dbg_rem >= dbg_trial);
    wire [7:0] dbg_quot_next = dbg_take
                             ? (dbg_quot | (8'd1 << dbg_bit)) : dbg_quot;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_mean_luma    <= 8'd0;
            O_luma_valid   <= 1'b0;
            O_frame_pixels <= 20'd0;
            dbg_rem        <= 32'd0;
            dbg_den        <= 32'd0;
            dbg_quot       <= 8'd0;
            dbg_bit        <= 3'd7;
            dbg_div_busy   <= 1'b0;
        end else if (frame_end) begin
            O_frame_pixels <= pixel_count;
            O_luma_valid   <= 1'b0;
            dbg_div_busy   <= (pixel_count >= 20'd1024);
            dbg_rem        <= acc;
            dbg_den        <= {12'd0, pixel_count};
            dbg_quot       <= 8'd0;
            dbg_bit        <= 3'd7;
        end else if (dbg_div_busy) begin
            dbg_quot <= dbg_quot_next;
            if (dbg_take)
                dbg_rem <= dbg_rem - dbg_trial;
            if (dbg_bit == 3'd0) begin
                O_mean_luma  <= dbg_quot_next;
                O_luma_valid <= 1'b1;
                dbg_div_busy <= 1'b0;
            end else begin
                dbg_bit <= dbg_bit - 3'd1;
            end
        end
    end

    wire [31:0] target_sum = TARGET_LUMA * meter_pixels;

    wire hold_highlight = highlight_near > (meter_pixels >> 5);
    wire reduce_highlight = highlight_high > (meter_pixels >> 5);
    wire severe_highlight = highlight_severe > (meter_pixels >> 5);
    wire [31:0] sum_hi2 = target_sum + (target_sum >> 2);
    wire [31:0] sum_hi1 = target_sum + (target_sum >> 5);
    wire [31:0] sum_lo1 = target_sum - (target_sum >> 5);
    wire [31:0] sum_lo2 = target_sum - (target_sum >> 2);

    localparam [7:0] UPDATE_LAST = (8'd1 << FRAME_DIV) - 8'd1;
    reg [7:0]  fdiv;
    reg [15:0] ae_cur;
    reg [7:0]  ag_cur;

    wire [15:0] ae_up4 = ae_cur + (ae_cur >> 2);
    wire [15:0] ae_dn4 = ae_cur - (ae_cur >> 2);
    wire [15:0] ae_up6 = ae_cur + (ae_cur >> 4);
    wire [15:0] ae_dn6 = ae_cur - (ae_cur >> 4);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            fdiv   <= 8'd0;
            ae_cur <= AE_INIT;
            ag_cur <= AG_INIT;
        end else if (frame_end) begin
            if (fdiv != UPDATE_LAST) begin
                fdiv <= fdiv + 8'd1;
            end else begin
                fdiv <= 8'd0;

                if (pixel_count >= 20'd1024) begin
                    if (severe_highlight || meter_acc > sum_hi2) begin
                        if (ag_cur > AG_MIN)
                            ag_cur <= (ag_cur < AG_MIN + 8'd4) ? AG_MIN
                                                              : ag_cur - 8'd4;
                        else if (ae_cur > AE_MIN)
                            ae_cur <= (ae_dn4 < AE_MIN) ? AE_MIN : ae_dn4;
                    end else if (reduce_highlight || meter_acc > sum_hi1) begin
                        if (ag_cur > AG_MIN)
                            ag_cur <= ag_cur - 8'd1;
                        else if (ae_cur > AE_MIN)
                            ae_cur <= (ae_dn6 < AE_MIN) ? AE_MIN : ae_dn6;
                    end else if (!hold_highlight && meter_acc < sum_lo2) begin
                        if (ae_cur < AE_MAX)
                            ae_cur <= (ae_up4 > AE_MAX) ? AE_MAX : ae_up4;
                        else if (ag_cur < AG_MAX)
                            ag_cur <= (ag_cur + 8'd4 > AG_MAX) ? AG_MAX
                                                              : ag_cur + 8'd4;
                    end else if (!hold_highlight && meter_acc < sum_lo1) begin
                        if (ae_cur < AE_MAX)
                            ae_cur <= (ae_up6 > AE_MAX) ? AE_MAX : ae_up6;
                        else if (ag_cur < AG_MAX)
                            ag_cur <= (ag_cur + 8'd1 > AG_MAX) ? AG_MAX
                                                              : ag_cur + 8'd1;
                    end

                end
            end
        end
    end

    (* ASYNC_REG = "TRUE" *) reg [1:0] cam_done_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ae_done_sync;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            cam_done_sync <= 2'b00;
            ae_done_sync  <= 2'b00;
        end else begin
            cam_done_sync <= {cam_done_sync[0], I_cam_cfg_done};
            ae_done_sync  <= {ae_done_sync[0],  I_ae_cfg_done};
        end
    end
    wire cam_cfg_done = cam_done_sync[1];
    wire ae_cfg_done  = ae_done_sync[1];
    assign O_target_luma = TARGET_LUMA[7:0];
    assign O_cam_ready  = cam_cfg_done;
    assign O_write_busy = cam_cfg_done && (O_ae_req || !ae_cfg_done);

    reg dbg_write_pending, dbg_ae_done_1d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_write_count     <= 16'd0;
            dbg_write_pending <= 1'b0;
            dbg_ae_done_1d    <= 1'b0;
        end else begin
            dbg_ae_done_1d <= ae_cfg_done;
            if (O_ae_req)
                dbg_write_pending <= 1'b1;
            else if (dbg_write_pending && ae_cfg_done && !dbg_ae_done_1d) begin
                dbg_write_pending <= 1'b0;
                if (O_write_count != 16'hffff)
                    O_write_count <= O_write_count + 16'd1;
            end
        end
    end

    reg [15:0] r_ae;
    reg [7:0]  r_ag;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_ae_req <= 1'b0;
            O_ae     <= AE_INIT;
            O_ag     <= AG_INIT;
            r_ae     <= 16'd0;
            r_ag     <= 8'd0;
        end else if (!ae_cfg_done) begin
            O_ae_req <= 1'b0;
        end else if (!O_ae_req && cam_cfg_done &&
                     ((ae_cur != r_ae) || (ag_cur != r_ag))) begin
            r_ae     <= ae_cur;
            r_ag     <= ag_cur;
            O_ae     <= ae_cur;
            O_ag     <= ag_cur;
            O_ae_req <= 1'b1;
        end
    end

endmodule
