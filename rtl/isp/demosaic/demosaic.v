module demosaic #(
 parameter IMG_HEIGHT=720,IMG_WIDTH=1280,data_complete_delay=50,
 parameter BAYER_MODE="BGGR"
)(input I_clk,I_rst_n,input [39:0] axi4s_video_tdata,input [9:0] axi4s_video_tdest,
 input axi4s_video_tlast,axi4s_video_tvalid,axi4s_video_tuser,
 output axi4s_video_tready,output O_tlast,O_tuser,output [127:0] O_tdata,
 output O_tvalid,input O_tready);
 wire [31:0] raw,packed_raw;wire rv,rl,rf,pv,pl,pf;
 mipi_to_raw_converter unpack(.I_clk(I_clk),.I_rst_n(I_rst_n),
  .I_raw_tdata(axi4s_video_tdata),.I_raw_tdest(axi4s_video_tdest),
  .I_raw_tlast(axi4s_video_tlast),.I_raw_tvalid(axi4s_video_tvalid),.I_raw_tuser(axi4s_video_tuser),
  .I_raw_tready(axi4s_video_tready),.O_raw_tdata(raw),.O_raw_tlast(rl),
  .O_raw_tvalid(rv),.O_raw_tuser(rf),.O_raw_tready(O_tready));

 zhenghe #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),.DATA_WIDTH(32),
  .data_complete_delay(data_complete_delay)) normalize(.I_clk(I_clk),.I_rst_n(I_rst_n),
  .I_tlast(rl),.I_tuser(rf),.I_tvalid(rv),.I_tdata(raw),
  .O_tlast(pl),.O_tuser(pf),.O_tvalid(pv),.O_tdata(packed_raw));
 mhc_stream4 #(.WIDTH(IMG_WIDTH),.HEIGHT(IMG_HEIGHT),.BAYER_MODE(BAYER_MODE)) stream(
  .clk(I_clk),.rst(I_rst_n),.valid(pv),.sof(pf),.data(packed_raw),
  .ov(O_tvalid),.of(O_tuser),.ol(O_tlast),.rgb(O_tdata));
endmodule

module mhc_stream4 #(parameter WIDTH=1280,HEIGHT=720,BAYER_MODE="BGGR")(
 input clk,rst,valid,sof,input [31:0] data,output ov,of,ol,output [127:0] rgb);
 localparam GROUPS=WIDTH/4;
 reg [10:0] x,y;
 reg have_frame,frame_complete,tail_pending;
 reg [1:0] bank_base,previous_base;
 wire [1:0] next_base=have_frame ? bank_base+(HEIGHT%4) : 2'd0;
 wire [1:0] input_base=sof ? next_base : bank_base;
 wire [10:0] ex=sof ? 11'd0 : x;
 wire [10:0] ey=sof ? 11'd0 : y;

 wire render_tail=(sof ? frame_complete : tail_pending)&&(ey<2);
 wire [10:0] virtual_y=render_tail ? HEIGHT+ey : ey;
 wire [1:0] source_base=render_tail ? (sof ? bank_base : previous_base) : input_base;
 reg read_valid,read_real;
 reg [10:0] read_x,read_y;reg [31:0] read_data;reg [1:0] read_base;
 wire [31:0] bankout[0:3];
 genvar bank;
 generate for(bank=0;bank<4;bank=bank+1)begin:g_rows
  ram_d32970204f32 #(.DATA_WIDTH_A(32),.ADDR_WIDTH_A(9),.DATA_DEPTH_A(512),
   .DATA_WIDTH_B(32),.ADDR_WIDTH_B(9),.DATA_DEPTH_B(512),
   .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
   .WRITEMODE_A("READBEFOREWRITE"),.WRITEMODE_B("READBEFOREWRITE")) memory(
   .dia(data),.addra(ex[8:0]),.wea(valid&&((input_base+ey[1:0])%4==bank)),.clka(clk),
   .doa(bankout[bank]),.dib(32'd0),.addrb(9'd0),.web(1'b0),.clkb(clk),.dob());
 end endgenerate
 always @(posedge clk or negedge rst)begin
  if(!rst)begin
   x<=0;y<=0;have_frame<=0;frame_complete<=0;tail_pending<=0;
   bank_base<=0;previous_base<=0;read_valid<=0;read_real<=0;
   read_x<=0;read_y<=0;read_data<=0;read_base<=0;
  end else begin
   read_valid<=valid;read_real<=!render_tail;
   if(sof)begin
    x<=0;y<=0;have_frame<=1;frame_complete<=0;tail_pending<=frame_complete;
    previous_base<=bank_base;bank_base<=next_base;
   end
   if(valid)begin
    read_x<=ex;read_y<=virtual_y;read_data<=data;read_base<=source_base;
    if(ex==GROUPS-1)begin
     x<=0;y<=(ey==HEIGHT-1)?11'd0:ey+1'b1;
     if(ey==1)tail_pending<=0;
     if(ey==HEIGHT-1)begin frame_complete<=1;tail_pending<=1;end
    end else x<=ex+1'b1;
   end
  end
 end
 wire [31:0] rowword[0:4];
 genvar row;
 generate for(row=0;row<5;row=row+1)begin:g_select
  wire [1:0] relative_bank=read_y[1:0]+row;
  wire reflect_one=((row==1)&&(read_y==2))||((row==0)&&(read_y==3))||
      ((row==4)&&(read_y==HEIGHT))||((row==3)&&(read_y==HEIGHT+1));
  wire [1:0] source_bank=read_base+(relative_bank^{reflect_one,1'b0});
  wire current_word=read_real&&((row==4)||((row==0)&&(read_y==2)));
  assign rowword[row]=current_word?read_data:bankout[source_bank];
 end endgenerate
 reg [31:0] left[0:4],center[0:4];
 reg [63:0] window[0:4];
 reg tail,win_valid,win_first,win_last;reg [10:0] tail_y,win_y;
 integer i;
 always @(posedge clk or negedge rst)begin
  if(!rst)begin
   tail<=0;tail_y<=0;win_valid<=0;win_first<=0;win_last<=0;win_y<=0;
   for(i=0;i<5;i=i+1)begin left[i]<=0;center[i]<=0;window[i]<=0;end
  end else begin
   tail<=0;win_valid<=0;win_first<=0;win_last<=0;

   if(tail)begin
    win_valid<=1;win_last<=1;win_y<=tail_y;
    for(i=0;i<5;i=i+1)window[i]<={left[i][15:0],center[i],center[i][15:8],center[i][23:16]};
   end
   if(read_valid&&read_y>=2)begin
    if(read_x==0)begin
     for(i=0;i<5;i=i+1)begin center[i]<=rowword[i];left[i]<=0;end
    end else begin
     win_valid<=1;win_y<=read_y-2;win_first<=(read_x==1)&&(read_y==2);
     for(i=0;i<5;i=i+1)begin
      if(read_x==1)window[i]<={center[i][15:8],center[i][23:16],center[i],rowword[i][31:16]};
      else window[i]<={left[i][15:0],center[i],rowword[i][31:16]};
      left[i]<=center[i];center[i]<=rowword[i];
     end
    end
    if(read_x==GROUPS-1)begin tail<=1;tail_y<=read_y-2;end
   end
  end
 end
 mhc_kernel4 #(.BAYER_MODE(BAYER_MODE)) kernel(.clk(clk),.rst(rst),
  .valid(win_valid),.first(win_first),.last(win_last),.y(win_y),
  .w0(window[0]),.w1(window[1]),.w2(window[2]),.w3(window[3]),.w4(window[4]),
  .ov(ov),.of(of),.ol(ol),.rgb(rgb));
endmodule

module mhc_kernel4 #(parameter BAYER_MODE="BGGR")(
 input clk,rst,valid,first,last,input [10:0] y,input [63:0] w0,w1,w2,w3,w4,
 output ov,of,ol,output [127:0] rgb);
 reg [3:0] vp,fp,lp;
 always @(posedge clk or negedge rst)begin
  if(!rst)begin vp<=0;fp<=0;lp<=0;end
  else begin vp<={vp[2:0],valid};fp<={fp[2:0],first&&valid};lp<={lp[2:0],last&&valid};end
 end
 assign ov=vp[3];assign of=fp[3];assign ol=lp[3];
 genvar lane;
 generate for(lane=0;lane<4;lane=lane+1)begin:g_pixel
  mhc_pixel #(.BAYER_MODE(BAYER_MODE),.X_ODD(lane%2)) pixel(
   .clk(clk),.rst(rst),.valid(valid),.yodd(y[0]),
   .c(w2[47-8*lane-:8]),
   .n(w1[47-8*lane-:8]),.s(w3[47-8*lane-:8]),
   .w(w2[55-8*lane-:8]),.e(w2[39-8*lane-:8]),
   .nn(w0[47-8*lane-:8]),.ss(w4[47-8*lane-:8]),
   .ww(w2[63-8*lane-:8]),.ee(w2[31-8*lane-:8]),
   .nw(w1[55-8*lane-:8]),.ne(w1[39-8*lane-:8]),
   .sw(w3[55-8*lane-:8]),.se(w3[39-8*lane-:8]),.rgb(rgb[lane*32+:32]));
 end endgenerate
endmodule

module mhc_pixel #(parameter BAYER_MODE="BGGR",X_ODD=0)(
 input clk,rst,valid,yodd,input [7:0] c,n,s,w,e,nn,ss,ww,ee,nw,ne,sw,se,
 output reg [31:0] rgb);
 localparam RX=(BAYER_MODE=="BGGR"||BAYER_MODE=="GRBG")?1:0;
 localparam RY=(BAYER_MODE=="BGGR"||BAYER_MODE=="GBRG")?1:0;
 reg [9:0] axial,far_sum,diagonal;
 reg [8:0] horizontal,vertical,hfar,vfar;
 reg [7:0] c1,c2,c3;reg [2:0] site1,site2,site3;
 reg signed [13:0] pg,po,ph,pv,mg,mo,mh,mv;
 reg signed [13:0] ng,no,nh,nv;
 function [7:0] clip;
  input signed [13:0] value;
  reg signed [14:0] rounded;
  begin rounded=($signed(value)+15'sd8)>>>4;
   if(rounded<0)clip=0;else if(rounded>255)clip=255;else clip=rounded[7:0];end
 endfunction
 always @(posedge clk or negedge rst)begin
  if(!rst)begin
   axial<=0;far_sum<=0;diagonal<=0;horizontal<=0;vertical<=0;hfar<=0;vfar<=0;
   c1<=0;c2<=0;c3<=0;site1<=0;site2<=0;site3<=0;
   pg<=0;po<=0;ph<=0;pv<=0;mg<=0;mo<=0;mh<=0;mv<=0;
   ng<=0;no<=0;nh<=0;nv<=0;rgb<=0;
  end else begin
   if(valid)begin
    axial<={2'd0,n}+{2'd0,s}+{2'd0,w}+{2'd0,e};
    far_sum<={2'd0,nn}+{2'd0,ss}+{2'd0,ww}+{2'd0,ee};
    diagonal<={2'd0,nw}+{2'd0,ne}+{2'd0,sw}+{2'd0,se};
    horizontal<={1'd0,w}+{1'd0,e};vertical<={1'd0,n}+{1'd0,s};
    hfar<={1'd0,ww}+{1'd0,ee};vfar<={1'd0,nn}+{1'd0,ss};c1<=c;
    site1<={(X_ODD==RX)&&(yodd==RY),(X_ODD!=RX)&&(yodd!=RY),(yodd==RY)};
   end
   c2<=c1;site2<=site1;
   pg<=($signed({6'd0,c1})<<<3)+($signed({4'd0,axial})<<<2);
   mg<=$signed({4'd0,far_sum})<<<1;
   po<=($signed({6'd0,c1})<<<3)+($signed({6'd0,c1})<<<2)+($signed({4'd0,diagonal})<<<2);
   mo<=($signed({4'd0,far_sum})<<<1)+$signed({4'd0,far_sum});
   ph<=($signed({6'd0,c1})<<<3)+($signed({6'd0,c1})<<<1)+($signed({5'd0,horizontal})<<<3)+$signed({5'd0,vfar});
   mh<=($signed({4'd0,diagonal})<<<1)+($signed({5'd0,hfar})<<<1);
   pv<=($signed({6'd0,c1})<<<3)+($signed({6'd0,c1})<<<1)+($signed({5'd0,vertical})<<<3)+$signed({5'd0,hfar});
   mv<=($signed({4'd0,diagonal})<<<1)+($signed({5'd0,vfar})<<<1);
   ng<=pg-mg;no<=po-mo;nh<=ph-mh;nv<=pv-mv;c3<=c2;site3<=site2;
   if(site3[2])rgb<={8'd0,c3,clip(ng),clip(no)};
   else if(site3[1])rgb<={8'd0,clip(no),clip(ng),c3};
   else if(site3[0])rgb<={8'd0,clip(nh),c3,clip(nv)};
   else rgb<={8'd0,clip(nv),c3,clip(nh)};
  end
 end
endmodule
