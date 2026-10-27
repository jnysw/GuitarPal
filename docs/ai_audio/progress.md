# AI 音频阶段进度

更新日期：2026-10-27。完整范围见 [原始开发规划](development_plan.md)，源码审计见 [current_state.md](current_state.md)。每批在 GitHub 开发分支提交代码、验证结果及本文件，完成后经 PR 评审。

## 本轮：M0 审计 + M1 协议基础

| 任务 | 状态 | 交付/下一步 |
| --- | --- | --- |
| GP-AI-001 仓库审计 | 已完成 | Flutter/Kotlin、Drift v9、播放器 200ms、循环容差、身份与解码复用点已核对；与新规划差异已登记 |
| GP-AI-002 可复现实验 | 待资料；登记基础已完成 | 两个固定提交 profile 默认关闭；缺实际权重、config、词表、硬件和音频；不填假基准 |
| GP-AI-003 协议与状态 | 进行中 | 已有结果 schema、OpenAPI 草案、Python 归一化/状态约束、Dart 解析/时间查找和共享 fixture；用量、任务列表分页、失败分支重试、下载与删除端点仍待细化 |
| GP-AI-004/005 持久任务、上传 | 未开始 | PostgreSQL 状态版本/lease/事务 outbox、Celery/Redis、不可变对象、鉴权/配额与删除竞态 |
| GP-AI-006 Android 输入与任务中心 | 进行中 | 已接音频文件/已有录音、上传确认、字节进度、Drift v10 任务/结果落盘、重新进入恢复与后台停轮询；视频精确区间提取/媒体修订仍待实现 |
| GP-AI-007/008 和弦闭环 | 客户端兼容流程已实现；模型闭环待验收 | 已接现有 `/api/v1/jobs` 上传/查询/结果与离线列表；v1 静音偏移未知，不开放原曲定位/A-B。真实 BTC 修补、基准、时间轴 UI 仍待完成 |
| GP-AI-009 指法库 | 未开始 | 固定数据转换、覆盖率、六弦图、偏好、署名 |
| GP-AI-010/011 分轨与回听 | 未开始 | 仅开放实测权重真正支持的轨；同步、下载、无双声/重复统计需单独验收 |
| GP-AI-012–014 修订/加固/部署 | 未开始 | 按 M2–M5 顺序执行 |

M0 整阶段尚未退出：缺模型复现和真实基准。此时先完成不依赖权重的契约基础，不将 M1 草案称为可用模型服务。

用户确认模型已在另一台 Windows 主机返回结果：RTX 5070 Ti 16GB、AMD 9600X、DDR5 32GB；月预算低于人民币 100 元。已提供 [API 交接说明](FLUTTER_ALGORITHM_API.md) 与配套 OpenAPI，明确现有和弦 HTTP/待实现分轨 HTTP 的区别。用户要求先开发，实际地址留到联调时提供，本轮不请求连接主机或运行真实模型。实际 checkpoint/config/运行时 OpenAPI 与基准仍待复核。部署路径与价格假设见 [Windows 联调与成本估算](deployment_and_costs.md)，尚未创建付费资源。

## 第二批：Windows v1 客户端与实验任务页

- `我的 → 音频工具（实验）`，路由 `/audio-tools`，仅 Debug 构建可使用；Release 不开放无鉴权实验服务。
- 可手动填写服务地址，或使用 `ALGORITHM_BASE_URL` 构建参数；HTTP 仅允许调试版的私有/回环地址。URL 中不接受内嵌密码，响应链接不得跨源或替换任务路径。
- Android 系统音频选择器创建有上限的私有副本；支持 MP3/WAV/FLAC/OGG/M4A，2–600 秒且不超过 50 MiB。已有练习录音可直接选取，移除分析历史不会删除原录音。
- 明确确认接收服务器与文件大小后，以 multipart `audio` 上传，`hmm`/`include_raw_chords` 在 query，设备保留服务端默认。进度来自实际读取的上传字节，不伪造模型进度。
- 202 后保存任务 ID；页面前台每 2 秒顺序轮询，网络错误退避到 30 秒并尊重 `Retry-After`；重入继续查询。404/410 显示已失效，HTTP 200 的 failed 正确停止。
- POST 回执丢失/应用中断保留“接收状态未知”，不自动重传；移除历史只清理本机记录/导入副本，不声称取消服务器任务。
- JSON 结果本地落盘；旧 v1 时间轴明确标为裁剪后坐标，置信度始终不可用，不显示未可靠验证的 BPM，不猜原曲 offset 或开放错误的 A-B。
- 分轨数据类型/安全 URL 解析已预备，`instrumental` 保留 derived 语义；HTTP 服务、下载和同步尚未实现，UI 仍未开放分轨。
- 数据库 v9 → v10 新增 `AlgorithmTasks`，未改动来源/片段/计划/录音旧表；任务不进入元数据同步队列。

交接协议保存在 `contracts/legacy_algorithm/`，与未来 GuitarPal 生产 `/v1` 隔离。操作步骤和本轮限制见 [客户端联调说明](windows_client_setup.md)。

本批验证：`flutter analyze` 无问题；完整 Flutter 测试 **292 项通过**，含 loopback 真实 multipart HTTP 流程、页面上传确认→离线结果、响应丢失不重传、GET 退避/过期、晚到响应不恢复已删历史，以及 v9 → v10 旧数据保留。Android Debug APK 构建通过。真实 Windows 模型和 Android 系统选择器端到端联调尚未执行，按用户要求留待后续。

## 时间轴与数据约定

- 上传的是选好区间的音频，服务端不重复裁切；`source_offset_ms` 只在引擎相对坐标转原媒体坐标时加一次。
- 下发的 `segments` 已是 `source_media_ms`，App 直接以播放器媒体位置查询，不乘除倍速、不再次加 offset。
- `[start_ms,end_ms)`；间隙、N、X 和区间外语义不同，不能延续上一和弦。v1 禁用首尾静音裁剪。
- 缺真实置信度聚合方法时 `confidence=null`；调性/BPM 缺失也为 null。
- `model_manifest.json` 的两个候选 profile 关闭；fixtures 仅为测试数据。

## 本轮验证

- 无依赖 Python 测试：5 项通过，覆盖时间/标签/结果非法输入、终态/取消、模型启用缺项。
- JSON Schema 2020-12、共享 fixture 跨字段不变量、OpenAPI 组件引用及关闭 profile 校验通过。
- Flutter 完整回归 282 项通过；随后补充人工修订保留原始 X/N 标签的路径，契约定向 4 项全部通过。
- `flutter analyze` 无问题。
- 带本机 Supabase 构建配置的 Android Debug APK 构建成功。最终补充只调整领域校验，不新增 UI 或数据库迁移。
- 新增 GitHub Actions：固定 Flutter 3.47.5 与 Python 3.11，分别执行应用分析/测试和音频契约校验；远程结果以 PR Checks 为准。
- 未运行真实模型；未测准确率、RTF、显存、分轨同步和真机新功能。未创建云资源。

## 下一批顺序

1. 补齐已实测模型资料并复现 M0；可并行完成未定义 API 和持久任务平台，实际 schema 不复制上游内存任务服务。
2. M1 本地环境：上传/校验/固定对象 → 建任务 → 持久调度 → 取消/重启恢复 → owner 越权验收。
3. M2 优先跑通本地视频 30–50 秒 → 真实和弦 → 原播放器定位/A-B → 保存片段 → 离线重开。
4. 再进入 M3 指法、M4 分轨和 M5 加固；元数据跨设备同步与其他 P2 不抢占 AI 主线。
