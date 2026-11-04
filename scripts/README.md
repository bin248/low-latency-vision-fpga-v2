# TD 流程脚本

这些脚本是安路 Tang Dynasty（TD）6.2 的流程模板，来自本工程实际使用的 run 配置，去掉了本机绝对路径。
它们不是“一键复现”脚本：`settings.cfg` 里的 `vendor_ip/`、`constraints/` 路径要按你的目录调整。

| 文件 | 用途 |
|---|---|
| `syn_flow.tcl` | 综合 run 的默认流程（read_design → opt_rtl → opt_gate） |
| `phy_flow.tcl` | 布局布线 run 的默认流程（opt_place → opt_route → bitgen） |
| `syn_settings.cfg` | 综合 run 的 `settings.cfg` 模板 |
| `phy_settings.cfg` | 布局布线 run 的 `settings.cfg` 模板，含 improve8 的 `pack_effort high` / `hfn_opt_effort low` |
| `bitgen.tcl` | 在已布线的 run 目录单独生成比特流 |

## 使用顺序

1. 在 TD 中新建工程，器件选 `PH1P35MDG324`、速度等级 `-3`；
2. 把 `rtl/` 下所有 `.v` 加入源文件，补齐 `rtl/vendor/README.md` 列出的 IP；
3. 加入 `constraints/pin.adc` 与 `constraints/camera_to_dsi_display.sdc`；
4. 用 TD 正常流程综合、布局布线；若要复现 improve8 的布局参数，把 `phy_settings.cfg` 里的
   `phyWildParams` 一行合并进 TD 生成的 `settings.cfg`；
5. 生成比特流并烧录。

## 注意

- `settings.cfg` 由 TD 自动生成，升级 TD 或重建 run 后会被覆盖；把自定义参数放在生成文件之后或合并进模板；
- 工程里没有 `.al` 文件：它含创建者本机的绝对路径，直接开源会造成路径失效，按上面步骤新建工程更稳；
- 资源很紧（约 3.8 万 LUT、4 万 DFF、40 个 DSP），如果你增加了新逻辑，先看 `gate.qor` 的 DSP 数与布局是否还能收敛。
