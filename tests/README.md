# 回归脚本说明

这里的脚本**不需要 TD、ModelSim 或开发板**，只验证“仓库结构 + 算法语义”：

```powershell
python -m unittest discover -s tests -v
```

| 脚本 | 检查内容 | 依赖 |
|---|---|---|
| `test_repo_layout.py` | 关键文件、文件边界（无加密 IP/构建产物）、按键/LED 引脚、模式映射、关键模块、OSD 模式表、README/vendor 覆盖 | 仓库文件 |
| `oil_model.py` | 5×5 邻域、4 bit 量化、4 桶投票、桶内均值、4 bit 扩展 | 无 |
| `motion_model.py` | 16 通道差分、≥6 票、连续 2 字支持、行配对、flood、中心计数 | 无 |
| `color_model.py` | 红/绿/蓝弱强判决、3×3 投票、尺寸/距离门限、死区/限幅 | 无 |
| `test_models.py` | 上述行为模型的 unittest 封装 | 无 |

三个行为模型也可以单独运行：

```powershell
python tests/oil_model.py
python tests/motion_model.py
python tests/color_model.py
```

## 这些脚本证明什么、不证明什么

- **证明**：RTL 里的参数、位段、状态机语义与文档一致；删掉关键模块或改坏模式映射会被发现；
- **不证明**：上板画质、颜色阈值在真实光照下的表现、DDR 时序收敛、资源是否放得下。

颜色阈值、曝光目标、油画强度、TNR 强度仍需要在你的板子与光照下确认。
