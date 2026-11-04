`timescale 1ns / 1ps

module mode_toggle (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_key,
    input  wire       I_vsync,
    output reg  [1:0] O_mode
);

    wire key_pulse;
    key_remove_shakes u_key_debounce (
        .I_clk        (I_clk),
        .I_rst_n      (I_rst_n),
        .I_key_in     (I_key),
        .O_key_trig_out(key_pulse)
    );

    reg req;
    reg vs_1d;
    always @(posedge I_clk) vs_1d <= I_vsync;
    wire vsync_rise = I_vsync & ~vs_1d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            req    <= 1'b0;
            O_mode <= 2'd0;
        end else begin
            if (key_pulse)
                req <= 1'b1;
            if (vsync_rise) begin
                req <= 1'b0;
                if (req)
                    O_mode <= (O_mode == 2'd3) ? 2'd0 : (O_mode + 2'd1);
            end
        end
    end
endmodule
