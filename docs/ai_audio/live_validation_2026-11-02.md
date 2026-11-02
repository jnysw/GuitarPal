# 2026-11-02：部署核对与同曲演奏对比

## 算法端部署核对

用户确认算法端优化已完成。已读取私有算法仓库 `codex/client-integrity-handoff` 的 `cdc5de3fc60213a2e9e50afc66a998b4614391d6`，相对上一批 `85c0269` 新增原流水线测试 fixture 更新、客户端说明及 [Windows 验证记录](https://github.com/jnysw/chordengine-algorithm-server/blob/cdc5de3fc60213a2e9e50afc66a998b4614391d6/diagnostics/chord_timeline_validation.md)。记录报告 Windows 90 项、CUDA 合成样本时间映射和分轨摘要校验已通过；这是 Windows 端记录，不冒充本轮 Mac 重新执行结果。

本轮 Mac 直连 HTTPS 只读核对：

- `/api/v1/health/ping` 返回 `ping=pong`。
- `/api/v1/health` 返回 `status=ok`、`model_loaded=true`。
- `/api/v1/separation/health` 返回 `ready`、`model_device=cuda:0`、RTX 5070 Ti、单 worker、AMP=false。
- 运行中的 `/api/openapi.json` 保留 `AnalysisResult.timeline` 可选字段；`ChordTimeline` 的 version、coordinate_system、采样率、完整输入样本数、分析起点／长度与帧 hop 与当前客户端协议一致。

未重跑推理、未上传用户音频、未改 Windows 代码或重启服务，未创建付费资源。以上不构成真实歌曲识别准确率或长曲性能基准。旧结果不会因为服务已更新就自动补齐 timeline；使用新分析结果才有采样自动映射。

## Flutter 与本机 A/B 对比

`flutter test` **456 项通过**，`flutter analyze` 无问题。新增 7 项覆盖共同原媒体区间、不同倍速／已保存微调只换算一次、来源修订／快照身份／起点缺失与过短区间拒绝、单播放器切换和共同末尾、后台迟到播放抑制、文件丢失，以及 320px 双倍字体下的操作与后台恢复。

Android 模拟器 `performance_comparison_test.dart` **1 项通过**：

- 使用两个自生成 AAC/M4A 正弦 fixture（6.2 秒、12.1 秒），隔离 SQLite 与临时目录，无用户录音。保存两条不同日期／倍速的成果，实际经过历史列表选择与路由进入对比。
- 开始不自动播放。共同原曲定位后，A 的原生播放器时长／位置与预期相符；播放中切 B，原生时长变为 B、位置按录制倍速与起点映射。位置断言保留播放器调度／压缩音频 seek 容差，不声称逐样本切换。
- 暂停无声音；返回列表后播放器卸载。两份音频字节不变，数据库仍只有两条录音，练习会话为空。读屏断言保持开启。

初轮集成测试临时目录创建失败，已修正测试目录为应用 filesDir 下的独立临时目录后通过；没有放宽原生位置、文件不变或统计断言。

Android 配置健康检查 `analysis_connection_and_range_test.dart` 的指定用例 **1 项通过**：未传入 API 地址的普通构建读取本机内置配置，并通过真实 HTTPS ping。只启用 `CHECK_ALGORITHM_HEALTH=true`，未启用真实上传测试。实体手机仍须自行连接同一 Tailscale 网络。

所有集成测试后重新执行 `flutter build apk --debug --no-pub --dart-define-from-file=config/supabase.local.json`，普通 Debug APK 构建成功。本机配置保持忽略，不将集成测试入口作为交付包。模拟器与合成音频的验证不代替实体手机、蓝牙或真实乐器的听感验收。
