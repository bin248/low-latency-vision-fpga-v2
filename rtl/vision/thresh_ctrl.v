`timescale 1ns/1ps

module thresh_ctrl #(
    parameter [11:0] INIT = 12'd96,
    parameter [11:0] STEP = 12'd5,
    parameter [11:0] MINV = 12'd16,
    parameter [11:0] MAXV = 12'd1023,
    parameter DEC_EN = 1'b1
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_key_inc,
    input  wire        I_key_dec,
    output reg  [11:0] O_thresh
);
    wire inc_pulse, dec_pulse;
    key_remove_shakes u_key_inc (
        .I_clk(I_clk), .I_rst_n(I_rst_n),
        .I_key_in(I_key_inc), .O_key_trig_out(inc_pulse));
    generate if(DEC_EN)begin:g_decrement
        key_remove_shakes u_key_dec (
            .I_clk(I_clk),.I_rst_n(I_rst_n),
            .I_key_in(I_key_dec),.O_key_trig_out(dec_pulse));
    end else begin:g_no_decrement
        assign dec_pulse=1'b0;
    end endgenerate

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            O_thresh <= INIT;
        else if (inc_pulse)
            O_thresh <= (O_thresh > MAXV - STEP) ? MAXV : O_thresh + STEP;
        else if (dec_pulse)
            O_thresh <= (O_thresh < MINV + STEP) ? MINV : O_thresh - STEP;
    end
endmodule
