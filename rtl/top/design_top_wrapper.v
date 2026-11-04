module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,

    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,

    inout wire [1:0]  I_button,
    input wire        I_key1,
    input wire        I_key2,

    output wire       O_led_red,
    output wire       O_led_green,
    output wire       O_led_blue,
    output wire       O_buzzer_n,
    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n,
    inout wire        IO_rx_clk_pad_p,
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n
);

    wire        	S_100m_clk;
    wire        	S_24m_clk;

	wire        	S_pll_lock;
    wire        	S_rst_n;

	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req;

	wire        	S_csi_rx_clk;
    wire        	S_hs_rx_valid;
    wire[15:0]  	S_hs_rx_data;
	wire[1:0]   	S_lane_error;

	wire        	S_csi_frame_start;
	wire        	S_csi_frame_end;
	wire        	S_csi_valid;
	wire[31:0]  	S_csi_data;

	wire        	S_raw10_frame_start;
	wire        	S_raw10_frame_end;
	wire        	S_raw10_valid;
	wire [39:0] 	S_raw10_data;

	wire 			S_axis_tlast;
	wire 			S_axis_tuser;
	wire [39:0]		S_axis_tdata;
	wire 			S_axis_tvalid;

	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;

	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid;

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;

    wire[127:0] S_vi_128b_data;

    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy;
    wire[1:0]   S_video_out_rp;

    wire        S_ddr_user_wr_en;
    wire        S_ddr_user_rd_en;
    wire[24:0]  S_ddr_user_addr;
    wire[127:0] S_ddr_user_wr_data;
    wire        S_ddr_user_ready;
    wire        S_ddr_user_rd_valid;
    wire[127:0] S_ddr_user_rd_data;

    wire        S_vi_ddr_wr_en;
    wire[24:0]  S_vi_ddr_wr_addr;
    wire[127:0] S_vi_ddr_wr_data;

    wire        S_vo_ddr_rd_en;
    wire[24:0]  S_vo_ddr_rd_addr;

    wire        S_init_calib_complete;
    wire[24:0]  S_mc_app_addr;
    wire[2:0]   S_mc_app_cmd;
    wire        S_mc_app_en;
    wire[127:0] S_mc_app_wdf_data;
    wire        S_mc_app_wdf_end;
    wire[15:0]  S_mc_app_wdf_mask;
    wire        S_mc_app_wdf_wren;
    wire[127:0] S_mc_app_rd_data;
    wire        S_mc_app_rd_data_end;
    wire        S_mc_app_rd_data_valid;
    wire        S_mc_app_rdy;
    wire        S_mc_app_wdf_rdy;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;
    wire        S_hdmi_out_vsync_g;
    wire        S_hdmi_out_de_g;
    wire[23:0]  S_hdmi_out_data_g;
    wire [1:0]  S_mode;
    wire[23:0]  S_edge_out_data;
    wire        S_edge_out_de;
    wire        S_edge_out_vsync;
    wire[23:0]  S_logo_out_data;
    wire        S_logo_out_de;
    wire        S_logo_out_vsync;
    wire[11:0]  S_edge_thresh;
    wire[11:0]  S_bin_thresh;

    wire[23:0]  S_video_rd_data;
    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;

    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;

    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),

        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );

  wire [7:0] S_ag_auto;
  wire [7:0] S_ae_mean_luma, S_ae_target_luma;
  wire [19:0] S_ae_frame_pixels;
  wire S_ae_luma_valid, S_ae_cam_ready, S_ae_write_busy;
  wire [15:0] S_ae_write_count;
  wire [15:0] S_cam_read_exp, S_cam_read_gain, S_cam_expected_gain, S_cam_read_count;
  wire S_cam_read_valid, S_cam_write_ack, S_cam_comm_error, S_cam_read_match;
  wire S_cam_diag_toggle;
  wire [67:0] S_cam_diag_bundle = {S_cam_read_count, S_cam_read_match,
      S_cam_comm_error, S_cam_write_ack, S_cam_read_valid,
      S_cam_expected_gain, S_cam_read_gain, S_cam_read_exp};
  (* ASYNC_REG = "TRUE" *) reg [2:0] S_cam_diag_toggle_sync;
  reg [67:0] S_cam_diag_video;

  always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
      if (!S_hdmi_rst_n) begin
          S_cam_diag_toggle_sync <= 3'd0;
          S_cam_diag_video <= 68'd0;
      end else begin
          S_cam_diag_toggle_sync <= {S_cam_diag_toggle_sync[1:0], S_cam_diag_toggle};
          if (S_cam_diag_toggle_sync[2] != S_cam_diag_toggle_sync[1])
              S_cam_diag_video <= S_cam_diag_bundle;
      end
  end

  auto_exposure #(
      .IMG_WIDTH   ( 1280     ),
      .IMG_HEIGHT  ( 720      ),
      .TARGET_LUMA ( 12'd130  ),
      .AE_INIT     ( 16'd1400 ),
      .AE_MAX      ( 16'd3980 ),
      .AG_INIT     ( 8'd24    ),
      .AG_MAX      ( 8'd112   ),
      .FRAME_DIV   ( 4'd3     )
  ) u_auto_exposure (
      .I_clk          ( S_hdmi_pixel_clk ),
      .I_rst_n        ( S_hdmi_rst_n     ),
      .I_de           ( S_hdmi_out_de    ),
      .I_vsync        ( S_hdmi_out_vsync ),
      .I_rgb          ( S_hdmi_out_data  ),
      .I_cam_cfg_done ( S_cam_cfg_done   ),
      .I_ae_cfg_done  ( S_ae_cfg_done    ),
      .O_ae_req       ( S_ae_req         ),
      .O_ae           ( S_ae             ),
      .O_ag           ( S_ag_auto        ),
      .O_mean_luma    ( S_ae_mean_luma   ),
      .O_luma_valid   ( S_ae_luma_valid  ),
      .O_frame_pixels ( S_ae_frame_pixels),
      .O_target_luma  ( S_ae_target_luma ),
      .O_cam_ready    ( S_ae_cam_ready   ),
      .O_write_busy   ( S_ae_write_busy  ),
      .O_write_count  ( S_ae_write_count )
  );

  assign S_ag = {8'd0, S_ag_auto};

    uicfgcs500_720p #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),
      .I_rst_n(S_rst_n),
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),
      .IO_cam_sda(IO_cam_sda),
      .O_cfg_done(S_cam_cfg_done),
      .O_ae_cfg_done(S_ae_cfg_done),
      .O_read_exp(S_cam_read_exp), .O_read_gain(S_cam_read_gain),
      .O_expected_gain(S_cam_expected_gain), .O_read_count(S_cam_read_count),
      .O_read_valid(S_cam_read_valid), .O_write_ack(S_cam_write_ack),
      .O_comm_error(S_cam_comm_error), .O_read_match(S_cam_read_match),
      .O_diag_toggle(S_cam_diag_toggle)
  );

    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),
        .HS_VGA_GAIN           ( "8dB" ),
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),

        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),

        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),

        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),

        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),

        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );

csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);

raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );

uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
)
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);

assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tuser  = S_axis_tuser;

    wire [39:0] S_raw_fixed_blc;
    wire [39:0] S_raw_spatial;
    wire S_raw_spatial_valid,S_raw_spatial_user,S_raw_spatial_last;
    raw_spatial_edge #(.ENABLE(1),.EDGE_LIMIT(10'd8)) u_raw_spatial_edge(
        .clk(S_csi_rx_clk),.rst_n(S_rst_n),.I_data(S_raw_tdata),
        .I_valid(S_raw_tvalid),.I_user(S_raw_tuser),.I_last(S_raw_tlast),
        .O_data(S_raw_spatial),.O_valid(S_raw_spatial_valid),
        .O_user(S_raw_spatial_user),.O_last(S_raw_spatial_last));
    raw_fixed_blc64 u_raw_fixed_blc(.raw_data(S_raw_spatial),.corrected_data(S_raw_fixed_blc));

isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_spatial_last),
.I_tuser         (S_raw_spatial_user),
.I_tdata         (S_raw_fixed_blc),
.I_tvalid        (S_raw_spatial_valid),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        ()
  );

    wire S_video_in_wr_request;
    wire [3:0] S_history_valid_pages;
    wire [31:0] S_history_generations;
    wire [23:0] S_latency_time_gray,S_capture_stamp,S_display_stamp;
    wire [95:0] S_page_stamps;
    wire S_display_stamp_valid;
    video_latency_clock u_latency_clock(
        .I_sys_clk(I_sys_clk),.I_rst_n(S_rst_n),
        .I_capture_clk(S_csi_rx_clk),.I_capture_start(S_raw_spatial_user),
        .O_time_gray(S_latency_time_gray),.O_capture_stamp(S_capture_stamp));
    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_in_wr_request( S_video_in_wr_request ),
        .O_video_out_rp       ( S_video_out_rp        ),
        .O_valid_pages        ( S_history_valid_pages ),
        .O_generations        ( S_history_generations ),
        .I_capture_stamp      ( S_capture_stamp       ),
        .O_page_stamps        ( S_page_stamps          ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );

    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;

    assign S_video_out_rst_n = S_hdmi_rst_n;

    wire [8:0] S_nr_diag;
    wire [63:0] S_motion_packet;
    wire S_motion_toggle;

    video_out_tnr #(.BURST_WORDS(48),.TNR_EN(1'b1),.NR_DIAG_EN(1'b0),.DIFF_MAX(8'd8)) u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),

        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_in_wr_request( S_video_in_wr_request ),
        .I_video_out_rp      ( S_video_out_rp       ),
        .I_valid_pages       ( S_history_valid_pages ),
        .I_generations       ( S_history_generations ),
        .I_page_stamps       ( S_page_stamps          ),
        .O_frame_stamp       ( S_display_stamp        ),
        .O_frame_stamp_valid ( S_display_stamp_valid  ),

        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_nr_diag           ( S_nr_diag            ),
        .O_motion_packet     ( S_motion_packet      ),
        .O_motion_toggle     ( S_motion_toggle      ),
        .O_vdieo_data        ( S_video_rd_data      )
    );

    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),

        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );

    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );

    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( 1280 ),
        .IMG_HEIGHT ( 720  ),
        .DEBUG_MODE ( 0    )
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( 4'd0               ),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );

    wire S_blue_weak,S_blue_strong;
    reg [1:0] S_blue_mask_g;
    color_blue_threshold u_blue_threshold(.I_rgb(S_hdmi_out_data),
        .O_weak(S_blue_weak),.O_strong(S_blue_strong));
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n)
        if(!S_hdmi_rst_n)S_blue_mask_g<=0;
        else S_blue_mask_g<=S_hdmi_out_de?{S_blue_strong,S_blue_weak}:2'd0;

    gamma_correction #(
        .DIGITAL_GAIN_Q8 ( 11'd256 )
    )u_gamma_correction(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_vsync         ( S_hdmi_out_vsync   ),
        .I_de            ( S_hdmi_out_de      ),
        .I_data          ( S_hdmi_out_data    ),
        .O_vsync         ( S_hdmi_out_vsync_g ),
        .O_de            ( S_hdmi_out_de_g    ),
        .O_data          ( S_hdmi_out_data_g  )
    );

    mode_toggle u_mode_toggle (
        .I_clk   ( S_hdmi_pixel_clk  ),
        .I_rst_n ( S_hdmi_rst_n      ),
        .I_key   ( I_key1            ),
        .I_vsync ( S_edge_out_vsync  ),
        .O_mode  ( S_mode            )
    );

    wire [1:0] S_style;
    mode_toggle u_style_toggle(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_key(I_key2 | (S_mode!=2'd0)),.I_vsync(S_edge_out_vsync),.O_mode(S_style));
    wire [1:0] S_recognition_view;
    mode_toggle u_recognition_toggle(.I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_key(I_key2 | (S_mode!=2'd3)),.I_vsync(S_edge_out_vsync),.O_mode(S_recognition_view));
    wire S_motion_enable=(S_mode==2'd3)&&S_recognition_view[0];
    wire [1:0] S_effect_select=(S_mode==0)?{1'b0,S_style[0]}:{S_motion_enable,1'b0};
    wire [2:0] S_color_led;
    assign O_led_red   = S_color_led[0];
    assign O_led_green = S_color_led[1];
    assign O_led_blue  = S_color_led[2];

    // already removed by synthesis; retain constants for the existing ports.
    assign S_edge_thresh = 12'd100;
    assign S_bin_thresh  = 12'd128;

    edge_detect #(
        .IMG_WIDTH    ( 1280     ),
        .IMG_HEIGHT   ( 720      ),
        .AW           ( 11       ),
        .LINE_CYCLE   ( 1650     ),
        .NR_BUILD     ( 23       ),
        .BIN_DIAG_EN ( 1'b0     ),
        .EDGE_SHAPE_FIX( 1'b1     )
    )u_edge_detect(
        .I_clk       ( S_hdmi_pixel_clk   ),
        .I_rst_n     ( S_hdmi_rst_n       ),
         .I_rgb       ( S_hdmi_out_data_g  ),
        .I_blue_mask(S_blue_mask_g),
        .I_de        ( S_hdmi_out_de_g    ),
        .I_vsync     ( S_hdmi_out_vsync_g ),
        .I_mode       ( S_mode            ),
        .I_style      ( S_effect_select   ),
        .I_thresh     ( S_edge_thresh     ),
        .I_bin_thresh ( S_bin_thresh      ),
        .I_dbg_exp    ( S_ae              ),
        .I_dbg_gain   ( S_ag_auto         ),
        .I_dbg_luma   ( S_ae_mean_luma    ),
        .I_dbg_target ( S_ae_target_luma  ),
        .I_dbg_pixels ( S_ae_frame_pixels ),
        .I_dbg_valid  ( S_ae_luma_valid   ),
        .I_dbg_cfg    ( S_ae_cam_ready    ),
        .I_dbg_busy   ( S_ae_write_busy   ),
        .I_dbg_writes ( S_ae_write_count  ),
        .I_dbg_read_exp(S_cam_diag_video[15:0]),
        .I_dbg_read_gain(S_cam_diag_video[31:16]),
        .I_dbg_expected_gain(S_cam_diag_video[47:32]),
        .I_dbg_read_valid(S_cam_diag_video[48]),
        .I_dbg_write_ack(S_cam_diag_video[49]),
        .I_dbg_comm_error(S_cam_diag_video[50]),
        .I_dbg_read_match(S_cam_diag_video[51]),
        .I_dbg_read_count(S_cam_diag_video[67:52]),
        .I_dbg_nr_diag(S_nr_diag),
        .O_color_led ( S_color_led        ),
        .O_rgb       ( S_edge_out_data    ),
        .O_de        ( S_edge_out_de      ),
        .O_vsync     ( S_edge_out_vsync   )
    );

    osd_logo #(
        .LOGO_X    ( 12   ),
        .LOGO_Y    ( 12   ),
        .IMG_WIDTH ( 1280 )
    )u_osd_logo(
        .I_clk   ( S_hdmi_pixel_clk  ),
        .I_rst_n ( S_hdmi_rst_n      ),
        .I_vsync ( S_edge_out_vsync  ),
        .I_de    ( S_edge_out_de     ),
        .I_rgb   ( S_edge_out_data   ),
        .O_vsync ( S_logo_out_vsync  ),
        .O_de    ( S_logo_out_de     ),
        .O_rgb   ( S_logo_out_data   )
    );

    wire [23:0] S_latency_out_data;
    osd_video_latency u_latency_osd(
        .I_clk(S_hdmi_pixel_clk),.I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_logo_out_vsync),.I_de(S_logo_out_de),.I_rgb(S_logo_out_data),
        .I_time_gray(S_latency_time_gray),.I_frame_stamp(S_display_stamp),
        .I_frame_stamp_valid(S_display_stamp_valid),.O_rgb(S_latency_out_data));

    assign O_buzzer_n=1'b1;
    wire S_motion_frame_tick;
    wire [63:0] S_motion_frame_packet;
    wire [15:0] S_guard_count;
    wire [23:0] S_alarm_out_data;
    motion_center_counter u_center_counter(
        .clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),.enable(S_motion_enable),
        .frame_tick(S_motion_frame_tick),.packet(S_motion_frame_packet),
        .count_bcd(S_guard_count));
    motion_alarm_osd u_motion_osd(
        .clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),
        .vs(S_logo_out_vsync),.de(S_logo_out_de),.rgb(S_latency_out_data),
        .enable(S_motion_enable),.count_bcd(S_guard_count),
        .motion_packet(S_motion_packet),.motion_toggle(S_motion_toggle),
        .out_rgb(S_alarm_out_data),.frame_packet(S_motion_frame_packet),.frame_tick(S_motion_frame_tick));
    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_logo_out_vsync  ),
        .I_video_in_de      ( S_logo_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_alarm_out_data),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );

endmodule
