# Tailscale / Windows / Flutter 实测记录

日期：2026-10-28（Asia/Shanghai）。真实私有域名只保存在忽略的本机配置；本报告不发布网络地址或用户录音。

## 真实 API

- Mac 通过 Tailscale HTTPS 请求 `/api/v1/health/ping`，返回 `{"ping":"pong"}`；默认 TLS 校验开启。
- 读取部署中的 `/api/openapi.json`，确认分轨 POST/status/result/files（GET/HEAD）均已实现。旧交接 OpenAPI 中 proposed 标记保留为历史交接资料，不据此关闭实际已验收的入口。
- 首个 3 秒连续和音样本在和弦处理时返回 HTTP 200 + failed，原因是未检测到节拍；这是输入不适合该管线的失败，不伪造成成功。
- 随后用脚本生成的 8 秒有节奏 C 大三和弦运行真实任务。输入 SHA-256：`27b69e4e828dcfc7956c848bc24195dca44c3b43684944689d630bee590bfe0f`。
- 两项 POST 均返回 202 和正确的相对查询路径，轮询均观察到 processing → completed。和弦约 3.30 秒、分轨约 74.04 秒，包括查询间隔；单次合成样本不能用作模型准确率或通用 RTF 基准，未核验实际 CPU/GPU 利用率。
- 和弦结果时长 7.87 秒，分轨保留完整 8.00 秒。该差异验证旧和弦静音裁剪限制仍然存在，不能猜 offset 或按时长缩放回原曲。
- 分轨实际返回 bass/drums/other/vocals/guitar/piano/instrumental 七条互异音轨；instrumental 为 derived，另外六条为 model。
- 七个文件分别验证 HEAD 长度、Range `bytes=0-11` 的 HTTP 206、完整 GET 长度/MIME、WAV 采样率/声道/帧数对应时长。此次每条 1,411,244 字节；不在代码中硬编码实测大小。

工具：`tools/smoke_legacy_algorithm.py`。原始结果、下载和 SHA-256 报告保存在 `/tmp/guitarpal-live-smoke/`，未提交原始音频、私有配置或服务端地址。

## Android / Flutter

在已配置的 Pixel_9a Android 模拟器执行 `integration_test/algorithm_stem_playback_test.dart`，两项均通过：

1. 应用持久私有目录写入合成 WAV，原生播放器播放/暂停/seek、时长快照、停止及禁止越目录播放。
2. Flutter `LegacyAlgorithmApi` 通过真实 HTTPS 查询已完成的 Windows 分轨任务，解析七轨清单，`AlgorithmStemStore` 下载真实 guitar 文件，原生播放器播放并跳转至约 2 秒。测试结束删除自己的测试音轨。

这覆盖实际 Flutter HTTP + Android 存储/解码/播放链路，不代表人工验收了音质或所有页面交互。Android 系统文件选择器、长文件、真机电话/蓝牙/耳机和多轨同步仍需后续验收。

## 回归检查

- `flutter analyze`：无问题。
- 完整 Flutter 单元/页面测试：300 项通过；含分轨 query/multipart、可空进度/结构化错误、任务类型持久化、v10 → v11 原任务/结果保留、v9 旧练习数据保留、文件类型/长度/路径/部分下载校验、离线试听界面及 seek。
- Python 契约测试：5 项通过；现有结果 schema / OpenAPI 引用检查通过。未验证的生产 model profile 仍关闭，这不影响独立 Windows 实验客户端。
- 正常 Android Debug APK 使用被 Git 忽略的本机账号和算法配置构建成功。
