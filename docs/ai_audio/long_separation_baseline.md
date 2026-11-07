# Android 长曲分轨性能基线

2026-11-07，在 Android API 37 的 Pixel 9a 模拟器上通过 MelPal 公网访客入口测试。输入为仓库自生成视频循环后编码得到的 44.1 kHz 单声道 AAC。Android 从视频提取 PCM16 WAV，再分别提交 30 秒、3 分钟、8 分钟三个分轨任务。每个样本提交一次，下载全部七个 FLAC 文件，载入六条模型轨做静音的原生混音时钟验证。

## 实测

| 样本 | 上传 WAV | 提取 | 提交至回执 | 提交至取回结果 | 服务器处理 | 首轨校验完成 | 七轨下载与校验 | 七轨总量 | 本机六轨首次载入 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 30 秒 | 2.52 MiB | 2.32 s | 1.21 s | 8.88 s | 5.49 s | 1.56 s | 3.76 s | 3.37 MiB | 1.03 s |
| 3 分钟 | 15.14 MiB | 12.85 s | 3.24 s | 27.20 s | 21.99 s | 2.66 s | 8.71 s | 20.17 MiB | 4.42 s |
| 8 分钟 | 40.37 MiB | 34.25 s | 7.76 s | 64.50 s | 56.03 s | 6.59 s | 22.31 s | 53.85 MiB | 12.21 s |

- 「提交至回执」含发送请求和接收 HTTP 202。「提交至取回结果」含提交、每 2 秒轮询一次及结果 GET。服务器只返回 `processing_time_seconds`，因此表中不拆分排队、模型推理和编码写盘。
- 首轨和全轨时间从开始下载计时，包含主动中断一次和校验。每次先中断最大轨并保留 1024 字节，接着从 `Range: bytes=1024-` 继续。七轨均通过容器和 SHA-256 校验，重新创建离线缓存读取器后可打开。
- 实测只有一轮合成样本和一条网络路径。峰值内存、网络层实际重传量、真实歌曲和实体机 Wi-Fi／移动网络仍需采集。静音播放头验证覆盖解码与混音调度。

## 本轮客户端优化

单轨达到 4 MiB 后，下载完成或冷缓存重开时把 SHA-256 计算交给 Dart 后台 isolate。练习面板在字节接收完毕后显示正在校验，随后才进入本机解码。暂停后完整的临时文件可继续校验和发布。已通过校验的成品仍可离线使用。

8 分钟样本从提取开始到六轨载入约 133 秒，其中服务器处理和 Android 提取分别约 56 秒、34 秒。下一轮先测本地提取对相同音频的吞吐和内存，再评估保留采样时间轴的无损压缩上传。44.1 kHz 立体声 PCM16 WAV 在约 4 分 57 秒达到 50 MiB，8 分钟约 80.75 MiB。本次使用单声道以覆盖 8 分钟链路。

## 复测

在仓库根目录生成仅用于测试的视频。FFmpeg 可在开发机上单独提供。

```sh
profile_dir=$(mktemp -d)
python3 - "$profile_dir/base.mp4" <<'PY'
import base64
import pathlib
import re
import sys

fixture = pathlib.Path("integration_test/support/video_analysis_fixture.dart").read_text()
encoded = "".join(re.findall(r"'([A-Za-z0-9+/=]+)'", fixture))
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(encoded))
PY
ffmpeg -hide_banner -loglevel error -stream_loop -1 -i "$profile_dir/base.mp4" \
  -t 481 -c:v copy -c:a aac -ar 44100 -ac 1 -b:a 96k -movflags +faststart \
  "$profile_dir/profile.mp4"
```

每次运行选一个时长（30、180 或 480），使用测试模拟器。每次运行会创建一条真实分轨任务，占用访客服务配额。

```sh
flutter test integration_test/melpal_live_algorithm_test.dart -d emulator-5554 \
  --no-pub --reporter expanded --dart-define=CHECK_MELPAL_LIVE=true \
  --dart-define=CHECK_MELPAL_GUEST_LIVE=true \
  --dart-define=MELPAL_LIVE_PROFILE_SECONDS=30
```

出现 `MELPAL_PROFILE_VIDEO_READY` 后，从另一终端将上一步生成的文件写到测试 App 私有目录。使用临时文件并在写完后改名。

```sh
adb -s emulator-5554 shell -T 'run-as com.guitarpal.guitar_pal sh -c "cat > files/guitarpal_videos/melpal-profile.tmp && mv files/guitarpal_videos/melpal-profile.tmp files/guitarpal_videos/melpal-profile.mp4"' < /path/to/profile.mp4
```

结果由 `MELPAL_PROFILE_METRICS` 一行输出，可读到阶段毫秒数、文件字节数和提交次数。测试结束清理临时媒体、恢复模拟器原会话。后续验收顺序见 [优化计划](../next_development_plan.md)。
