"""仓库结构与关键 RTL 连接关系的静态检查。

这些检查不编译 Verilog，只确认：
  - 开源文件边界（没有加密 IP、比特流、综合产物）；
  - 顶层按键/LED 与 pin.adc 一致；
  - 四种主模式、两个子模式的映射仍在；
  - 关键算法模块没有被误删或改名；
  - 文档与 vendor 说明覆盖了必要内容。
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8", errors="replace")


class RepoLayoutTest(unittest.TestCase):
    def test_required_files_exist(self):
        required = [
            "README.md",
            "LICENSE",
            ".gitignore",
            "rtl/top/design_top_wrapper.v",
            "rtl/capture/csi_unpacket_2lane.v",
            "rtl/capture/raw10_unpacket_2lane.v",
            "rtl/isp/isp_top.v",
            "rtl/isp/demosaic/demosaic.v",
            "rtl/video/video_in.v",
            "rtl/video/video_out.v",
            "rtl/vision/edge_detect.v",
            "rtl/vision/osd_text.v",
            "rtl/display/hdmi_tx.v",
            "rtl/control/auto_exposure.v",
            "rtl/drivers/sc500/uicfgcs500_720p.v",
            "rtl/vendor/README.md",
            "constraints/pin.adc",
            "constraints/camera_to_dsi_display.sdc",
            "scripts/syn_flow.tcl",
            "scripts/phy_flow.tcl",
            "docs/01_项目总览与数据通路.md",
            "docs/02_算法流水线.md",
            "docs/03_核心代码解读.md",
            "docs/04_参数与调参.md",
            "docs/05_资源_验证与限制.md",
            "hardware/README.md",
            "assets/README.md",
        ]
        missing = [p for p in required if not (ROOT / p).exists()]
        self.assertEqual(missing, [], f"缺少文件: {missing}")

    def test_no_encrypted_ip_or_build_artifacts(self):
        bad = []
        for p in ROOT.rglob("*"):
            if not p.is_file():
                continue
            name = p.name.lower()
            if ".enc." in name or p.suffix.lower() in {".bit", ".bid", ".db", ".qor", ".zip"}:
                bad.append(str(p.relative_to(ROOT)))
            if p.suffix.lower() in {".area", ".timing", ".ts", ".log", ".logw", ".prj"}:
                bad.append(str(p.relative_to(ROOT)))
        self.assertEqual(bad, [], f"仓库中不应出现加密 IP/构建产物: {bad}")
        self.assertFalse((ROOT / "td_project").exists(), "td_project 不应入库")

    def test_key_and_led_pins(self):
        pin = read("constraints/pin.adc")
        expected = {
            "I_key1": "D5",
            "I_key2": "A9",
            "O_led_red": "V1",
            "O_led_green": "U2",
            "O_led_blue": "U1",
        }
        for signal, location in expected.items():
            pattern = r"set_pin_assignment\s*\{\s*" + re.escape(signal) + r"\s*\}\s*\{\s*LOCATION\s*=\s*" + location + r"\b"
            self.assertRegex(pin, pattern, f"{signal} 应分配到 {location}")

    def test_mode_mapping(self):
        top = read("rtl/top/design_top_wrapper.v")
        self.assertIn("wire [1:0]  S_mode;", top)
        self.assertIn("wire [1:0] S_style;", top)
        self.assertIn("wire [1:0] S_recognition_view;", top)
        self.assertIn("wire S_motion_enable=(S_mode==2'd3)&&S_recognition_view[0];", top)
        self.assertIn("wire [1:0] S_effect_select=(S_mode==0)?{1'b0,S_style[0]}:{S_motion_enable,1'b0};", top)
        self.assertIn(".I_key(I_key2 | (S_mode!=2'd0))", top)
        self.assertIn(".I_key(I_key2 | (S_mode!=2'd3))", top)
        self.assertIn("O_led_red", top)
        self.assertIn("O_led_green", top)
        self.assertIn("O_led_blue", top)
        self.assertIn("assign S_edge_thresh = 12'd100;", top)
        self.assertIn("assign S_bin_thresh  = 12'd128;", top)

    def test_key_algorithm_modules_exist(self):
        edge = read("rtl/vision/edge_detect.v")
        for module in ["edge_detect", "oil_pixel5", "color_blue_threshold",
                       "color_post_rg_threshold", "color_tracks4", "color_detect"]:
            self.assertIn(f"module {module}", edge, f"edge_detect.v 缺少 {module}")

        osd = read("rtl/vision/osd_text.v")
        for module in ["osd_text", "motion_word_observer", "motion_center_counter", "motion_alarm_osd"]:
            self.assertIn(f"module {module}", osd, f"osd_text.v 缺少 {module}")

        video = read("rtl/video/video_out.v")
        for module in ["video_out", "tnr_word_blend", "tnr_frame_tracker", "video_out_tnr"]:
            self.assertIn(f"module {module}", video, f"video_out.v 缺少 {module}")

    def test_osd_mode_table(self):
        osd = read("rtl/vision/osd_text.v")
        for mode, cid in [(0, 0), (1, 4), (2, 8), (4, 16), (5, 20), (6, 24)]:
            pattern = rf"3'd{mode}:\s*begin\s*s0\s*=\s*(?:5'd)?{cid}\b"
            self.assertRegex(osd, pattern, f"模式 {mode} 的字模起始编号应为 {cid}")
        # 模式 3 走 default（色彩识别）
        self.assertRegex(osd, r"default:\s*begin\s*s0\s*=\s*5'd11\b")

    def test_readme_covers_v2_features(self):
        readme = read("README.md")
        for word in ["油画", "色彩分块", "帧差", "运动检测", "RGB LED", "11.6 寸", "KEY0", "KEY1", "MIT License"]:
            self.assertIn(word, readme, f"README 缺少 {word}")
        self.assertIn("tests/test_repo_layout.py", read("docs/05_资源_验证与限制.md"))

    def test_vendor_notes(self):
        vendor = read("rtl/vendor/README.md")
        for dep in ["mipi_dphy_rx", "ph1p35_ddr", "hdmi_1_4b_transmitter_core_wrapper",
                    "PLL", "w128_d512_fifo", "blk_mem_gen_zhenghe", "divider", "anlogic_logo_rom"]:
            self.assertIn(dep, vendor, f"vendor 说明缺少 {dep}")

    def test_gitignore_ignores_build_products(self):
        ignore = read(".gitignore")
        for pattern in ["td_project/", "vendor_ip/", "*.bit", "*.db", "*.qor", "*.zip"]:
            self.assertIn(pattern, ignore)


if __name__ == "__main__":
    unittest.main(verbosity=2)
