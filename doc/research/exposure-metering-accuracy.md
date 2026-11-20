# 测光精度调研与算法修订

日期：2026-10-27。对象：当前工作区的 CameraManager、ExposureCalculator、MeteringViewModel，以及点击/重新测光入口。

## 结论

旧链路不能从预览亮度得到可靠的绝对曝光：它没有使用拍摄时的曝光时间、光圈和相机 ISO，
而预览像素已经受自动曝光、传递函数及 ISP 处理影响。仅增加小数位或平滑窗口不能补回这些信息。

本次采用“指定测光位置 → 等待相机 AE 稳定 → 读取实际曝光元数据 → EV100 → 胶片曝光建议”的链路。
这是基于相机测光系统的曝光估计，不是经标定的亮度计，也不宣称手机具有专业 1° 点测光视角。

## 公开依据

- 反射式测光与曝光设置的关系为 N²/t = L·S/K；N 为光圈、t 为秒、S 为 ISO、L 为场景亮度。
  因此 EV100 = log₂(N²/t) − log₂(S/100)。参考摄影指导 David Yedlin 的
  [曝光方程及测光表校准说明](https://www.yedlin.net/NerdyFilmTechStuff/ExposureEquationsAndMeterCalibration)。
- K=12.5 是一种反射式测光表校准常数，不能直接当作场景 EV，也不是归一化像素灰值。
  例如 [Sekonic L-758 手册](https://sekonic.com/content/Files/manual/L-758/l-758_operating_manual_en.pdf)
  列出了反射式测光的 K。标准范围见 [ISO 2720:1974](https://www.iso.org/standard/7690.html)。
- sRGB 分量须先通过分段反传递函数线性化，才能计算相对亮度。
  [W3C sRGB 说明](https://www.w3.org/Graphics/Color/srgb)和
  [相对亮度公式](https://www.w3.org/WAI/WCAG21/Understanding/relative-luminance.html)说明了此区别。
  摄像头输出不一定是 sRGB，更不能把经过 ISP 的预览直接解释为场景 cd/m²。
- Apple 提供实际的 [lensAperture](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lensaperture)、
  [exposureDuration](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposureduration)和
  [ISO](https://developer.apple.com/documentation/avfoundation/avcapturedevice/iso)，
  以及 [isAdjustingExposure](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isadjustingexposure)
  和 [exposureTargetOffset](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuretargetoffset)。
  本实现等待收敛，不凭未经验证的 offset 符号直接修补欠曝/过曝数据。
- 界面位置必须通过 Apple 的
  [captureDevicePointConverted(fromLayerPoint:)](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/capturedevicepointconverted(fromlayerpoint:))
  转换，再设置 [exposurePointOfInterest](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposurepointofinterest)。
  此位置是 AE 的兴趣区域，具体权重仍由相机实现决定。

## 对照与修订

| 环节 | 原实现 | 本次实现 |
|---|---|---|
| 绝对测光 | 预览 BGRA 加权值除以 0.18，再加固定 EV 12.5 | 使用已稳定的实际光圈、曝光秒数和相机 ISO 计算 EV100 |
| 坐标 | 主界面的 0…1 坐标直接当像素；重测另用固定 393×500 尺寸 | 使用实际预览层转换，覆盖竖屏旋转和 aspect-fill 裁切 |
| 平滑 | 不同位置共用最近五次亮度历史，可能串入其他目标 | 每次测光独立收敛，四次有效元数据样本的 EV 极差不大于 0.1 |
| 不可用数据 | 无帧时返回默认 0.18，可变成伪测量 | 无新帧、无效元数据、未收敛或越界时不创建测光点，显示重试提示 |
| 相机曝光补偿 | 未纳入相机曝光状态 | 每次测量先归零相机 bias，等待稳定；用户的胶片曝光补偿独立处理 |
| ISO | 光圈锁定路径中 ISO 升高反而延长曝光 | t=N²/[2^EV100·(S/100)]；ISO 翻倍，快门时间减半 |
| 曝光补偿 | 一边开大光圈、一边缩短快门，效果互相抵消 | 固定所选光圈后只改变快门时间一次；+1 档令时间翻倍 |
| EV 与 Zone | 从取整、限制为 0…X 的 Zone 重建 EV | 保存原始连续 EV100；Zone 相对当前推荐曝光计算，仅绘图时裁切 |
| 标准档位 | 按秒的绝对差吸附到整档，多条重复实现 | 按 log₂ 比值比较，统一约 1/3 档的显示档位 |
| 默认结果 | 未测量也显示 EV12.5 和固定推荐曝光 | 测光前显示“—”，胶片 ISO 仍可选择 |
| 校准 | 预览亮度暗含固定灰卡假设 | 菜单中输入对照 EV100，按镜头保存 additive EV 偏移，可清除 |

## 算法细节

1. 点击预览或重新测光时，由真实预览层生成设备坐标。切换测光位置后至少等待 300 ms。
2. 每 80 ms 检查一次相机元数据，最多 30 次。需要新鲜视频帧、AE 未调整、相机 bias 接近零，
   且 targetOffset 的绝对值不超过 0.2 EV。四次有效样本极差 ≤0.1 EV 才返回 EV 的平均值。
   这些阈值是保守的稳定性门槛，不是绝对精度承诺。
3. 相机 ROI 自动曝光可能改变预览明暗，但存下的每个点是独立 EV100 快照，后续测光不改写旧点。
4. 校准只使用 raw EV100：offset = 参考 EV100 − raw EV100。限制 ±5 EV，避免明显输入错误；
   同一镜头的历史点按 raw+offset 重算，因此重复校准不会叠加漂移。
5. 多点的 EV100 均值作为曝光基准，保留小数。相对 Zone = 5 + 点 EV100 − 推荐设置 EV100。
   当场景跨度超过胶片设定宽容度，采用平衡两端溢出的 minimax 放置；不声称可恢复胶片无法容纳的跨度。
6. 光圈优先直接求快门；自动模式先选接近 1/125 s 的标准光圈，再求精确时间。
   正曝光补偿降低“设置 EV100”，增加曝光；正快门偏移提高设置 EV100，缩短时间。
7. 内部计算保留连续值，显示档位才吸附。标称 1/3 档的近似数值仍可能带来约 0.2 EV 的显示量化差。
   超过 30 秒的需求直接显示实际长曝光时间，不悄悄截成 30 秒。

## 可复现的检查

```bash
bash scripts/test-exposure.sh
bash scripts/test-rangefinder.sh
bash scripts/check-ios27-compatibility.sh
```

数学测试覆盖 EV100 −5…20、ISO 50/100/400/800、光圈 1.4/2.8/8/16，
加上自动光圈路径，共 2020 组曝光方程组合；另测 ISO 方向、补偿、非整数 EV、
无效输入、稳定性、标准档位及校准边界。视图模型测试直接使用实际项目代码，不复制算法。
这些检查证明公式一致性，不能证明手机实际测量的绝对误差小于某一数值。

真机自检已在连接的 iPhone 16 Pro 执行：LiDAR 取景链路正常，曝光元数据与新视频帧可读取。
当时镜头处于极暗条件，ISO 达 5184、曝光约 1/30 秒，targetOffset 仍约 −3.8…−4.0 EV；
三次测量均被拒绝，没有生成假 EV 或测光点。这验证了越界保护；正常光线重复性和参考表误差还需另测。

## 真机对照验收

- 在稳定、无频闪的照明下，让中性灰卡填满测量区域；手机与参考表对准同一平面，避免自身阴影与反光。
- 使用反射式参考测光，或明确区分入射式表和灰卡反射率/校准常数的关系，不直接强迫两种读数等同。
- 参考表设 ISO 100，输入其 EV100 进行校准。更换光源、照度和测量位置后记录残差。
- 至少覆盖明亮室外、普通室内与弱光，记录每档 10 次重复测量的均值、极差及参考误差。
- 同一光线切换胶片 ISO：EV100 应保持不变，建议曝光时间按 ISO 反比变化。
- 在复杂反差场景检查兴趣区域的权重局限。高光削顶、频闪、相机曝光极限与镜头透射率差异不能靠统一偏移完全消除。
- 长曝光胶片互易律失效补偿尚未实现，须按具体胶片数据表另行修正。
