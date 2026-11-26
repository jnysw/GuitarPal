# Flutter 算法服务器 API 交接文档

核对日期：2026-10-27。依据本机源码整理，未启动服务或运行真实模型推理。

**交付范围：接口说明与新增服务契约，不是已完成的后端实现。** `chord-engine` 的 HTTP 接口已存在；本文的 `separation` HTTP 接口需要后端开发 AI 实现。配套 `algorithm-api.openapi.json` 可导入支持 OpenAPI 的工具；其中 `x-implementation-status` 标记实现状态。

## 1. 给开发 AI 的任务说明

```text
为 Flutter 应用接入 F:\ChordEngine 下的两个算法项目：
1. chord-engine：和弦、调性、BPM、和弦时间片识别。
2. bs-roformer-infer：人声、鼓、贝斯、吉他、钢琴、其他及伴奏分离。

以本文件及 algorithm-api.openapi.json 为接口契约。
保留 chord-engine 已存在的 /api/v1/jobs 系列端点。
在服务适配层新增 /api/v1/separation/jobs 系列端点及音轨下载端点。
Flutter 只调用 HTTP 服务，不调用服务器本地路径或 Python 包。
默认两个算法独立处理同一份原始音频，不要求先分轨再识别和弦。
先实现各自的上传→任务轮询→取结果，再实现分轨下载、播放和同步。
修复本文第 7 节列出的对接问题；任何改变现有 v1 JSON 语义的修复应版本化。
不要把新增接口、原有文档示例或 Python API 当成已经运行的 HTTP 服务。
```

建议架构：Flutter → 一个对外 API 地址 → 两个算法适配器 → 后台推理任务与文件存储。两个适配器可以同进程起步，也可以分别部署，由网关提供同一域名。模型加载、设备选择、队列和缓存由服务器管理。

本文不纳入同目录的 `demucs`。分轨不是和弦识别的必需前置步骤；如后续对比发现伴奏识别更合适，再由服务端编排，不让 Flutter 负责把分轨文件下载后重新上传。

## 2. 通用约定

| 项目 | 约定 |
|---|---|
| BASE_URL | 通过 Flutter 环境配置注入；路径从 `/api/v1` 开始 |
| 上传 | `multipart/form-data`，文件字段固定为 `audio` |
| 参数位置 | 本文所有算法选项都是 URL query 参数，不是表单字段 |
| JSON | UTF-8；字段名使用 `snake_case` |
| 时长/片段坐标 | 秒，JSON number；Flutter 转 `Duration` 时乘 1000 并取整 |
| 日期 | ISO 8601 UTC，例如 `2026-10-27T03:00:00.000Z` |
| 任务状态 | `queued` → `processing` → `completed`，执行异常为 `failed` |
| 上传成功 | HTTP `202 Accepted`；只表示接收并创建任务 |
| 轮询 | 2–3 秒一次；终态停止轮询，页面退出时取消轮询 |
| 返回的 URL | `poll_url`、`result_url`、`download_url` 均为相对路径，基于 BASE_URL 的源地址解析 |
| 数值解析 | Dart 使用 `(value as num).toDouble()`，兼容 JSON 整数和小数 |
| 鉴权现状 | 当前 chord-engine 没有鉴权；配套 OpenAPI 也未声明已存在的鉴权机制 |

对外部署时由现有业务后端/网关进行用户鉴权和任务归属校验；若采用 Bearer token，由业务登录系统签发。Flutter 不内置服务器长期密钥，下载音轨也必须通过同等授权校验。业务鉴权的 401/403 属于新增部署层能力。

手机的 `localhost` 指手机自己。局域网测试使用服务器局域网 IP，服务器监听 `0.0.0.0`，并允许相应端口。发布环境使用 HTTPS。不要把本文中的示例域名当成已部署地址。

## 3. chord-engine：现有 HTTP API

源码位置：`chord-engine/api/main.py`、`api/routes/jobs.py`、`api/models/response.py`。

| 方法 | 路径 | 用途 | 实现状态 |
|---|---|---|---|
| POST | `/api/v1/jobs` | 上传并创建和弦识别任务 | 已有 |
| GET | `/api/v1/jobs/{job_id}/status` | 查询任务状态 | 已有 |
| GET | `/api/v1/jobs/{job_id}/result` | 获取识别结果 | 已有 |
| GET | `/api/v1/health` | 服务状态 | 已有 |
| GET | `/api/v1/health/ping` | 轻量存活检查 | 已有 |
| GET | `/api/docs` | Swagger UI | 已有 |
| GET | `/api/redoc` | ReDoc | 已有 |
| GET | `/api/openapi.json` | 服务器生成的实际 OpenAPI | 已有 |

### 3.1 创建任务

```http
POST /api/v1/jobs?smooth_method=hmm&device=cpu&include_raw_chords=false
Content-Type: multipart/form-data; boundary=客户端自动生成

audio: <文件二进制>
```

| 参数 | 类型 | 必填 | 默认/范围 |
|---|---|---|---|
| `audio` | 文件，multipart body | 是 | `.mp3`、`.wav`、`.flac`、`.ogg`、`.m4a` |
| `smooth_method` | string，query | 否 | `hmm`；可选 `hmm`、`median` |
| `device` | string，query | 否 | `cpu`；可选 `cpu`、`cuda` |
| `include_raw_chords` | boolean，query | 否 | `false` |

上限实际为 `52,428,800` 字节，即 50 MiB。解码并裁掉首尾静音后，音频至少 2 秒；不足时任务会失败，上传时不一定被拒绝。扩展名被接受也不保证文件的实际编码可解码。

HTTP 202：

```json
{
  "job_id": "a1b2c3d4e5f6789012345678abcdef01",
  "status": "queued",
  "message": "Audio received. Analysis queued.",
  "poll_url": "/api/v1/jobs/a1b2c3d4e5f6789012345678abcdef01/status",
  "result_url": "/api/v1/jobs/a1b2c3d4e5f6789012345678abcdef01/result"
}
```

### 3.2 轮询状态

```http
GET /api/v1/jobs/{job_id}/status
```

HTTP 200：

```json
{
  "job_id": "a1b2c3d4e5f6789012345678abcdef01",
  "status": "processing",
  "progress": 60,
  "message": "Running chord inference...",
  "created_at": "2026-10-27T03:00:00.000Z",
  "error": null
}
```

`progress` 是 0–100 整数，是阶段检查点，不是精确剩余时间。`failed` 时 `error` 为错误描述字符串；失败进度可能停留在任意值，不能用 `progress == 100` 代替终态判断。

### 3.3 结果

```http
GET /api/v1/jobs/{job_id}/result
```

下面是完整字段的简短示例，数值仅用于格式说明：

```json
{
  "job_id": "a1b2c3d4e5f6789012345678abcdef01",
  "status": "completed",
  "audio_filename": "song.mp3",
  "duration_seconds": 8.0,
  "tempo_bpm": 120.0,
  "key": "C major",
  "progression": "I → V",
  "chord_count": 2,
  "segments": [
    {"chord": "C", "roman": "I", "start": 0.0, "end": 4.0, "duration": 4.0, "confidence": 1.0},
    {"chord": "G", "roman": "V", "start": 4.0, "end": 8.0, "duration": 4.0, "confidence": 1.0}
  ],
  "raw_chords": null,
  "processing_time_seconds": 12.34,
  "created_at": "2026-10-27T03:00:12.340Z"
}
```

| 字段 | 类型 | 语义 |
|---|---|---|
| `job_id` | string | 32 位 UUID hex；客户端当作不透明字符串 |
| `status` | string | 结果成功返回时固定 `completed` |
| `audio_filename` | string | 上传文件显示名称 |
| `duration_seconds` | number | 当前实现为裁剪静音后的分析音频时长 |
| `tempo_bpm` | number | 全局估计 BPM；不要当作固定节拍的精确时间表 |
| `key` | string | 调性，例如 `C major`、`E minor` |
| `progression` | string | 和弦级数进行，作为展示文本，不依赖特定箭头字符解析 |
| `chord_count` | integer | 不同和弦的数量，排除 `N`、`X`、`-`；不是片段数 |
| `segments` | array | 按时间排列的和弦片段 |
| `segments[].chord` | string | `C`、`A:min`、`G:7` 等；裸根音表示大三和弦 |
| `segments[].roman` | string | 级数，例如 `I`、`vi`；不能确定时可能是 `?` |
| `segments[].start/end/duration` | number | 秒；数值通常四舍五入至三位小数 |
| `segments[].confidence` | number | **当前流水线默认填充 1.0，不是真实可信度** |
| `raw_chords` | string[] 或 null | 原始逐帧标签；默认 null，没有配套逐帧时间戳 |
| `processing_time_seconds` | number | 算法流水线耗时，不含客户端上传耗时 |
| `created_at` | string | 此结果里实际上是完成时间；状态接口同名字段是任务创建时间 |

当前 170 类标签包含 `min`、`maj`、`dim`、`aug`、`min6`、`maj6`、`min7`、`minmaj7`、`maj7`、`7`、`dim7`、`hdim7`、`sus2`、`sus4`；大三和弦输出为裸根音，另有 `N`（无和弦）和 `X`（未知）。Flutter 可兼容 `C:maj`，但不能只支持这种形式。保留原始标签，并单独做显示名称转换。

**当前 HTTP 结果不包含 `beats`。** 内部 `build_output()` 虽生成该字段，API 流水线返回字典及 Pydantic 结果模型均未暴露，前端不能按旧文档假定存在。

### 3.4 错误与保留时间

业务错误一般为以下扁平 JSON，不是 `{"detail": {...}}`：

```json
{"error": "unsupported_format", "detail": "Unsupported file extension '.txt'.", "job_id": null}
```

| HTTP | `error` | 前端处理 |
|---|---|---|
| 400 | `unsupported_format` / `invalid_file` | 修正文件 |
| 404 | `job_not_found` | ID 不存在、过期或服务器重启丢失 |
| 409 | `job_not_complete` | 等待后继续查询状态 |
| 413 | `file_too_large` | 换用更小文件 |
| 422 | `validation_error` | 参数错误或缺少 audio |
| 422 | `processing_failed` | 任务执行失败；展示失败状态 |
| 500 | `internal_server_error` | 服务端异常 |

任务状态接口对已执行失败的任务仍返回 HTTP 200、`status=failed`。结果接口对该任务返回 422。Flutter 必须同时处理 HTTP 错误与任务状态失败。

任务当前仅存在进程内存中，重启丢失；按创建时间超过 60 分钟后可能被每 30 分钟运行一次的清理任务移除。上传文件在推理成功或失败后删除，不提供原音频下载。Flutter 应保存已取得的 JSON 和本地原音频引用。

### 3.5 本机启动入口

先准备项目依赖和权重，再从 `F:\ChordEngine\chord-engine` 启动：

```powershell
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --workers 1
```

当前 `config.py` 把临时目录写死为 `/tmp`，Windows 上不能直接假定该路径可用。启动前改为可配置目录，默认使用 `tempfile.gettempdir()`，并确保目录存在。此处仅给启动入口，本次没有安装依赖或启动服务。

## 4. bs-roformer-infer：现有 Python 接口

当前没有 HTTP 路由；`clean_api.py` 是 Python API，不是 FastAPI 应用。

```python
from bs_roformer import BSRoformerSession

# Worker 启动时加载一次；device 可为 auto/cpu/cuda/cuda:N。
session = BSRoformerSession(device="auto").load()
try:
    # inputs 目录只放这一项任务的 WAV，避免混入其他用户文件。
    manifest = session.infer(
        r"D:\algorithm-data\job-id\inputs",
        store_dir=r"D:\algorithm-data\job-id\outputs",
        output_format="wav_s16",
    )
    receipt = manifest.as_dict()
finally:
    # 示例展示完整生命周期；常驻 Worker 应在关闭时才执行 close()。
    session.close()
```

`infer()` 接受的是**文件夹**，当前只扫描该层的 `*.wav`；不直接接受 MP3 或单个音频文件路径。HTTP 适配器需先解码成 WAV，处理声道和目标采样率，再调用它。推理实现直接读取 WAV，并不自动重采样；不能把更改文件扩展名当作转码。

当前默认模型 slug：`roformer-model-bs-roformer-sw-by-jarredou`。其六个模型音轨为 `bass`、`drums`、`other`、`vocals`、`guitar`、`piano`；另生成 `instrumental = 输入混音 - vocals`。因此默认共有七个输出文件。`instrumental` 是派生伴奏，不是第七个模型预测声部，也不应假定恰好等于其他五个预测声部相加。

支持的真实输出参数：

| `output_format` | 文件 | 编码 |
|---|---|---|
| `wav_float32` | `.wav` | 32 位浮点；Python API 原默认值 |
| `wav_s16` | `.wav` | PCM 16 位 |
| `flac16` | `.flac` | FLAC PCM 16 位 |

不支持直接输出 MP3。新增 HTTP API 默认采用 `wav_s16`；这是适配层的显式默认值，需在 Flutter 目标平台实际验证解码与播放。

Manifest 格式：

```json
{
  "outputs": [
    {"input_path": "服务器内部/input.wav", "output_id": "vocals", "output_path": "服务器内部/input_vocals.wav"},
    {"input_path": "服务器内部/input.wav", "output_id": "instrumental", "output_path": "服务器内部/input_instrumental.wav"}
  ]
}
```

上面缩略展示两条；实际必须遍历真实 manifest。它没有时长、采样率、大小和 URL，这些信息由 HTTP 适配器读取音频文件并补充。服务器磁盘路径不返回给 Flutter。

## 5. 新增分轨 HTTP API 契约（尚未实现）

| 方法 | 路径 | 成功状态 | 用途 |
|---|---|---|---|
| POST | `/api/v1/separation/jobs` | 202 | 创建分轨任务 |
| GET | `/api/v1/separation/jobs/{job_id}/status` | 200 | 查询状态 |
| GET | `/api/v1/separation/jobs/{job_id}/result` | 200 | 获取所有输出描述 |
| GET / HEAD | `/api/v1/separation/jobs/{job_id}/files/{stem_id}` | 200 / 206 | 下载或读取音轨头信息 |

第一版固定使用上述默认模型，不向 Flutter 开放任意 checkpoint、配置路径、模型下载 URL 或设备选项。设备由服务端配置，且显式请求不可用 CUDA 应报错，不能静默降级。

### 5.1 创建分轨任务

```http
POST /api/v1/separation/jobs?output_format=wav_s16
Content-Type: multipart/form-data; boundary=客户端自动生成

audio: <文件二进制>
```

`output_format` 可选 `wav_s16`、`wav_float32`、`flac16`，默认 `wav_s16`。输入格式与和弦接口一致。新增适配层限制：最大 50 MiB，解码后时长 2–600 秒；这两个时长边界是新服务的产品约束，不是原 Python 包已有校验。服务端在创建任务前检查大小与扩展名，后台解码时检查实际时长与可解码性。

HTTP 202：

```json
{
  "job_id": "b1b2c3d4e5f6789012345678abcdef02",
  "status": "queued",
  "message": "Audio received. Separation queued.",
  "poll_url": "/api/v1/separation/jobs/b1b2c3d4e5f6789012345678abcdef02/status",
  "result_url": "/api/v1/separation/jobs/b1b2c3d4e5f6789012345678abcdef02/result"
}
```

### 5.2 分轨任务状态

```json
{
  "job_id": "b1b2c3d4e5f6789012345678abcdef02",
  "status": "processing",
  "stage": "separating",
  "progress": null,
  "message": "Separating audio...",
  "created_at": "2026-10-27T03:00:00.000Z",
  "updated_at": "2026-10-27T03:00:10.000Z",
  "error": null
}
```

`stage`：`queued`、`decoding`、`loading_model`、`separating`、`writing_outputs`、`completed`、`failed`。`progress` 为 0–100 整数或 null，完成必须 100。原包没有可直接接到 HTTP 的进度回调；无法精确测量时返回 null，Flutter 显示不定进度。若需写盘阶段的细分进度，适配器须增加可靠事件，不能靠控制台文字伪造精确进度。

失败时 `status=failed`、`stage=failed`，`error` 是以下对象；其余状态为 null：

```json
{"code": "processing_failed", "message": "Audio separation failed.", "retryable": false}
```

注意：该错误对象与现有和弦状态接口的错误字符串不同，Dart 分别定义类型。

### 5.3 分轨结果

```json
{
  "job_id": "b1b2c3d4e5f6789012345678abcdef02",
  "status": "completed",
  "audio_filename": "song.mp3",
  "model": "roformer-model-bs-roformer-sw-by-jarredou",
  "duration_seconds": 180.0,
  "output_format": "wav_s16",
  "processing_time_seconds": 93.5,
  "created_at": "2026-10-27T03:00:00.000Z",
  "completed_at": "2026-10-27T03:01:33.500Z",
  "expires_at": "2026-10-28T03:01:33.500Z",
  "stems": [
    {
      "id": "vocals",
      "origin": "model",
      "filename": "input_vocals.wav",
      "content_type": "audio/wav",
      "size_bytes": 31752044,
      "duration_seconds": 180.0,
      "sample_rate": 44100,
      "channels": 2,
      "download_url": "/api/v1/separation/jobs/b1b2c3d4e5f6789012345678abcdef02/files/vocals"
    },
    {
      "id": "instrumental",
      "origin": "derived",
      "filename": "input_instrumental.wav",
      "content_type": "audio/wav",
      "size_bytes": 31752044,
      "duration_seconds": 180.0,
      "sample_rate": 44100,
      "channels": 2,
      "download_url": "/api/v1/separation/jobs/b1b2c3d4e5f6789012345678abcdef02/files/instrumental"
    }
  ]
}
```

示例仅列两条；默认成功结果应包含全部七条实际输出。`size_bytes`、`sample_rate`、`channels` 等均从实际文件读取，以上数字不能硬编码。`stems` 以 ID 识别，不依赖数组顺序。

| ID | 展示名 | `origin` |
|---|---|---|
| `vocals` | 人声 | `model` |
| `drums` | 鼓 | `model` |
| `bass` | 贝斯 | `model` |
| `guitar` | 吉他 | `model` |
| `piano` | 钢琴 | `model` |
| `other` | 其他 | `model` |
| `instrumental` | 伴奏 | `derived` |

所有音轨保留输入音频的完整时间轴，不裁掉首尾静音；采样率/声道若经适配层转换，以输出文件元数据为准。默认仅保留到完成后 24 小时，`expires_at` 为准确过期时间。Flutter 需要长期保存时，在过期前下载到本地并持久保存结果信息。

### 5.4 音轨下载和播放

```http
GET /api/v1/separation/jobs/{job_id}/files/vocals
Range: bytes=0-1048575
```

服务端必须支持 `GET`、`HEAD` 以及**单个字节范围**请求：无 Range 时返回 200 和完整文件；合法 Range 返回 206、`Content-Range` 和对应字节；超出范围返回 416、`Content-Range: bytes */总大小`。HEAD 与完整 GET 的文件头一致，响应体为空。

完整响应的 `Content-Type` 为 `audio/wav` 或 `audio/flac`，并设置 `Content-Length`、`Accept-Ranges: bytes`；文件名仅用于显示。只按任务记录和 `stem_id` 查找文件，不接受任意路径。Range/HEAD 对 Flutter 远程读取与拖动播放有用；也可以先下载到本地再播放。

### 5.5 分轨错误

HTTP 错误继续使用与和弦一致的 `{error, detail, job_id}` 格式：

| HTTP | `error` | 含义 |
|---|---|---|
| 400 | `unsupported_format` / `invalid_file` | 扩展名或文件内容不符合要求 |
| 404 | `job_not_found` / `stem_not_found` | 任务或音轨不存在 |
| 409 | `job_not_complete` | 分轨尚未完成 |
| 410 | `result_expired` | 已知任务的文件已到期删除 |
| 413 | `file_too_large` | 超出 50 MiB |
| 416 | `range_not_satisfiable` | 文件范围无效 |
| 422 | `validation_error` / `processing_failed` | 参数错误或任务失败 |
| 429 | `queue_full` | 队列满，返回 `Retry-After` 秒数 |
| 500 | `internal_server_error` | 服务端异常 |
| 503 | `model_unavailable` | 服务尚未就绪 |

任务失败详情通过状态接口的 `error.code/message/retryable` 提供；结果接口对失败任务返回 422。已过期任务可保留元数据以返回 410；元数据也删除后返回 404。第一版不提供任务取消、删除、WebSocket、批量上传或实时流式推理接口。

## 6. Flutter 对接要求

分别定义 `ChordUploadResponse`、`ChordJobStatus`、`ChordResult`、`ChordSegment`、`SeparationUploadResponse`、`SeparationJobStatus`、`SeparationResult`、`StemFile`、`TaskError` 和通用 `ApiError`。

接口调用顺序：

```text
选择本地音频
  → 上传至对应 POST，显示上传字节进度
  → 收到 202 后保存 job_id，显示服务器任务状态
  → 每 2–3 秒 GET status
      queued/processing：继续
      failed：停止，展示 error
      completed：停止，GET result
  → 和弦：保存 segments，结合播放器位置更新当前和弦
  → 分轨：展示 stems，按 download_url 下载或播放
```

上传失败后不要自动无限重试 POST，因为服务可能已经创建任务；当前没有幂等键保证。轮询 GET 遇短暂网络故障可退避重试；App 进入后台暂停轮询，恢复后用保存的 job_id 查询。

不要手写 multipart boundary；交给 HTTP 客户端生成。字段名必须为 `audio`。若使用 Dio，构造方式示意如下（需项目已有依赖）：

```dart
final response = await dio.post<Map<String, dynamic>>(
  '/api/v1/jobs',
  queryParameters: {
    'smooth_method': 'hmm',
    'device': 'cpu',
    'include_raw_chords': false,
  },
  data: FormData.fromMap({
    'audio': await MultipartFile.fromFile(filePath, filename: fileName),
  }),
);
// 分轨改用 /api/v1/separation/jobs，query 为 {'output_format': 'wav_s16'}。
// Flutter Web 应使用所选文件的 bytes 构造 MultipartFile，不能依赖本地路径 API。
```

和弦显示区间采用 `[start, end)`，无覆盖片段显示空白或“无和弦”；播放位置转秒后查找片段。**完成第 7 节时间轴修复前，现有 v1 片段不能直接保证与原曲同步。**

分轨同步混音：所有播放器使用同一播放起点，播放/暂停/seek 一起控制，并定期校正漂移。将 `instrumental` 与全部其他音轨同时播放会重复叠加内容，界面应区分“伴奏播放”和“独立声部混音”。

## 7. 后端开发必须处理的源码差异

1. **旧文档端点不准确。** `chord-engine/API_DOCUMENTATION.md` 提到 `/api/analyze`、`/api/analyze-youtube` 及 `beats`，当前路由并没有实现这些契约。以 `api/main.py` 注册路由和运行时 `/api/openapi.json` 为准。
2. **原曲时间轴。** `engine/loader.py` 调用 `librosa.effects.trim()` 后丢弃 trim 索引，因此 v1 的 `start/end/duration_seconds` 基于裁剪后的音频。服务端应保留起始偏移并把片段/节拍映射回原曲，或增加保留完整时间轴的分析模式。建议新版本返回 `timeline_origin="original"`、`original_duration_seconds`、`analysis_offset_seconds`；这是后续版本需求，未混入当前 v1 OpenAPI。不能靠 Flutter 猜偏移，也不能按全曲时长比例拉伸片段。
3. **真实置信度。** 流水线调用 `predict()`，没有把概率交给 `build_output()`，后者默认填 1.0。现有 Flutter 不展示“100%准确”。后端若要提供真实分段分数，应使用 `predict_with_confidence()` 并在平滑/合并后按段汇总；新的字段语义须明确标注，不能只按片段序号取前几帧概率。
4. **节拍字段。** 如要实现节拍线，把内部 `beat_times` 明确加入新版响应模型并说明时间轴基准；当前 v1 无此字段，不能仅修改 README。
5. **模型生命周期与设备。** 和弦 `_detector` 为全局缓存，首次加载后不随 query 的 device 切换，且加载没有互斥保护。实际服务固定设备、初始化加锁。分轨复用 ready 的 `BSRoformerSession`；在关闭 Worker 时释放，不为每个请求重新下载权重或加载模型。
6. **后台任务与并发。** 当前和弦 `BackgroundTasks` + 内存 JobStore 不持久，不支持多进程共享任务。原样部署先用一个 Uvicorn worker，并限制 GPU 推理并发；多进程或正式队列需共享状态存储。HTTP 上传成功后不等待长推理；阻塞算法在后台执行，保持状态查询可响应。
7. **任务文件隔离。** 当前和弦上传拼接客户端 filename，需改为服务器生成的任务目录和固定输入名，原文件名只做显示。每个分轨任务独立输入/输出目录；真实 manifest 决定下载文件映射。输入文件不能在另一个算法尚未读取时提前删除。
8. **音频标准化。** 新增分轨适配器必须真正解码 WAV、处理立体声/多声道并采用经过该 checkpoint 验证的采样率。当前随包 YAML 没有声明 sample_rate，推理代码也不会校验/重采样；配套示例的 44100 是格式示例及现有测试所用采样率，不是代码自动保证的限制。服务部署配置需显式记录并验证目标采样率，输出数据以文件实测为准。
9. **分轨文件生命周期。** 在任务写入完成并核对 manifest 后才标记 completed；失败不发布半成品。新增任务元数据与结果文件应持久保存，过期后清理；不要套用和弦当前完成即删上传音频的逻辑来删除分轨输出。
10. **健康检查语义。** 现有 `/health/ping` 只表示进程存活；`/health` 的 `_detector` 是直接导入的绑定，加载后可能仍显示 false，不能用作可靠模型就绪判断。修复为读取 pipeline 模块当前状态；分轨 Worker 就绪应单独纳入部署层就绪检查。

## 8. 联调验收

- 用同一份音频验证两种上传，202 后页面可继续操作，轮询最终成功或失败。
- 验证中文文件名、同名文件并发上传、空文件、伪造扩展名、超限文件、短音频及非法参数。
- 用带明显片头静音的音频校验和弦在原曲播放轴上的位置；修复前记录为已知限制。
- 确认当前不展示置信度百分比、不读取不存在的 beats、不请求未注册的旧端点。
- 分轨默认结果含六个模型声部和一个派生伴奏；所有 download_url 可访问且元数据匹配文件。
- 验证 GET/HEAD/Range、下载后本地播放、拖动、网络中断、App 恢复以及结果过期。
- 验证任务查询不受推理阻塞；生产鉴权配置后，用户不能读取其他用户的任务或音轨。
- 明确交付实际部署 BASE_URL；运行时导出的 OpenAPI 与本文新服务契约核对后，再生成 Flutter 客户端。

## 9. 源码核对入口

- `chord-engine/api/main.py`：应用路由与 OpenAPI 地址。
- `chord-engine/api/routes/jobs.py`：上传参数、状态码与任务响应。
- `chord-engine/api/models/response.py`：现有 JSON 字段。
- `chord-engine/api/services/pipeline.py`：实际算法链、缓存和置信度传递。
- `chord-engine/api/services/job_store.py`、`config.py`：状态存储与限额。
- `chord-engine/engine/loader.py`、`engine/output.py`：静音裁剪和默认 confidence。
- `bs-roformer-infer/src/bs_roformer/clean_api.py`：Python Session 生命周期。
- `bs-roformer-infer/src/bs_roformer/inference.py`：WAV 文件夹输入、输出格式与 manifest。
- `bs-roformer-infer/src/bs_roformer/configs/BS-Rofo-SW-Fixed.yaml`：默认六声部配置。
