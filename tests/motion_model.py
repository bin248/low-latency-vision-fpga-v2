"""帧差运动检测的纯 Python 模型，对应 video_out.v 的 motion_word_observer
与 osd_text.v 的 motion_center_counter。

RTL 的粒度是 128 bit 字（16 个字节通道）：
  - 当前字与参考字逐字节比较，绝对差 >16 记一票，>=6 票为 hot；
  - 连续 2 个字都 hot 才算 support，抑制单字噪声；
  - 同一行里 support 段相距 <=8 像素就连起来，相邻行的段再配对成包围盒；
  - 一帧 hot_words 在 [24, 总字数/4] 之间、框至少 16x6 才算有效运动；
  - 目标覆盖 (640,360) 且此前离开中心 4 帧，计数 +1。
"""

DIFF = 16
VOTES = 6
SUPPORT_WORDS = 2
GAP = 8
MIN_W = 16
MIN_H = 6
HOT_MIN = 24
ARM_FRAMES = 4


def word_votes(current, reference):
    """16 字节通道的绝对差票数；输入长度必须为 16。"""
    if len(current) != 16 or len(reference) != 16:
        raise ValueError("word 需要 16 个字节通道")
    return sum(1 for a, b in zip(current, reference) if abs(a - b) > DIFF)


def word_hot(current, reference):
    return word_votes(current, reference) >= VOTES


def _row_segments(row_hot, word_px=16):
    """把一行里的 hot 字压成 support 段；连续 >=2 个字才算 support。"""
    segments = []
    i = 0
    while i < len(row_hot):
        if not row_hot[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(row_hot) and row_hot[j + 1]:
            j += 1
        if j - i + 1 >= SUPPORT_WORDS:
            segments.append([i * word_px, j * word_px + word_px - 1])
        i = j + 1

    merged = []
    for seg in segments:
        if merged and seg[0] - merged[-1][1] <= GAP:
            merged[-1][1] = max(merged[-1][1], seg[1])
        else:
            merged.append(seg)
    return merged


def frame_motion(hot_matrix, word_px=16):
    """hot_matrix: 每行一个 bool 列表（字粒度）。

    返回 dict：valid / flood / box / hot_words。box=(x0,x1,y0,y1)。
    """
    rows = len(hot_matrix)
    total_words = sum(len(r) for r in hot_matrix)
    hot_words = sum(sum(1 for v in r if v) for r in hot_matrix)
    flood = hot_words > total_words // 4

    boxes = []
    prev = None
    prev_row = None
    for y, row in enumerate(hot_matrix):
        segs = _row_segments(row, word_px)
        current = []
        for seg in segs:
            hit = None
            if prev:
                for p in prev:
                    if seg[0] <= p[1] + GAP and seg[1] >= p[0] - GAP:
                        hit = p
                        break
            if hit is None:
                current.append([seg[0], seg[1], y, y])
            else:
                hit[0] = min(hit[0], seg[0])
                hit[1] = max(hit[1], seg[1])
                hit[3] = y
                current.append(hit)
        for p in prev or []:
            if p not in current:
                boxes.append(tuple(p))
        prev = current
        prev_row = y
    for p in prev or []:
        boxes.append(tuple(p))

    best = None
    for x0, x1, y0, y1 in boxes:
        w = x1 - x0 + 1
        h = y1 - y0 + 1
        if w >= MIN_W and h >= MIN_H:
            if best is None or (w * h) > ((best[1] - best[0] + 1) * (best[3] - best[2] + 1)):
                best = (x0, x1, y0, y1)

    usable = (not flood) and (HOT_MIN <= hot_words <= total_words // 4) and best is not None
    return {"valid": usable, "flood": flood, "box": best, "hot_words": hot_words}


class CenterCounter:
    """motion_center_counter 的行为模型。"""

    def __init__(self):
        self.count = 0
        self.armed = False
        self.outside_frames = 0

    def frame(self, packet):
        box = packet.get("box")
        usable = packet.get("valid") and not packet.get("flood") and box is not None
        if not usable:
            self.outside_frames = 0
            return

        x0, x1, y0, y1 = box
        covers = x0 <= 640 <= x1 and y0 <= 360 <= y1
        outside = x1 < 635 or x0 > 645 or y1 < 355 or y0 > 365

        if covers:
            self.outside_frames = 0
            if self.armed:
                self.armed = False
                self.count = min(9999, self.count + 1)
        elif outside:
            if self.outside_frames >= ARM_FRAMES:
                self.armed = True
                self.outside_frames = 0
            else:
                self.outside_frames += 1
        else:
            self.outside_frames = 0

    def absent(self):
        self.outside_frames = 0


def _self_test():
    quiet = [[False] * 80 for _ in range(20)]
    assert not frame_motion(quiet)["valid"]

    # 单字热点不构成 support
    one = [[False] * 80 for _ in range(20)]
    one[10][10] = True
    assert not frame_motion(one)["valid"]

    # 30 行 x 2 个连续字：60 个 hot 字，框 32x30，应有效
    moving = [[False] * 80 for _ in range(30)]
    for y in range(30):
        moving[y][10] = True
        moving[y][11] = True
    pkt = frame_motion(moving)
    assert pkt["valid"] and pkt["box"] == (160, 191, 0, 29), pkt

    counter = CenterCounter()
    center = {"valid": True, "flood": False, "box": (630, 650, 350, 370)}
    outside = {"valid": True, "flood": False, "box": (0, 20, 0, 20)}
    counter.frame(center)
    assert counter.count == 0
    for _ in range(ARM_FRAMES + 1):
        counter.frame(outside)
    assert counter.armed
    counter.frame(center)
    assert counter.count == 1
    counter.frame(center)
    assert counter.count == 1  # 停在中心不重复计数


if __name__ == "__main__":
    _self_test()
    print("motion_model: ok")
