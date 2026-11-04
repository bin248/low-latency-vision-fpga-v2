module video_out (
    input wire        I_rst_n,

    input wire        I_ddr_clk,
    output wire       O_video_out_rd_busy,
    input wire        I_video_in_wr_busy,
    input wire[1:0]   I_video_out_rp,
    output wire       O_ddr_user_rd_en,
    output reg[24:0]  O_ddr_user_addr,
    input wire        I_ddr_user_ready,
    input wire        I_ddr_user_rd_valid,
    input wire[127:0] I_ddr_user_rd_data,

    input wire        I_dsi_clk,
    input wire        I_video_vsync,
    input wire        I_video_rd_en,
    output reg[23:0]  O_vdieo_data
);

    reg         S_fifo_rst;
    reg[7:0]    S_fifo_rst_cnt;
    wire[8:0]   S_fifo_wr_num;
    wire        S_fifo_rd_en;
    wire[127:0] S_fifo_rd_data;
    reg         S_video_vsync_1d;
    reg         S_video_vsync_2d;
    reg         S_video_vsync_3d;
    wire        S_video_frame_start;
    wire        S_ddr_rd_trig;
    reg         S_ddr_rd_valid;
    reg[9:0]    S_ddr_rd_cnt;
    reg[3:0]    S_fifo_rd_cnt;
    reg         S_video_rd_en_1d;
    reg[3:0]    S_fifo_rd_cnt_1d;
    reg[127:0]  S_fifo_rd_data_1d;
	wire        S_fifo_emtpy;

    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;

    always @(posedge I_ddr_clk) begin
        S_video_vsync_1d <= I_video_vsync;
        S_video_vsync_2d <=S_video_vsync_1d;
        S_video_vsync_3d <= S_video_vsync_2d;
    end

    assign S_video_frame_start = ~S_video_vsync_3d & S_video_vsync_2d;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_fifo_rst <= 1'b0;
        else
            if(S_video_frame_start)
                S_fifo_rst <= 1'b1;
            else if(S_fifo_rst_cnt == 'd10)
                S_fifo_rst <= 1'b0;
            else
                S_fifo_rst <= S_fifo_rst;
    end

    always @(posedge I_ddr_clk) begin
        if(S_fifo_rst)
            S_fifo_rst_cnt <= S_fifo_rst_cnt + 'd1;
        else
            S_fifo_rst_cnt <= 'd0;
    end

    assign S_ddr_rd_trig = (('d511 - S_fifo_wr_num) >= 'd300) && (!I_video_in_wr_busy) && (!S_ddr_rd_valid) && (!S_fifo_rst) && I_rst_n ? 1'b1 : 1'b0;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_valid <= 1'b0;
        else
			if(O_ddr_user_rd_en && S_ddr_rd_cnt == 'd239)
                S_ddr_rd_valid <= 1'b0;
            else if(S_ddr_rd_trig)
                S_ddr_rd_valid <= 1'b1;
            else
                S_ddr_rd_valid <= S_ddr_rd_valid;
    end

    assign O_ddr_user_rd_en = S_ddr_rd_valid & I_ddr_user_ready;

    always @(posedge I_ddr_clk) begin
        if(S_ddr_rd_valid)
            begin
                if(O_ddr_user_rd_en)
                    S_ddr_rd_cnt <= S_ddr_rd_cnt + 'd1;
                else
                    S_ddr_rd_cnt <= S_ddr_rd_cnt;
            end
        else
            S_ddr_rd_cnt <= 'd0;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 'd0;
        else
            if(S_video_frame_start)
                begin
                    case(I_video_out_rp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                    endcase
                end
            else if(O_ddr_user_rd_en)
                O_ddr_user_addr <= O_ddr_user_addr + 'd8;
            else
                O_ddr_user_addr <= O_ddr_user_addr;
    end

    assign O_video_out_rd_busy = S_ddr_rd_trig | S_ddr_rd_valid;

    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst          ),

        .clkw       ( I_ddr_clk           ),
        .we         ( I_ddr_user_rd_valid ),
        .di         ( I_ddr_user_rd_data  ),
        .wrusedw    ( S_fifo_wr_num       ),
        .afull      (),
        .full_flag  (),

        .clkr       ( I_dsi_clk           ),
        .re         ( S_fifo_rd_en        ),
        .dout       ( S_fifo_rd_data      ),
        .rdusedw    (),
        .valid      (),
        .empty_flag ( S_fifo_emtpy        ),
        .aempty     ()
    );

   always @(posedge I_dsi_clk) begin
       if(I_video_rd_en)
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
       else
           S_fifo_rd_cnt <= 'd0;
   end

   assign S_fifo_rd_en = I_video_rd_en && (S_fifo_rd_cnt == 'd0)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd5)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd10) ? 1'b1 : 1'b0;

   always @(posedge I_dsi_clk) begin
       S_video_rd_en_1d  <= I_video_rd_en;
       S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
       S_fifo_rd_data_1d <= S_fifo_rd_data;
   end

   always @(posedge I_dsi_clk) begin
       if(S_video_rd_en_1d)
           begin
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else
           O_vdieo_data <= 'd0;
   end

endmodule

`timescale 1ns/1ps

module tnr_word_blend #(parameter [7:0] DIFF_MAX=8'd24)(
    input wire clk,rst_n,clear,in_valid,in_blend,in_last,
    input wire [127:0] current_word,reference_word,
    output reg out_valid,out_blended,
    output reg [4:0] out_fused_channels,
    output reg [127:0] out_word,
    output wire busy
);
    reg have_previous,flush_previous,previous_enable,head_gate;
    reg [1:0] phase,previous_phase;
    reg [127:0] previous_word,previous_average;
    reg [15:0] previous_similar;
    wire [15:0] similar;
    reg [15:0] pixel_gate;
    reg next_head_gate;
    integer lane,j;
    function [7:0] mean8;
        input [7:0] a,b;
        reg [8:0] sum;
        begin sum={1'b0,a}+{1'b0,b};mean8=sum[8:1];end
    endfunction
    genvar g;
    generate for(g=0;g<16;g=g+1)begin:channel_difference
        wire [7:0] a=current_word[127-g*8-:8],b=reference_word[127-g*8-:8];

        wire [8:0] delta={1'b0,a}-{1'b0,b};
        wire [8:0] negative_limit=-{1'b0,DIFF_MAX};
        assign similar[g]=(delta<={1'b0,DIFF_MAX}) ||
                          ((DIFF_MAX!=0) && delta>=negative_limit);
    end endgenerate
    always @*begin
        pixel_gate=0;next_head_gate=1;
        case(previous_phase)
        0:begin
            for(j=0;j<15;j=j+3)pixel_gate[j+:3]={3{&previous_similar[j+:3]}};
            pixel_gate[15]=previous_similar[15] && similar[0] && similar[1];
            next_head_gate=pixel_gate[15];
        end
        1:begin
            pixel_gate[1:0]={2{head_gate}};
            for(j=2;j<14;j=j+3)pixel_gate[j+:3]={3{&previous_similar[j+:3]}};
            pixel_gate[15:14]={2{previous_similar[14] && previous_similar[15] && similar[0]}};
            next_head_gate=pixel_gate[14];
        end
        default:begin
            pixel_gate[0]=head_gate;
            for(j=1;j<16;j=j+3)pixel_gate[j+:3]={3{&previous_similar[j+:3]}};
        end
        endcase
    end
    wire [2:0] pc0={2'b0,pixel_gate[0]}+{2'b0,pixel_gate[1]}+{2'b0,pixel_gate[2]}+{2'b0,pixel_gate[3]};
    wire [2:0] pc1={2'b0,pixel_gate[4]}+{2'b0,pixel_gate[5]}+{2'b0,pixel_gate[6]}+{2'b0,pixel_gate[7]};
    wire [2:0] pc2={2'b0,pixel_gate[8]}+{2'b0,pixel_gate[9]}+{2'b0,pixel_gate[10]}+{2'b0,pixel_gate[11]};
    wire [2:0] pc3={2'b0,pixel_gate[12]}+{2'b0,pixel_gate[13]}+{2'b0,pixel_gate[14]}+{2'b0,pixel_gate[15]};
    wire [3:0] pc01={1'b0,pc0}+{1'b0,pc1},pc23={1'b0,pc2}+{1'b0,pc3};
    wire [4:0] fused_channels={1'b0,pc01}+{1'b0,pc23};
    assign busy=have_previous || flush_previous || out_valid;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            have_previous<=0;flush_previous<=0;phase<=0;previous_phase<=0;
            previous_enable<=0;head_gate<=1;previous_word<=0;previous_average<=0;
            previous_similar<=0;out_valid<=0;out_blended<=0;out_word<=0;out_fused_channels<=0;
        end else if(clear)begin
            have_previous<=0;flush_previous<=0;phase<=0;head_gate<=1;
            out_valid<=0;out_blended<=0;out_fused_channels<=0;
        end else begin
            out_valid<=0;out_blended<=0;out_fused_channels<=0;
            if(flush_previous || (in_valid && have_previous))begin
                out_valid<=1;out_blended<=previous_enable && (|pixel_gate);
                out_fused_channels<=previous_enable?fused_channels:5'd0;
                for(lane=0;lane<16;lane=lane+1)
                    out_word[127-lane*8-:8]<=(previous_enable && pixel_gate[lane])?
                        previous_average[127-lane*8-:8]:previous_word[127-lane*8-:8];
            end
            if(flush_previous)begin
                flush_previous<=0;have_previous<=0;phase<=0;head_gate<=1;
            end else if(in_valid)begin
                have_previous<=1;flush_previous<=in_last;
                previous_word<=current_word;previous_similar<=similar;
                previous_enable<=in_blend;previous_phase<=phase;
                head_gate<=have_previous?next_head_gate:1'b1;
                phase<=(phase==2)?0:phase+1'b1;
                for(lane=0;lane<16;lane=lane+1)
                    previous_average[127-lane*8-:8]<=mean8(current_word[127-lane*8-:8],reference_word[127-lane*8-:8]);
            end
        end
    end
endmodule

module tnr_frame_tracker #(parameter FRAME_WORDS=172800)(
    input wire clk,rst_n,frame_start,write_en,frame_error,pause,
    input wire [1:0] target_page,
    output reg [3:0] valid_pages,
    output reg [31:0] generations
);
    localparam CW=$clog2(FRAME_WORDS+1);
    reg [CW-1:0] words;
    reg [1:0] write_page;
    reg [7:0] generation;
    reg bad_frame;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            words<=0;write_page<=0;generation<=0;bad_frame<=1;
            valid_pages<=0;generations<=0;
        end else if(frame_start)begin
            words<=0;write_page<=target_page;generation<=generation+8'd1;
            bad_frame<=frame_error || pause;
            if(words!=FRAME_WORDS || bad_frame || frame_error || pause)
                valid_pages<=0;
            else valid_pages<=valid_pages & ~(4'b0001<<target_page);
        end else begin
            if(frame_error || pause)begin bad_frame<=1;valid_pages<=0;end
            if(write_en)begin
                if(words<FRAME_WORDS)begin
                    words<=words+1'b1;
                    if(words==FRAME_WORDS-1 && !bad_frame && !frame_error && !pause)begin
                        valid_pages<=valid_pages | (4'b0001<<write_page);
                        generations[write_page*8+:8]<=generation;
                    end
                end else begin bad_frame<=1;valid_pages<=0;end
            end
        end
    end
endmodule

module video_out_tnr #(
    parameter IMG_WIDTH=1280,IMG_HEIGHT=720,
    parameter BURST_WORDS=48,
    parameter TNR_EN=1'b1,
    parameter NR_DIAG_EN=1'b1,
    parameter [7:0] DIFF_MAX=8'd24
)(
    input wire I_rst_n,I_ddr_clk,
    output wire O_video_out_rd_busy,
    input wire I_video_in_wr_busy,I_video_in_wr_request,
    input wire [1:0] I_video_out_rp,
    input wire [3:0] I_valid_pages,
    input wire [31:0] I_generations,
    input wire [95:0] I_page_stamps,
    output reg [23:0] O_frame_stamp,
    output reg O_frame_stamp_valid,
    output wire O_ddr_user_rd_en,
    output reg [24:0] O_ddr_user_addr,
    input wire I_ddr_user_ready,I_ddr_user_rd_valid,
    input wire [127:0] I_ddr_user_rd_data,
    input wire I_dsi_clk,I_video_vsync,I_video_rd_en,
    output wire [8:0] O_nr_diag,
    output wire [63:0] O_motion_packet,
    output wire O_motion_toggle,
    output reg [23:0] O_vdieo_data
);
    localparam FRAME_WORDS=IMG_WIDTH*IMG_HEIGHT*3/16;
    localparam FW=$clog2(FRAME_WORDS+1);
    localparam BW=$clog2(BURST_WORDS+1);
    localparam AW=$clog2(BURST_WORDS);
    localparam IDLE=3'd0,CURRENT=3'd1,REFERENCE=3'd2,WAIT=3'd3,ZERO=3'd4;
    reg [2:0] state;
    (* ASYNC_REG="TRUE" *) reg [2:0] vs_sync;
    wire frame_start=vs_sync[1] && !vs_sync[2];

    always @(posedge I_ddr_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin O_frame_stamp<=0;O_frame_stamp_valid<=0;end
        else if(frame_start)begin
            O_frame_stamp<=I_page_stamps[I_video_out_rp*24+:24];
            O_frame_stamp_valid<=I_valid_pages[I_video_out_rp];
        end
    end
    reg frame_pending,fifo_reset,abandon;
    reg [3:0] reset_left;
    reg [1:0] pending_page;
    reg pending_valid,pending_pair;
    reg [24:0] current_base,reference_base;
    reg current_valid,pair_valid;
    reg [FW-1:0] offset;
    reg [BW-1:0] chunk_words,index;
    reg [BW:0] issued,received;
    reg [BW-1:0] emitted;
    reg chunk_pair,chunk_zero;
    wire [8:0] fifo_used;
    wire fifo_empty;
    wire [127:0] fifo_data;
    wire fifo_rd_en;
    wire [1:0] sample_ref=I_video_out_rp+2'd1;
    wire [7:0] sample_next_generation=I_generations[I_video_out_rp*8+:8]+8'd1;
    wire sample_pair=I_valid_pages[I_video_out_rp] && I_valid_pages[sample_ref] &&
                     I_generations[sample_ref*8+:8]==sample_next_generation;
    function [24:0] page_base;
        input [1:0] page;
        begin
            case(page)
            0:page_base=25'd0;1:page_base=25'd7000000;
            2:page_base=25'd14000000;default:page_base=25'd21000000;
            endcase
        end
    endfunction
    wire can_start=state==IDLE && !frame_pending && !fifo_reset &&
                   !frame_start && !I_video_in_wr_busy && !I_video_in_wr_request && offset<FRAME_WORDS &&
                   (9'd511-fifo_used)>=(BURST_WORDS+16);

    assign O_video_out_rd_busy=(state==CURRENT || state==REFERENCE)||can_start;
    assign O_ddr_user_rd_en=(state==CURRENT || state==REFERENCE) &&
                           !frame_pending && !fifo_reset && !frame_start &&
                           I_ddr_user_ready;
    wire return_valid=I_ddr_user_rd_valid && received<issued;
    wire history_return=return_valid && chunk_pair && received>=chunk_words;
    wire [AW-1:0] history_index=received-chunk_words;
    (* ram_style="dram" *) reg [127:0] current_buffer [0:BURST_WORDS-1];

    always @(posedge I_ddr_clk)begin
        if(return_valid && chunk_pair && received<chunk_words)
            current_buffer[received[AW-1:0]]<=I_ddr_user_rd_data;
    end
    wire zero_word=state==ZERO && !frame_pending && !fifo_reset && !frame_start;
    wire blend_input_valid=!abandon && !frame_pending && !frame_start &&
                           (zero_word || (return_valid && (!chunk_pair || history_return)));
    wire [127:0] blend_current=zero_word?128'd0:
                             chunk_pair?current_buffer[history_index]:I_ddr_user_rd_data;
    wire blend_valid,blend_applied,blend_busy;
    wire last_blend_word=zero_word?(index==chunk_words-1'b1):
                          chunk_pair?(received==2*chunk_words-1'b1):(received==chunk_words-1'b1);
    wire [127:0] blend_word;

    motion_word_observer motion_observer(
        .clk(I_ddr_clk),.rst_n(I_rst_n),.frame_start(frame_start),
        .valid(blend_input_valid),.paired(chunk_pair&&!zero_word),
        .current_word(blend_current),.reference_word(I_ddr_user_rd_data),
        .packet(O_motion_packet),.toggle(O_motion_toggle));
    wire [4:0] blend_fused_channels;
    generate if (TNR_EN) begin : g_tnr_blend
        tnr_word_blend #(.DIFF_MAX(DIFF_MAX)) blend(
            .clk(I_ddr_clk),.rst_n(I_rst_n),.clear(frame_start || frame_pending),
            .in_valid(blend_input_valid),.in_last(last_blend_word),
            .in_blend(chunk_pair && !zero_word),.current_word(blend_current),
            .reference_word(I_ddr_user_rd_data),.out_valid(blend_valid),
            .out_blended(blend_applied),.out_fused_channels(blend_fused_channels),
            .out_word(blend_word),.busy(blend_busy));
    end else begin : g_tnr_bypass

        reg have_previous,flush_previous;
        reg [127:0] previous_word,out_word_r;
        reg out_valid_r;
        always @(posedge I_ddr_clk or negedge I_rst_n)begin
            if(!I_rst_n)begin
                have_previous<=0;flush_previous<=0;previous_word<=0;
                out_valid_r<=0;out_word_r<=0;
            end else if(frame_start || frame_pending)begin
                have_previous<=0;flush_previous<=0;out_valid_r<=0;
            end else begin
                out_valid_r<=flush_previous || (blend_input_valid && have_previous);
                if(flush_previous)begin
                    out_word_r<=previous_word;
                    flush_previous<=0;have_previous<=0;
                end else if(blend_input_valid)begin
                    out_word_r<=previous_word;
                    have_previous<=1;
                    flush_previous<=last_blend_word;
                    previous_word<=blend_current;
                end
            end
        end
        assign blend_valid=out_valid_r;
        assign blend_word=out_word_r;
        assign blend_applied=1'b0;
        assign blend_busy=have_previous || flush_previous || out_valid_r;
        assign blend_fused_channels=5'd0;
    end endgenerate
    reg [1:0] pipeline_busy;
    wire fifo_write=blend_valid && !abandon && !fifo_reset && !frame_pending && !frame_start;

    generate if (TNR_EN && NR_DIAG_EN) begin : g_tnr_diag
        tnr_frame_diag #(.FRAME_WORDS(FRAME_WORDS)) nr_diagnostics(
            .clk(I_ddr_clk),.pixel_clk(I_dsi_clk),.rst_n(I_rst_n),
            .frame_start(frame_start),.word_valid(fifo_write),.pair_used(pair_valid),
            .fused_channels(blend_fused_channels),.O_diag(O_nr_diag));
    end else begin : g_tnr_diag_off
        assign O_nr_diag = 9'd0;
    end endgenerate
    always @(posedge I_ddr_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            vs_sync<=0;state<=IDLE;frame_pending<=0;fifo_reset<=1;reset_left<=0;abandon<=0;
            pending_page<=0;pending_valid<=0;pending_pair<=0;
            current_base<=0;reference_base<=0;current_valid<=0;pair_valid<=0;
            offset<=0;chunk_words<=0;index<=0;issued<=0;received<=0;emitted<=0;
            chunk_pair<=0;chunk_zero<=0;O_ddr_user_addr<=0;pipeline_busy<=0;
        end else begin
            vs_sync<={vs_sync[1:0],I_video_vsync};
            pipeline_busy<={pipeline_busy[0],blend_input_valid};
            if(O_ddr_user_rd_en)issued<=issued+1'b1;
            if(return_valid)received<=received+1'b1;
            if(fifo_write)emitted<=emitted+1'b1;
            if(frame_start)begin
                frame_pending<=1;abandon<=1;fifo_reset<=1;reset_left<=0;
                pending_page<=I_video_out_rp;
                pending_valid<=I_valid_pages[I_video_out_rp];
                pending_pair<=TNR_EN && sample_pair;
                state<=WAIT;
            end else if(frame_pending)begin

                if(received==issued && pipeline_busy==0 && !blend_busy)begin
                    current_base<=page_base(pending_page);
                    reference_base<=page_base(pending_page+2'd1);
                    current_valid<=pending_valid;pair_valid<=pending_pair;
                    offset<=0;state<=IDLE;frame_pending<=0;abandon<=0;
                    issued<=0;received<=0;emitted<=0;reset_left<=4'd11;
                end
            end else if(fifo_reset)begin
                if(reset_left==0)fifo_reset<=0;
                else reset_left<=reset_left-1'b1;
            end else begin
                case(state)
                IDLE:if(can_start)begin
                    issued<=0;received<=0;emitted<=0;index<=0;
                    chunk_words<=((FRAME_WORDS-offset)<BURST_WORDS)?FRAME_WORDS-offset:BURST_WORDS;
                    chunk_pair<=pair_valid;chunk_zero<=!current_valid;
                    O_ddr_user_addr<=current_base+(offset<<3);
                    state<=current_valid?CURRENT:ZERO;
                end
                CURRENT:if(O_ddr_user_rd_en)begin
                    if(index==chunk_words-1'b1)begin
                        index<=0;
                        if(chunk_pair)begin
                            state<=REFERENCE;
                            O_ddr_user_addr<=reference_base+(offset<<3);
                        end else state<=WAIT;
                    end else begin index<=index+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;end
                end
                REFERENCE:if(O_ddr_user_rd_en)begin
                    if(index==chunk_words-1'b1)begin index<=0;state<=WAIT;end
                    else begin index<=index+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;end
                end
                ZERO:begin
                    if(index==chunk_words-1'b1)begin index<=0;state<=WAIT;end
                    else index<=index+1'b1;
                end
                WAIT:if(emitted==chunk_words && received==issued &&
                        pipeline_busy==0 && !blend_busy)begin
                    offset<=offset+chunk_words;state<=IDLE;
                end
                default:state<=IDLE;
                endcase
            end
        end
    end
    w128_d512_fifo U_w128_d512_fifo(
        .rst(fifo_reset || !I_rst_n),.clkw(I_ddr_clk),.we(fifo_write),.di(blend_word),
        .wrusedw(fifo_used),.afull(),.full_flag(),
        .clkr(I_dsi_clk),.re(fifo_rd_en),.dout(fifo_data),.rdusedw(),.valid(),
        .empty_flag(fifo_empty),.aempty());

    reg [3:0] pixel_count,pixel_count_d1;
    reg read_d1;
    reg [127:0] data_d1;
    always @(posedge I_dsi_clk)begin
        if(I_video_rd_en)pixel_count<=pixel_count+1'b1;else pixel_count<=0;
        read_d1<=I_video_rd_en;pixel_count_d1<=pixel_count;data_d1<=fifo_data;
        if(read_d1)begin
            case(pixel_count_d1)
            0:O_vdieo_data<=fifo_data[127:104];1:O_vdieo_data<=fifo_data[103:80];
            2:O_vdieo_data<=fifo_data[79:56];3:O_vdieo_data<=fifo_data[55:32];
            4:O_vdieo_data<=fifo_data[31:8];5:O_vdieo_data<={data_d1[7:0],fifo_data[127:112]};
            6:O_vdieo_data<=fifo_data[111:88];7:O_vdieo_data<=fifo_data[87:64];
            8:O_vdieo_data<=fifo_data[63:40];9:O_vdieo_data<=fifo_data[39:16];
            10:O_vdieo_data<={data_d1[15:0],fifo_data[127:120]};
            11:O_vdieo_data<=fifo_data[119:96];12:O_vdieo_data<=fifo_data[95:72];
            13:O_vdieo_data<=fifo_data[71:48];14:O_vdieo_data<=fifo_data[47:24];
            15:O_vdieo_data<=fifo_data[23:0];
            endcase
        end else O_vdieo_data<=0;
    end
    assign fifo_rd_en=I_video_rd_en && (pixel_count==0 || pixel_count==5 || pixel_count==10);
endmodule

module tnr_frame_diag #(parameter FRAME_WORDS=172800)(
    input wire clk,pixel_clk,rst_n,frame_start,word_valid,pair_used,
    input wire [4:0] fused_channels,
    output reg [8:0] O_diag
);
    localparam TOTAL_CHANNELS=FRAME_WORDS*16;
    localparam WW=$clog2(FRAME_WORDS+1),CW=$clog2(TOTAL_CHANNELS+1),SW=CW+7;
    localparam [SW-1:0] DENOMINATOR=TOTAL_CHANNELS;
    reg [WW-1:0] words;
    reg [CW-1:0] fused_sum;
    reg scale_pending,divide_busy,result_ready,result_pair;
    reg [SW-1:0] remainder;
    reg [6:0] percentage;
    reg [8:0] payload_hold;
    reg payload_toggle;
    wire [SW-1:0] extended_sum={{7{1'b0}},fused_sum};

    wire [SW-1:0] scaled_sum=(extended_sum<<6)+(extended_sum<<5)+(extended_sum<<2);
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            words<=0;fused_sum<=0;scale_pending<=0;divide_busy<=0;
            result_ready<=0;result_pair<=0;remainder<=0;percentage<=0;
            payload_hold<=0;payload_toggle<=0;
        end else if(frame_start)begin
            payload_hold<=result_ready?{1'b1,result_pair,percentage}:9'd0;
            payload_toggle<=~payload_toggle;
            words<=0;fused_sum<=0;scale_pending<=0;divide_busy<=0;result_ready<=0;
        end else begin
            if(word_valid && words<FRAME_WORDS)begin
                words<=words+1'b1;fused_sum<=fused_sum+fused_channels;
                if(words==FRAME_WORDS-1)begin scale_pending<=1;result_pair<=pair_used;end
            end
            if(scale_pending)begin
                scale_pending<=0;divide_busy<=1;remainder<=scaled_sum;percentage<=0;
            end else if(divide_busy)begin
                if(remainder>=DENOMINATOR)begin
                    remainder<=remainder-DENOMINATOR;percentage<=percentage+7'd1;
                end else begin divide_busy<=0;result_ready<=1;end
            end
        end
    end

    (* ASYNC_REG="TRUE" *) reg [8:0] payload_meta,payload_sync;
    (* ASYNC_REG="TRUE" *) reg [2:0] toggle_sync;
    reg toggle_seen;
    always @(posedge pixel_clk or negedge rst_n)begin
        if(!rst_n)begin
            payload_meta<=0;payload_sync<=0;toggle_sync<=0;toggle_seen<=0;O_diag<=0;
        end else begin
            payload_meta<=payload_hold;payload_sync<=payload_meta;
            toggle_sync<={toggle_sync[1:0],payload_toggle};
            if(toggle_sync[2]!=toggle_seen)begin O_diag<=payload_sync;toggle_seen<=toggle_sync[2];end
        end
    end
endmodule
