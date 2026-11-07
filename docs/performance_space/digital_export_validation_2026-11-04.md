# 2026-11-04 Android 数字音频导出验收

## 已交付

已保存演奏回听 → 保存调整 → 导出演奏音频 → 确认是否包含伴奏 → 生成 WAV → 回听／保存到文件／系统分享。未保存的草稿先保存，修改过标题／对齐／音量时提示先保存，避免导出未持久化配置。没有数据库迁移。

仅完整本机缓存，原视频修订／输入指纹／清单及所选轨均重新校验；完成后再次校验快照再展示作品。缺轨／源变化不伪装成完整作品，可显式关闭伴奏，仅导出录音。1.00× 伴奏离线渲染；其它速度只开放录音导出。`backingMs = micMs - leadMs + alignmentMs`，只在 `[0, endSourceMs - preset.startMs)` 混入，不叠加 source.startMs。

WAV 固定 44100 Hz、PCM16、立体声。AAC 分块解码到磁盘 PCM，逐轨 WAV／FLAC 使用既有校验与解码，文件分块读取；先测峰值再统一固定衰减至最多 0.98。静音／独奏／声像、逐轨音量、伴奏 master 和回听配比各施加一次。取消／后台／销毁中断并清理本次未完成文件，完整作品才原子发布；保存失败保留本机完整作品用于重试。导出不创建会话、改原录音或调用网络。

## 验证证据

- Flutter 全量 **479 项通过**；新增快照／缓存／非 1×／完成后二次校验 4 项，窄屏 320×568 双倍文字与后台迟到结果 2 项。已有回听保存回归通过。
- Kotlin/JVM **6 项通过**：正负 lead／alignment、首尾静音、实际结束；分层音量与声像／静音；固定整体衰减；48k→44.1k 正弦时长与音高；两遍取消；文件块边界与单声道复制。命令：`JAVA_HOME=<JDK> ./gradlew :app:testDebugUnitTest`。
- Android 模拟器 `emulator-5554` **1 项通过**，真实 MediaRecorder 录制 AAC 后渲染，伴奏使用本机生成 PCM WAV。生成的文件用原生 MediaPlayer 静音回放，取消另一次生成后重试成功，录音与伴奏 SHA-256 均不变，工作目录清空。
- 上述 Android 验收显式启用 `CHECK_EXPORT_DOCUMENT_UI=true`。通过系统 ACTION_CREATE_DOCUMENT 保存至 Downloads，读回 WAV：双声道、16 bit、44100Hz、74749 帧、约 1.695 秒、299040 字节。右声道在 50ms 为 0、300ms 为 2048、1200ms 为 0，与预期 100–1100ms 区间和 0.0625 振幅一致；左声道为静音。随后系统分享面板打开，未选择联系人或发送到外部服务。
- 核心日志：`/tmp/gp-export-full.log`、`/tmp/gp-export-native-unit.log`、`/tmp/gp-export-integration.log`、`/tmp/gp-export-analyze.log`；读回的测试作品 `/tmp/gp-export-document.wav`。这些本机临时证据不随 Git 上传。

## 剩余验收

没有实体安卓手机接入本轮。非 1× 保音高渲染尚未实现；未完成最长录音／16 轨压力、磁盘耗尽／写失败注入、FLAC 导出专项或真实乐器听感验证。空间预检不保证生成期间其它应用不会占满磁盘。设备、编码与蓝牙延迟仍是人工听感校准；采样时间映射不等于已测定硬件延迟。进程强杀不保证 finally 立即执行，过期临时目录在之后启动清理。

Android 普通 APK 在全部集成验收结束后另行构建恢复，不分发 integration_test 入口。GitHub 开发分支／Draft PR 同步；不合并、不部署 Windows，不创建付费资源。
