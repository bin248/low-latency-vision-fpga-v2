`timescale 1ns / 1ps

module osd_text #(
    parameter [11:0] X0 = 12'd24,
    parameter [11:0] Y0 = 12'd676
)(
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire [2:0]  I_mode,
    output wire        O_pixel,
    output wire        O_region
);
    localparam OSD_W = 100;
    localparam OSD_H = 27;
    localparam LEFT  = 2;

    localparam [4:0] CH_SPACE = 5'd15;

    wire [11:0] tx = I_x - X0;
    wire [11:0] ty = I_y - Y0;

    assign O_region = (I_x >= X0) && (I_x < X0 + OSD_W) &&
                      (I_y >= Y0) && (I_y < Y0 + OSD_H);

    reg [4:0] s0, s1, s2, s3;
    always @* begin
        case (I_mode)
            3'd0: begin s0 = 5'd0; s1 = 5'd1; s2 = 5'd2; s3 = 5'd3; end
            3'd1: begin s0 = 5'd4; s1 = 5'd5; s2 = 5'd6; s3 = 5'd7; end
            3'd2: begin s0 = 5'd8; s1 = 5'd9; s2 = 5'd10; s3 = 5'd15; end
            3'd4: begin s0=16; s1=17; s2=18; s3=19; end
            3'd5: begin s0=20; s1=21; s2=22; s3=23; end
            3'd6: begin s0=24; s1=25; s2=15; s3=15; end
            default: begin s0 = 5'd11; s1 = 5'd12; s2 = 5'd13; s3 = 5'd14; end
        endcase
    end

    wire [11:0] off = tx - LEFT;
    wire [2:0] slot = (off < 12'd24) ? 3'd0 :
                      (off < 12'd48) ? 3'd1 :
                      (off < 12'd72) ? 3'd2 :
                      (off < 12'd96) ? 3'd3 : 3'd4;
    wire [11:0] slot24 = ({9'd0, slot} << 4) + ({9'd0, slot} << 3);
    wire [11:0] col = off - slot24;
    wire [11:0] row = ty;

    reg [4:0] cid;
    always @* begin
        case (slot)
            3'd0: cid = s0;
            3'd1: cid = s1;
            3'd2: cid = s2;
            3'd3: cid = s3;
            default: cid = CH_SPACE;
        endcase
    end

    function [23:0] glyph_row(input [4:0] c, input [4:0] r);
        begin
            case ({c, r})
                10'h203: glyph_row=24'h0000C0;
                10'h204: glyph_row=24'h0600C0;
                10'h205: glyph_row=24'h0780C0;
                10'h206: glyph_row=24'h01C0C0;
                10'h207: glyph_row=24'h0080C0;
                10'h208: glyph_row=24'h003FFF;
                10'h209: glyph_row=24'h003FFF;
                10'h20A: glyph_row=24'h0E30C3;
                10'h20B: glyph_row=24'h0F30C3;
                10'h20C: glyph_row=24'h0330C3;
                10'h20D: glyph_row=24'h0030C3;
                10'h20E: glyph_row=24'h003FFF;
                10'h20F: glyph_row=24'h013FFF;
                10'h210: glyph_row=24'h01B0C3;
                10'h211: glyph_row=24'h03B0C3;
                10'h212: glyph_row=24'h0330C3;
                10'h213: glyph_row=24'h0330C3;
                10'h214: glyph_row=24'h063FFF;
                10'h215: glyph_row=24'h0E3FFF;
                10'h216: glyph_row=24'h0C3003;
                10'h217: glyph_row=24'h0C3003;
                10'h224: glyph_row=24'h0FFFFF;
                10'h225: glyph_row=24'h07FFFF;
                10'h228: glyph_row=24'h00FFF0;
                10'h229: glyph_row=24'h006633;
                10'h22A: glyph_row=24'h0C4633;
                10'h22B: glyph_row=24'h0C4633;
                10'h22C: glyph_row=24'h0C7FF3;
                10'h22D: glyph_row=24'h0C7FF3;
                10'h22E: glyph_row=24'h0C4633;
                10'h22F: glyph_row=24'h0C4633;
                10'h230: glyph_row=24'h0C4633;
                10'h231: glyph_row=24'h0CFFF3;
                10'h232: glyph_row=24'h0CFFF3;
                10'h233: glyph_row=24'h0C0003;
                10'h234: glyph_row=24'h0C0003;
                10'h235: glyph_row=24'h0FFFFF;
                10'h236: glyph_row=24'h0FFFFF;
                10'h237: glyph_row=24'h000003;
                10'h243: glyph_row=24'h03FFF8;
                10'h244: glyph_row=24'h03FFF8;
                10'h245: glyph_row=24'h030018;
                10'h246: glyph_row=24'h030018;
                10'h247: glyph_row=24'h030098;
                10'h248: glyph_row=24'h0320D8;
                10'h249: glyph_row=24'h037198;
                10'h24A: glyph_row=24'h033198;
                10'h24B: glyph_row=24'h031B18;
                10'h24C: glyph_row=24'h030F18;
                10'h24D: glyph_row=24'h030E18;
                10'h24E: glyph_row=24'h030618;
                10'h24F: glyph_row=24'h060F18;
                10'h250: glyph_row=24'h061F98;
                10'h251: glyph_row=24'h063998;
                10'h252: glyph_row=24'h0671CC;
                10'h253: glyph_row=24'h06E0CD;
                10'h254: glyph_row=24'h0C40CD;
                10'h255: glyph_row=24'h0C000F;
                10'h256: glyph_row=24'h1C0007;
                10'h257: glyph_row=24'h180003;
                10'h263: glyph_row=24'h018180;
                10'h264: glyph_row=24'h018180;
                10'h265: glyph_row=24'h018380;
                10'h266: glyph_row=24'h0183FE;
                10'h267: glyph_row=24'h0D870C;
                10'h268: glyph_row=24'h0FFF0C;
                10'h269: glyph_row=24'h039D98;
                10'h26A: glyph_row=24'h0388F8;
                10'h26B: glyph_row=24'h03C0F0;
                10'h26C: glyph_row=24'h07E0F0;
                10'h26D: glyph_row=24'h07E3DE;
                10'h26E: glyph_row=24'h07BF0F;
                10'h26F: glyph_row=24'h0D9C03;
                10'h270: glyph_row=24'h0D87FE;
                10'h271: glyph_row=24'h198606;
                10'h272: glyph_row=24'h098606;
                10'h273: glyph_row=24'h018606;
                10'h274: glyph_row=24'h018606;
                10'h275: glyph_row=24'h0187FE;
                10'h276: glyph_row=24'h0187FE;
                10'h277: glyph_row=24'h018606;
                10'h282: glyph_row=24'h010040;
                10'h283: glyph_row=24'h018060;
                10'h284: glyph_row=24'h018060;
                10'h285: glyph_row=24'h01807F;
                10'h286: glyph_row=24'h018060;
                10'h287: glyph_row=24'h1FF060;
                10'h288: glyph_row=24'h1BB060;
                10'h289: glyph_row=24'h19B7FF;
                10'h28A: glyph_row=24'h19B7FF;
                10'h28B: glyph_row=24'h19B603;
                10'h28C: glyph_row=24'h19B663;
                10'h28D: glyph_row=24'h19B663;
                10'h28E: glyph_row=24'h19B663;
                10'h28F: glyph_row=24'h19B663;
                10'h290: glyph_row=24'h19B663;
                10'h291: glyph_row=24'h19B663;
                10'h292: glyph_row=24'h19F6C3;
                10'h293: glyph_row=24'h19C0D8;
                10'h294: glyph_row=24'h01819E;
                10'h295: glyph_row=24'h018387;
                10'h296: glyph_row=24'h018F03;
                10'h297: glyph_row=24'h018C01;
                10'h2A3: glyph_row=24'h006070;
                10'h2A4: glyph_row=24'h003060;
                10'h2A5: glyph_row=24'h0030C0;
                10'h2A6: glyph_row=24'h0FFFFF;
                10'h2A7: glyph_row=24'h07FFFF;
                10'h2A8: glyph_row=24'h000C00;
                10'h2A9: glyph_row=24'h000C00;
                10'h2AA: glyph_row=24'h03FFFE;
                10'h2AB: glyph_row=24'h001C00;
                10'h2AC: glyph_row=24'h001800;
                10'h2AD: glyph_row=24'h1FFFFF;
                10'h2AE: glyph_row=24'h1FFFFF;
                10'h2AF: glyph_row=24'h007000;
                10'h2B0: glyph_row=24'h006000;
                10'h2B1: glyph_row=24'h00FFFC;
                10'h2B2: glyph_row=24'h01BFFC;
                10'h2B3: glyph_row=24'h070180;
                10'h2B4: glyph_row=24'h0E0180;
                10'h2B5: glyph_row=24'h1C0180;
                10'h2B6: glyph_row=24'h09FFFF;
                10'h2B7: glyph_row=24'h01FFFF;
                10'h2C2: glyph_row=24'h010040;
                10'h2C3: glyph_row=24'h030066;
                10'h2C4: glyph_row=24'h030066;
                10'h2C5: glyph_row=24'h030060;
                10'h2C6: glyph_row=24'h031FFF;
                10'h2C7: glyph_row=24'h1FDFFF;
                10'h2C8: glyph_row=24'h1FE060;
                10'h2C9: glyph_row=24'h030060;
                10'h2CA: glyph_row=24'h030FFF;
                10'h2CB: glyph_row=24'h030FFF;
                10'h2CC: glyph_row=24'h03CC63;
                10'h2CD: glyph_row=24'h03CC63;
                10'h2CE: glyph_row=24'h1F8FFF;
                10'h2CF: glyph_row=24'h1F0FFF;
                10'h2D0: glyph_row=24'h030C63;
                10'h2D1: glyph_row=24'h030C63;
                10'h2D2: glyph_row=24'h030FFF;
                10'h2D3: glyph_row=24'h030FFF;
                10'h2D4: glyph_row=24'h030C63;
                10'h2D5: glyph_row=24'h030C63;
                10'h2D6: glyph_row=24'h0F0C6F;
                10'h2D7: glyph_row=24'h0E0C6F;
                10'h2D8: glyph_row=24'h000800;
                10'h2E3: glyph_row=24'h018000;
                10'h2E4: glyph_row=24'h018FFE;
                10'h2E5: glyph_row=24'h018FFE;
                10'h2E6: glyph_row=24'h018C06;
                10'h2E7: glyph_row=24'h018C06;
                10'h2E8: glyph_row=24'h1FEC06;
                10'h2E9: glyph_row=24'h1FEC06;
                10'h2EA: glyph_row=24'h018FFE;
                10'h2EB: glyph_row=24'h018FFE;
                10'h2EC: glyph_row=24'h01A060;
                10'h2ED: glyph_row=24'h01E060;
                10'h2EE: glyph_row=24'h0FCC60;
                10'h2EF: glyph_row=24'h1F8C7F;
                10'h2F0: glyph_row=24'h098C7F;
                10'h2F1: glyph_row=24'h018C60;
                10'h2F2: glyph_row=24'h019C60;
                10'h2F3: glyph_row=24'h019E60;
                10'h2F4: glyph_row=24'h01BF60;
                10'h2F5: glyph_row=24'h01B3E0;
                10'h2F6: glyph_row=24'h07F0FF;
                10'h2F7: glyph_row=24'h07201F;
                10'h303: glyph_row=24'h020060;
                10'h304: glyph_row=24'h070060;
                10'h305: glyph_row=24'h038060;
                10'h306: glyph_row=24'h01C060;
                10'h307: glyph_row=24'h00C060;
                10'h308: glyph_row=24'h000060;
                10'h309: glyph_row=24'h000060;
                10'h30A: glyph_row=24'h1FBFFF;
                10'h30B: glyph_row=24'h1FBFFF;
                10'h30C: glyph_row=24'h018060;
                10'h30D: glyph_row=24'h018060;
                10'h30E: glyph_row=24'h018060;
                10'h30F: glyph_row=24'h018060;
                10'h310: glyph_row=24'h018060;
                10'h311: glyph_row=24'h01B060;
                10'h312: glyph_row=24'h01B060;
                10'h313: glyph_row=24'h01E060;
                10'h314: glyph_row=24'h01C060;
                10'h315: glyph_row=24'h038060;
                10'h316: glyph_row=24'h010060;
                10'h317: glyph_row=24'h000060;
                10'h323: glyph_row=24'h04E460;
                10'h324: glyph_row=24'h0ECCE0;
                10'h325: glyph_row=24'h064CC0;
                10'h326: glyph_row=24'h0248C0;
                10'h327: glyph_row=24'h0FFEC1;
                10'h328: glyph_row=24'h0FFFFF;
                10'h329: glyph_row=24'h01C186;
                10'h32A: glyph_row=24'h03F986;
                10'h32B: glyph_row=24'h0E5F86;
                10'h32C: glyph_row=24'h1C4B8C;
                10'h32D: glyph_row=24'h00C7CC;
                10'h32E: glyph_row=24'h01C2CC;
                10'h32F: glyph_row=24'h1FFCCC;
                10'h330: glyph_row=24'h039C6C;
                10'h331: glyph_row=24'h031878;
                10'h332: glyph_row=24'h079838;
                10'h333: glyph_row=24'h03F838;
                10'h334: glyph_row=24'h007C78;
                10'h335: glyph_row=24'h00E4EE;
                10'h336: glyph_row=24'h078387;
                10'h337: glyph_row=24'h0E0703;
                9'h004 : glyph_row = 24'h100008;
                9'h005 : glyph_row = 24'h1FFFF8;
                9'h006 : glyph_row = 24'h101C08;
                9'h007 : glyph_row = 24'h001C00;
                9'h008 : glyph_row = 24'h001C00;
                9'h009 : glyph_row = 24'h001C00;
                9'h00A : glyph_row = 24'h061C00;
                9'h00B : glyph_row = 24'h061C00;
                9'h00C : glyph_row = 24'h061FF8;
                9'h00D : glyph_row = 24'h061FF8;
                9'h00E : glyph_row = 24'h061C00;
                9'h00F : glyph_row = 24'h061C00;
                9'h010 : glyph_row = 24'h061C00;
                9'h011 : glyph_row = 24'h061C00;
                9'h012 : glyph_row = 24'h061C00;
                9'h013 : glyph_row = 24'h061C00;
                9'h014 : glyph_row = 24'h061C00;
                9'h015 : glyph_row = 24'h3FFFFC;
                9'h016 : glyph_row = 24'h7FFFFC;
                9'h022 : glyph_row = 24'h001800;
                9'h023 : glyph_row = 24'h061860;
                9'h024 : glyph_row = 24'h061860;
                9'h025 : glyph_row = 24'h0318C0;
                9'h026 : glyph_row = 24'h0319C0;
                9'h027 : glyph_row = 24'h3FFFFC;
                9'h028 : glyph_row = 24'h30000C;
                9'h029 : glyph_row = 24'h30000C;
                9'h02A : glyph_row = 24'h37FFEC;
                9'h02B : glyph_row = 24'h07FFE0;
                9'h02C : glyph_row = 24'h060060;
                9'h02D : glyph_row = 24'h07FFE0;
                9'h02E : glyph_row = 24'h07FFE0;
                9'h02F : glyph_row = 24'h001800;
                9'h030 : glyph_row = 24'h001800;
                9'h031 : glyph_row = 24'h1FFFF8;
                9'h032 : glyph_row = 24'h1C1818;
                9'h033 : glyph_row = 24'h181818;
                9'h034 : glyph_row = 24'h181818;
                9'h035 : glyph_row = 24'h1818F8;
                9'h036 : glyph_row = 24'h1818F0;
                9'h037 : glyph_row = 24'h001800;
                9'h038 : glyph_row = 24'h001800;
                9'h042 : glyph_row = 24'h000460;
                9'h043 : glyph_row = 24'h0C0460;
                9'h044 : glyph_row = 24'h0C7FFC;
                9'h045 : glyph_row = 24'h0C7FFC;
                9'h046 : glyph_row = 24'h0C0460;
                9'h047 : glyph_row = 24'h0E0460;
                9'h048 : glyph_row = 24'h7FBFF8;
                9'h049 : glyph_row = 24'h0E3FF8;
                9'h04A : glyph_row = 24'h0C3008;
                9'h04B : glyph_row = 24'h0C3FF8;
                9'h04C : glyph_row = 24'h1F3FF8;
                9'h04D : glyph_row = 24'h1FB008;
                9'h04E : glyph_row = 24'h3DBFF8;
                9'h04F : glyph_row = 24'h3C9FF8;
                9'h050 : glyph_row = 24'h6C0100;
                9'h051 : glyph_row = 24'h2C7FFC;
                9'h052 : glyph_row = 24'h0C7FFE;
                9'h053 : glyph_row = 24'h0C03C0;
                9'h054 : glyph_row = 24'h0C0660;
                9'h055 : glyph_row = 24'h0C1C38;
                9'h056 : glyph_row = 24'h0C781E;
                9'h057 : glyph_row = 24'h0C600E;
                9'h062 : glyph_row = 24'h000C00;
                9'h063 : glyph_row = 24'h000E40;
                9'h064 : glyph_row = 24'h000EE0;
                9'h065 : glyph_row = 24'h000E70;
                9'h066 : glyph_row = 24'h000E20;
                9'h067 : glyph_row = 24'h7FFFFC;
                9'h068 : glyph_row = 24'h7FFFFC;
                9'h069 : glyph_row = 24'h000E00;
                9'h06A : glyph_row = 24'h000600;
                9'h06B : glyph_row = 24'h000600;
                9'h06C : glyph_row = 24'h1FF600;
                9'h06D : glyph_row = 24'h1FF600;
                9'h06E : glyph_row = 24'h030300;
                9'h06F : glyph_row = 24'h030300;
                9'h070 : glyph_row = 24'h030300;
                9'h071 : glyph_row = 24'h030380;
                9'h072 : glyph_row = 24'h030180;
                9'h073 : glyph_row = 24'h03F9C6;
                9'h074 : glyph_row = 24'h07F0EE;
                9'h075 : glyph_row = 24'h3F007E;
                9'h076 : glyph_row = 24'h38003C;
                9'h077 : glyph_row = 24'h00001C;
                9'h082 : glyph_row = 24'h000600;
                9'h083 : glyph_row = 24'h180600;
                9'h084 : glyph_row = 24'h180600;
                9'h085 : glyph_row = 24'h1C0600;
                9'h086 : glyph_row = 24'h0C0600;
                9'h087 : glyph_row = 24'h0CFFF8;
                9'h088 : glyph_row = 24'h00FFF8;
                9'h089 : glyph_row = 24'h000618;
                9'h08A : glyph_row = 24'h000618;
                9'h08B : glyph_row = 24'h7C0C18;
                9'h08C : glyph_row = 24'h7C0C18;
                9'h08D : glyph_row = 24'h0C0C18;
                9'h08E : glyph_row = 24'h0C1C18;
                9'h08F : glyph_row = 24'h0C1818;
                9'h090 : glyph_row = 24'h0C3818;
                9'h091 : glyph_row = 24'h0C7038;
                9'h092 : glyph_row = 24'h0CE1F8;
                9'h093 : glyph_row = 24'h0C40F0;
                9'h094 : glyph_row = 24'h1F0000;
                9'h095 : glyph_row = 24'h33E000;
                9'h096 : glyph_row = 24'h70FFFE;
                9'h097 : glyph_row = 24'h201FFC;
                9'h0A2 : glyph_row = 24'h000800;
                9'h0A3 : glyph_row = 24'h0C0C00;
                9'h0A4 : glyph_row = 24'h0C0C00;
                9'h0A5 : glyph_row = 24'h181FF0;
                9'h0A6 : glyph_row = 24'h181870;
                9'h0A7 : glyph_row = 24'h331860;
                9'h0A8 : glyph_row = 24'h333FE0;
                9'h0A9 : glyph_row = 24'h671060;
                9'h0AA : glyph_row = 24'h7E40E6;
                9'h0AB : glyph_row = 24'h7CFFFE;
                9'h0AC : glyph_row = 24'h0C0E00;
                9'h0AD : glyph_row = 24'h181E18;
                9'h0AE : glyph_row = 24'h187B78;
                9'h0AF : glyph_row = 24'h33E7F0;
                9'h0B0 : glyph_row = 24'h3F0DB0;
                9'h0B1 : glyph_row = 24'h3039D0;
                9'h0B2 : glyph_row = 24'h00F3D8;
                9'h0B3 : glyph_row = 24'h0066D8;
                9'h0B4 : glyph_row = 24'h7F1CCE;
                9'h0B5 : glyph_row = 24'h7E78CE;
                9'h0B6 : glyph_row = 24'h20E3C0;
                9'h0B7 : glyph_row = 24'h004780;
                9'h0B8 : glyph_row = 24'h000200;
                9'h0C3 : glyph_row = 24'h060300;
                9'h0C4 : glyph_row = 24'h060700;
                9'h0C5 : glyph_row = 24'h040780;
                9'h0C6 : glyph_row = 24'h040CC0;
                9'h0C7 : glyph_row = 24'h3F8CE0;
                9'h0C8 : glyph_row = 24'h7F9870;
                9'h0C9 : glyph_row = 24'h0C383C;
                9'h0CA : glyph_row = 24'h0C7FDE;
                9'h0CB : glyph_row = 24'h0CEFC4;
                9'h0CC : glyph_row = 24'h1C4000;
                9'h0CD : glyph_row = 24'h1F0618;
                9'h0CE : glyph_row = 24'h3FB718;
                9'h0CF : glyph_row = 24'h35B338;
                9'h0D0 : glyph_row = 24'h643B30;
                9'h0D1 : glyph_row = 24'h6419B0;
                9'h0D2 : glyph_row = 24'h041960;
                9'h0D3 : glyph_row = 24'h041860;
                9'h0D4 : glyph_row = 24'h0400C0;
                9'h0D5 : glyph_row = 24'h04FFFC;
                9'h0D6 : glyph_row = 24'h06FFFC;
                9'h0D7 : glyph_row = 24'h060000;
                9'h0E3 : glyph_row = 24'h30000C;
                9'h0E4 : glyph_row = 24'h39FE0C;
                9'h0E5 : glyph_row = 24'h1DFE0C;
                9'h0E6 : glyph_row = 24'h0D866C;
                9'h0E7 : glyph_row = 24'h01866C;
                9'h0E8 : glyph_row = 24'h01B66C;
                9'h0E9 : glyph_row = 24'h21B66C;
                9'h0EA : glyph_row = 24'h79B66C;
                9'h0EB : glyph_row = 24'h19B66C;
                9'h0EC : glyph_row = 24'h09B66C;
                9'h0ED : glyph_row = 24'h01B66C;
                9'h0EE : glyph_row = 24'h01B66C;
                9'h0EF : glyph_row = 24'h0DB66C;
                9'h0F0 : glyph_row = 24'h0DB66C;
                9'h0F1 : glyph_row = 24'h1C706C;
                9'h0F2 : glyph_row = 24'h18686C;
                9'h0F3 : glyph_row = 24'h386C0C;
                9'h0F4 : glyph_row = 24'h30CE0C;
                9'h0F5 : glyph_row = 24'h71C70C;
                9'h0F6 : glyph_row = 24'h61833C;
                9'h0F7 : glyph_row = 24'h030038;
                9'h106 : glyph_row = 24'h0FFFF0;
                9'h107 : glyph_row = 24'h0FFFF0;
                9'h108 : glyph_row = 24'h0FFFF0;
                9'h113 : glyph_row = 24'h200004;
                9'h114 : glyph_row = 24'h7FFFFE;
                9'h115 : glyph_row = 24'h7FFFFE;
                9'h123 : glyph_row = 24'h030300;
                9'h124 : glyph_row = 24'h070300;
                9'h125 : glyph_row = 24'h06FFFC;
                9'h126 : glyph_row = 24'h06FFFC;
                9'h127 : glyph_row = 24'h0C0300;
                9'h128 : glyph_row = 24'h0C0700;
                9'h129 : glyph_row = 24'h1C3FF0;
                9'h12A : glyph_row = 24'h3C3030;
                9'h12B : glyph_row = 24'h3C3030;
                9'h12C : glyph_row = 24'h7C3FF0;
                9'h12D : glyph_row = 24'h2C3FF0;
                9'h12E : glyph_row = 24'h0C3030;
                9'h12F : glyph_row = 24'h0C3FF0;
                9'h130 : glyph_row = 24'h0C3FF0;
                9'h131 : glyph_row = 24'h0C3030;
                9'h132 : glyph_row = 24'h0C3FF0;
                9'h133 : glyph_row = 24'h0C3FF0;
                9'h134 : glyph_row = 24'h0C3030;
                9'h135 : glyph_row = 24'h0DFFFE;
                9'h136 : glyph_row = 24'h0DFFFE;
                9'h137 : glyph_row = 24'h0C0000;
                9'h143 : glyph_row = 24'h030600;
                9'h144 : glyph_row = 24'h038600;
                9'h145 : glyph_row = 24'h030600;
                9'h146 : glyph_row = 24'h070608;
                9'h147 : glyph_row = 24'h06061C;
                9'h148 : glyph_row = 24'h0E0638;
                9'h149 : glyph_row = 24'h1E0670;
                9'h14A : glyph_row = 24'h1E06E0;
                9'h14B : glyph_row = 24'h3607C0;
                9'h14C : glyph_row = 24'h760780;
                9'h14D : glyph_row = 24'h260700;
                9'h14E : glyph_row = 24'h061E00;
                9'h14F : glyph_row = 24'h063E00;
                9'h150 : glyph_row = 24'h06F600;
                9'h151 : glyph_row = 24'h06C600;
                9'h152 : glyph_row = 24'h060600;
                9'h153 : glyph_row = 24'h060606;
                9'h154 : glyph_row = 24'h06060E;
                9'h155 : glyph_row = 24'h06060E;
                9'h156 : glyph_row = 24'h0607FC;
                9'h157 : glyph_row = 24'h0603F8;
                9'h163 : glyph_row = 24'h00E000;
                9'h164 : glyph_row = 24'h01C000;
                9'h165 : glyph_row = 24'h01FF80;
                9'h166 : glyph_row = 24'h03FF80;
                9'h167 : glyph_row = 24'h070300;
                9'h168 : glyph_row = 24'h0E0700;
                9'h169 : glyph_row = 24'h3C0600;
                9'h16A : glyph_row = 24'h3FFFF0;
                9'h16B : glyph_row = 24'h061C30;
                9'h16C : glyph_row = 24'h061830;
                9'h16D : glyph_row = 24'h061830;
                9'h16E : glyph_row = 24'h061830;
                9'h16F : glyph_row = 24'h07FFF0;
                9'h170 : glyph_row = 24'h060030;
                9'h171 : glyph_row = 24'h060030;
                9'h172 : glyph_row = 24'h060000;
                9'h173 : glyph_row = 24'h060000;
                9'h174 : glyph_row = 24'h06000C;
                9'h175 : glyph_row = 24'h06000C;
                9'h176 : glyph_row = 24'h07FFF8;
                9'h177 : glyph_row = 24'h03FFF0;
                9'h183 : glyph_row = 24'h007808;
                9'h184 : glyph_row = 24'h3FFC1C;
                9'h185 : glyph_row = 24'h3F8038;
                9'h186 : glyph_row = 24'h010C70;
                9'h187 : glyph_row = 24'h318CE0;
                9'h188 : glyph_row = 24'h399BC0;
                9'h189 : glyph_row = 24'h199980;
                9'h18A : glyph_row = 24'h18300C;
                9'h18B : glyph_row = 24'h01801C;
                9'h18C : glyph_row = 24'h018038;
                9'h18D : glyph_row = 24'h3FFC70;
                9'h18E : glyph_row = 24'h3FFDE0;
                9'h18F : glyph_row = 24'h038380;
                9'h190 : glyph_row = 24'h07A304;
                9'h191 : glyph_row = 24'h07F00E;
                9'h192 : glyph_row = 24'h0DB81C;
                9'h193 : glyph_row = 24'h1D9C38;
                9'h194 : glyph_row = 24'h398CF0;
                9'h195 : glyph_row = 24'h7181C0;
                9'h196 : glyph_row = 24'h618780;
                9'h197 : glyph_row = 24'h018700;
                9'h1A2 : glyph_row = 24'h080000;
                9'h1A3 : glyph_row = 24'h1C0000;
                9'h1A4 : glyph_row = 24'h0E3FF8;
                9'h1A5 : glyph_row = 24'h073FF8;
                9'h1A6 : glyph_row = 24'h063018;
                9'h1A7 : glyph_row = 24'h003018;
                9'h1A8 : glyph_row = 24'h003018;
                9'h1A9 : glyph_row = 24'h7C3018;
                9'h1AA : glyph_row = 24'h7C3018;
                9'h1AB : glyph_row = 24'h0C3018;
                9'h1AC : glyph_row = 24'h0C3018;
                9'h1AD : glyph_row = 24'h0C3FF8;
                9'h1AE : glyph_row = 24'h0C3FF8;
                9'h1AF : glyph_row = 24'h0C0000;
                9'h1B0 : glyph_row = 24'h0C0000;
                9'h1B1 : glyph_row = 24'h0D8C60;
                9'h1B2 : glyph_row = 24'h0F9C70;
                9'h1B3 : glyph_row = 24'h0F3838;
                9'h1B4 : glyph_row = 24'h0E3038;
                9'h1B5 : glyph_row = 24'h1C601C;
                9'h1B6 : glyph_row = 24'h0CE00E;
                9'h1B7 : glyph_row = 24'h00C004;
                9'h1C3 : glyph_row = 24'h1FF00C;
                9'h1C4 : glyph_row = 24'h1FF00C;
                9'h1C5 : glyph_row = 24'h18308C;
                9'h1C6 : glyph_row = 24'h18318C;
                9'h1C7 : glyph_row = 24'h18318C;
                9'h1C8 : glyph_row = 24'h18318C;
                9'h1C9 : glyph_row = 24'h1FF18C;
                9'h1CA : glyph_row = 24'h1FF18C;
                9'h1CB : glyph_row = 24'h03018C;
                9'h1CC : glyph_row = 24'h03018C;
                9'h1CD : glyph_row = 24'h03018C;
                9'h1CE : glyph_row = 24'h3FFD8C;
                9'h1CF : glyph_row = 24'h3FFD8C;
                9'h1D0 : glyph_row = 24'h030D8C;
                9'h1D1 : glyph_row = 24'h03098C;
                9'h1D2 : glyph_row = 24'h06098C;
                9'h1D3 : glyph_row = 24'h06180C;
                9'h1D4 : glyph_row = 24'h0E180C;
                9'h1D5 : glyph_row = 24'h1C180C;
                9'h1D6 : glyph_row = 24'h78787C;
                9'h1D7 : glyph_row = 24'h707078;
                default: glyph_row = 24'h000000;
            endcase
        end
    endfunction

    wire [23:0] gr = glyph_row(cid, row[4:0]);
    wire col_ok = (slot != 3'd4);

    assign O_pixel = O_region && col_ok && gr[23 - col[4:0]];
endmodule

module osd_ae_debug #(
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    parameter NR_BUILD = 1'b0,
    parameter [15:0] AE_MAX = 16'd3980,
    parameter [7:0] AG_MAX = 8'd112
)(
    input wire I_clk, I_rst_n, I_vsync,
    input wire [11:0] I_x, I_y,
    input wire [15:0] I_exp,
    input wire [7:0] I_gain, I_luma, I_target,
    input wire [19:0] I_pixels,
    input wire I_valid, I_cfg, I_busy,
    input wire [15:0] I_writes,
    input wire [15:0] I_read_exp, I_read_gain, I_expected_gain, I_read_count,
    input wire I_read_valid, I_write_ack, I_comm_error, I_read_match,
    input wire [8:0] I_nr_diag,
    output wire O_pixel, O_region
);
    generate if(NR_BUILD==23)begin:g_temporal_external_panel
        assign O_pixel=1'b0;assign O_region=1'b0;
    end else if(NR_BUILD==21)begin:g_raw_calibration
        osd_raw_debug #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) u_raw_osd(
            .I_clk(I_clk),.I_rst_n(I_rst_n),.I_vsync(I_vsync),.I_x(I_x),.I_y(I_y),
            .I_exp(I_exp),.I_gain(I_gain),.I_luma(I_luma),.I_nr_diag(I_nr_diag),
            .I_camera_status({I_read_match,I_write_ack}),
            .I_diag({I_pixels[7:0],I_comm_error,I_read_valid,I_read_count,
                     I_expected_gain,I_read_gain,I_read_exp,I_writes}),
            .O_pixel(O_pixel),.O_region(O_region));
    end else begin:g_legacy_diagnostics
    localparam X0 = IMG_WIDTH - 544;
    localparam Y0 = IMG_HEIGHT - 176;
    localparam BOX_W = 520;
    localparam BOX_H = 152;
    reg vs_1d;
    reg nr_valid_snap,nr_pair_snap;
    reg [6:0] nr_value;
    reg [2:0] nr_left;
    reg [11:0] nr_work,nr_percent_bcd;
    function [11:0] nr_bcd_step(input [11:0] previous,input next_bit);
        reg [11:0] value;integer n;
        begin
            value=previous;
            for(n=0;n<3;n=n+1)if(value[n*4+:4]>=5)value[n*4+:4]=value[n*4+:4]+4'd3;
            nr_bcd_step={value[10:0],next_bit};
        end
    endfunction
    wire [11:0] nr_next_bcd=nr_bcd_step(nr_work,nr_value[6]);
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin nr_valid_snap<=0;nr_pair_snap<=0;nr_value<=0;nr_left<=0;nr_work<=0;nr_percent_bcd<=0;end
        else if(I_vsync && !vs_1d)begin
            nr_valid_snap<=I_nr_diag[8];nr_pair_snap<=I_nr_diag[7];
            nr_value<=I_nr_diag[6:0];nr_left<=3'd7;nr_work<=0;
        end else if(nr_left!=0)begin
            nr_work<=nr_next_bcd;nr_value<={nr_value[5:0],1'b0};nr_left<=nr_left-1'b1;
            if(nr_left==1)nr_percent_bcd<=nr_next_bcd;
        end
    end
    reg [27:0] exp_bcd, expmax_bcd, gain_bcd, gainmax_bcd;
    reg [27:0] luma_bcd, target_bcd, pixels_bcd, writes_bcd;
    reg [27:0] read_exp_bcd, read_count_bcd;
    reg [15:0] read_gain_snap, expected_gain_snap;
    reg read_valid_snap, write_ack_snap, comm_error_snap, read_match_snap;
    reg cfg_snap, busy_snap, valid_snap, exp_limit_snap, gain_limit_snap;
    reg [199:0] dbg_values;
    reg [279:0] dbg_bcd_work;
    reg [4:0] dbg_bcd_left;
    reg dbg_bcd_busy;

    function [27:0] bcd20(input [19:0] value);
        reg [27:0] bcd;
        integer bit_index, digit_index;
        begin
            bcd = 28'd0;
            for (bit_index = 19; bit_index >= 0; bit_index = bit_index - 1) begin
                for (digit_index = 0; digit_index < 7; digit_index = digit_index + 1)
                    if (bcd[digit_index*4 +: 4] >= 4'd5)
                        bcd[digit_index*4 +: 4] = bcd[digit_index*4 +: 4] + 4'd3;
                bcd = {bcd[26:0], value[bit_index]};
            end
            bcd20 = bcd;
        end
    endfunction

    function [27:0] bcd_step(input [27:0] previous, input next_bit);
        reg [27:0] corrected;
        integer digit_index;
        begin
            corrected = previous;
            for (digit_index = 0; digit_index < 7; digit_index = digit_index + 1)
                if (corrected[digit_index*4 +: 4] >= 4'd5)
                    corrected[digit_index*4 +: 4] = corrected[digit_index*4 +: 4] + 4'd3;
            bcd_step = {corrected[26:0], next_bit};
        end
    endfunction
    wire [279:0] dbg_bcd_next;
    genvar field_index;
        for (field_index = 0; field_index < 10; field_index = field_index + 1) begin : g_bcd
            assign dbg_bcd_next[field_index*28 +: 28] =
                bcd_step(dbg_bcd_work[field_index*28 +: 28], dbg_values[field_index*20 + 19]);
        end
    integer shift_index;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            vs_1d <= 1'b0;
            exp_bcd <= 28'd0; expmax_bcd <= bcd20({4'd0, AE_MAX});
            gain_bcd <= 28'd0; gainmax_bcd <= bcd20({12'd0, AG_MAX});
            luma_bcd <= 28'd0; target_bcd <= 28'd0;
            pixels_bcd <= 28'd0; writes_bcd <= 28'd0;
            read_exp_bcd <= 0; read_count_bcd <= 0;
            read_gain_snap <= 0; expected_gain_snap <= 0;
            read_valid_snap <= 0; write_ack_snap <= 0;
            comm_error_snap <= 0; read_match_snap <= 0;
            cfg_snap <= 1'b0; busy_snap <= 1'b0; valid_snap <= 1'b0;
            exp_limit_snap <= 1'b0; gain_limit_snap <= 1'b0;
            dbg_values <= 200'd0; dbg_bcd_work <= 280'd0;
            dbg_bcd_left <= 5'd0; dbg_bcd_busy <= 1'b0;
        end else begin
            vs_1d <= I_vsync;
            if (I_vsync && !vs_1d) begin
                dbg_values <= {4'd0, I_read_count, 4'd0, I_read_exp,
                               4'd0, I_writes, I_pixels, 12'd0, I_target,
                               12'd0, I_luma, 12'd0, AG_MAX, 12'd0, I_gain,
                               4'd0, AE_MAX, 4'd0, I_exp};
                dbg_bcd_work <= 280'd0;
                dbg_bcd_left <= 5'd20;
                dbg_bcd_busy <= 1'b1;
                cfg_snap <= I_cfg; busy_snap <= I_busy; valid_snap <= I_valid;
                exp_limit_snap <= (I_exp >= AE_MAX);
                gain_limit_snap <= (I_gain >= AG_MAX);
                read_gain_snap <= I_read_gain; expected_gain_snap <= I_expected_gain;
                read_valid_snap <= I_read_valid; write_ack_snap <= I_write_ack;
                comm_error_snap <= I_comm_error; read_match_snap <= I_read_match;
            end else if (dbg_bcd_busy) begin
                dbg_bcd_work <= dbg_bcd_next;
                for (shift_index = 0; shift_index < 10; shift_index = shift_index + 1)
                    dbg_values[shift_index*20 +: 20] <=
                        {dbg_values[shift_index*20 +: 19], 1'b0};
                dbg_bcd_left <= dbg_bcd_left - 5'd1;
                if (dbg_bcd_left == 5'd1) begin
                    exp_bcd     <= dbg_bcd_next[0 +: 28];
                    expmax_bcd  <= dbg_bcd_next[28 +: 28];
                    gain_bcd    <= dbg_bcd_next[56 +: 28];
                    gainmax_bcd <= dbg_bcd_next[84 +: 28];
                    luma_bcd    <= dbg_bcd_next[112 +: 28];
                    target_bcd  <= dbg_bcd_next[140 +: 28];
                    pixels_bcd  <= dbg_bcd_next[168 +: 28];
                    writes_bcd  <= dbg_bcd_next[196 +: 28];
                    read_exp_bcd <= dbg_bcd_next[224 +: 28];
                    read_count_bcd <= dbg_bcd_next[252 +: 28];
                    dbg_bcd_busy <= 1'b0;
                end
            end
        end
    end

    function [7:0] digit_ascii(input [3:0] digit);
        begin digit_ascii = 8'd48 + {4'd0, digit}; end
    endfunction
    function [7:0] hex_ascii(input [3:0] digit);
        begin hex_ascii = (digit < 10) ? 8'd48 + digit : 8'd65 + (digit - 10); end
    endfunction
    function [7:0] text_char(input [2:0] line_index, input [5:0] column);
        begin
            text_char = 8'd32;
            case (line_index)
                3'd0: case (column)
                    6'd0: text_char = 8'd69;
                    6'd1: text_char = 8'd88;
                    6'd2: text_char = 8'd80;
                    6'd3: text_char = 8'd58;
                    6'd4: text_char = digit_ascii(exp_bcd[16 +: 4]);
                    6'd5: text_char = digit_ascii(exp_bcd[12 +: 4]);
                    6'd6: text_char = digit_ascii(exp_bcd[8 +: 4]);
                    6'd7: text_char = digit_ascii(exp_bcd[4 +: 4]);
                    6'd8: text_char = digit_ascii(exp_bcd[0 +: 4]);
                    6'd9: text_char = 8'd47;
                    6'd10: text_char = digit_ascii(expmax_bcd[16 +: 4]);
                    6'd11: text_char = digit_ascii(expmax_bcd[12 +: 4]);
                    6'd12: text_char = digit_ascii(expmax_bcd[8 +: 4]);
                    6'd13: text_char = digit_ascii(expmax_bcd[4 +: 4]);
                    6'd14: text_char = digit_ascii(expmax_bcd[0 +: 4]);
                    6'd15: text_char = 8'd32;
                    6'd16: text_char = 8'd65;
                    6'd17: text_char = 8'd71;
                    6'd18: text_char = 8'd58;
                    6'd19: text_char = digit_ascii(gain_bcd[8 +: 4]);
                    6'd20: text_char = digit_ascii(gain_bcd[4 +: 4]);
                    6'd21: text_char = digit_ascii(gain_bcd[0 +: 4]);
                    6'd22: text_char = 8'd47;
                    6'd23: text_char = digit_ascii(gainmax_bcd[8 +: 4]);
                    6'd24: text_char = digit_ascii(gainmax_bcd[4 +: 4]);
                    6'd25: text_char = digit_ascii(gainmax_bcd[0 +: 4]);
                    6'd28: text_char = NR_BUILD ? 8'd78 : 8'd32;
                    6'd29: text_char = NR_BUILD ? 8'd82 : 8'd32;
                    6'd30: text_char = NR_BUILD ? (8'd48+NR_BUILD) : 8'd32;
                    default: text_char = 8'd32;
                endcase
                3'd1: case (column)
                    6'd0: text_char = 8'd89;
                    6'd1: text_char = 8'd58;
                    6'd2: text_char = digit_ascii(luma_bcd[8 +: 4]);
                    6'd3: text_char = digit_ascii(luma_bcd[4 +: 4]);
                    6'd4: text_char = digit_ascii(luma_bcd[0 +: 4]);
                    6'd5: text_char = 8'd32;
                    6'd6: text_char = 8'd84;
                    6'd7: text_char = 8'd58;
                    6'd8: text_char = digit_ascii(target_bcd[8 +: 4]);
                    6'd9: text_char = digit_ascii(target_bcd[4 +: 4]);
                    6'd10: text_char = digit_ascii(target_bcd[0 +: 4]);
                    6'd11: text_char = 8'd32;
                    6'd12: text_char = 8'd80;
                    6'd13: text_char = 8'd88;
                    6'd14: text_char = 8'd58;
                    6'd15: text_char = digit_ascii(pixels_bcd[24 +: 4]);
                    6'd16: text_char = digit_ascii(pixels_bcd[20 +: 4]);
                    6'd17: text_char = digit_ascii(pixels_bcd[16 +: 4]);
                    6'd18: text_char = digit_ascii(pixels_bcd[12 +: 4]);
                    6'd19: text_char = digit_ascii(pixels_bcd[8 +: 4]);
                    6'd20: text_char = digit_ascii(pixels_bcd[4 +: 4]);
                    6'd21: text_char = digit_ascii(pixels_bcd[0 +: 4]);
                    6'd23: text_char = (NR_BUILD>=2)?"P":" ";
                    6'd24: text_char = (NR_BUILD>=2)?(nr_valid_snap?(nr_pair_snap?"1":"0"):"-"):" ";
                    6'd26: text_char = (NR_BUILD>=2)?"F":" ";
                    6'd27: text_char = (NR_BUILD>=2)?":":" ";
                    6'd28: text_char = (NR_BUILD>=2)?(nr_valid_snap?digit_ascii(nr_percent_bcd[11:8]):"-"):" ";
                    6'd29: text_char = (NR_BUILD>=2)?(nr_valid_snap?digit_ascii(nr_percent_bcd[7:4]):"-"):" ";
                    6'd30: text_char = (NR_BUILD>=2)?(nr_valid_snap?digit_ascii(nr_percent_bcd[3:0]):"-"):" ";
                    6'd31: text_char = (NR_BUILD>=2)?"%":" ";
                    default: text_char = 8'd32;
                endcase
                3'd2: case (column)
                    6'd0: text_char = 8'd67;
                    6'd1: text_char = 8'd70;
                    6'd2: text_char = 8'd71;
                    6'd3: text_char = 8'd58;
                    6'd4: text_char = (cfg_snap ? 8'd49 : 8'd48);
                    6'd5: text_char = 8'd32;
                    6'd6: text_char = 8'd66;
                    6'd7: text_char = 8'd85;
                    6'd8: text_char = 8'd83;
                    6'd9: text_char = 8'd89;
                    6'd10: text_char = 8'd58;
                    6'd11: text_char = (busy_snap ? 8'd49 : 8'd48);
                    6'd12: text_char = 8'd32;
                    6'd13: text_char = 8'd87;
                    6'd14: text_char = 8'd82;
                    6'd15: text_char = 8'd58;
                    6'd16: text_char = digit_ascii(writes_bcd[16 +: 4]);
                    6'd17: text_char = digit_ascii(writes_bcd[12 +: 4]);
                    6'd18: text_char = digit_ascii(writes_bcd[8 +: 4]);
                    6'd19: text_char = digit_ascii(writes_bcd[4 +: 4]);
                    6'd20: text_char = digit_ascii(writes_bcd[0 +: 4]);
                    default: text_char = 8'd32;
                endcase
                3'd3: case (column)
                    6'd0: text_char = 8'd86;
                    6'd1: text_char = 8'd65;
                    6'd2: text_char = 8'd76;
                    6'd3: text_char = 8'd73;
                    6'd4: text_char = 8'd68;
                    6'd5: text_char = 8'd58;
                    6'd6: text_char = (valid_snap ? 8'd49 : 8'd48);
                    6'd7: text_char = 8'd32;
                    6'd8: text_char = 8'd76;
                    6'd9: text_char = 8'd73;
                    6'd10: text_char = 8'd77;
                    6'd11: text_char = 8'd73;
                    6'd12: text_char = 8'd84;
                    6'd13: text_char = 8'd58;
                    6'd14: text_char = 8'd69;
                    6'd15: text_char = (exp_limit_snap ? 8'd49 : 8'd48);
                    6'd16: text_char = 8'd32;
                    6'd17: text_char = 8'd71;
                    6'd18: text_char = (gain_limit_snap ? 8'd49 : 8'd48);
                    default: text_char = 8'd32;
                endcase
                3'd4: case (column)
                    0: text_char = "R"; 1: text_char = "E"; 2: text_char = ":";
                    3: text_char = digit_ascii(read_exp_bcd[16 +: 4]);
                    4: text_char = digit_ascii(read_exp_bcd[12 +: 4]);
                    5: text_char = digit_ascii(read_exp_bcd[8 +: 4]);
                    6: text_char = digit_ascii(read_exp_bcd[4 +: 4]);
                    7: text_char = digit_ascii(read_exp_bcd[0 +: 4]);
                    9: text_char = "R"; 10: text_char = "G"; 11: text_char = ":";
                    12: text_char = hex_ascii(read_gain_snap[15:12]);
                    13: text_char = hex_ascii(read_gain_snap[11:8]);
                    14: text_char = hex_ascii(read_gain_snap[7:4]);
                    15: text_char = hex_ascii(read_gain_snap[3:0]);
                    17: text_char = "S"; 18: text_char = "G"; 19: text_char = ":";
                    20: text_char = hex_ascii(expected_gain_snap[15:12]);
                    21: text_char = hex_ascii(expected_gain_snap[11:8]);
                    22: text_char = hex_ascii(expected_gain_snap[7:4]);
                    23: text_char = hex_ascii(expected_gain_snap[3:0]);
                    default: text_char = 8'd32;
                endcase
                3'd5: case (column)
                    0: text_char = "R"; 1: text_char = "D"; 2: text_char = ":";
                    3: text_char = digit_ascii({3'd0, read_valid_snap});
                    5: text_char = "W"; 6: text_char = "A"; 7: text_char = ":";
                    8: text_char = digit_ascii({3'd0, write_ack_snap});
                    10: text_char = "E"; 11: text_char = "R"; 12: text_char = "R";
                    13: text_char = ":"; 14: text_char = digit_ascii({3'd0, comm_error_snap});
                    16: text_char = "E"; 17: text_char = "Q"; 18: text_char = ":";
                    19: text_char = digit_ascii({3'd0, read_match_snap});
                    21: text_char = "R"; 22: text_char = "C"; 23: text_char = ":";
                    24: text_char = digit_ascii(read_count_bcd[16 +: 4]);
                    25: text_char = digit_ascii(read_count_bcd[12 +: 4]);
                    26: text_char = digit_ascii(read_count_bcd[8 +: 4]);
                    27: text_char = digit_ascii(read_count_bcd[4 +: 4]);
                    28: text_char = digit_ascii(read_count_bcd[0 +: 4]);
                    default: text_char = 8'd32;
                endcase
                default: text_char = 8'd32;
            endcase
        end
    endfunction
    function [39:0] font5x8(input [7:0] character);
        begin
            case (character)
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
                default: font5x8 = 40'd0;
            endcase
        end
    endfunction

    wire [11:0] tx = I_x - X0 - 4;
    wire [11:0] ty = I_y - Y0 - 4;
    wire [2:0] line_index = (ty < 24) ? 3'd0 : (ty < 48) ? 3'd1
                          : (ty < 72) ? 3'd2 : (ty < 96) ? 3'd3
                          : (ty < 120) ? 3'd4 : 3'd5;
    wire [11:0] row_y = (line_index == 0) ? ty : (line_index == 1) ? ty - 24
                                      : (line_index == 2) ? ty - 48
                                      : (line_index == 3) ? ty - 72
                                      : (line_index == 4) ? ty - 96 : ty - 120;
    wire [5:0] column = tx[9:4];
    wire [2:0] gx = tx[3:1];
    wire [2:0] gy = row_y[3:1];
    wire [39:0] glyph = font5x8(text_char(line_index, column));
    wire in_text = (I_x >= X0 + 4) && (I_x < X0 + 4 + 512) &&
                   (I_y >= Y0 + 4) && (I_y < Y0 + 4 + 144) &&
                   (gx < 5) && (row_y < 16);
    assign O_region = (I_x >= X0) && (I_x < X0 + BOX_W) &&
                      (I_y >= Y0) && (I_y < Y0 + BOX_H);
    assign O_pixel = (O_region && in_text) ? glyph[39 - (gy*5 + gx)] : 1'b0;
    end endgenerate
endmodule

module osd_bin_debug #(
    parameter IMG_WIDTH=1280, IMG_HEIGHT=720
)(
    input wire I_clk,I_rst_n,I_vsync,
    input wire [11:0] I_x,I_y,
    input wire [7:0] I_thresh,I_target,I_low,I_high,I_bias,
    input wire I_valid,I_seed,
    input wire [15:0] I_updates,
    input wire [19:0] I_pixels,I_white,
    output wire O_pixel,O_region
);
    localparam X0=IMG_WIDTH-544, Y0=IMG_HEIGHT-264;
    localparam BOX_W=520, BOX_H=80;
    reg vs_d, valid_snap, seed_snap, busy;
    reg [95:0] snapshot;
    reg [19:0] value;
    reg [27:0] work;
    reg [4:0] left;
    reg [2:0] field;
    reg [11:0] bt_bcd,tg_bcd,lo_bcd,hi_bcd,bias_bcd;
    reg [19:0] updates_bcd;
    reg [27:0] pixels_bcd,white_bcd;
    function [19:0] field_value(input [95:0] s,input [2:0] f);
        begin
            case(f)
                0:field_value={12'd0,s[7:0]};
                1:field_value={12'd0,s[15:8]};
                2:field_value={12'd0,s[23:16]};
                3:field_value={12'd0,s[31:24]};
                4:field_value={4'd0,s[47:32]};
                5:field_value=s[67:48];
                6:field_value=s[87:68];
                default:field_value={12'd0,s[95:88]};
            endcase
        end
    endfunction
    function [27:0] bcd_step(input [27:0] prev,input bit_in);
        reg [27:0] v;
        integer i;
        begin
            v=prev;
            for(i=0;i<7;i=i+1)if(v[4*i +: 4]>=5)v[4*i +: 4]=v[4*i +: 4]+4'd3;
            bcd_step={v[26:0],bit_in};
        end
    endfunction
    wire [27:0] next_bcd=bcd_step(work,value[19]);
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            vs_d<=0;valid_snap<=0;seed_snap<=0;busy<=0;snapshot<=0;value<=0;work<=0;
            left<=0;field<=0;bt_bcd<=0;tg_bcd<=0;lo_bcd<=0;hi_bcd<=0;
            bias_bcd<=0;updates_bcd<=0;pixels_bcd<=0;white_bcd<=0;
        end else begin
            vs_d<=I_vsync;
            if(I_vsync&&!vs_d)begin
                snapshot<={I_bias,I_white,I_pixels,I_updates,I_high,I_low,I_target,I_thresh};
                valid_snap<=I_valid;seed_snap<=I_seed;value<={12'd0,I_thresh};
                work<=0;left<=20;field<=0;busy<=1;
            end else if(busy)begin
                work<=next_bcd;value<={value[18:0],1'b0};left<=left-1'b1;
                if(left==1)begin
                    case(field)
                        0:bt_bcd<=next_bcd[11:0];
                        1:tg_bcd<=next_bcd[11:0];
                        2:lo_bcd<=next_bcd[11:0];
                        3:hi_bcd<=next_bcd[11:0];
                        4:updates_bcd<=next_bcd[19:0];
                        5:pixels_bcd<=next_bcd;
                        6:white_bcd<=next_bcd;
                        7:bias_bcd<=next_bcd[11:0];
                    endcase
                    if(field==7)busy<=0;
                    else begin
                        field<=field+1'b1;value<=field_value(snapshot,field+3'd1);
                        work<=0;left<=20;
                    end
                end
            end
        end
    end
    function [7:0] digit(input [3:0] d);
        begin digit=8'd48+{4'd0,d};end
    endfunction
    function [7:0] text_char(input [1:0] line_index,input [5:0] col);
        begin
            text_char=" ";
            case(line_index)
                0:case(col)
                    0:text_char="B";1:text_char="T";2:text_char=":";
                    3:text_char=digit(bt_bcd[11:8]);4:text_char=digit(bt_bcd[7:4]);5:text_char=digit(bt_bcd[3:0]);
                    7:text_char="T";8:text_char="G";9:text_char=":";
                    10:text_char=digit(tg_bcd[11:8]);11:text_char=digit(tg_bcd[7:4]);12:text_char=digit(tg_bcd[3:0]);
                    14:text_char="L";15:text_char="O";16:text_char=":";
                    17:text_char=digit(lo_bcd[11:8]);18:text_char=digit(lo_bcd[7:4]);19:text_char=digit(lo_bcd[3:0]);
                    21:text_char="H";22:text_char="I";23:text_char=":";
                    24:text_char=digit(hi_bcd[11:8]);25:text_char=digit(hi_bcd[7:4]);26:text_char=digit(hi_bcd[3:0]);
                    default:text_char=" ";
                endcase
                1:case(col)
                    0:text_char="V";1:text_char=":";2:text_char=valid_snap?"1":"0";
                    4:text_char="U";5:text_char="P";6:text_char=":";
                    7:text_char=digit(updates_bcd[19:16]);8:text_char=digit(updates_bcd[15:12]);
                    9:text_char=digit(updates_bcd[11:8]);10:text_char=digit(updates_bcd[7:4]);11:text_char=digit(updates_bcd[3:0]);
                    13:text_char="B";14:text_char=":";
                    15:text_char=digit(bias_bcd[11:8]);16:text_char=digit(bias_bcd[7:4]);17:text_char=digit(bias_bcd[3:0]);
                    19:text_char="M";20:text_char=":";21:text_char="1";
                    23:text_char="S";24:text_char=":";25:text_char=seed_snap?"1":"0";
                    default:text_char=" ";
                endcase
                2:case(col)
                    0:text_char="N";1:text_char=":";
                    2:text_char=digit(pixels_bcd[27:24]);3:text_char=digit(pixels_bcd[23:20]);
                    4:text_char=digit(pixels_bcd[19:16]);5:text_char=digit(pixels_bcd[15:12]);
                    6:text_char=digit(pixels_bcd[11:8]);7:text_char=digit(pixels_bcd[7:4]);8:text_char=digit(pixels_bcd[3:0]);
                    10:text_char="W";11:text_char=":";
                    12:text_char=digit(white_bcd[27:24]);13:text_char=digit(white_bcd[23:20]);
                    14:text_char=digit(white_bcd[19:16]);15:text_char=digit(white_bcd[15:12]);
                    16:text_char=digit(white_bcd[11:8]);17:text_char=digit(white_bcd[7:4]);18:text_char=digit(white_bcd[3:0]);
                    default:text_char=" ";
                endcase
                default:text_char=" ";
            endcase
        end
    endfunction
    function [39:0] font5x8(input [7:0] character);
        begin
            case (character)
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
                8'd72: font5x8 = 40'h8c63f8c620;
                8'd78: font5x8 = 40'h8e6b38c620;
                8'd79: font5x8 = 40'h746318c5c0;
                default: font5x8 = 40'd0;
            endcase
        end
    endfunction

    wire [11:0] tx=I_x-X0-4,ty=I_y-Y0-4;
    wire [1:0] line_index=ty<24?0:(ty<48?1:2);
    wire [11:0] row_y=line_index==0?ty:(line_index==1?ty-24:ty-48);
    wire [5:0] col=tx[9:4];
    wire [2:0] gx=tx[3:1],gy=row_y[3:1];
    wire [39:0] glyph=font5x8(text_char(line_index,col));
    wire in_text=I_x>=X0+4 && I_x<X0+516 && I_y>=Y0+4 && I_y<Y0+76 && gx<5 && row_y<16;
    assign O_region=I_x>=X0 && I_x<X0+BOX_W && I_y>=Y0 && I_y<Y0+BOX_H;
    assign O_pixel=(O_region&&in_text)?glyph[39-(gy*5+gx)]:1'b0;
endmodule

module osd_raw_debug #(parameter IMG_WIDTH=1280,IMG_HEIGHT=720)(
    input wire I_clk,I_rst_n,I_vsync,
    input wire [11:0] I_x,I_y,
    input wire [15:0] I_exp,
    input wire [7:0] I_gain,I_luma,
    input wire [8:0] I_nr_diag,
    input wire [89:0] I_diag,
    input wire [1:0] I_camera_status,
    output wire O_pixel,O_region
);
    localparam X0=IMG_WIDTH-544,Y0=IMG_HEIGHT-176;
    reg vs_d,raw_valid,raw_error,nr_valid,nr_pair;
    reg [7:0] raw_sequence;
    reg [1:0] camera_status;
    reg [191:0] values;
    reg [19:0] work_bcd;
    reg [3:0] field_index;
    reg [19:0] numbers[0:11];
    reg [4:0] left;
    function [19:0] bcd_step(input [19:0] previous,input bit_in);
        reg [19:0] v;integer k;
        begin
            v=previous;
            for(k=0;k<5;k=k+1)if(v[k*4+:4]>=5)v[k*4+:4]=v[k*4+:4]+4'd3;
            bcd_step={v[18:0],bit_in};
        end
    endfunction
    wire [19:0] bcd_next=bcd_step(work_bcd,values[15]);
    integer i;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            vs_d<=0;raw_valid<=0;raw_error<=0;nr_valid<=0;nr_pair<=0;
            camera_status<=0;raw_sequence<=0;values<=0;work_bcd<=0;left<=0;field_index<=0;
            for(i=0;i<12;i=i+1)numbers[i]<=0;
        end else begin
            vs_d<=I_vsync;
            if(I_vsync&&!vs_d)begin
                values[0+:16]<=I_exp;
                values[16+:16]<={8'd0,I_gain};
                values[32+:16]<={8'd0,I_luma};
                values[48+:16]<={9'd0,I_nr_diag[6:0]};
                for(i=0;i<8;i=i+1)values[(i+4)*16+:16]<={6'd0,I_diag[i*10+:10]};
                camera_status<=I_camera_status;
                raw_valid<=I_diag[80];raw_error<=I_diag[81];raw_sequence<=I_diag[89:82];
                nr_valid<=I_nr_diag[8];nr_pair<=I_nr_diag[7];
                work_bcd<=0;left<=16;field_index<=0;
            end else if(left!=0)begin

                if(left==1)begin
                    numbers[field_index]<=bcd_next;
                    work_bcd<=0;
                    values<={16'd0,values[191:16]};
                    field_index<=field_index+1'b1;
                    left<=(field_index==11)?0:16;
                end else begin
                    work_bcd<=bcd_next;
                    values[15:0]<={values[14:0],1'b0};
                    left<=left-1'b1;
                end
            end
        end
    end
    function [7:0] digit(input [3:0] v);begin digit=8'd48+{4'd0,v};end endfunction
    function [7:0] hex_digit(input [3:0] v);
        begin hex_digit=(v<10)?8'd48+v:8'd65+(v-10);end
    endfunction
    function [7:0] text_char(input [2:0] line_id,input [5:0] col);
        reg [19:0] a,b;reg [7:0] label0,label1;
        begin
            text_char=" ";a=0;b=0;label0="M";label1="0";
            case(line_id)
                0:case(col)
                    0:text_char="E";1:text_char="X";2:text_char="P";3:text_char=":";
                    4:text_char=digit(numbers[0][19:16]);5:text_char=digit(numbers[0][15:12]);
                    6:text_char=digit(numbers[0][11:8]);7:text_char=digit(numbers[0][7:4]);
                    8:text_char=digit(numbers[0][3:0]);
                    10:text_char="A";11:text_char="G";12:text_char=":";
                    13:text_char=digit(numbers[1][11:8]);14:text_char=digit(numbers[1][7:4]);
                    15:text_char=digit(numbers[1][3:0]);
                    18:text_char="N";19:text_char="R";20:text_char="2";21:text_char="-";22:text_char="D";
                    24:text_char="W";25:text_char=camera_status[0]?"1":"0";
                    27:text_char="E";28:text_char=camera_status[1]?"1":"0";
                    default:text_char=" ";
                endcase
                1:case(col)
                    0:text_char="Y";1:text_char=":";
                    2:text_char=digit(numbers[2][11:8]);3:text_char=digit(numbers[2][7:4]);
                    4:text_char=digit(numbers[2][3:0]);
                    6:text_char="P";7:text_char=nr_valid?(nr_pair?"1":"0"):"-";
                    9:text_char="F";10:text_char=":";
                    11:text_char=nr_valid?digit(numbers[3][11:8]):"-";
                    12:text_char=nr_valid?digit(numbers[3][7:4]):"-";
                    13:text_char=nr_valid?digit(numbers[3][3:0]):"-";14:text_char="%";
                    16:text_char="V";17:text_char=":";18:text_char=raw_valid?"1":"0";
                    20:text_char="X";21:text_char=":";22:text_char=raw_error?"1":"0";
                    24:text_char="Q";25:text_char=":";
                    26:text_char=hex_digit(raw_sequence[7:4]);27:text_char=hex_digit(raw_sequence[3:0]);
                    default:text_char=" ";
                endcase
                2,3,4,5:begin
                    case(line_id)
                        2:begin a=numbers[4];b=numbers[5];label0="M";label1="0";end
                        3:begin a=numbers[6];b=numbers[7];label0="M";label1="2";end
                        4:begin a=numbers[8];b=numbers[9];label0="D";label1="0";end
                        5:begin a=numbers[10];b=numbers[11];label0="D";label1="2";end
                    endcase
                    case(col)
                        0,8:text_char=label0;
                        1:text_char=label1;9:text_char=label1+8'd1;
                        2,10:text_char=":";
                        3:text_char=raw_valid?digit(a[15:12]):"-";
                        4:text_char=raw_valid?digit(a[11:8]):"-";
                        5:text_char=raw_valid?digit(a[7:4]):"-";
                        6:text_char=raw_valid?digit(a[3:0]):"-";
                        11:text_char=raw_valid?digit(b[15:12]):"-";
                        12:text_char=raw_valid?digit(b[11:8]):"-";
                        13:text_char=raw_valid?digit(b[7:4]):"-";
                        14:text_char=raw_valid?digit(b[3:0]):"-";
                        default:text_char=" ";
                    endcase
                end
                default:text_char=" ";
            endcase
        end
    endfunction
    function [39:0] font5x8(input [7:0] character);
        begin
            case (character)
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
                default: font5x8 = 40'd0;
            endcase
        end
    endfunction
    wire [11:0] tx=I_x-X0-4,ty=I_y-Y0-4;
    wire [2:0] line_id=(ty<24)?0:(ty<48)?1:(ty<72)?2:(ty<96)?3:(ty<120)?4:5;
    wire [11:0] row_y=(line_id==0)?ty:(line_id==1)?ty-24:(line_id==2)?ty-48:
                      (line_id==3)?ty-72:(line_id==4)?ty-96:ty-120;
    wire [2:0] gx=tx[3:1],gy=row_y[3:1];
    wire [39:0] glyph=font5x8(text_char(line_id,tx[9:4]));
    wire in_text=(I_x>=X0+4)&&(I_x<X0+516)&&(I_y>=Y0+4)&&(I_y<Y0+148)&&
                 (gx<5)&&(row_y<16);
    assign O_region=(I_x>=X0)&&(I_x<X0+520)&&(I_y>=Y0)&&(I_y<Y0+152);
    assign O_pixel=(O_region&&in_text)?glyph[39-(gy*5+gx)]:1'b0;
endmodule

module osd_color_label #(
    parameter [11:0] XMAX=12'd1280,YMAX=12'd720
)(
    input wire I_clk,I_rst_n,I_update,I_frame_blank,I_de,
    input wire [11:0] I_x,I_y,
    input wire [5:0] I_ok,
    input wire [65:0] I_x0,I_x1,
    input wire [59:0] I_y0,I_y1,
    output wire O_pixel,
    output wire [1:0] O_color,
    output wire O_box_any,
    output wire [23:0] O_box_rgb
);
    localparam [11:0] LBL_W=176,LBL_H=34,MARGIN=4;
    localparam IDLE=0,LOAD=1,BCD_X=2,BCD_Y=3,TEXT=4,PUBLISH=5;
    reg [2:0] state,slot;
    reg [3:0] bit_count;
    reg [10:0] binary_shift;
    reg [15:0] bcd,x_bcd;
    reg [31:0] build_numbers;
    reg [7:0] cursor;
    reg active_bank,work_bank;
    reg [5:0] pending_ok,display_ok;
    reg [65:0] pending_x0,pending_x1,display_x0,display_x1;
    reg [59:0] pending_y0,pending_y1,display_y0,display_y1;
    reg [10:0] pending_cx[0:5],center_x[0:5];
    reg [9:0] pending_cy[0:5],center_y[0:5];
    reg [11:0] pending_lx[0:5],pending_ly[0:5];
    reg [11:0] label_x[0:5],label_y[0:5];
    wire [10:0] x0=pending_x0[slot*11+:11];
    wire [10:0] x1=pending_x1[slot*11+:11];
    wire [9:0] y0=pending_y0[slot*10+:10];
    wire [9:0] y1=pending_y1[slot*10+:10];
    wire [11:0] sum_x={1'b0,x0}+{1'b0,x1};
    wire [10:0] sum_y={1'b0,y0}+{1'b0,y1};
    wire [11:0] left={1'b0,x0};

    wire [11:0] top=({2'd0,y0}>=LBL_H+MARGIN+3)?
        {2'd0,y0}-LBL_H-12'd3:{2'd0,y0}+12'd3;
    function [15:0] bcd_step;
        input [15:0] previous;input bit_in;
        reg [15:0] adjusted;integer d;
        begin
            adjusted=previous;
            for(d=0;d<4;d=d+1)
                if(previous[d*4+:4]>=5)adjusted[d*4+:4]=previous[d*4+:4]+4'd3;
            bcd_step={adjusted[14:0],bit_in};
        end
    endfunction
    wire [15:0] bcd_next=bcd_step(bcd,binary_shift[10]);
    wire [2:0] build_slot=cursor[7:5];

    function [4:0] text_code;
        input [2:0] target;input line_id;input [3:0] col;
        input [31:0] value;
        begin
            text_code=31;
            if(line_id)case(col)
                0:text_code=18;
                1:text_code={1'b0,value[31:28]};
                2:text_code={1'b0,value[27:24]};
                3:text_code={1'b0,value[23:20]};
                4:text_code={1'b0,value[19:16]};
                6:text_code=19;
                7:text_code={1'b0,value[15:12]};
                8:text_code={1'b0,value[11:8]};
                9:text_code={1'b0,value[7:4]};
                10:text_code={1'b0,value[3:0]};
                default:text_code=31;
            endcase
            else case(target[2:1])
                0:case(col)
                    0:text_code=16;1:text_code=12;2:text_code=11;
                    3:text_code=target[0]?5'd2:5'd1;
                    default:text_code=31;
                endcase
                1:case(col)
                    0:text_code=13;1:text_code=16;2,3:text_code=12;4:text_code=15;
                    5:text_code=target[0]?5'd2:5'd1;
                    default:text_code=31;
                endcase
                default:case(col)
                    0:text_code=10;1:text_code=14;2:text_code=17;3:text_code=12;
                    4:text_code=target[0]?5'd2:5'd1;
                    default:text_code=31;
                endcase
            endcase
        end
    endfunction
    integer j;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            state<=IDLE;slot<=0;bit_count<=0;binary_shift<=0;bcd<=0;x_bcd<=0;
            cursor<=0;active_bank<=0;work_bank<=1;build_numbers<=0;
            pending_ok<=0;display_ok<=0;
            pending_x0<=0;pending_x1<=0;pending_y0<=0;pending_y1<=0;
            display_x0<=0;display_x1<=0;display_y0<=0;display_y1<=0;
            for(j=0;j<6;j=j+1)begin
                pending_cx[j]<=0;pending_cy[j]<=0;
                center_x[j]<=0;center_y[j]<=0;
                pending_lx[j]<=0;pending_ly[j]<=0;label_x[j]<=0;label_y[j]<=0;
            end
        end else if(I_update)begin
            pending_ok<=I_ok;
            pending_x0<=I_x0;pending_x1<=I_x1;pending_y0<=I_y0;pending_y1<=I_y1;
            work_bank<=!active_bank;slot<=0;state<=LOAD;
        end else case(state)
            LOAD:begin
                pending_cx[slot]<=sum_x[11:1];pending_cy[slot]<=sum_y[10:1];
                pending_lx[slot]<=(left<MARGIN)?MARGIN:
                    (left>XMAX-MARGIN-LBL_W)?XMAX-MARGIN-LBL_W:left;
                pending_ly[slot]<=(top>YMAX-MARGIN-LBL_H)?YMAX-MARGIN-LBL_H:top;
                binary_shift<=sum_x[11:1];bit_count<=0;bcd<=0;state<=BCD_X;
            end
            BCD_X:begin
                bcd<=bcd_next;binary_shift<={binary_shift[9:0],1'b0};
                if(bit_count==10)begin
                    x_bcd<=bcd_next;binary_shift<={1'b0,pending_cy[slot]};
                    bcd<=0;bit_count<=0;state<=BCD_Y;
                end else bit_count<=bit_count+1'b1;
            end
            BCD_Y:begin
                bcd<=bcd_next;binary_shift<={binary_shift[9:0],1'b0};
                if(bit_count==10)begin

                    build_numbers<={x_bcd,bcd_next};
                    cursor<={slot,5'd0};state<=TEXT;
                end else bit_count<=bit_count+1'b1;
            end
            TEXT:begin
                if(cursor[4:0]==31)begin
                    if(slot==5)state<=PUBLISH;
                    else begin slot<=slot+1'b1;state<=LOAD;end
                end else cursor<=cursor+1'b1;
            end
            PUBLISH:if(I_frame_blank&&!I_de)begin
                display_ok<=pending_ok;
                display_x0<=pending_x0;display_x1<=pending_x1;
                display_y0<=pending_y0;display_y1<=pending_y1;
                for(j=0;j<6;j=j+1)begin
                    center_x[j]<=pending_cx[j];center_y[j]<=pending_cy[j];
                    label_x[j]<=pending_lx[j];label_y[j]<=pending_ly[j];
                end
                active_bank<=work_bank;state<=IDLE;
            end
            default:state<=IDLE;
        endcase
    end

    (* ram_style="dram" *) reg [4:0] characters[0:511];
    reg [4:0] read_code;
    reg [39:0] glyph;
    function [39:0] font5x8;
        input [4:0] code;
        begin case(code)
            0:font5x8=40'h74675cc5c0;1:font5x8=40'h23084211c0;
            2:font5x8=40'h74422223e0;3:font5x8=40'hf042e087c0;
            4:font5x8=40'h11952f8840;5:font5x8=40'hfc21e087c0;
            6:font5x8=40'h7421e8c5c0;7:font5x8=40'hf844442100;
            8:font5x8=40'h7462e8c5c0;9:font5x8=40'h7462f085c0;
            10:font5x8=40'hf463e8c7c0;11:font5x8=40'hf46318c7c0;
            12:font5x8=40'hfc21e843e0;13:font5x8=40'h746178c5e0;
            14:font5x8=40'h84210843e0;15:font5x8=40'h8e6b38c620;
            16:font5x8=40'hf463ea4a20;17:font5x8=40'h8c6318c5c0;
            18:font5x8=40'h8c54454620;19:font5x8=40'h8c54421080;
            default:font5x8=0;
        endcase end
    endfunction

    wire [11:0] look_x=I_x+12'd2;
    wire [5:0] region_hit;
    wire [7:0] local_x[0:5];
    wire [5:0] local_y[0:5];
    genvar k;
    generate for(k=0;k<6;k=k+1)begin:g_region
        wire [12:0] dx={1'b0,look_x}-{1'b0,label_x[k]};
        wire [12:0] dy={1'b0,I_y}-{1'b0,label_y[k]};
        assign local_x[k]=dx[7:0];assign local_y[k]=dy[5:0];
        assign region_hit[k]=display_ok[k]&&!dx[12]&&(dx<LBL_W)&&
            !dy[12]&&((dy<16)||((dy>=18)&&(dy<LBL_H)));
    end endgenerate
    reg [2:0] chosen;
    reg [7:0] px;
    reg [5:0] py;
    always @*begin
        if(region_hit[0])chosen=0;else if(region_hit[1])chosen=1;
        else if(region_hit[2])chosen=2;else if(region_hit[3])chosen=3;
        else if(region_hit[4])chosen=4;else chosen=5;
        px=local_x[chosen];py=local_y[chosen];
    end
    wire second_line=py>=18;
    wire [5:0] text_y=second_line?(py-6'd18):py;
    wire [8:0] read_address={active_bank,chosen,second_line,px[7:4]};
    reg valid1,valid2;
    reg [2:0] gx1,gx2,gy1,gy2;
    reg [1:0] color1,color2;
    always @(posedge I_clk)begin
        if(I_rst_n&&(state==TEXT)&&!I_update)
            characters[{work_bank,cursor}]<=text_code(build_slot,cursor[4],cursor[3:0],build_numbers);
        read_code<=characters[read_address];
        glyph<=font5x8(read_code);
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            valid1<=0;valid2<=0;gx1<=0;gx2<=0;gy1<=0;gy2<=0;color1<=0;color2<=0;
        end else begin
            valid1<=|region_hit;valid2<=valid1;
            gx1<=px[3:1];gx2<=gx1;gy1<=text_y[3:1];gy2<=gy1;
            color1<=chosen[2:1];color2<=color1;
        end
    end
    wire [5:0] glyph_index=6'd39-({3'd0,gy2}*6'd5+{3'd0,gx2});
    assign O_pixel=I_de&&valid2&&(gx2<5)&&glyph[glyph_index];
    assign O_color=color2;
    function box_hit;
        input [10:0] ax0,ax1;input [9:0] ay0,ay1;
        input [11:0] x,y;
        reg ix,iy,ex,ey;
        begin
            ix=(x>={1'b0,ax0})&&(x<={1'b0,ax1});
            iy=(y>={2'd0,ay0})&&(y<={2'd0,ay1});
            ex=(x=={1'b0,ax0})||(x=={1'b0,ax0}+12'd1)||
               (x=={1'b0,ax1})||(x=={1'b0,ax1}-12'd1);
            ey=(y=={2'd0,ay0})||(y=={2'd0,ay0}+12'd1)||
               (y=={2'd0,ay1})||(y=={2'd0,ay1}-12'd1);
            box_hit=(ix&&ey)||(iy&&ex);
        end
    endfunction
    wire [5:0] box_ink;
    generate for(k=0;k<6;k=k+1)begin:g_box

        wire [12:0] dx={1'b0,I_x}+13'd4-{2'd0,center_x[k]};
        wire [12:0] dy={1'b0,I_y}+13'd4-{3'd0,center_y[k]};
        wire cross_ink=((I_x=={1'b0,center_x[k]})&&(dy<=8))||
                       ((I_y=={2'd0,center_y[k]})&&(dx<=8));
        assign box_ink[k]=I_de&&display_ok[k]&&(cross_ink||
            box_hit(display_x0[k*11+:11],display_x1[k*11+:11],
                    display_y0[k*10+:10],display_y1[k*10+:10],I_x,I_y));
    end endgenerate
    assign O_box_any=|box_ink;
    assign O_box_rgb=(|box_ink[1:0])?24'hff0000:
        (|box_ink[3:2])?24'h00ff00:(|box_ink[5:4])?24'h0000ff:24'd0;
endmodule

module video_latency_clock #(parameter TICK_CYCLES=5000)(
    input wire I_sys_clk,I_rst_n,I_capture_clk,I_capture_start,
    output reg [23:0] O_time_gray,O_capture_stamp
);
    localparam DW=$clog2(TICK_CYCLES);
    reg [DW-1:0] divider;
    reg [23:0] time_bin;
    wire [23:0] next_time=time_bin+24'd1;
    (* ASYNC_REG="TRUE" *) reg [23:0] capture_gray_meta,capture_gray_sync;
    function [23:0] gray_to_bin;
        input [23:0] g;integer b;
        begin for(b=0;b<24;b=b+1)gray_to_bin[b]=^(g>>b);end
    endfunction
    always @(posedge I_sys_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin divider<=0;time_bin<=0;O_time_gray<=0;end
        else if(divider==TICK_CYCLES-1)begin
            divider<=0;time_bin<=next_time;O_time_gray<=next_time^(next_time>>1);
        end else divider<=divider+1'b1;
    end
    always @(posedge I_capture_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin capture_gray_meta<=0;capture_gray_sync<=0;O_capture_stamp<=0;end
        else begin
            capture_gray_meta<=O_time_gray;capture_gray_sync<=capture_gray_meta;
            if(I_capture_start)O_capture_stamp<=gray_to_bin(capture_gray_sync);
        end
    end
endmodule

module osd_video_latency #(parameter [11:0] IMG_WIDTH=1280)(
    input wire I_clk,I_rst_n,I_vsync,I_de,
    input wire [23:0] I_rgb,I_time_gray,I_frame_stamp,
    input wire I_frame_stamp_valid,
    output wire [23:0] O_rgb
);
    (* ASYNC_REG="TRUE" *) reg [23:0] gray_meta,gray_sync;
    (* ASYNC_REG="TRUE" *) reg [24:0] stamp_meta,stamp_sync;
    reg [23:0] time_now;
    reg armed,de_d;
    reg [11:0] x_count,y_count;
    reg busy,measurement_valid,pending_valid;
    reg [3:0] bit_count;
    reg [13:0] binary_shift;
    reg [15:0] bcd,digits;
    wire [23:0] elapsed=time_now-stamp_sync[23:0];
    function [23:0] gray_to_bin;
        input [23:0] g;integer b;
        begin for(b=0;b<24;b=b+1)gray_to_bin[b]=^(g>>b);end
    endfunction
    function [15:0] bcd_step;
        input [15:0] previous;input bit_in;reg [15:0] adjusted;integer d;
        begin
            adjusted=previous;
            for(d=0;d<4;d=d+1)
                if(previous[d*4+:4]>=5)adjusted[d*4+:4]=previous[d*4+:4]+4'd3;
            bcd_step={adjusted[14:0],bit_in};
        end
    endfunction
    wire [15:0] next_bcd=bcd_step(bcd,binary_shift[13]);
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            gray_meta<=0;gray_sync<=0;stamp_meta<=0;stamp_sync<=0;time_now<=0;
            armed<=0;de_d<=0;x_count<=0;y_count<=0;
            busy<=0;measurement_valid<=0;pending_valid<=0;
            bit_count<=0;binary_shift<=0;bcd<=0;digits<=0;
        end else begin
            gray_meta<=I_time_gray;gray_sync<=gray_meta;time_now<=gray_to_bin(gray_sync);
            stamp_meta<={I_frame_stamp_valid,I_frame_stamp};stamp_sync<=stamp_meta;
            de_d<=I_de;
            if(I_vsync)begin x_count<=0;y_count<=0;armed<=1;end
            else begin
                if(I_de)x_count<=(x_count==IMG_WIDTH-1)?12'd0:x_count+12'd1;
                else x_count<=0;
                if(de_d&&!I_de)y_count<=y_count+12'd1;
            end
            if(armed&&I_de&&!I_vsync)begin
                armed<=0;busy<=1;bit_count<=0;bcd<=0;
                binary_shift<=elapsed[13:0];
                pending_valid<=stamp_sync[24]&&(elapsed<=24'd9999);
            end else if(busy)begin
                bcd<=next_bcd;binary_shift<={binary_shift[12:0],1'b0};
                if(bit_count==13)begin
                    busy<=0;digits<=next_bcd;measurement_valid<=pending_valid;
                end else bit_count<=bit_count+1'b1;
            end
        end
    end
    function [7:0] text_char;
        input [3:0] column;
        begin case(column)
            0:text_char=measurement_valid?(8'd48+{4'd0,digits[15:12]}):"-";
            1:text_char=measurement_valid?(8'd48+{4'd0,digits[11:8]}):"-";
            2:text_char=measurement_valid?(8'd48+{4'd0,digits[7:4]}):"-";
            3:text_char=".";
            4:text_char=measurement_valid?(8'd48+{4'd0,digits[3:0]}):"-";
            6:text_char="m";
            7:text_char="s";
            default:text_char=" ";
        endcase end
    endfunction
    function [39:0] font5x8;
        input [7:0] ch;
        begin case(ch)
            "0":font5x8=40'h74675cc5c0;"1":font5x8=40'h23084211c0;
            "2":font5x8=40'h74422223e0;"3":font5x8=40'hf042e087c0;
            "4":font5x8=40'h11952f8840;"5":font5x8=40'hfc21e087c0;
            "6":font5x8=40'h7421e8c5c0;"7":font5x8=40'hf844442100;
            "8":font5x8=40'h7462e8c5c0;"9":font5x8=40'h7462f085c0;
            "-":font5x8=40'h0001f00000;
            ".":font5x8=40'h0000000180;
            "m":font5x8={5'b00000,5'b00000,5'b11010,5'b10101,
                          5'b10101,5'b10101,5'b10101,5'b00000};
            "s":font5x8={5'b00000,5'b00000,5'b01111,5'b10000,
                          5'b01110,5'b00001,5'b11110,5'b00000};
            default:font5x8=0;
        endcase end
    endfunction
    localparam [11:0] PANEL_X=IMG_WIDTH-12'd148,PANEL_Y=12'd12;
    wire [12:0] dx={1'b0,x_count}-{1'b0,PANEL_X};
    wire [12:0] dy={1'b0,y_count}-{1'b0,PANEL_Y};
    wire in_panel=I_de&&!dx[12]&&(dx<136)&&!dy[12]&&(dy<24);

    wire [11:0] look_x=x_count+12'd1;
    wire [12:0] font_dx={1'b0,look_x}-{1'b0,PANEL_X};
    wire [12:0] tx=font_dx-13'd4,ty=dy-13'd4;
    wire in_text=(font_dx>=4)&&(font_dx<132)&&(dy>=4)&&(dy<20);
    wire [39:0] glyph=font5x8(text_char(tx[7:4]));
    wire [5:0] glyph_index=6'd39-({3'd0,ty[3:1]}*6'd5+{3'd0,tx[3:1]});
    wire next_ink=in_text&&(tx[3:1]<5)&&glyph[glyph_index];
    reg ink;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)ink<=1'b0;else ink<=next_ink;
    end
    assign O_rgb=in_panel?(ink?24'hffffff:24'h080808):I_rgb;
endmodule

module motion_word_observer #(
 parameter WIDTH=1280,HEIGHT=720,WORDS_PER_LINE=WIDTH*3/16,
 parameter FRAME_WORDS=WORDS_PER_LINE*HEIGHT,DIFF=16
)(input wire clk,rst_n,frame_start,valid,paired,
 input wire [127:0] current_word,reference_word,
 output reg [63:0] packet,output reg toggle);
 wire [15:0] changed;genvar k;
 generate for(k=0;k<16;k=k+1)begin:g_diff
  wire [8:0] a={1'b0,current_word[k*8+:8]},b={1'b0,reference_word[k*8+:8]};
  assign changed[k]=(a>b)?(a-b>DIFF):(b-a>DIFF);
 end endgenerate
 integer n;reg [4:0] votes;
 always @*begin votes=0;for(n=0;n<16;n=n+1)votes=votes+changed[n];end
 reg [17:0] words,hot_words;reg [7:0] wx;reg [10:0] px;reg [9:0] py;
 reg [1:0] phase,streak;reg bad,have;
 reg [10:0] xmin,xmax;reg [9:0] ymin,ymax;
 reg row_have,prev_have;reg [10:0] row_left,row_right,prev_left,prev_right;
 wire hot=paired&&(votes>=6);
 wire support=hot&&(streak>=2);
 wire [10:0] right_x=(px+11'd5>=WIDTH)?WIDTH-1:px+11'd5;
 wire [10:0] left_x=(px>=11'd11)?px-11'd11:11'd0;
 wire row_ok=row_have||support;
 wire [10:0] row_l=!row_have?left_x:row_left;
 wire [10:0] row_r=support?right_x:row_right;
 wire row_pair=row_ok&&prev_have&&({1'b0,row_l}<={1'b0,prev_right}+12'd8)&&
                  ({1'b0,row_r}+12'd8>={1'b0,prev_left});
 wire [10:0] pair_l=(row_l<prev_left)?row_l:prev_left;
 wire [10:0] pair_r=(row_r>prev_right)?row_r:prev_right;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   packet<=0;toggle<=0;words<=0;hot_words<=0;wx<=0;px<=0;py<=0;
   row_have<=0;prev_have<=0;row_left<=0;row_right<=0;prev_left<=0;prev_right<=0;
   phase<=0;streak<=0;bad<=0;have<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;
  end else if(frame_start)begin

   packet<={19'd0,(words==FRAME_WORDS)&&!bad,
     (hot_words>FRAME_WORDS/4),
     have&&(hot_words>=24)&&(hot_words<=FRAME_WORDS/4)&&(ymax-ymin>=5)&&(xmax-xmin>=15),
     ymin,ymax,xmin,xmax};
   toggle<=!toggle;words<=0;hot_words<=0;wx<=0;px<=0;py<=0;
   phase<=0;streak<=0;bad<=0;have<=0;row_have<=0;prev_have<=0;
  end else if(valid)begin
   if(words<FRAME_WORDS)begin
    words<=words+1'b1;if(!paired)bad<=1;
    if(hot)begin if(hot_words!=18'h3ffff)hot_words<=hot_words+1'b1;end
    if(support)begin
     if(!row_have)row_left<=left_x;
     row_right<=right_x;row_have<=1;
    end
    if(wx==WORDS_PER_LINE-1)begin
     if(row_pair)begin
      if(!have)begin xmin<=pair_l;xmax<=pair_r;ymin<=py-1'b1;ymax<=py;have<=1;end
      else begin if(pair_l<xmin)xmin<=pair_l;if(pair_r>xmax)xmax<=pair_r;ymax<=py;end
     end
     prev_have<=row_ok;prev_left<=row_l;prev_right<=row_r;row_have<=0;
     wx<=0;px<=0;py<=py+1'b1;phase<=0;streak<=0;
    end
    else begin
     wx<=wx+1'b1;px<=px+((phase==2)?11'd6:11'd5);phase<=(phase==2)?0:phase+1'b1;
     if(!hot)streak<=0;else if(streak!=3)streak<=streak+1'b1;
    end
   end else bad<=1;
  end
 end
endmodule

module motion_center_counter(
 input wire clk,rst_n,enable,frame_tick,input wire [63:0] packet,
 output reg [15:0] count_bcd);
 wire [10:0] x0=packet[21:11],x1=packet[10:0];
 wire [9:0] y0=packet[41:32],y1=packet[31:22];
 wire usable=packet[44]&&!packet[43]&&packet[42];
 wire covers=usable&&(x0<=640)&&(x1>=640)&&(y0<=360)&&(y1>=360);

 wire outside=usable&&((x1<635)||(x0>645)||(y1<355)||(y0>365));
 reg armed;reg [2:0] outside_frames;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin count_bcd<=0;armed<=0;outside_frames<=0;end
  else if(!enable)begin armed<=0;outside_frames<=0;end
  else if(frame_tick)begin
   if(!usable)outside_frames<=0;
   else if(covers)begin
    outside_frames<=0;
    if(armed)begin
     armed<=0;
      if(count_bcd!=16'h9999)begin
       if(count_bcd[3:0]!=9)count_bcd[3:0]<=count_bcd[3:0]+1'b1;
       else begin count_bcd[3:0]<=0;
        if(count_bcd[7:4]!=9)count_bcd[7:4]<=count_bcd[7:4]+1'b1;
        else begin count_bcd[7:4]<=0;
         if(count_bcd[11:8]!=9)count_bcd[11:8]<=count_bcd[11:8]+1'b1;
         else begin count_bcd[11:8]<=0;count_bcd[15:12]<=count_bcd[15:12]+1'b1;end
        end
       end
      end
    end
   end else if(outside)begin
    if(outside_frames==4)begin armed<=1;outside_frames<=0;end
    else outside_frames<=outside_frames+1'b1;
   end else outside_frames<=0;
  end
 end
endmodule

module motion_alarm_osd #(
 parameter WIDTH=1280,

 parameter [7:0] HOLD_FRAMES=8'd120
)(
 input wire clk,rst_n,vs,de,enable,
 input wire [15:0] count_bcd,input wire [23:0] rgb,
 input wire [63:0] motion_packet,input wire motion_toggle,
 output wire [23:0] out_rgb,output wire [63:0] frame_packet,output wire frame_tick);
 (* ASYNC_REG="TRUE" *) reg [2:0] ts;
 reg [63:0] bus_meta,bus_sync,snapshot;
 reg [11:0] x,y;reg de_d,vs_d;
 reg [15:0] display_count;
 reg [63:0] previous_packet;reg enable_d;
 reg [63:0] hold_packet;reg [7:0] hold_left;

 reg visible;reg [1:0] on_count;
 wire [63:0] display_packet=visible?hold_packet:64'd0;
 function close11;input [10:0] a,b;begin close11=(a>b)?(a-b<=32):(b-a<=32);end endfunction
 wire coherent=previous_packet[44]&&previous_packet[42]&&!previous_packet[43]&&
   close11(snapshot[21:11],previous_packet[21:11])&&close11(snapshot[10:0],previous_packet[10:0])&&
   close11({1'b0,snapshot[41:32]},{1'b0,previous_packet[41:32]})&&
   close11({1'b0,snapshot[31:22]},{1'b0,previous_packet[31:22]});
 wire [63:0] accepted_packet=(!enable||!enable_d)?64'd0:
   (snapshot[42]&&!coherent)?(snapshot&~64'h140000000000):snapshot;

 wire held_valid=accepted_packet[44]&&accepted_packet[42]&&!accepted_packet[43];

 wire activity=enable&&snapshot[44]&&(snapshot[42]||snapshot[43]);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   previous_packet<=0;enable_d<=0;ts<=0;bus_meta<=0;bus_sync<=0;snapshot<=0;
   x<=0;y<=0;de_d<=0;vs_d<=0;display_count<=0;hold_packet<=0;hold_left<=0;
   visible<=0;on_count<=0;
  end else begin
   ts<={ts[1:0],motion_toggle};bus_meta<=motion_packet;bus_sync<=bus_meta;
   if(ts[2]!=ts[1])snapshot<=bus_sync;
   de_d<=de;vs_d<=vs;
   if(vs)begin
    x<=0;y<=0;
    if(!vs_d)begin
     previous_packet<=snapshot;enable_d<=enable;

     if(!enable)begin
      visible<=0;on_count<=0;hold_left<=0;hold_packet<=64'd0;
     end else if(held_valid)begin
      hold_left<=HOLD_FRAMES;
      if(visible)begin hold_packet<=accepted_packet;on_count<=0;end
      else if(on_count!=2'd0)begin

       visible<=1;on_count<=0;hold_packet<=accepted_packet;
      end else on_count<=2'd1;
     end else if(activity)begin

      hold_left<=HOLD_FRAMES;on_count<=0;
     end else begin
      on_count<=0;
      if(hold_left!=8'd0)hold_left<=hold_left-1'b1;
      else visible<=0;
     end
    end
    display_count<=count_bcd;
   end else begin if(de)x<=(x==WIDTH-1)?0:x+1'b1;else x<=0;if(de_d&&!de)y<=y+1'b1;end
  end
 end
 assign frame_packet=accepted_packet;
 assign frame_tick=vs&&!vs_d;
 wire [10:0] mx0=display_packet[21:11],mx1=display_packet[10:0];
 wire [9:0] my0=display_packet[41:32],my1=display_packet[31:22];
 wire motion_region=display_packet[44]&&!display_packet[43]&&display_packet[42]&&
  x>=mx0&&x<=mx1&&y>=my0&&y<=my1;

 wire [8:0] tint_r={1'b0,rgb[23:16]}+9'd255;
 wire [8:0] tint_g={1'b0,rgb[15:8]}+9'd128;
 wire [8:0] tint_b={1'b0,rgb[7:0]}+9'd128;
 wire [23:0] tint_rgb={tint_r[8:1],tint_g[8:1],tint_b[8:1]};
 wire center_mark=((x>=639)&&(x<=641)&&(y>=350)&&(y<=370))||
                  ((y>=359)&&(y<=361)&&(x>=630)&&(x<=650));
 function [39:0] font;
  input [7:0] c;begin case(c)
   "0":font=40'h74675cc5c0;"1":font=40'h23084211c0;"2":font=40'h74422223e0;
   "3":font=40'hf042e087c0;"4":font=40'h11952f8840;"5":font=40'hfc21e087c0;
   "6":font=40'h7421e8c5c0;"7":font=40'hf844442100;"8":font=40'h7462e8c5c0;
   "9":font=40'h7462f085c0;"C":font=40'h7c210843c0;"A":font=40'h7463f8c620;
   "L":font=40'h84210843e0;"I":font=40'h71084211c0;"N":font=40'h8e6b38c620;
   "M":font=40'h8eeb58c620;"O":font=40'h746318c5c0;"T":font=40'hf908421080;default:font=0;
  endcase end
 endfunction
 wire caption=(x>=24)&&(x<124)&&(y>=676)&&(y<703);
 wire [11:0] dx=x-(WIDTH-148),dy=y-44;
 wire panel=((x>=WIDTH-148)&&(x<WIDTH-12)&&(y>=44)&&(y<71));
 wire count_ink;
 osd_text #(.X0(WIDTH-148),.Y0(44)) u_count_caption(
  .I_x(x),.I_y(y),.I_mode(3'd6),.O_pixel(count_ink),.O_region());
 wire [11:0] tx=dx-4,ty=dy-4;
 reg [7:0] ch;
 always @*begin
  ch=" ";
  case(tx[7:4])
   4:ch=8'd48+display_count[15:12];5:ch=8'd48+display_count[11:8];
   6:ch=8'd48+display_count[7:4];7:ch=8'd48+display_count[3:0];
  endcase
 end
 wire [39:0] glyph=font(ch);
 wire ink=(dx>=4)&&(dx<132)&&(dy>=4)&&(dy<20)&&(tx[3:1]<5)&&
   glyph[39-(ty[3:1]*5+tx[3:1])];
 assign out_rgb=(!enable||!de)?rgb:
   caption?rgb:
   panel?((ink||count_ink)?24'hffffff:24'h080808):
   center_mark?24'hffffff:
   motion_region?tint_rgb:rgb;
endmodule
