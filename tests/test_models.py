"""行为模型的 unittest 封装。

运行：
    python -m unittest discover -s tests -v
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import color_model  # noqa: E402
import motion_model  # noqa: E402
import oil_model  # noqa: E402


class OilModelTest(unittest.TestCase):
    def test_uniform_white(self):
        white = oil_model.Pixel(255, 255, 255)
        self.assertEqual(oil_model.oil_pixel([[white] * 5 for _ in range(5)]),
                         oil_model.Pixel(255, 255, 255))

    def test_quantization_and_mean(self):
        px = oil_model.Pixel(0x1F, 0x2F, 0x3F)
        self.assertEqual(oil_model.oil_pixel([[px] * 5 for _ in range(5)]),
                         oil_model.Pixel(0x11, 0x22, 0x33))

    def test_dark_bucket_wins(self):
        black = oil_model.Pixel(0, 0, 0)
        white = oil_model.Pixel(255, 255, 255)
        rows = [[black] * 5 for _ in range(2)]
        rows.append([black] * 3 + [white] * 2)
        rows += [[white] * 5 for _ in range(2)]
        self.assertEqual(oil_model.oil_pixel(rows), oil_model.Pixel(0, 0, 0))

    def test_rejects_bad_window(self):
        with self.assertRaises(ValueError):
            oil_model.oil_pixel([[oil_model.Pixel(0, 0, 0)] * 4] * 5)


class MotionModelTest(unittest.TestCase):
    def test_quiet_frame(self):
        quiet = [[False] * 80 for _ in range(20)]
        self.assertFalse(motion_model.frame_motion(quiet)["valid"])

    def test_single_word_not_supported(self):
        one = [[False] * 80 for _ in range(20)]
        one[10][10] = True
        self.assertFalse(motion_model.frame_motion(one)["valid"])

    def test_two_word_streak_forms_box(self):
        moving = [[False] * 80 for _ in range(30)]
        for y in range(30):
            moving[y][10] = True
            moving[y][11] = True
        pkt = motion_model.frame_motion(moving)
        self.assertTrue(pkt["valid"])
        self.assertEqual(pkt["box"], (160, 191, 0, 29))

    def test_flood_is_rejected(self):
        flood = [[True] * 80 for _ in range(20)]
        pkt = motion_model.frame_motion(flood)
        self.assertTrue(pkt["flood"])
        self.assertFalse(pkt["valid"])

    def test_center_counter_arms_after_leaving(self):
        counter = motion_model.CenterCounter()
        center = {"valid": True, "flood": False, "box": (630, 650, 350, 370)}
        outside = {"valid": True, "flood": False, "box": (0, 20, 0, 20)}

        counter.frame(center)
        self.assertEqual(counter.count, 0)
        for _ in range(motion_model.ARM_FRAMES + 1):
            counter.frame(outside)
        self.assertTrue(counter.armed)
        counter.frame(center)
        self.assertEqual(counter.count, 1)
        counter.frame(center)
        self.assertEqual(counter.count, 1)


class ColorModelTest(unittest.TestCase):
    def test_primary_colors(self):
        red = color_model.classify(255, 0, 0)
        green = color_model.classify(0, 200, 0)
        blue = color_model.classify(0, 0, 255)
        self.assertTrue(red[0])
        self.assertTrue(green[2] and green[3])
        self.assertTrue(blue[4] and blue[5])

    def test_gray_is_not_blue(self):
        self.assertFalse(color_model.classify(128, 128, 128)[4])

    def test_core_vote_needs_center(self):
        self.assertTrue(color_model.core_vote([False, False, False, False, True, True, True, True, True]))
        self.assertFalse(color_model.core_vote([True, False, False, False, False, False, False, False, False]))

    def test_smoothing(self):
        self.assertEqual(color_model.smooth_edge(100, 105), 100)
        self.assertEqual(color_model.smooth_edge(100, 200), 124)
        self.assertEqual(color_model.smooth_edge(200, 100), 176)

    def test_track_gate(self):
        track = (100, 200, 100, 200)
        self.assertIsNotNone(color_model.match_cost((110, 210, 105, 205), track))
        self.assertIsNone(color_model.match_cost((100, 400, 100, 400), track))
        self.assertIsNone(color_model.match_cost((500, 600, 300, 400), track))


if __name__ == "__main__":
    unittest.main(verbosity=2)
