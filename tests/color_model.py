"""颜色判决与分块跟踪的纯 Python 模型。

对应 edge_detect.v 的 color_blue_threshold / color_post_rg_threshold /
color_core_support / color_candidate_bank / color_tracks4。

RTL 的参数是写死的比较阈值；这里逐字复刻，方便在没有板子的情况下验证：
  - 红/绿/蓝的弱/强判决；
  - 3x3 空间核心至少 5 票；
  - 目标最小面积、最小宽高；
  - 候选与轨迹的尺寸/距离门限；
  - 死区 8、每帧限幅 24、丢失保持 3 帧。
"""

MIN_AREA = 200
MIN_W = 8
MIN_H = 8
MIN_STRONG = 32
BORDER = 12
SMOOTH_DEAD = 8
SMOOTH_STEP = 24
HOLD_FRAMES = 3


def classify(r, g, b):
    """返回 (red, red_strong, green, green_strong, blue, blue_strong)。"""
    red = (r > g + 40) and (r > b + 40) and (r > 60)
    green = (g >= r + 20) and (g >= b + 20) and (g >= 36)
    green_strong = (g >= r + 24) and (g >= b + 24) and (g >= 44)

    y = (r + 2 * g + b) // 4
    hi = max(r, g, b)
    lo = min(r, g, b)
    sat = hi - lo
    blue_gap = max(hi // 4, 10)
    blue_weak = (y >= 12) and (sat >= 8) and (sat >= hi // 8) and (y >= 16)
    blue = blue_weak and (b > r + blue_gap) and (b > g + blue_gap)

    blue_strong_gap = max(hi // 4 + hi // 8, 12)
    blue_strong = blue and (y >= 20) and (sat >= 16) and (sat >= hi // 4) \
        and (b > r + blue_strong_gap) and (b > g + blue_strong_gap)
    return red, red, green, green_strong, blue, blue_strong


def core_vote(mask3x3, center_index=4, need=5):
    """3x3 窗口至少 need 票，且中心像素本身要命中。"""
    if len(mask3x3) != 9:
        raise ValueError("需要 3x3 窗口")
    return bool(mask3x3[center_index]) and sum(1 for v in mask3x3 if v) >= need


def candidate_ok(area, width, height, strong):
    return area >= MIN_AREA and width >= MIN_W and height >= MIN_H and strong >= MIN_STRONG


def smooth_edge(old, new, dead=SMOOTH_DEAD, step=SMOOTH_STEP):
    delta = abs(new - old)
    if delta <= dead:
        return old
    return old + step if new > old else old - step


def admissible(candidate, track, gate_px):
    """candidate/track: (x0,x1,y0,y1)；尺寸 0.5~2 倍，中心距离 <= 2*gate。"""
    cx0, cx1, cy0, cy1 = candidate
    tx0, tx1, ty0, ty1 = track
    cw, ch = cx1 - cx0 + 1, cy1 - cy0 + 1
    tw, th = tx1 - tx0 + 1, ty1 - ty0 + 1
    if not (tw / 2 <= cw <= tw * 2 and th / 2 <= ch <= th * 2):
        return False
    movement = abs((cx0 + cx1) - (tx0 + tx1)) + abs((cy0 + cy1) - (ty0 + ty1))
    return movement <= 2 * gate_px


def match_cost(candidate, track, gate_px=None):
    """匹配代价：中心距离 + 宽高差；不可匹配返回 None。"""
    if gate_px is None:
        tw = track[1] - track[0] + 1
        th = track[3] - track[2] + 1
        size_max = max(tw, th)
        gate_px = 32 if size_max < 64 else (128 if size_max > 256 else size_max // 2)
    if not admissible(candidate, track, gate_px):
        return None
    cx0, cx1, cy0, cy1 = candidate
    tx0, tx1, ty0, ty1 = track
    movement = abs((cx0 + cx1) - (tx0 + tx1)) + abs((cy0 + cy1) - (ty0 + ty1))
    size_diff = abs((cx1 - cx0) - (tx1 - tx0)) + abs((cy1 - cy0) - (ty1 - ty0))
    return movement + size_diff


def _self_test():
    assert classify(255, 0, 0)[0]
    assert not classify(60, 50, 40)[0]
    assert classify(0, 200, 0)[2] and classify(0, 200, 0)[3]
    assert classify(0, 0, 255)[4] and classify(0, 0, 255)[5]
    assert not classify(128, 128, 128)[4]

    assert core_vote([False, False, False, False, True, True, True, True, True])
    assert not core_vote([True, False, False, False, False, False, False, False, False])

    assert candidate_ok(500, 30, 30, 40)
    assert not candidate_ok(199, 30, 30, 40)

    assert smooth_edge(100, 105) == 100          # 死区内不动
    assert smooth_edge(100, 200) == 124          # 每帧最多 24
    assert smooth_edge(200, 100) == 176

    track = (100, 200, 100, 200)
    assert match_cost((110, 210, 105, 205), track) is not None
    assert match_cost((100, 400, 100, 400), track) is None   # 尺寸超 2 倍
    assert match_cost((500, 600, 300, 400), track) is None   # 距离太远


if __name__ == "__main__":
    _self_test()
    print("color_model: ok")
