create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 4.167 -waveform {0.000 2.083} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[4]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[5]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]


set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] \
    -group [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]

# Only CDC synchronizer input stages are exempt from synchronous setup/hold.
# Do not declare the related PLL clocks asynchronous or cut whole clock domains.
# TD get_regs takes register OUTPUT NET names, not physical cell/.d pin names.
set_false_path -to [get_regs {u_uicfgcs500/ae_req_meta}]
set_false_path -to [get_regs {u_auto_exposure/cam_done_sync[0] u_auto_exposure/ae_done_sync[0] S_cam_diag_toggle_sync[0]}]

# Bundled-data handshakes: the source holds AE/AG for the full write handshake,
# and diagnostics until the next 0.5s readout. Capture is delayed by three
# receiving clock stages. Bound data flight to 20ns, well below that settling
# interval; retain a real routed check rather than false-pathing these buses.
set_max_delay -datapath_only 20.000 \
    -from [get_clocks {HDMI_PIXEL_CLK}] \
    -to [get_regs {u_uicfgcs500/ae_hold[*] u_uicfgcs500/ag_hold[*]}]
set_max_delay -datapath_only 20.000 \
    -from [get_clocks {pll_clk_24m}] \
    -to [get_regs {S_cam_diag_video[*] u_edge_detect/u_osd_ae_debug/*snap*}]
# The source clock qualifiers cover aliased/merged source flops; destination scopes remain
# restricted to the held AE payload and held diagnostic snapshot, never pixels.
