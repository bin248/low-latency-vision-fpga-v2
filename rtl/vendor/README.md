# 原厂 IP 与生成文件说明

本仓库只包含**自己编写或修改**的 RTL、约束、脚本与文档。下列内容来自安路科技、开发板厂商或赛题例程，
**不随仓库分发**。编译前请从官方渠道或你手上的原工程取得，并遵守各自的许可。

## 需要自行补齐的依赖

| 依赖 | 本工程中的典型文件/目录 | 用途 | 获取方式 |
|---|---|---|---|
| MIPI D-PHY 接收 | `mipi_dphy_rx/*.enc.v`、`*.enc.sv`、`mipi_dphy_rx_ph1p_mipiio_wrapper.sv`、`ph1p_mipiio_rx_wrapper.v` | 2-lane HS 接收、字节/通道对齐 | 安路 IP 目录或开发板例程 |
| DDR2 控制器与 PHY | `ph1p35_ddr/**`（含 `ph1p_ddrmc_wrapper_*.v`、`alc_mc_top_all.enc.sv`、`ddr2.adc`、`ddr2.sdc`） | 4 页视频帧缓存 | 安路 IP 目录或开发板例程 |
| HDMI 1.4 TMDS 发送核 | `hdmi_1_4b_transmitter_core_wrapper.enc.v` | HDMI 输出 | 安路 IP 目录或例程 |
| PLL | `PLL.v`、`ph1p_phy_pll_wrapper_*.v` | 50 MHz → 100 MHz / 23.81 MHz / 75 MHz / 375 MHz | TD IP 生成器（参数见下） |
| 异步 FIFO | `w128_d512_fifo`、`w155_d512_fifo` | 128 bit × 512 与 155 bit × 512 跨时钟域缓冲 | TD IP 生成器 |
| 移位 RAM | `ram_d32970204f32`（`blk_mem_gen_zhenghe`） | 去马赛克整合模块的行缓存（32 bit × 2048） | TD IP 生成器 |
| 流水除法器 | `divider`（`divider_gate.v`） | AWB 的 G/R、G/B（48 位分子 / 32 位分母，50 级） | TD IP 生成器 |
| 安路 Logo 位图 | `anlogic_logo_rom.v` | OSD 左上角 Logo（146×94） | 赛题例程 `lab_ex_3` |
| SC500CS 寄存器表 | `rtl/drivers/sc500/uics500reg_*.v`、`SC500GainTbl.v` | 摄像头初始化与 AE 寄存器 | 原厂/开发板参考代码（本仓库保留修改后的接口版本） |

## 建议的本地目录

```
low-latency-vision-fpga-v2/
  rtl/                 本仓库源码
  constraints/         本仓库约束
  scripts/             TD 流程模板
  vendor_ip/           从原工程拷入的 IP（.gitignore 已忽略）
  td_project/          TD 新建的工程与 Runs（.gitignore 已忽略）
```

`scripts/*_settings.cfg` 里的路径按 `td_project/camera_to_dsi_display_Runs/syn_1` 与
`vendor_ip/` 的相对位置写好；如果你的目录层级不同，按实际位置调整。

## 重新生成 IP 的参数

| IP | 参数 |
|---|---|
| PLL | 输入 50 MHz；C0=100 MHz、C1=23.809524 MHz、C4=75 MHz、C5=375 MHz |
| `w128_d512_fifo` | 写/读数据 128 bit，深度 512 |
| `w155_d512_fifo` | 写/读数据 155 bit，深度 512 |
| `blk_mem_gen_zhenghe` | 32 bit × 2048，双端口，异步读 |
| `divider` | 无符号 48 位 ÷ 32 位，流水线模式，50 级 |

## 版权

- 上述 IP、D-PHY/DDR/HDMI 加密源码、Logo 位图与摄像头寄存器表，版权归安路科技、开发板厂商或原例程作者所有；
- “安路”“Anlogic”是其商标；
- 本仓库仅保留必要的接口、例化与说明，不包含其加密源码、比特流或综合产物。
