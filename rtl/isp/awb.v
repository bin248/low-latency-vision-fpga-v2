module awb #(
    parameter IMG_HEIGHT = 1080,
    parameter IMG_WIDTH  = 1920
)(
    input                   I_clk,
    input                   I_rst_n,

    input                   I_tlast,
    input                   I_tuser,
    input      [95:0]       I_tdata,
    input                   I_tvalid,
    output                  I_tready,

    output                  O_tlast,
    output                  O_tuser,
    output     [95:0]       O_tdata,
    output                  O_tvalid,
    input                   O_tready
);

    localparam [19:0] GAIN_ONE = 20'h10000;
    localparam [19:0] GAIN_MIN = 20'h08000;
    localparam [19:0] GAIN_MAX = 20'h40000;
    localparam [19:0] GAIN_DEADBAND = 20'h00400;
    localparam FRAME_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam FRAME_BEATS = FRAME_PIXELS / 4;
    localparam BEAT_COUNT_W = $clog2(FRAME_BEATS + 2);
    localparam SAMPLE_COUNT_W = $clog2(FRAME_PIXELS + 1);
    localparam MIN_SAMPLES = (FRAME_PIXELS / 64 > 1024) ? FRAME_PIXELS / 64 : 1024;

    localparam [7:0] STATS_MAX_EXCLUSIVE = 8'd234;

    wire [7:0] in_r0 = I_tdata[23:16];
    wire [7:0] in_g0 = I_tdata[15: 8];
    wire [7:0] in_b0 = I_tdata[ 7: 0];
    wire [7:0] in_r1 = I_tdata[47:40];
    wire [7:0] in_g1 = I_tdata[39:32];
    wire [7:0] in_b1 = I_tdata[31:24];
    wire [7:0] in_r2 = I_tdata[71:64];
    wire [7:0] in_g2 = I_tdata[63:56];
    wire [7:0] in_b2 = I_tdata[55:48];
    wire [7:0] in_r3 = I_tdata[95:88];
    wire [7:0] in_g3 = I_tdata[87:80];
    wire [7:0] in_b3 = I_tdata[79:72];

    wire [9:0] rgb_sum0 = {2'b0, in_r0} + {2'b0, in_g0} + {2'b0, in_b0};
    wire [9:0] rgb_sum1 = {2'b0, in_r1} + {2'b0, in_g1} + {2'b0, in_b1};
    wire [9:0] rgb_sum2 = {2'b0, in_r2} + {2'b0, in_g2} + {2'b0, in_b2};
    wire [9:0] rgb_sum3 = {2'b0, in_r3} + {2'b0, in_g3} + {2'b0, in_b3};

    function [7:0] channel_max;
        input [7:0] r, g, b;
        begin channel_max = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b); end
    endfunction
    wire use_p0 = (rgb_sum0 > 10'd60) && (channel_max(in_r0,in_g0,in_b0) < STATS_MAX_EXCLUSIVE);
    wire use_p1 = (rgb_sum1 > 10'd60) && (channel_max(in_r1,in_g1,in_b1) < STATS_MAX_EXCLUSIVE);
    wire use_p2 = (rgb_sum2 > 10'd60) && (channel_max(in_r2,in_g2,in_b2) < STATS_MAX_EXCLUSIVE);
    wire use_p3 = (rgb_sum3 > 10'd60) && (channel_max(in_r3,in_g3,in_b3) < STATS_MAX_EXCLUSIVE);

    wire [11:0] beat_sum_r = (use_p0 ? {4'b0, in_r0} : 12'd0) +
                             (use_p1 ? {4'b0, in_r1} : 12'd0) +
                             (use_p2 ? {4'b0, in_r2} : 12'd0) +
                             (use_p3 ? {4'b0, in_r3} : 12'd0);
    wire [11:0] beat_sum_g = (use_p0 ? {4'b0, in_g0} : 12'd0) +
                             (use_p1 ? {4'b0, in_g1} : 12'd0) +
                             (use_p2 ? {4'b0, in_g2} : 12'd0) +
                             (use_p3 ? {4'b0, in_g3} : 12'd0);
    wire [11:0] beat_sum_b = (use_p0 ? {4'b0, in_b0} : 12'd0) +
                             (use_p1 ? {4'b0, in_b1} : 12'd0) +
                             (use_p2 ? {4'b0, in_b2} : 12'd0) +
                             (use_p3 ? {4'b0, in_b3} : 12'd0);
    wire [2:0] beat_count = {2'b0, use_p0} + {2'b0, use_p1} +
                            {2'b0, use_p2} + {2'b0, use_p3};

    reg [31:0] frame_sum_r;
    reg [31:0] frame_sum_g;
    reg [31:0] frame_sum_b;
    reg [SAMPLE_COUNT_W-1:0] frame_sample_count;
    reg [BEAT_COUNT_W-1:0] frame_beats;
    reg frame_started;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            frame_sum_r        <= 32'd1;
            frame_sum_g        <= 32'd1;
            frame_sum_b        <= 32'd1;
            frame_sample_count <= 20'd0;
            frame_beats        <= 0;
            frame_started      <= 1'b0;
        end else if (I_tuser) begin

            frame_sum_r        <= 32'd1 + (I_tvalid ? beat_sum_r : 12'd0);
            frame_sum_g        <= 32'd1 + (I_tvalid ? beat_sum_g : 12'd0);
            frame_sum_b        <= 32'd1 + (I_tvalid ? beat_sum_b : 12'd0);
            frame_sample_count <= I_tvalid ? beat_count : 3'd0;
            frame_beats        <= I_tvalid ? 1 : 0;
            frame_started      <= 1'b1;
        end else if (I_tvalid && frame_started) begin

            if (frame_beats < FRAME_BEATS+1)
                frame_beats <= frame_beats + 1'b1;
            if (frame_beats < FRAME_BEATS) begin
                frame_sum_r        <= frame_sum_r + beat_sum_r;
                frame_sum_g        <= frame_sum_g + beat_sum_g;
                frame_sum_b        <= frame_sum_b + beat_sum_b;
                frame_sample_count <= frame_sample_count + beat_count;
            end
        end
    end

    wire stats_valid = frame_started && (frame_beats == FRAME_BEATS) &&
                       (frame_sample_count >= MIN_SAMPLES);
    wire div_start   = I_tuser && stats_valid;
    wire [47:0] quotient_r;
    wire [47:0] quotient_b;
    wire div_done_r;
    wire div_done_b;

    wire [19:0] compact_r_gain, compact_b_gain;
    wire gain_pair_done;
    awb_gain_pair u_gain_pair (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_start(div_start),
        .I_green(frame_sum_g), .I_red(frame_sum_r), .I_blue(frame_sum_b),
        .O_red(compact_r_gain), .O_blue(compact_b_gain), .O_done(gain_pair_done)
    );
    assign quotient_r = {28'd0, compact_r_gain};
    assign quotient_b = {28'd0, compact_b_gain};
    assign div_done_r = gain_pair_done;
    assign div_done_b = gain_pair_done;

    function [19:0] clamp_gain;
        input [47:0] quotient;
        begin
            if (|quotient[47:20])
                clamp_gain = GAIN_MAX;
            else if (quotient[19:0] > GAIN_MAX)
                clamp_gain = GAIN_MAX;
            else if (quotient[19:0] < GAIN_MIN)
                clamp_gain = GAIN_MIN;
            else
                clamp_gain = quotient[19:0];
        end
    endfunction

    function [19:0] smooth_gain;
        input [19:0] current_gain;
        input [19:0] target_gain;
        reg   [19:0] difference;
        begin
            if (target_gain >= current_gain) begin
                difference = target_gain - current_gain;
                smooth_gain = (difference <= GAIN_DEADBAND) ? current_gain :
                              current_gain + (difference >> 2);
            end else begin
                difference = current_gain - target_gain;
                smooth_gain = (difference <= GAIN_DEADBAND) ? current_gain :
                              current_gain - (difference >> 2);
            end
        end
    endfunction

    wire [19:0] target_r_gain = clamp_gain(quotient_r);
    wire [19:0] target_b_gain = clamp_gain(quotient_b);

    reg [19:0] active_r_gain;
    reg [19:0] active_b_gain;
    reg [19:0] pending_r_gain;
    reg [19:0] pending_b_gain;

    wire [19:0] pixel_r_gain = I_tuser ? pending_r_gain : active_r_gain;
    wire [19:0] pixel_b_gain = I_tuser ? pending_b_gain : active_b_gain;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            active_r_gain  <= GAIN_ONE;
            active_b_gain  <= GAIN_ONE;
            pending_r_gain <= GAIN_ONE;
            pending_b_gain <= GAIN_ONE;
        end else begin

            if (I_tuser) begin
                active_r_gain <= pending_r_gain;
                active_b_gain <= pending_b_gain;
            end

            if (div_done_r && div_done_b) begin
                pending_r_gain <= smooth_gain(active_r_gain, target_r_gain);
                pending_b_gain <= smooth_gain(active_b_gain, target_b_gain);
            end
        end
    end

    reg [27:0] r_mul_d1 [0:3];
    reg [27:0] b_mul_d1 [0:3];
    reg  [7:0] g_d1     [0:3];
    reg        valid_d1;

    function [7:0] gain_and_clip;
        input [27:0] product;
        begin
            gain_and_clip = (|product[27:24]) ? 8'd255 : product[23:16];
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            r_mul_d1[0] <= 28'd0;
            r_mul_d1[1] <= 28'd0;
            r_mul_d1[2] <= 28'd0;
            r_mul_d1[3] <= 28'd0;
            b_mul_d1[0] <= 28'd0;
            b_mul_d1[1] <= 28'd0;
            b_mul_d1[2] <= 28'd0;
            b_mul_d1[3] <= 28'd0;
            g_d1[0]     <= 8'd0;
            g_d1[1]     <= 8'd0;
            g_d1[2]     <= 8'd0;
            g_d1[3]     <= 8'd0;
            valid_d1    <= 1'b0;
        end else begin
            valid_d1 <= I_tvalid;
            if (I_tvalid) begin
                r_mul_d1[0] <= in_r0 * pixel_r_gain;
                r_mul_d1[1] <= in_r1 * pixel_r_gain;
                r_mul_d1[2] <= in_r2 * pixel_r_gain;
                r_mul_d1[3] <= in_r3 * pixel_r_gain;
                b_mul_d1[0] <= in_b0 * pixel_b_gain;
                b_mul_d1[1] <= in_b1 * pixel_b_gain;
                b_mul_d1[2] <= in_b2 * pixel_b_gain;
                b_mul_d1[3] <= in_b3 * pixel_b_gain;
                g_d1[0]     <= in_g0;
                g_d1[1]     <= in_g1;
                g_d1[2]     <= in_g2;
                g_d1[3]     <= in_g3;
            end
        end
    end

    wire [95:0] corrected_data = {
        gain_and_clip(r_mul_d1[3]), g_d1[3], gain_and_clip(b_mul_d1[3]),
        gain_and_clip(r_mul_d1[2]), g_d1[2], gain_and_clip(b_mul_d1[2]),
        gain_and_clip(r_mul_d1[1]), g_d1[1], gain_and_clip(b_mul_d1[1]),
        gain_and_clip(r_mul_d1[0]), g_d1[0], gain_and_clip(b_mul_d1[0])
    };

    wire        delayed_valid;
    wire [95:0] delayed_data;
    wire        delayed_user_unused;

    signal_delay #(
        .IMG_HEIGHT  (IMG_HEIGHT),
        .IMG_WIDTH   (IMG_WIDTH),
        .DATA_WIDTH  (96),
        .DELAY_CYCLE (50)
    ) u_output_delay (
        .I_clk   (I_clk),
        .I_rst_n (I_rst_n),
        .I_tuser (I_tuser),
        .I_valid (valid_d1),
        .I_data  (corrected_data),
        .O_valid (delayed_valid),
        .O_data  (delayed_data),
        .O_tuser (delayed_user_unused)
    );

    reg        delayed_valid_d1;
    reg [95:0] delayed_data_d1;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            delayed_valid_d1 <= 1'b0;
            delayed_data_d1  <= 96'd0;
        end else begin
            delayed_valid_d1 <= delayed_valid;
            delayed_data_d1  <= delayed_data;
        end
    end

    assign O_tuser  = I_tuser;
    assign O_tvalid = delayed_valid_d1;
    assign O_tlast  = delayed_valid_d1 && !delayed_valid;
    assign O_tdata  = delayed_valid_d1 ? delayed_data_d1 : 96'd0;

    assign I_tready = O_tready;

endmodule

module awb_gain_pair (
    input wire I_clk, I_rst_n, I_start,
    input wire [31:0] I_green, I_red, I_blue,
    output reg [19:0] O_red, O_blue,
    output reg O_done
);
    localparam LOAD=2'd0, DIVIDE=2'd1, WAIT_DONE=2'd2;
    reg [1:0] state;
    reg busy, channel;
    reg [5:0] age;
    reg [4:0] bit_index;
    reg [31:0] green_hold, red_hold, blue_hold, denominator;
    reg [32:0] remainder;
    reg [17:0] quotient;
    wire [31:0] selected_den = channel ? blue_hold : red_hold;
    wire saturate = {2'b00,green_hold} >= {selected_den,2'b00};
    wire [32:0] trial = (bit_index >= 16) ? remainder : {remainder[31:0],1'b0};
    wire [32:0] divisor = (bit_index == 17) ? {denominator,1'b0} : {1'b0,denominator};
    wire [33:0] difference = {1'b0,trial} - {1'b0,divisor};
    wire take_bit = !difference[33];
    wire [17:0] quotient_next = {quotient[16:0],take_bit};
    wire [19:0] completed_gain = (quotient_next < 18'h08000) ?
                                20'h08000 : {2'b00,quotient_next};

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            state<=LOAD; busy<=0; channel<=0; age<=0; bit_index<=0;
            green_hold<=0; red_hold<=0; blue_hold<=0; denominator<=0;
            remainder<=0; quotient<=0; O_red<=20'h10000;
            O_blue<=20'h10000; O_done<=0;
        end else begin
            O_done<=0;
            if (I_start) begin
                green_hold<=I_green; red_hold<=I_red; blue_hold<=I_blue;
                state<=LOAD; busy<=1; channel<=0; age<=0;
            end else if (busy) begin
                age<=age+1'b1;
                case(state)
                LOAD: begin
                    if (saturate) begin
                        if (!channel) begin O_red<=20'h40000; channel<=1; end
                        else begin O_blue<=20'h40000; state<=WAIT_DONE; end
                    end else begin
                        denominator<=selected_den; remainder<={1'b0,green_hold};
                        quotient<=0; bit_index<=17; state<=DIVIDE;
                    end
                end
                DIVIDE: begin
                    remainder<=take_bit ? difference[32:0] : trial;
                    quotient<=quotient_next;
                    if (bit_index==0) begin
                        if (!channel) begin
                            O_red<=completed_gain; channel<=1; state<=LOAD;
                        end else begin O_blue<=completed_gain; state<=WAIT_DONE; end
                    end else bit_index<=bit_index-1'b1;
                end
                default: if (age==48) begin O_done<=1; busy<=0; state<=LOAD; end
                endcase
            end
        end
    end
endmodule
