# Windows 算法客户端联调

更新：2026-10-28。已通过 Tailscale Serve HTTPS 跑通实际和弦、分轨任务，以及 Android 模拟器上的 Flutter 下载和本机试听。该服务仅供同一 tailnet 的开发测试，普通互联网用户不能访问。

## 配置和入口

真实源地址写入本机 `config/algorithm.local.json`（已忽略，不进入 GitHub），格式见 `config/algorithm.example.json`。与既有账号配置一起启动：

```bash
flutter run --dart-define-from-file=config/supabase.local.json --dart-define-from-file=config/algorithm.local.json
```

也可只追加 `--dart-define=API_BASE_URL=https://YOUR_TAILNET_HOST`。`API_BASE_URL` 是统一配置键；兼容旧构建的 `ALGORITHM_BASE_URL`，前者优先。地址只包含 HTTPS 源，不加 `/api/v1`，不内嵌密码。没有构建配置时仍可在页面填写；已有任务保存自己的源地址，不随新配置迁移到另一服务。

Debug 构建：“我的 → 音频工具（实验）”。Mac 的 Tailscale 需保持连接，Windows 需开机并运行算法服务。模拟器通过 Mac 网络访问，独立 Android 真机也需要可访问该 tailnet。TLS 使用正常校验，不绕过证书。

“检查连接”只调用 `/api/v1/health/ping`，不能证明模型已就绪。Release 仍隐藏无内置账号鉴权的实验服务入口。

## 操作流程

1. 选择音频文件或已有练习录音，选择“和弦分析”或“分离音轨”。系统文件导入会创建私有副本；支持 MP3/WAV/FLAC/OGG/M4A，2–600 秒且不超过 50 MiB。
2. 确认接收服务器、文件和上传用途后提交。multipart 字段为 `audio`，参数放 query。客户端不发送 Supabase token，也不根据显卡型号擅自选择设备，沿用服务端默认配置。
3. 收到 202 后保存任务 ID 和类型，前台每 2 秒查询。处理阶段进度与上传字节进度分开；服务端未提供处理百分比时显示不定进度。
4. 离开任务页/打开结果页/进入后台会停止后续轮询；回到任务页恢复查询。停止查询不等于远端取消。响应丢失的 POST 不自动重传；重启或过期引起的 404/410 明确提示任务失效。
5. 和弦 JSON 可离线查看。旧接口时间基于裁剪静音后的音频，尚不用于原曲定位、同步或 A-B；默认 1.0 不作为模型置信度展示，不显示兜底 BPM。
6. 分轨结果列出人声、鼓、贝斯、吉他、钢琴、其他、伴奏七轨。伴奏保留 `derived` 含义。清单落盘不代表音频已下载；到期前需逐条“下载到本机”。显示服务端 `expires_at` 的本地时间。
7. 下载以流式写入 `.part`，检查长度、类型和 WAV/FLAC 头，再原子改名到持久私有目录 `algorithm_stems`。失败/中断不显示为已下载，重试从头获取；当前没有断点续传。服务器已到期时仍能试听本机完整文件。
8. 点击“试听”播放单条音轨；或“进入分轨练习”，对已下载的 PCM16 WAV 使用共享进度、0.50–2.00x（0.01 步进）、A-B 循环、主音量和各轨音量/静音/独奏。六轨混音或人声＋伴奏两种模式互斥，切换后保持位置并暂停；“保存练习设置”供下次恢复。离页停止，进入后台暂停；关联曲目／整曲计划后计入既有统计，未关联仍为试听；视频同步与片段计划仍待开发。详见 [分轨练习说明](stem_mix_practice.md)。
9. “移除本机记录”清理本机 JSON、导入副本和已下载音轨，不删除用户原有练习录音，也不取消远端任务。正在下载时不能删除该任务。离开结果页后已开始的下载可继续，应用进程被系统终止时下次需重试。

## 验证与后续

实测记录见 [2026-10-28 联调](live_validation_2026-10-28.md)。协议/页面测试仍使用明确标记的合成 fixture，不能据此声明模型准确率。

视频区间精确提取、源媒体修订、和弦原曲时间轴、指法库、视频同步与片段时间映射、跨账户权限及生产持久任务系统继续按规划开发。Windows 上游内存任务服务不具备生产队列的重启恢复保证。

复现真实接口冒烟（仅上传脚本生成的节奏音频）：

```bash
python3 tools/smoke_legacy_algorithm.py --base-url https://YOUR_TAILNET_HOST
```

输出与下载默认位于 `/tmp/guitarpal-live-smoke`，不提交到 Git。独立 Android 原生试听测试：

```bash
flutter test integration_test/algorithm_stem_playback_test.dart -d emulator-5554
```

若提供 `--dart-define-from-file=config/algorithm.local.json --dart-define=SMOKE_SEPARATION_JOB=<未过期的已完成任务ID>`，还会执行 Flutter HTTPS 下载真实吉他音轨并本机试听的测试；不提供时仅跳过该联网项。
