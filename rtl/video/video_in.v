module video_in #(parameter FRAME_WORDS=172800, parameter WRITE_BURST_WORDS=16) (
    input wire         I_rst_n,

    input wire         I_camera_clk,
    input wire         I_camera_frame_start,
    input wire         I_camera_valid,
    input wire[127:0]  I_camera_data,
    input wire         I_mipi_rx_error,

    input wire         I_ddr_clk,

    input wire         I_display_pause,
    input wire         I_video_out_rd_busy,
    output wire        O_video_in_wr_busy,
    output wire        O_video_in_wr_request,
    output reg[1:0]    O_video_out_rp,

    output wire [3:0]  O_valid_pages,
    output wire [31:0] O_generations,

    input wire [23:0] I_capture_stamp,
    output reg [95:0] O_page_stamps,

    output reg         O_ddr_user_wr_en,
    output reg[24:0]   O_ddr_user_addr,
    output wire[127:0] O_ddr_user_wr_data,
    input wire         I_ddr_user_ready
);

    wire        S_fifo_rst;
    reg         S_camera_frame_start_extend;
    reg[3:0]    S_extend_cnt;
    reg         S_camera_frame_start_extend_1d;
    reg         S_camera_frame_start_extend_2d;
    reg         S_camera_frame_start_extend_3d;
    wire        S_frame_start;
    reg[1:0]    S_video_in_wp;
    wire[8:0]   S_fifo_rd_num;
    wire        S_fifo_rd_en;

    wire[127:0] S_fifo_rd_data;
    reg         S_ddr_wr_valid;
    reg[9:0]    S_ddr_wr_cnt;

    wire [1:0] history_target = I_mipi_rx_error ? S_video_in_wp-2'd1 : S_video_in_wp;
    (* ASYNC_REG="TRUE" *) reg [23:0] capture_stamp_meta,capture_stamp_sync;
    always @(posedge I_ddr_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            capture_stamp_meta<=0;capture_stamp_sync<=0;O_page_stamps<=0;
        end else begin
            capture_stamp_meta<=I_capture_stamp;capture_stamp_sync<=capture_stamp_meta;
            if(S_frame_start&&!I_display_pause)
                O_page_stamps[history_target*24+:24]<=capture_stamp_sync;
        end
    end
    tnr_frame_tracker #(.FRAME_WORDS(FRAME_WORDS)) history_tracker(
        .clk(I_ddr_clk),.rst_n(I_rst_n),.frame_start(S_frame_start),
        .write_en(O_ddr_user_wr_en),.frame_error(I_mipi_rx_error),
        .pause(I_display_pause),.target_page(history_target),
        .valid_pages(O_valid_pages),.generations(O_generations));

    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;

    assign S_fifo_rst = S_camera_frame_start_extend_3d;

    assign O_video_in_wr_busy = S_ddr_wr_valid;
    assign O_video_in_wr_request = S_fifo_rd_num >= WRITE_BURST_WORDS && !S_fifo_rst;

    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst         ),

        .clkw       ( I_camera_clk       ),
        .we         ( I_camera_valid     ),
        .di         ( I_camera_data      ),
        .afull      (),
        .full_flag  (),
        .wrusedw    (),

        .clkr       ( I_ddr_clk          ),
        .re         ( S_fifo_rd_en       ),
        .dout       ( O_ddr_user_wr_data ),
        .rdusedw    ( S_fifo_rd_num      ),
        .valid      (),
        .empty_flag (),
        .aempty     ()
    );

    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_camera_frame_start_extend <= 1'b0;
        else
            if(I_camera_frame_start)
                S_camera_frame_start_extend <= 1'b1;
            else if(S_extend_cnt == 'd7)
                S_camera_frame_start_extend <= 1'b0;
            else
                S_camera_frame_start_extend <= S_camera_frame_start_extend;
    end

    always @ (posedge I_camera_clk) begin
    	if(S_camera_frame_start_extend)
        	S_extend_cnt <= S_extend_cnt + 'd1;
      	else
          	S_extend_cnt <= 'd0;
    end

    always @(posedge I_ddr_clk) begin
        S_camera_frame_start_extend_1d <= S_camera_frame_start_extend;
        S_camera_frame_start_extend_2d <= S_camera_frame_start_extend_1d;
        S_camera_frame_start_extend_3d <= S_camera_frame_start_extend_2d;
    end

    assign S_frame_start = ~S_camera_frame_start_extend_3d & S_camera_frame_start_extend_2d;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_video_in_wp <= 'd0;
        else
            if(I_display_pause)
                S_video_in_wp <= S_video_in_wp;
            else if(S_frame_start)
                begin
                    if(I_mipi_rx_error)
                        S_video_in_wp <= S_video_in_wp;
                    else
                        S_video_in_wp <= S_video_in_wp + 'd1;
                end
            else
                S_video_in_wp <= S_video_in_wp;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_video_out_rp <= 'd0;
        else
            if(I_display_pause)
                O_video_out_rp <= O_video_out_rp;
            else if(S_frame_start)
                begin
                    case(S_video_in_wp)
                        'd0: O_video_out_rp <= 'd2;
                        'd1: O_video_out_rp <= 'd3;
                        'd2: O_video_out_rp <= 'd0;
                        'd3: O_video_out_rp <= 'd1;
                    endcase
                end
            else
                O_video_out_rp <= O_video_out_rp;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_wr_valid <= 1'b0;
        else
            if(S_ddr_wr_valid && I_ddr_user_ready && S_ddr_wr_cnt == (WRITE_BURST_WORDS-1))
                S_ddr_wr_valid <= 1'b0;
            else if(S_fifo_rd_num >= WRITE_BURST_WORDS && (!I_video_out_rd_busy) && (!S_fifo_rst))
                S_ddr_wr_valid <= 1'b1;
            else
                S_ddr_wr_valid <= S_ddr_wr_valid;
    end

    always @(posedge I_ddr_clk) begin
        if(S_ddr_wr_valid)
            begin
                if(I_ddr_user_ready)
                    S_ddr_wr_cnt <= S_ddr_wr_cnt + 'd1;
                else
                    S_ddr_wr_cnt <= S_ddr_wr_cnt;
            end
        else
            S_ddr_wr_cnt <= 'd0;
    end

    assign S_fifo_rd_en = S_ddr_wr_valid & I_ddr_user_ready;

    always @(posedge I_ddr_clk) begin
        O_ddr_user_wr_en <= S_fifo_rd_en;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 1'b0;
        else
            if(S_frame_start && (!I_mipi_rx_error))
                begin
                    case(S_video_in_wp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                    endcase
                end
			else if(S_frame_start && I_mipi_rx_error)
				begin
                	case(S_video_in_wp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                    endcase
                end
            else if(O_ddr_user_wr_en)
                O_ddr_user_addr <= O_ddr_user_addr + 'd8;
            else
                O_ddr_user_addr <= O_ddr_user_addr;
    end

endmodule
