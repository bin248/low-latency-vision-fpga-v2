# 位图与字模说明

## 安路 Logo

`rtl/osd/osd_logo.v` 例化一个 146×94 的位图 ROM（`anlogic_logo_rom`），透明像素直接透出原画面。
该 ROM 来自赛题例程 `lab_ex_3`，属于安路品牌素材，**本仓库不包含**。

恢复方法：

1. 从赛题例程或开发板资料中找到 `anlogic_logo_rom.v`；
2. 放到 `rtl/osd/` 或工程的 IP 目录；
3. 确认 `osd_logo.v` 的例化名与文件模块名一致。

没有该 ROM 时，可以临时把 `osd_logo.v` 的输出直通（不叠加），其余功能不受影响。

## 模式名、计数与标签

`rtl/vision/osd_text.v` 内置：

- 左下角模式名：4 个 24 像素字格，模式 0~5 各一句；
- 运动检测的计数面板：右上角 `COUNT:` 标题 + 4 位十进制数字；
- 中心十字与活动区着色由 `motion_alarm_osd` 直接绘制，不依赖外部字库；
- 颜色框标签：`osd_color_label` 在框边画颜色条，不额外存字模。

字模由 SimHei 24 px 渲染后阈值化生成，去掉了全空行。`tests/test_repo_layout.py` 会检查
`osd_text.v` 中模式 0~6 的字模编号仍与 RTL 的模式选择一致。

## 为什么不在仓库里放截图

截图会随显示器、曝光、光照变化，容易让人误以为“跑出来必须长这样”。
仓库只保留可复现的矢量架构图（`docs/images/system_arch.svg`），实拍图请以你本地板子为准。
