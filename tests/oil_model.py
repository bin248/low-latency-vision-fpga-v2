"""5x5 油画算法的纯 Python 模型，对应 edge_detect.v 中的 oil_pixel5。

RTL 的做法：
  1. 每个通道取高 4 位（量化到 16 级）；
  2. lum = R4 + 2*G4 + B4，取 lum[5:4] 作为 4 个亮度桶之一；
  3. 统计 5x5 邻域里每个桶的像素数，选最多的桶（平票偏向低索引桶）；
  4. 对该桶的 R/G/B 分别求和，用移位减法除以 count，得到 4 bit 均值；
  5. 4 bit 复制成 8 bit 输出。

这里不模拟行缓冲和 20 项滑动窗口，只模拟稳定态的“选桶 + 桶内均值”，
用于验证算法语义与测试边界条件。
"""

from collections import namedtuple

Pixel = namedtuple("Pixel", "r g b")
Bucket = namedtuple("Bucket", "count r g b")


def quant4(value):
    """8 bit -> 4 bit，与 RTL 的 px[11:8] 等位段一致。"""
    return (value >> 4) & 0xF


def oil_pixel(rows):
    """rows: 5x5 的 Pixel 序列；返回量化后的 Pixel（每通道 0..255）。"""
    if len(rows) != 5 or any(len(row) != 5 for row in rows):
        raise ValueError("oil_pixel 需要 5x5 邻域")

    buckets = [{"count": 0, "r": 0, "g": 0, "b": 0} for _ in range(4)]
    for row in rows:
        for px in row:
            r4, g4, b4 = quant4(px.r), quant4(px.g), quant4(px.b)
            lum = r4 + 2 * g4 + b4          # 与 RTL 的 lum[5:0] 一致
            k = (lum >> 4) & 0x3            # lum[5:4]
            buckets[k]["count"] += 1
            buckets[k]["r"] += r4
            buckets[k]["g"] += g4
            buckets[k]["b"] += b4

    def pick(a, b):
        # RTL: count[b] > count[a] 才选 b，因此平票选低索引
        return b if buckets[b]["count"] > buckets[a]["count"] else a

    w01 = pick(0, 1)
    w23 = pick(2, 3)
    winner = pick(w01, w23)
    chosen = buckets[winner]

    if chosen["count"] == 0:
        return Pixel(0, 0, 0)

    # RTL 用 q3/q2/q1/q0 的移位减法求 floor(value/count)；
    # 对 0..25 的计数，整数除法与它逐位等价。
    mean_r = chosen["r"] // chosen["count"]
    mean_g = chosen["g"] // chosen["count"]
    mean_b = chosen["b"] // chosen["count"]
    return Pixel(mean_r * 0x11, mean_g * 0x11, mean_b * 0x11)


def _self_test():
    white = Pixel(255, 255, 255)
    black = Pixel(0, 0, 0)
    assert oil_pixel([[white] * 5 for _ in range(5)]) == Pixel(255, 255, 255)
    assert oil_pixel([[black] * 5 for _ in range(5)]) == Pixel(0, 0, 0)

    mixed = [[white if (x + y) % 2 == 0 else black for x in range(5)] for y in range(5)]
    assert oil_pixel(mixed) in (Pixel(255, 255, 255), Pixel(0, 0, 0))

    # 量化：0x1F/0x2F/0x3F -> 1/2/3，lum=8 -> 桶 0，均值回写为 0x11/0x22/0x33
    px = Pixel(0x1F, 0x2F, 0x3F)
    assert oil_pixel([[px] * 5 for _ in range(5)]) == Pixel(0x11, 0x22, 0x33)

    # 平票：12 白(桶3) + 13 黑(桶0)，黑桶更多
    rows = [[black] * 5 for _ in range(2)] + [[black] * 3 + [white] * 2] + [[white] * 5 for _ in range(2)]
    assert oil_pixel(rows) == Pixel(0, 0, 0)


if __name__ == "__main__":
    _self_test()
    print("oil_model: ok")
