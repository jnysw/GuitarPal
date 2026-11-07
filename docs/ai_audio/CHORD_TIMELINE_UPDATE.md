# GuitarPal 和弦自动对齐更新（Windows）

本更新在现有 v1 结果中新增可选 `timeline`，不改变 `segments.start/end` 的裁剪后秒坐标，也不改变旧客户端的字段含义。旧结果没有原始裁剪索引，不能凭总时长比例可靠补回；新字段只随更新后的新分析产生。

## 修复内容

- `load_audio` 保留重采样后完整输入采样数、实际 trim 起始样本和分析采样数。保留 librosa 真正返回的 trim 索引，不用固定偏移猜测。
- API 输出 `timeline.version=1`、`coordinate_system=trimmed_input_seconds`、`sample_rate_hz`、`input_sample_count`、`analysis_start_sample`、`analysis_sample_count`、`frame_hop_samples`。
- BTC 帧数刚好整除窗口长度时，padding 应为 0，避免丢掉最后一整窗；普通预测和带置信度的预测都覆盖。
- API 使用实际 detector feature 配置的 hop 映射帧时间，而不是另一份固定常量；末尾超出的 padding 按分析长度裁掉，不按歌曲时长拉伸和弦。

客户端映射：`原视频时间 = 提取区间起点 + analysis_start_sample / sample_rate_hz + segment 秒数`。速度不会参与这条原媒体坐标公式。人工微调优先，用户可以恢复自动映射；输入时长不符或 metadata 不合法时不自动应用。模型默认约 93ms 帧分辨率和音乐识别质量本身不因这项坐标修复而变成毫秒级准确。

## 更新与检查

1. 在 Windows 服务仓库先查看 `git status`，保存本地修改，再按原有流程更新 `codex/client-integrity-handoff` 分支。该 Draft PR 同时包含之前的可选分轨 sha256 增量；没有自动合并 main 或自动部署。
2. 使用原 CUDA 服务环境执行测试，例如 `.\.venv-server-cuda\Scripts\python.exe -m pytest server_tests/test_chord_timeline.py -q`。不在 Windows CUDA 环境安装 CI 的 CPU torch wheel，不更换权重或设备配置。
3. 按原有停止／启动脚本重启服务。Mac 本批没有远程执行 Windows 命令；若当前服务还未更新，App 会继续兼容旧响应。
4. 用户明确发起一次新和弦分析后，检查新结果有上述可选 timeline 字段，且 `analysis_start_sample + analysis_sample_count <= input_sample_count`。裁掉前导静音时 start sample 应非零，输入总时长要匹配上传 WAV；旧缓存不强制重算。
5. 更新 GuitarPal APK。在正常视频、全屏、滚动和弦及舞台中应显示“自动对齐原音频”；前导静音不提前显示第一和弦。手动修改后应显示人工校准，点击“恢复自动对齐”可回到服务端映射。A-B、定位和倍速都应使用相同原视频时间，不再重复添加裁剪偏移。

## 验证范围

CPU 回归使用生成信号、真实 librosa trim、真实预测循环但假模型输出，不下载权重。覆盖前导静音平移、模型整窗及非整窗长度、边界裁剪、实际 hop、Pydantic 输出保留与旧结果兼容；不替代 RTX 5070 Ti／Windows 的真实歌曲质量、模型边界与延迟验收。
