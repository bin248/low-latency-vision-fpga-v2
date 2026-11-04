`timescale 1ns / 1ns

module uicfgcs500_720p #(
    parameter CLK_DIV = 16'd239,
    parameter READ_PERIOD = 24'd12000000,
    parameter READ_TIMEOUT = 24'd240000
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_ae_req,
    input  wire [15:0] I_ae,
    input  wire [15:0] I_ag,
    output wire        O_cam_scl,
    inout  wire        IO_cam_sda,
    output reg         O_cfg_done,
    output reg         O_ae_cfg_done,
    output reg [15:0]  O_read_exp, O_read_gain, O_expected_gain,
    output reg         O_read_valid, O_write_ack, O_comm_error, O_read_match,
    output reg [15:0]  O_read_count,
    output reg         O_diag_toggle
);

localparam CAM_ID = 8'h6c;
localparam [17:0] POST_STREAM_DELAY = 18'd240000;

reg [7:0]  rst_cnt = 8'd0;
reg        iic_req;
wire       iic_busy;
reg [31:0] wr_data;
reg [2:0]  state;
reg [8:0]  reg_index;
reg [17:0] delay_cnt;
reg read_mode;
reg [2:0] read_index;
reg [23:0] read_timer, read_timeout;
reg [1:0] iic_reset_hold;
wire [7:0] rd_data;
wire iic_error;
wire [15:0] gain_value;

(* ASYNC_REG = "TRUE" *) reg ae_req_meta, ae_req_sync1, ae_req_sync2;
reg ae_req_prev;
reg [15:0] ae_hold, ag_hold;
always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        ae_req_meta <= 1'b0;
        ae_req_sync1 <= 1'b0;
        ae_req_sync2 <= 1'b0;
        ae_req_prev <= 1'b0;
        ae_hold <= 16'd0;
        ag_hold <= 16'd16;
    end else begin
        ae_req_meta <= I_ae_req;
        ae_req_sync1 <= ae_req_meta;
        ae_req_sync2 <= ae_req_sync1;
        ae_req_prev <= ae_req_sync2;
        if (ae_req_sync2 && !ae_req_prev) begin
            ae_hold <= I_ae;
            ag_hold <= I_ag;
        end
    end
end
reg transaction_error, write_batch_error, read_batch_error, error_seen;
reg write_ack_latest;
reg [15:0] read_exp_work, read_gain_work, expected_exp_work, expected_gain_work;
wire [15:0] read_address = (read_index == 0) ? 16'h3e00 :
                           (read_index == 1) ? 16'h3e01 :
                           (read_index == 2) ? 16'h3e02 :
                           (read_index == 3) ? 16'h3e08 : 16'h3e09;

wire [23:0] init_data;
wire [8:0]  init_size;
wire [23:0] ae_data;
wire [8:0]  ae_size;
wire [23:0] selected_data = O_cfg_done ? ae_data : init_data;

always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n)
        rst_cnt <= 8'd0;
    else if (!rst_cnt[7])
        rst_cnt <= rst_cnt + 1'b1;
end

always @(posedge I_clk) begin
    if (!rst_cnt[7]) begin
        reg_index            <= 9'd0;
        iic_req              <= 1'b0;
        wr_data              <= 32'd0;
        O_cfg_done           <= 1'b0;
        O_ae_cfg_done        <= 1'b0;
        delay_cnt            <= 18'd0;
        state                <= 2'd0;
        read_mode <= 1'b0; read_index <= 0;
        read_timer <= 0; read_timeout <= 0; iic_reset_hold <= 0;
        transaction_error <= 0; write_batch_error <= 0; read_batch_error <= 0;
        error_seen <= 0; write_ack_latest <= 0;
        read_exp_work <= 0; read_gain_work <= 0;
        expected_exp_work <= 0; expected_gain_work <= 0;
        O_read_exp <= 0; O_read_gain <= 0; O_expected_gain <= 0;
        O_read_valid <= 0; O_write_ack <= 0; O_comm_error <= 0;
        O_read_match <= 0; O_read_count <= 0; O_diag_toggle <= 0;
    end else begin
        if (iic_reset_hold != 0) iic_reset_hold <= iic_reset_hold - 1'b1;
        if (O_cfg_done && read_timer < READ_PERIOD) read_timer <= read_timer + 1'b1;
        if (iic_error) begin
            transaction_error <= 1'b1;
            error_seen <= 1'b1;
        end

        if ((state == 3'd5 || state == 3'd6) && read_timeout >= READ_TIMEOUT) begin
            iic_req <= 1'b0;
            iic_reset_hold <= 2'd3;
            read_batch_error <= 1'b1;
            error_seen <= 1'b1;
            state <= 3'd7;
        end else begin
        case (state)
            2'd0: begin
                iic_req <= 1'b0;
                if (!O_cfg_done) begin
                    if ((reg_index == 9'd115) && (delay_cnt < POST_STREAM_DELAY)) begin

                        delay_cnt <= delay_cnt + 1'b1;
                    end else if (reg_index == init_size) begin
                        O_cfg_done    <= 1'b1;
                        O_ae_cfg_done <= 1'b1;
                        reg_index     <= 9'd0;
                    end else begin
                        state <= 2'd1;
                    end
                end else if (ae_req_sync2) begin
                    O_ae_cfg_done <= 1'b0;
                    reg_index     <= 9'd0;
                    write_batch_error <= 1'b0;
                end else if (!O_ae_cfg_done) begin
                    if (reg_index == ae_size) begin
                        O_ae_cfg_done <= 1'b1;
                        write_ack_latest <= !write_batch_error;
                    end else
                        state <= 2'd1;
                end else if (read_timer >= READ_PERIOD && iic_reset_hold == 0) begin
                    read_timer <= 0;
                    read_index <= 0;
                    read_batch_error <= 0;
                    expected_exp_work <= ae_hold;
                    expected_gain_work <= gain_value;
                    state <= 3'd4;
                end
            end
            2'd1: begin
                if (!iic_busy) begin
                    iic_req       <= 1'b1;
                    read_mode     <= 1'b0;
                    transaction_error <= 1'b0;
                    wr_data[7:0]  <= CAM_ID;
                    wr_data[15:8] <= selected_data[23:16];
                    wr_data[23:16]<= selected_data[15:8];
                    wr_data[31:24]<= selected_data[7:0];
                    state         <= 2'd2;
                end
            end
            2'd2: begin
                if (iic_busy) begin
                    iic_req <= 1'b0;
                    state   <= 2'd3;
                end
            end
            2'd3: begin
                if (!iic_busy) begin
                    if (O_cfg_done)
                        write_batch_error <= write_batch_error | transaction_error | iic_error;
                    reg_index <= reg_index + 1'b1;
                    state     <= 2'd0;
                end
            end
            3'd4: begin
                if (!iic_busy && iic_reset_hold == 0) begin
                    read_mode <= 1'b1;
                    transaction_error <= 1'b0;
                    wr_data <= {8'd0, read_address[7:0], read_address[15:8], CAM_ID};
                    iic_req <= 1'b1;
                    read_timeout <= 0;
                    state <= 3'd5;
                end
            end
            3'd5: begin
                read_timeout <= read_timeout + 1'b1;
                if (iic_busy) begin
                    iic_req <= 1'b0;
                    state <= 3'd6;
                end
            end
            3'd6: begin
                read_timeout <= read_timeout + 1'b1;
                if (!iic_busy) begin
                    read_batch_error <= read_batch_error | transaction_error | iic_error;
                    case (read_index)
                        0: read_exp_work[15:12] <= rd_data[3:0];
                        1: read_exp_work[11:4] <= rd_data;
                        2: read_exp_work[3:0] <= rd_data[7:4];
                        3: read_gain_work[15:8] <= rd_data;
                        4: read_gain_work[7:0] <= rd_data;
                    endcase
                    if (read_index == 4) state <= 3'd7;
                    else begin
                        read_index <= read_index + 1'b1;
                        state <= 3'd4;
                    end
                end
            end
            3'd7: begin

                O_read_exp <= read_exp_work;
                O_read_gain <= read_gain_work;
                O_expected_gain <= expected_gain_work;
                O_read_valid <= !read_batch_error;
                O_write_ack <= write_ack_latest;
                O_comm_error <= error_seen;
                O_read_match <= !read_batch_error &&
                                read_exp_work == expected_exp_work &&
                                read_gain_work == expected_gain_work;
                if (O_read_count != 16'hffff) O_read_count <= O_read_count + 1'b1;
                O_diag_toggle <= !O_diag_toggle;
                read_mode <= 1'b0;
                state <= 3'd0;
            end
            default: state <= 3'd0;
        endcase
        end
    end
end

uii2c #(
    .WMEN_LEN (4),
    .RMEN_LEN (1),
    .CLK_DIV  (CLK_DIV)
) u_i2c (
    .I_clk      (I_clk),
    .I_rstn     (rst_cnt[7] && iic_reset_hold == 0),
    .O_iic_scl  (O_cam_scl),
    .IO_iic_sda (IO_cam_sda),
    .I_wr_data  (wr_data),
    .I_wr_cnt   (read_mode ? 8'd3 : 8'd4),
    .O_rd_data  (rd_data),
    .I_rd_cnt   (read_mode ? 8'd1 : 8'd0),
    .I_iic_mode (read_mode),
    .I_iic_req  (iic_req),
    .O_iic_busy (iic_busy),
    .O_iic_bus_error(iic_error)
);

uics500reg_720p60 u_init_table (
    .REG_INDEX (reg_index),
    .REG_DATA  (init_data),
    .REG_SIZE  (init_size)
);

SC500GainTbl u_gain_table (
    .I_clk  (I_clk),
    .I_rstn (rst_cnt[7]),
    .I      (ag_hold - 16),
    .O      (gain_value)
);

uics500regAE u_ae_table (
    .REG_INDEX (reg_index),
    .REG_DATA  (ae_data),
    .REG_SIZE  (ae_size),
    .I_AG      (gain_value),
    .I_AE      (ae_hold)
);

endmodule
