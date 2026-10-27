# M0：仓库现状与 AI 音频接入审计

核对日期：2026-10-27。依据当前源码与本轮测试；原始需求见 [开发规划](development_plan.md)。本报告不把原规划的“已完成”直接当作验收结论。

## 真实技术栈与现状

- Flutter 3.47.5 / Dart 3.13.4，Riverpod、GoRouter；Android 原生 Kotlin 通过 MethodChannel 和 PlatformView 接入系统媒体能力。
- Drift 数据库当前为 v9：`PracticeSources`、`PracticeSegments`、`PracticePlans`、`PracticeSessions`、`PracticeRecordings`、`SyncOutboxEntries`。
- 本轮开始前，GitHub main 停留在 `aa5075d`；本机已有账号、提醒、反馈二级页和 outbox 改动尚未提交。本轮先单独归档这些改动，再提交 AI 音频基础，避免覆盖历史工作。
- Supabase Auth 已接入；真实邮箱回跳与登录恢复仍需实际邮箱验证，Google Provider 未配置。尚无 AI API、对象存储上传、模型、云端业务表或推理 worker。
- 本地 Python 为 3.9.6；未发现 Docker/uv 命令。尚未提供目标 GPU、已实测模型目录、运行命令、权重、配置或基准音频。

## 能力与复用点

| 现有实现 | 可复用部分 | AI 增量与限制 |
| --- | --- | --- |
| `lib/domain/practice_source/practice_source.dart` | 稳定来源 ID、元数据、视频/网页/文件类型 | 尚无明确音频类型、媒体修订或绑定；不能直接把任意 `file` 当作已支持音频 |
| `lib/core/platform/local_video_gateway.dart`、Android `LocalVideoImportPlugin.kt` | 系统选择、临时副本、提交/删除私有文件 | 目前只导入视频；尚无按样本精确提取区间音频、音频校验和及可恢复上传 |
| Android `PracticeAudioAnalyzer.kt` | MediaExtractor/MediaCodec、工作线程 PCM 解码、能量/起音分析 | 当前专用于自己的录音，仅返回摘要，不持久保存完整 PCM；和弦、音高、分轨均未实现 |
| `lib/media/playback/local_video_playback_controller.dart`、Android `LocalVideoPlatformView.kt` | 原媒体 position/duration、seek、倍速、音量、Surface 恢复 | 状态发送间隔 200ms；原生使用旧 `seekTo(Int)`，未通过音频精确 seek 验收；尚无外部音轨时钟同步 |
| `lib/media/playback/bilibili_web_playback_controller.dart` | 现有受限 JS 桥、原视频播放位置 | `timeupdate` 限流 200ms；网页播放不提供可上传音频字节；外部 stem 同步未实现 |
| `lib/media/playback/loop_controller.dart` | `LoopRange`、`setRange`、循环统计 | 默认 180ms 容差；不能将毫秒显示当作毫秒级循环准确度 |
| 两播放器的 `activateLoopRange`、`showPracticeSegmentEditorSheet` | 定位、设置 A-B、既有片段编辑和保存 | 和弦选区应调用同一链路；不新建一套循环存储 |
| `PracticePlaybackSessionRecorder`、`PracticeSessionService` | 单一播放器练习统计与后台检查点 | 分轨继续只使用这一份会话；不得每条音轨重复记录 |
| `lib/features/recordings/`、`PracticeAudioRecordingPlugin.kt` | 私有 M4A、普通试录/成果、同位置切换、清理 | 录音分析轴属于录音本身；不能默认与原曲一一对齐 |
| `lib/features/profile/data/supabase_auth_*` | 邮箱/Google SDK 调用、PKCE、安全会话存储 | 音频 API 需验证 Supabase JWT 的 issuer/audience/签名/到期；尚无服务端验证 |
| `lib/core/sync/` | 本机元数据队列与修订确认 | 这是练习元数据 outbox，不能充当服务端任务分发 outbox、上传队列或 AI 任务恢复系统 |

本地原生倍速使用 `PlaybackParams.setSpeed()`，未显式设置音高；B站使用 HTML5 `playbackRate`。保调效果仍需耳机/真机测量，本轮不据此承诺音高不变。

## 与新规划的差异及处理

1. 原规划基线为 10 月 15 日，现有提醒中心、反馈二级页、Supabase 和 v9 outbox 已更进一步；保留并回归这些实现。
2. 新规划将跨设备内容同步放在 P2。本轮保留既有基础，把研发顺序切到 AI 的 M0 → M1 → M2；不继续扩展元数据云同步。
3. `SourceCapabilities` 没有 `externalAudioSync`、时钟分辨率或精确 seek 描述。后续增加播放器适配层前应先验证原生 seek 和刷新精度；当前不开放 stem 同步入口。
4. 既有录音规划暂缓分轨与上传，新规划明确新增 AI 处理。这是新的用户主动提交能力；已有录音仍保留本地默认策略，上传前需显示区间、大小和留存说明。
5. 本轮无数据库结构变更；未来 `MediaRevision`/`AnalysisTaskLocal`/结果缓存迁移必须另测来源、A-B、录音路径和计划统计。

## 固定上游审查

本轮通过已连接 GitHub 读取规划指定提交的源码，未运行或下载权重。

- [loader.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/engine/loader.py)：`librosa.effects.trim` 丢弃索引，首尾静音不能保持原坐标。
- [output.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/engine/output.py)：无概率时填 `1.0`，部分 tempo 路径使用 120 兜底；不能直接作为可信结果下发。
- [pipeline.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/api/services/pipeline.py)：默认 `use_chordmini=True`、调用 `predict`，上游并未在该管线接入真实概率。
- [model.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/engine/model.py)：帧数恰好整除 timestep 时 `num_pad` 仍为 timestep，而尾块跳过条件使用该值，存在丢掉最后整块的风险。真实 adapter 必须修正并用实测权重回归；本轮仅登记，未声称修复上游。
- [job_store.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/api/services/job_store.py)：内存字典；不能提供生产持久任务语义。
- [config.py](https://github.com/Jeremyszs/chord-engine/blob/df2c526a82b5a3df0bb9c8fbf36d4de4d659b520/config.py)：明确区分 `N`/`X`，词表包含 14 种 quality。新归一化保留二者及未识别扩展、等音拼写和斜杠低音。
- BS-RoFormer 固定库提交来自规划；实际权重/推理封装、目标轨、配置和许可资料尚待复现核实。当前 `targets` 为空、profile 关闭，不能对用户显示吉他轨或声称已实现二轨。

## M0 尚缺的复现输入

需要用户已实测的两个项目路径/启动命令、checkpoint/config/词表、硬件、音源样例及授权依据。登记位置为 `server/model_manifest.json`，缺项保留 `null`/空数组，`enabled=false`。

随后为每个真实 profile 运行 30 秒/3 分钟/10 分钟输入，各重复 3 次，记录冷/热启动、RTF、峰值显存/RAM、磁盘、输出大小、时间坐标及真实轨道；本轮这些数据均为**未测**。协议 fixtures 为手工样例，不是黄金音频集，不能替代质量指标。

## 本轮可验证成果

- Python 和 Dart 的原媒体时间映射、半开区间、越界/重叠/重复分段校验；Android 按原媒体位置二分查找当前/下一和弦。
- 保留 N/X、不用默认 100% 概率、未知 schema 提示升级；人工偏移独立于机器区间。
- 任务状态领域约束、关闭未验证 profile 的校验、JSON Schema/OpenAPI 草案与共享 fixture。
- 尚无真实识别、分轨、可部署服务或新的 App 分析入口；本轮不改变用户已有练习流程。
