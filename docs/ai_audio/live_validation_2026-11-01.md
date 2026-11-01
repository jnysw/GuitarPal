# 2026-11-01：演奏录音与对齐回听验证

本批延续 10 月 31 日 P0b，交付 Android Debug 的 P0c 录音／回听首版。没有向 Windows 新建任务或上传用户媒体，没有服务端部署、付费资源或音频文件云同步。使用隔离数据库、合成八秒视频／伴奏和模拟器麦克风；不以此代替耳机、蓝牙、真实乐器录音的延迟与质量验收。

## Flutter 与迁移

最终 `flutter test --no-pub --reporter expanded` **444 项通过**，`flutter analyze --no-pub` 无问题。新增 **18 项**：

- 快照脱离外部可变 JSON、清单／来源／时间校验；原子日志串行写、重开／删除与结束后禁止旧写入；保存失败保留原文件／草稿、同 ID 重试幂等、已保存录音禁止走草稿丢弃路径；已提交文件恢复与缺失文件显式丢弃。
- 实际临时 SQLite 文件保存旧录音，移除新 nullable 列并设置 v13，再由 v14 迁移；旧标题／路径／种类保持，新演奏快照重开可读。既有 v8／v9／v10／v11／v12 迁移 fixture 按各自真实历史形态补齐旧表或移除新增列，不把“当前表只改 user_version”当旧 schema；没有跳过生产迁移错误。
- 捕获控制器的权限拒绝／永久拒绝、磁盘预检、迟到权限确认不得后台启动、实际 preset 冻结、并发停止只有一次原生 stop、后台不续录、试录不播放伴奏／不可存为正式成果、设备列表变化结束 take。
- 回听从完整缓存暂停载入，麦克风时间经原速度与起点估计映射到伴奏；独立音量／伴奏开关／手动对齐、定位、后台与自然结束、缺来源或缺轨时原始录音仍可播放，绝不补下载或推理。回听控制器不持有练习计时 recorder。
- 320px 双倍文字能回听和保存，试录丢弃、未保存退出提示；开启 semantics 的舞台录音权限弹窗在短暂 inactive 后继续前台授权，正式后台取消；原横竖屏舞台测试与旧录音流程保留。

## Android 原生与完整链路

最终接受轮（原版 Flutter SDK）三个文件 **4 项通过**：

1. `performance_audio_test.dart`：原生 available 设备列表／空间、单调启动确认时间、有效 M4A 时长及文件、提交后恢复、以零音量开始回听／调音量／暂停。
2. 同文件后台用例：先绘制真实应用首帧，录音后主机发送 HOME，等待原生 `onStop` 完成再重开 MainActivity；`isRecording=false`，已提交录音可恢复且容器／时长有效。验证的是新演奏录音的提交恢复，不改旧练习录音的取消语义。
3. 扩展 `performance_preparation_test.dart`：原视频→伴奏准备→舞台，保持原有去吉他／独立方案；明确开始正式录音、三秒倒计时、同一伴奏实际时钟推进→结束录音→回听→保存→返回舞台与原视频。数据库新增一个 `performanceTake`，快照保留本场实际 master=0、速度／控制与未校准标记；练习记录仍仅“原练习 + 本场舞台”两条，回听前后累计时长相同，原视频与原混音 JSON 不变，返回不自动播放。
4. `practice_audio_recording_test.dart`：旧练习录音提交／解析／能量分析／播放／删除全部通过。

另有本批早先同一原生音频实现的三项回归通过：`algorithm_mix_levels_test.dart`、`video_analysis_playback_test.dart`、`video_mix_restore_test.dart`。覆盖硬件头电平／声像／静音／seek epoch、原视频 WAV／FLAC 共享速度／A-B／原声控制、六轨／单轨／人声伴奏离线恢复。没有请求模型服务器。

集成测试 APK 每次重装会重置麦克风授权，主机验证脚本仅对模拟器测试包重新授予 RECORD_AUDIO。首次后台用例没有绘制首帧且未可靠触发原生 onStop，随后补绘制真实 UI 和实际 HOME／重开操作；未放宽“已停止录音且文件可恢复”的断言。

## 读屏问题与修复

Native 完整链路初轮虽然录音／保存断言通过，仍捕获到语义树异常，因此没有当作通过。临时诊断仅在本机 Flutter SDK 的原有断言上增加祖先链信息，确认涉及 `stage_position` Slider 被弹窗阻塞后改为 disabled；定位后 SDK 恢复为备份的相同字节。

上游相同问题见 [Flutter #193706](https://github.com/flutter/flutter/issues/193706)。应用侧统一使用 `showPerformanceDialog` 等待 `DialogRoute.completed`，弹窗 overlay 完全移除后才改变 Slider 的 enabled 状态。读屏与原始框架断言保持；未修改 SDK 行为、屏蔽异常或禁用 semantics。恢复原 SDK 后，最终全量 444 项与接受轮原生 4 项均通过。

## 同步与数据边界

保存纯麦克风原始 M4A，不渲染或替换成数字伴奏混音。快照保存录音启动确认、伴奏硬件播放头观察值与估计 lead，`deviceLatencyCalibrated=false`；可用设备列表不是已验证的实际路由。回听使用两条播放器与约 200ms 容差的进度纠偏，按录制时速度映射；±2 秒／10ms 手动对齐与音量可保存，不能据此宣称逐样本同步、自动设备延迟补偿或数字导出。

草稿先写日志再启动麦克风；已提交文件可恢复，进程被强杀时尚未完成封装的 pending 文件不保证恢复。退出保留草稿须明确确认；用户可回听／保存／丢弃，已保存成果删除走历史列表。录音／快照目前留在本机，未新增 Supabase 音频上传。

`build/qa/performance_take.png` 来自合成歌曲和模拟器输入，已检查回听、独立音量、伴奏开关、对齐入口、标题与保存／丢弃控件。它不包含用户 IP 或真实演奏，不作为真机听感证据。

## 普通安装包

所有集成回归结束后，重新运行 `flutter build apk --debug --no-pub --dart-define-from-file=config/supabase.local.json` 生成普通应用入口的 Debug APK，安装到 `emulator-5554` 并启动 MainActivity；不交付测试入口。私网／Supabase 本地配置保持忽略，未写入仓库。实体手机未连接，本批不代替真机输入质量与耳机路由验收。
