`timescale 1ns/1ps
module raw_fixed_blc64(input wire [39:0] raw_data,output wire [39:0] corrected_data);
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:g_subtract
  wire [10:0] delta={1'b0,raw_data[g*10+:10]}-11'd64;
  assign corrected_data[g*10+:10]=delta[10]?10'd0:delta[9:0];
 end endgenerate
endmodule

`timescale 1ns/1ps

module raw_md_stats #(
 parameter IMG_WIDTH=1280,IMG_HEIGHT=720,
 parameter SETTLE_FRAMES=4,MAX_FRAME_GAP_CYCLES=3000000
)(
 input wire raw_clk,pixel_clk,rst_n,
 input wire [39:0] raw_data,input wire raw_valid,raw_user,raw_last,
 input wire [25:0] control_source,

 output reg [113:0] O_diag,output reg O_alive,output wire O_safe
);
 localparam WORDS=IMG_WIDTH/4,RW=8,RH=32,DEPTH=RW*RH;
 localparam X0=(WORDS-RW)/2,Y0=((IMG_HEIGHT-RH)/2)&~1;
 localparam AGE_W=$clog2(MAX_FRAME_GAP_CYCLES+1);
 reg [$clog2(WORDS+1)-1:0] word_x;
 reg [$clog2(IMG_HEIGHT+1)-1:0] row_y;
 reg seen,complete,bad,frame_control_bad;
 reg [7:0] frame_seq;reg [8:0] sample_words;
 reg [17:0] sum[0:3];reg [16:0] spatial_sum[0:3];
 reg [23:0] frame_control;
 reg [$clog2(SETTLE_FRAMES+1)-1:0] quiet_frames;
 reg [AGE_W-1:0] frame_age;
 (* ASYNC_REG="TRUE" *)reg [25:0] control_meta,control_sync;
 reg [25:0] last_control;
 wire control_ok=control_sync[25]&&!control_sync[24];
 wire control_changed=control_sync!=last_control;
 wire sof=raw_valid&&raw_user;
 wire timed_out=seen&&(frame_age>=MAX_FRAME_GAP_CYCLES);
 wire in_roi=word_x>=X0&&word_x<X0+RW&&row_y>=Y0&&row_y<Y0+RH;
 wire sample=raw_valid&&!raw_user&&seen&&!complete&&in_roi;
 function [9:0] abs10(input [9:0] a,b);begin abs10=a>=b?a-b:b-a;end endfunction
 wire [10:0] m0={1'b0,raw_data[9:0]}+{1'b0,raw_data[29:20]};
 wire [10:0] m1={1'b0,raw_data[19:10]}+{1'b0,raw_data[39:30]};
 wire [9:0] d0=abs10(raw_data[9:0],raw_data[29:20]);
 wire [9:0] d1=abs10(raw_data[19:10],raw_data[39:30]);
 wire frame_good=complete&&!bad&&sample_words==DEPTH;
 reg [113:0] payload_hold;
 reg request_toggle,acknowledge;
 (* ASYNC_REG="TRUE" *)reg [2:0] ack_sync,request_sync;
 (* ASYNC_REG="TRUE" *)reg [113:0] payload_meta,payload_sync;
 (* ASYNC_REG="TRUE" *)reg [1:0] health_meta,health_sync;
 wire [1:0] raw_health={seen&&!timed_out&&control_ok&&!control_changed&&
       quiet_frames>=SETTLE_FRAMES&&!frame_control_bad,seen&&!timed_out};
 assign O_safe=health_sync[1];
 integer n;
 always @(posedge raw_clk or negedge rst_n)begin
  if(!rst_n)begin control_meta<=0;control_sync<=0;ack_sync<=0;end
  else begin control_meta<=control_source;control_sync<=control_meta;ack_sync<={ack_sync[1:0],acknowledge};end
 end
 always @(posedge raw_clk or negedge rst_n)begin
  if(!rst_n)begin
   word_x<=0;row_y<=0;seen<=0;complete<=0;bad<=0;frame_control_bad<=1;
   frame_seq<=0;sample_words<=0;frame_control<=0;quiet_frames<=0;frame_age<=0;last_control<=0;
   payload_hold<=0;request_toggle<=0;
   for(n=0;n<4;n=n+1)begin sum[n]<=0;spatial_sum[n]<=0;end
  end else begin
   last_control<=control_sync;
   if(sof)frame_age<=0;
   else if(seen&&frame_age<MAX_FRAME_GAP_CYCLES)frame_age<=frame_age+1'b1;
   if(sof)begin
    if(seen)begin
     frame_seq<=frame_seq+1'b1;
     if(ack_sync[2]==request_toggle)begin
      for(n=0;n<4;n=n+1)begin
       payload_hold[n*10+:10]<=frame_good?(sum[n]>>8):10'd0;
       payload_hold[40+n*10+:10]<=frame_good?(spatial_sum[n]>>7):10'd0;
      end
      payload_hold[80]<=frame_good;payload_hold[81]<=!frame_good;
      payload_hold[89:82]<=frame_seq;payload_hold[105:90]<=frame_control[23:8];
      payload_hold[113:106]<=frame_control[7:0];request_toggle<=~request_toggle;
     end
    end
    if(seen&&frame_good&&!frame_control_bad&&control_ok&&!control_changed&&!timed_out)begin
     if(quiet_frames<SETTLE_FRAMES)quiet_frames<=quiet_frames+1'b1;
    end else quiet_frames<=0;
    frame_control<=control_sync[23:0];frame_control_bad<=!control_ok||control_changed;
    seen<=1;word_x<=1;row_y<=0;complete<=0;bad<=raw_last;sample_words<=0;
    for(n=0;n<4;n=n+1)begin sum[n]<=0;spatial_sum[n]<=0;end
   end else if(raw_valid&&seen)begin
    if(complete||raw_last!=(word_x==WORDS-1))bad<=1;
    if(raw_last)begin
     word_x<=0;if(row_y==IMG_HEIGHT-1)complete<=1;
     else if(row_y<IMG_HEIGHT)row_y<=row_y+1'b1;else bad<=1;
    end else if(word_x<WORDS)word_x<=word_x+1'b1;
    if(sample)begin
     sample_words<=sample_words+1'b1;
     if(!row_y[0])begin sum[0]<=sum[0]+m0;sum[1]<=sum[1]+m1;
      spatial_sum[0]<=spatial_sum[0]+d0;spatial_sum[1]<=spatial_sum[1]+d1;end
     else begin sum[2]<=sum[2]+m0;sum[3]<=sum[3]+m1;
      spatial_sum[2]<=spatial_sum[2]+d0;spatial_sum[3]<=spatial_sum[3]+d1;end
    end
   end
   if(!control_ok||control_changed||(timed_out&&!sof))begin quiet_frames<=0;frame_control_bad<=1;end
  end
 end
 always @(posedge pixel_clk or negedge rst_n)begin
  if(!rst_n)begin request_sync<=0;payload_meta<=0;payload_sync<=0;acknowledge<=0;
   O_diag<=0;health_meta<=0;health_sync<=0;O_alive<=0;end
  else begin
   request_sync<={request_sync[1:0],request_toggle};payload_meta<=payload_hold;payload_sync<=payload_meta;
   health_meta<=raw_health;health_sync<=health_meta;
   if(!health_sync[0])O_alive<=0;
   if(request_sync[2]!=acknowledge)begin O_diag<=payload_sync;acknowledge<=request_sync[2];O_alive<=health_sync[0];end
  end
 end
endmodule

module gamma_luma_stats #(parameter IMG_WIDTH=1280,IMG_HEIGHT=720)(
 input wire clk,rst_n,I_vsync,I_de,input wire [23:0] I_rgb,
 output reg [7:0] O_mean,output reg O_valid,output reg [19:0] O_pixels
);
 localparam [19:0] PIXELS=IMG_WIDTH*IMG_HEIGHT;
 wire [15:0] r={8'd0,I_rgb[23:16]},g={8'd0,I_rgb[15:8]},b={8'd0,I_rgb[7:0]};
 wire [15:0] rr=(r<<6)+(r<<3)+(r<<2)+r;
 wire [15:0] gg=(g<<7)+(g<<4)+(g<<2)+(g<<1);
 wire [15:0] bb=(b<<4)+(b<<3)+(b<<2)+b;
 wire [15:0] weighted=rr+gg+bb;
 reg [7:0] sample_y;
 reg sample_de,sample_vs,vs_d,seen;
 reg [31:0] acc,remainder;
 reg [19:0] count;
 reg [7:0] quotient;
 reg [2:0] bit_index;
 reg busy;
 wire start_frame=sample_vs&&!vs_d;
 wire [31:0] trial={12'd0,PIXELS}<<bit_index;
 wire take=remainder>=trial;
 wire [7:0] next_quotient=take?(quotient|(8'd1<<bit_index)):quotient;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin sample_y<=0;sample_de<=0;sample_vs<=0;vs_d<=0;end
  else begin sample_y<=weighted[15:8];sample_de<=I_de;sample_vs<=I_vsync;vs_d<=sample_vs;end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   seen<=0;acc<=0;count<=0;remainder<=0;quotient<=0;bit_index<=7;busy<=0;
   O_mean<=0;O_valid<=0;O_pixels<=0;
  end else if(start_frame)begin
   O_pixels<=count;O_valid<=0;O_mean<=0;
   busy<=seen&&count==PIXELS;remainder<=acc;quotient<=0;bit_index<=7;
   seen<=1;acc<=0;count<=0;
  end else begin
   if(seen&&!sample_vs&&sample_de)begin
    if(count<PIXELS+1'b1)count<=count+1'b1;
    if(count<PIXELS)acc<=acc+{24'd0,sample_y};
   end
   if(busy)begin
    quotient<=next_quotient;if(take)remainder<=remainder-trial;
    if(bit_index==0)begin O_mean<=next_quotient;O_valid<=1;busy<=0;end
    else bit_index<=bit_index-1'b1;
   end
  end
 end
endmodule

module raw_md_gamma_panel #(parameter PANEL_EN=1)(
 input wire clk,rst_n,I_vsync,I_de,
 input wire [23:0] I_rgb,input wire [113:0] diag,
 input wire alive,safe,input wire [7:0] luma,input wire luma_valid,
 input wire [7:0] gamma_luma,input wire gamma_valid,input wire [8:0] nr_diag,
 input wire [1:0] camera_status,
 output wire O_vsync,O_de,output wire [23:0] O_rgb
);
 reg vs_d,de_d;reg [11:0] x,y;
 reg [79:0] values;
 reg [7:0] gain_snap,luma_snap,gamma_snap,seq_snap;
 reg [6:0] percent_snap;
 reg nr_valid_snap,nr_pair_snap,valid_snap,error_snap,gamma_valid_snap,luma_valid_snap;
 reg [1:0] camera_snap;
 reg [3:0] field;reg [4:0] left;reg busy;
 reg [15:0] value;reg [19:0] work;reg [19:0] bcd[0:12];
 function [19:0] bcd_step(input [19:0] previous,input bit_in);
  reg [19:0] v;integer n;begin v=previous;
   for(n=0;n<5;n=n+1)if(v[n*4+:4]>=5)v[n*4+:4]=v[n*4+:4]+4'd3;
   bcd_step={v[18:0],bit_in};end
 endfunction
 function [15:0] select_number(input [3:0] f,input [79:0] numbers,input [7:0] ag,yy,yg,input [6:0] pct);
  begin case(f)
   1:select_number={8'd0,ag};2:select_number={8'd0,yy};3:select_number={9'd0,pct};
   4:select_number={6'd0,numbers[9:0]};5:select_number={6'd0,numbers[19:10]};
   6:select_number={6'd0,numbers[29:20]};7:select_number={6'd0,numbers[39:30]};
   8:select_number={6'd0,numbers[49:40]};9:select_number={6'd0,numbers[59:50]};
   10:select_number={6'd0,numbers[69:60]};11:select_number={6'd0,numbers[79:70]};
   12:select_number={8'd0,yg};default:select_number=0;
  endcase end
 endfunction
 wire [3:0] next_field=field+1'b1;
 wire [15:0] next_value=select_number(next_field,values,gain_snap,luma_snap,gamma_snap,percent_snap);
 wire [19:0] next_bcd=bcd_step(work,value[15]);
 integer n;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   vs_d<=0;de_d<=0;x<=0;y<=0;values<=0;gain_snap<=0;luma_snap<=0;gamma_snap<=0;seq_snap<=0;percent_snap<=0;
   nr_valid_snap<=0;nr_pair_snap<=0;valid_snap<=0;error_snap<=0;gamma_valid_snap<=0;luma_valid_snap<=0;camera_snap<=0;
   field<=0;left<=0;busy<=0;value<=0;work<=0;for(n=0;n<13;n=n+1)bcd[n]<=0;
  end else begin
   vs_d<=I_vsync;de_d<=I_de;
   if(I_vsync)y<=0;else if(de_d&&!I_de)y<=y+1'b1;
   if(I_de)x<=x+1'b1;else x<=0;
   if(I_vsync&&!vs_d)begin
    values<=diag[79:0];gain_snap<=diag[113:106];luma_snap<=luma;gamma_snap<=gamma_luma;seq_snap<=diag[89:82];
    valid_snap<=diag[80];error_snap<=diag[81];gamma_valid_snap<=gamma_valid;luma_valid_snap<=luma_valid;
    percent_snap<=nr_diag[6:0];nr_pair_snap<=nr_diag[7];nr_valid_snap<=nr_diag[8];camera_snap<=camera_status;
    field<=0;left<=16;busy<=1;value<=diag[105:90];work<=0;
   end else if(busy)begin
    work<=next_bcd;value<={value[14:0],1'b0};left<=left-1'b1;
    if(left==1)begin
     bcd[field]<=next_bcd;work<=0;left<=16;field<=next_field;value<=next_value;
     if(field==12)busy<=0;
    end
   end
  end
 end
 wire display_valid=valid_snap&&alive;
 function [7:0] digit(input [3:0] d);begin digit="0"+d;end endfunction
 function [7:0] hex_digit(input [3:0] d);begin hex_digit=d<10?"0"+d:"A"+d-10;end endfunction
 function [7:0] text_char(input [2:0] row,input [5:0] col);
  begin text_char=" ";case(row)
   0:case(col)
    0:text_char="N";1:text_char="R";2:text_char="2";3:text_char="-";4:text_char="G";5:text_char="1";6:text_char="6";
    8:text_char="B";9:text_char="0";10:text_char="6";11:text_char="4";
    13:text_char="E";14:text_char="X";15:text_char="P";16:text_char=":";
    17:text_char=digit(bcd[0][16+:4]);18:text_char=digit(bcd[0][12+:4]);19:text_char=digit(bcd[0][8+:4]);20:text_char=digit(bcd[0][4+:4]);21:text_char=digit(bcd[0][0+:4]);
    23:text_char="A";24:text_char="G";25:text_char=":";
    26:text_char=digit(bcd[1][8+:4]);27:text_char=digit(bcd[1][4+:4]);28:text_char=digit(bcd[1][0+:4]);
   endcase
   1:case(col)
    0:text_char="Y";1:text_char="0";2:text_char=":";
    3:text_char=luma_valid_snap?digit(bcd[2][8+:4]):"-";4:text_char=luma_valid_snap?digit(bcd[2][4+:4]):"-";5:text_char=luma_valid_snap?digit(bcd[2][0+:4]):"-";
    7:text_char="Y";8:text_char="G";9:text_char=":";
    10:text_char=gamma_valid_snap?digit(bcd[12][8+:4]):"-";11:text_char=gamma_valid_snap?digit(bcd[12][4+:4]):"-";12:text_char=gamma_valid_snap?digit(bcd[12][0+:4]):"-";
    14:text_char="P";15:text_char=nr_valid_snap?(nr_pair_snap?"1":"0"):"-";
    17:text_char="F";18:text_char=":";19:text_char=nr_valid_snap?digit(bcd[3][8+:4]):"-";20:text_char=nr_valid_snap?digit(bcd[3][4+:4]):"-";21:text_char=nr_valid_snap?digit(bcd[3][0+:4]):"-";22:text_char="%";
   endcase
   2:case(col)
    0:text_char="M";1:text_char="0";2:text_char=":";
    3:text_char=display_valid?digit(bcd[4][12+:4]):"-";4:text_char=display_valid?digit(bcd[4][8+:4]):"-";5:text_char=display_valid?digit(bcd[4][4+:4]):"-";6:text_char=display_valid?digit(bcd[4][0+:4]):"-";
    8:text_char="M";9:text_char="1";10:text_char=":";
    11:text_char=display_valid?digit(bcd[5][12+:4]):"-";12:text_char=display_valid?digit(bcd[5][8+:4]):"-";13:text_char=display_valid?digit(bcd[5][4+:4]):"-";14:text_char=display_valid?digit(bcd[5][0+:4]):"-";
    16:text_char="V";17:text_char=":";18:text_char=display_valid?"1":"0";
    20:text_char="X";21:text_char=":";22:text_char=error_snap?"1":"0";
    24:text_char="Q";25:text_char=":";26:text_char=hex_digit(seq_snap[7:4]);27:text_char=hex_digit(seq_snap[3:0]);
   endcase
   3:case(col)
    0:text_char="M";1:text_char="2";2:text_char=":";
    3:text_char=display_valid?digit(bcd[6][12+:4]):"-";4:text_char=display_valid?digit(bcd[6][8+:4]):"-";5:text_char=display_valid?digit(bcd[6][4+:4]):"-";6:text_char=display_valid?digit(bcd[6][0+:4]):"-";
    8:text_char="M";9:text_char="3";10:text_char=":";
    11:text_char=display_valid?digit(bcd[7][12+:4]):"-";12:text_char=display_valid?digit(bcd[7][8+:4]):"-";13:text_char=display_valid?digit(bcd[7][4+:4]):"-";14:text_char=display_valid?digit(bcd[7][0+:4]):"-";
    16:text_char="S";17:text_char=":";18:text_char="1";
    20:text_char="G";21:text_char=":";22:text_char=safe?"1":"0";
   endcase
   4:case(col)
    0:text_char="D";1:text_char="0";2:text_char=":";
    3:text_char=display_valid?digit(bcd[8][12+:4]):"-";4:text_char=display_valid?digit(bcd[8][8+:4]):"-";5:text_char=display_valid?digit(bcd[8][4+:4]):"-";6:text_char=display_valid?digit(bcd[8][0+:4]):"-";
    8:text_char="D";9:text_char="1";10:text_char=":";
    11:text_char=display_valid?digit(bcd[9][12+:4]):"-";12:text_char=display_valid?digit(bcd[9][8+:4]):"-";13:text_char=display_valid?digit(bcd[9][4+:4]):"-";14:text_char=display_valid?digit(bcd[9][0+:4]):"-";
    16:text_char="W";17:text_char=camera_snap[0]?"1":"0";19:text_char="E";20:text_char=camera_snap[1]?"1":"0";
   endcase
   5:case(col)
    0:text_char="D";1:text_char="2";2:text_char=":";
    3:text_char=display_valid?digit(bcd[10][12+:4]):"-";4:text_char=display_valid?digit(bcd[10][8+:4]):"-";5:text_char=display_valid?digit(bcd[10][4+:4]):"-";6:text_char=display_valid?digit(bcd[10][0+:4]):"-";
    8:text_char="D";9:text_char="3";10:text_char=":";
    11:text_char=display_valid?digit(bcd[11][12+:4]):"-";12:text_char=display_valid?digit(bcd[11][8+:4]):"-";13:text_char=display_valid?digit(bcd[11][4+:4]):"-";14:text_char=display_valid?digit(bcd[11][0+:4]):"-";
    16:text_char="A";17:text_char=":";18:text_char=alive?"1":"0";
   endcase
  endcase end
 endfunction
    function [39:0] font5x8(input [7:0] character);
        begin
            case (character)
                8'd46: font5x8 = 40'h0000000080;
                8'd48: font5x8 = 40'h74675cc5c0;
                8'd49: font5x8 = 40'h23084211c0;
                8'd50: font5x8 = 40'h74422223e0;
                8'd51: font5x8 = 40'hf042e087c0;
                8'd52: font5x8 = 40'h11952f8840;
                8'd53: font5x8 = 40'hfc21e087c0;
                8'd54: font5x8 = 40'h7421e8c5c0;
                8'd55: font5x8 = 40'hf844442100;
                8'd56: font5x8 = 40'h7462e8c5c0;
                8'd57: font5x8 = 40'h7462f085c0;
                8'd65: font5x8 = 40'h7463f8c620;
                8'd66: font5x8 = 40'hf463e8c7c0;
                8'd67: font5x8 = 40'h74610845c0;
                8'd68: font5x8 = 40'hf46318c7c0;
                8'd69: font5x8 = 40'hfc21e843e0;
                8'd70: font5x8 = 40'hfc21e84200;
                8'd71: font5x8 = 40'h746178c5e0;
                8'd73: font5x8 = 40'h71084211c0;
                8'd76: font5x8 = 40'h84210843e0;
                8'd77: font5x8 = 40'h8eeb58c620;
                8'd78: font5x8 = 40'h8e6b38c620;
                8'd80: font5x8 = 40'hf463e84200;
                8'd81: font5x8 = 40'h746318d5a0;
                8'd82: font5x8 = 40'hf463ea4a20;
                8'd83: font5x8 = 40'h7c20e087c0;
                8'd84: font5x8 = 40'hf908421080;
                8'd85: font5x8 = 40'h8c6318c5c0;
                8'd86: font5x8 = 40'h8c6318a880;
                8'd87: font5x8 = 40'h8c635ad540;
                8'd88: font5x8 = 40'h8c54454620;
                8'd89: font5x8 = 40'h8c54421080;
                8'd58: font5x8 = 40'h0108021000;
                8'd47: font5x8 = 40'h0884442200;
                8'd37: font5x8 = 40'hce888b1800;
                8'd45: font5x8 = 40'h0001f00000;
                8'd79: font5x8=40'h746318c5c0;
                default: font5x8 = 40'd0;
            endcase
        end
    endfunction
 wire region=x>=736&&x<1256&&y>=496&&y<648;
 wire [11:0] tx=x-740,ty=y-500;
 wire [2:0] row=ty<24?0:ty<48?1:ty<72?2:ty<96?3:ty<120?4:ty<144?5:ty<168?6:7;
 wire [11:0] ry=ty-row*24;
 wire [5:0] col=tx[9:4];wire [2:0] gx=tx[3:1],gy=ry[3:1];

 reg [39:0] glyph;
 reg [39:0] font_rom[0:127];
 integer font_i;
 initial for(font_i=0;font_i<128;font_i=font_i+1)font_rom[font_i]=font5x8(font_i);
 wire [5:0] fetch_col=col+(tx[3:0]>=10?6'd1:6'd0);
 wire [7:0] fetch_char=text_char(row,fetch_col);
 always @(posedge clk)glyph<=font_rom[fetch_char[6:0]];
 wire ink=tx<512&&ry<16&&gx<5&&glyph[39-(gy*5+gx)];
 assign O_vsync=I_vsync;assign O_de=I_de;
 assign O_rgb=(PANEL_EN&&region)?(ink?24'hffffff:24'd0):I_rgb;
endmodule

module raw_spatial_edge #(
 parameter ENABLE=1,parameter [9:0] EDGE_LIMIT=10'd16
)(input wire clk,rst_n,
 input wire [39:0] I_data,input wire I_valid,I_user,I_last,
 output reg [39:0] O_data,output reg O_valid,O_user,O_last);
 reg [39:0] center_word;
 reg [19:0] left_word;
 reg have_word,have_left,new_line,center_user,center_last;
 wire right_ok=I_valid&&!I_user&&!center_last;
 function [9:0] smooth(input [9:0] a,c,b,input eligible);
  reg [10:0] da,db,negative_limit;
  reg [11:0] total;
  reg [10:0] rounded;
  begin

   da={1'b0,a}-{1'b0,c};db={1'b0,b}-{1'b0,c};
   negative_limit=-{1'b0,EDGE_LIMIT};
   total={2'b0,a}+{1'b0,c,1'b0}+{2'b0,b};

   rounded={1'b0,total[11:2]}+(total[1]&&(total[0]||total[2]));
   smooth=ENABLE&&eligible&&
      (da<={1'b0,EDGE_LIMIT}||((EDGE_LIMIT!=0)&&da>=negative_limit))&&
      (db<={1'b0,EDGE_LIMIT}||((EDGE_LIMIT!=0)&&db>=negative_limit))?rounded[9:0]:c;
  end
 endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   center_word<=0;left_word<=0;have_word<=0;have_left<=0;new_line<=1;
   center_user<=0;center_last<=0;O_data<=0;O_valid<=0;O_user<=0;O_last<=0;
  end else begin
   O_valid<=0;O_user<=0;O_last<=0;

   if(have_word&&(I_valid||center_last))begin
    O_valid<=1;O_user<=center_user;O_last<=center_last;
    O_data[9:0]<=smooth(left_word[9:0],center_word[9:0],center_word[29:20],have_left);
    O_data[19:10]<=smooth(left_word[19:10],center_word[19:10],center_word[39:30],have_left);
    O_data[29:20]<=smooth(center_word[9:0],center_word[29:20],I_data[9:0],right_ok);
    O_data[39:30]<=smooth(center_word[19:10],center_word[39:30],I_data[19:10],right_ok);
    have_word<=0;
   end
   if(I_valid)begin
    center_word<=I_data;center_user<=I_user;center_last<=I_last;have_word<=1;
    have_left<=have_word&&!new_line&&!I_user&&!center_last;
    left_word<=center_word[39:20];
    new_line<=I_last;
   end
  end
 end
endmodule
