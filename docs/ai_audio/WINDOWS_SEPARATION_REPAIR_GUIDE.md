# Windows 分轨服务性能与下载修复指导

日期：2026-10-30。适用机器：RTX 5070 Ti 16GB、AMD 9600X、32GB 内存。可直接把本文交给 Windows 上的开发工具执行；不需要先把算法项目上传 GitHub。

本文是待执行的服务端工作说明，不代表 Windows 端已经完成修复。Flutter 端已完成断点续传、最多两条并行下载、完整缓存复用及 FLAC16 本机解码；Windows 端需要定位长音频计算的瓶颈，并保持下载协议可靠。

文中的 Python 示例已通过语法检查；Range 校验脚本已在 Mac 对现有 HTTPS 服务运行通过，包括正确续传拼接、版本不符返回 200 和越界返回 416。Windows PowerShell、CUDA 和模型优化步骤尚待 Windows 端执行。

## 1. 交给 Windows 开发工具的任务

```text
请在 F:\ChordEngine 下找到当前实际运行的算法 API 和 bs-roformer-infer。
先阅读项目本身的说明、当前启动脚本、依赖和配置，不按历史目录猜入口。

目标：
1. 证明实际分轨进程、模型及输入都使用 RTX 5070 Ti，而非只检查 CUDA 可用。
2. 记录排队、解码/重采样、模型加载、推理、输出编码和发布的独立耗时。
3. 同一 worker 常驻复用模型；修复每任务重复初始化、CPU 回退、阻塞 API 等问题。
4. 保持现有 v1 路由和 JSON 含义，支持 flac16、稳定文件、ETag 与 Range/If-Range。
5. 在相同模型、权重、输入和配置下对比修复前后；有证据后才调整推理配置。

先输出审计发现和基准，分小步实现并验证。不要替换成假分轨或静音文件。
不要自动降低音质、随意改变采样率、移除静音或改动既有和弦时间坐标。
不要把 APP 的下载并发数当作 GPU 推理并发数；单 GPU 先限制为一项重推理。
不需要租服务器、开放公网端口或改现有 Tailscale 网络。
最后交付修改文件、准确启动命令、版本/权重/配置指纹、基准 CSV 和接口回归结果。
```

历史交接资料将 `chord-engine`、`bs-roformer-infer` 放在上述目录，并描述 `BSRoformerSession` 接口。其布局可能已变，以 Windows 当前代码为准。[历史接口说明](FLUTTER_ALGORITHM_API.md) 不是实际执行代码。

## 2. 已知情况与待确认事项

| 项目 | 当前证据 | 不能据此推断 |
| --- | --- | --- |
| 服务可用性 | Mac／安卓模拟器已成功调用现有 HTTPS API | 实体手机网络、所有时段连通性 |
| 分轨文件 | 服务已返回强 ETag、Accept-Ranges 和可下载文件 | 所有文件／版本／网关均正确处理续传 |
| 压缩格式 | 单次 2 秒自生成输入成功返回七轨 FLAC16 | 真实音乐固定压缩率、所有曲目质量 |
| 计算耗时 | 此次服务记录 27.016 秒；历史 8 秒样本约 63 秒 | 是否 GPU、是否冷启动、线性吞吐量 |
| 健康响应 | 返回 model_loaded 等基本状态 | CUDA、模型参数所在设备、显存、耗时分布 |

两秒测试多条轨道是静音，仅用于接口／编码／播放验证；不能用来验收分轨准确率或音乐质量。先找瓶颈，不预设一定是 GPU 未启用。

## 3. 第一阶段：收集运行环境，不先重装

在**当前服务使用的虚拟环境**中打开 PowerShell。若服务由 bat／ps1／任务计划程序启动，先记录其 Python 完整路径和工作目录；在另一个 Python 环境测试成功不能证明服务正常。

```powershell
Set-Location F:\ChordEngine
New-Item -ItemType Directory -Force .\diagnostics | Out-Null
Get-Command python | Format-List Source
python --version
python -m pip freeze | Set-Content -Encoding utf8 .\diagnostics\packages-before.txt
nvidia-smi
```

将下面 Python 保存为 `diagnostics\check_cuda.py`，用同一个环境的 `python .\diagnostics\check_cuda.py` 执行。此脚本不加载项目权重，只检查这个解释器是否能实际完成 CUDA 运算。

```python
import json
import sys
import torch

report = {
    "python": sys.executable,
    "torch_path": torch.__file__,
    "torch_version": torch.__version__,
    "torch_cuda_runtime": torch.version.cuda,
    "cuda_available": torch.cuda.is_available(),
    "cudnn_version": torch.backends.cudnn.version(),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
if not report["cuda_available"]:
    raise SystemExit("CUDA 不可用；先检查此环境的 PyTorch 构建、驱动和服务解释器")

device = torch.device("cuda:0")
print("gpu:", torch.cuda.get_device_name(device))
print("capability:", torch.cuda.get_device_capability(device))
print("build_arches:", torch.cuda.get_arch_list())
with torch.inference_mode():
    x = torch.randn(512, 512, device=device)
    y = x @ x
    torch.cuda.synchronize(device)
    print("matmul_device:", y.device, "finite:", torch.isfinite(y).all().item())
```

若出现不支持当前架构、`no kernel image`、CPU-only wheel 或扩展编译错误，再根据项目锁定依赖和官方 Windows 安装选项处理。先建立可回退的新虚拟环境，不覆盖现有可运行环境。不能仅靠 `nvidia-smi` 的 CUDA Version 判断当前 Python 安装了什么。Blackwell 支持需核对具体构建，历史发布说明不是所有 Windows 依赖组合的保证。[PyTorch 安装与 GPU 检查](https://pytorch.org/get-started/locally/)，[Blackwell 历史支持说明](https://pytorch.org/blog/pytorch-2-7/)。

另开终端，在**真实任务运行期间**记录：

```powershell
nvidia-smi --query-gpu=timestamp,name,driver_version,utilization.gpu,memory.used,memory.total --format=csv -l 1 -f .\diagnostics\gpu-during-job.csv
```

任务结束后按 Ctrl+C 停止。某些 Windows/WDDM 进程指标可能显示 N/A；不能将 N/A 当作零使用。利用率是采样值，仍要结合实际模型设备、日志与耗时判断。[NVIDIA nvidia-smi 文档](https://docs.nvidia.com/deploy/nvidia-smi/index.html)。

同时记录启动命令、Python 路径、模型 slug、权重与配置文件 SHA-256；不要复制账号口令或完整私网配置到公开日志。

## 4. 第二阶段：证明实际模型路径并定位耗时

### 4.1 审计加载、设备与推理入口

查找当前服务调用 `BSRoformerSession`／加载 checkpoint／调用模型 forward 的地方，逐项核对：

- 是在 worker 初始化时加载，还是在每次 POST／每个文件／每个分块都重新加载？
- `auto` 最终解析到哪个设备？模型参数和输入张量实际在哪个设备？是否有捕获所有异常后悄悄切回 CPU 的逻辑？
- 有无每项任务启动新 Python 子进程、启动时重新下载权重或重复创建多份模型？
- GPU 负载期间 CPU 是否主要耗在音频解码、STFT、重采样、文件写盘或网络传输？
- API event loop 是否直接执行同步推理，导致状态和健康请求也要等任务结束？

由真实模型执行层打印模型设备、输入设备及形状；不要猜测封装对象里一定有 `session.model`。若采用 GPU 专用 worker，CUDA 初始化失败应明确报告模型不可用并拒绝开始重推理，不伪装成正常 GPU 服务。CPU 模式只能作为明确配置的独立选择。

已确认当前接口与历史描述一致时，可采用以下**生命周期结构**，具体集成到现有 worker，不直接另开一套 HTTP 服务：

```python
# 示意：先核对当前包的导出、参数与线程安全约束。
from bs_roformer import BSRoformerSession

# 单个 GPU worker 启动时执行一次。
session = BSRoformerSession(device="cuda:0").load()
try:
    # 在原队列中串行取得任务；每个输入目录只放当前任务的已解码 WAV。
    # 不在每次 infer 前后反复 load / close。
    manifest = session.infer(
        current_job_input_directory,
        store_dir=current_job_output_directory,
        output_format="flac16",
    )
    # 校验并原子发布输出，然后把任务标记为 completed。
finally:
    # 常驻 worker 应把这个 finally 放在整个任务消费循环外，关闭时才 close。
    session.close()
```

原始 `infer()` 接受目录还是文件、重采样由谁负责、任务结果字段怎样生成，应从当前代码确认，不能只套用上面的示意。

基础模型应处于 `eval()` 模式；实际推理工作线程内使用 `torch.inference_mode()`。它不会自动替代 `eval()`，且上下文具有线程局部性，不能只包在启动 API 的线程外面就认为后台线程也生效。[PyTorch inference_mode](https://docs.pytorch.org/docs/stable/generated/torch.autograd.grad_mode.inference_mode.html)。

### 4.2 给真实阶段加计时

至少记录下面字段；名称是建议新增的诊断字段，不是客户端已经要求的协议：

| 字段 | 起止点 |
| --- | --- |
| queue_ms | 上传落盘并入队 → worker 真正开始处理 |
| decode_resample_ms | 解码、声道整理、重采样与输入准备 |
| model_load_ms | 仅实际加载模型时计，常驻复用时不重复伪计 |
| inference_ms | 实际推理；必要时再拆 STFT、forward 和重组 |
| encode_ms | 所有模型轨和派生轨的输出编码 |
| publish_ms | 校验输出、原子发布、生成清单 |
| worker_total_ms | worker 开始到输出可下载的整体墙钟时间 |
| peak_gpu_allocated_bytes | 当前 worker 本任务的 PyTorch 显存峰值 |

用 `time.perf_counter()` 计进程内时差。CUDA 运算是异步的，诊断 GPU 阶段时须在计时前后对正确设备同步，或使用 CUDA Event；否则可能只量到提交运算的时间。[PyTorch CUDA 同步](https://docs.pytorch.org/docs/stable/generated/torch.cuda.synchronize.html)。

```python
# 插入真实推理代码的示意；不替代现有模型调用和错误处理。
import time
import torch

torch.cuda.synchronize(device)
torch.cuda.reset_peak_memory_stats(device)
started = time.perf_counter()
with torch.inference_mode():
    result = run_existing_inference()  # 替换为原模型执行入口
torch.cuda.synchronize(device)
inference_ms = (time.perf_counter() - started) * 1000
peak_gpu_allocated_bytes = torch.cuda.max_memory_allocated(device)
```

此代码只适用于已确认的 CUDA 执行路径，CPU 路径不能调用 CUDA 同步。诊断同步不要插在每个小算子之间或任意并发请求中。单次模型冷加载和热身需单独记录，不能每项用户任务都重新热身。

## 5. 第三阶段：按收益与质量风险逐项优化

| 优先顺序 | 有证据时采取的修改 | 验证重点 |
| --- | --- | --- |
| 1 | 修正错误解释器／CPU 回退／模型与输入设备不一致 | 相同权重与音频的实际 CUDA 推理、错误明确 |
| 2 | 模型常驻；去掉每任务重复加载或重复启动子进程 | 第二次起 model_load 不再重复，内存稳定 |
| 3 | 独立有界队列／GPU worker；HTTP 只负责收发和状态 | 计算中健康与状态查询仍响应，不重复执行 |
| 4 | 减少每块 CPU/GPU 往返、重复重采样和多余中间文件 | 分阶段耗时下降，输出采样率／帧数不变 |
| 5 | 按当前模型正式支持的参数测试 chunk／batch | 显存峰值、边界接缝、长短音频质量 |
| 6 | 最后再评估 AMP、编译或其他模型优化 | 明确开关、冷编译时间、兼容性、音质与回退 |

16GB 显存先采用一个重推理执行者；API 进程数量和 GPU 模型进程数量分别管理。多开 Uvicorn worker 可能复制模型，不作为默认加速方案。可在资源允许时安排独立 I/O，但先确认模型封装线程安全。

分块时保留模型原有上下文、重叠和重建方式；不能简单硬切短文件拼接或独立归一化各轨。不要凭空添加 `chunk_size`／`batch_size` HTTP 参数，先核对实际推理包。OOM 时明确失败或按预先验证配置有限次回退，不能无限重试或悄悄转 CPU。

AMP 可减少某些算子的计算／存储成本，但并非所有算子使用相同精度，也不保证这个模型更快或音质等价。只用当前项目支持的 `torch.autocast` 路径进行对照，不直接把整个模型 `.half()`；未通过测试不默认开启。[PyTorch AMP](https://docs.pytorch.org/docs/stable/amp.html)。

CPU 解码／编码瓶颈用同一输入分别比较，再调整相应实现和线程数量；不将全部 CPU 线程数或编码并发一律拉满。输出 FLAC 的压缩级别如需调整，应保持 PCM16 无损和帧数，记录编码时间／体积，不硬设一个未经项目支持的参数。

## 6. 下载服务必须保持的契约

保留现有路由、multipart 字段 `audio`、query `output_format=flac16`、任务 ID、状态和相对下载 URL。和弦分析不能因分轨优化而变成必须先分轨的串行流程。

输出先写临时文件，关闭／校验后再原子发布；只在所有清单文件已经可读且稳定时标记 completed。清单需如实记录编码、字节数、帧数对应时长、采样率、声道和 origin；不伪造参考图里的主音／节奏轨。derived 伴奏保持派生含义。

对 `/api/v1/separation/jobs/{job_id}/files/{stem_id}` 检查：

- 普通 GET：200、正确 Content-Type／Content-Length、Accept-Ranges: bytes、稳定的强 ETag。
- 合法 Range + 匹配 If-Range：206、精确 Content-Range 和剩余长度，响应体只含该区间。
- If-Range 不匹配：忽略 Range，返回完整 200，不能把新文件余段伪装成旧版本的续传。
- 超出范围：416，按 HTTP 约定返回总长度；只影响本次请求，不删除任务结果。
- HEAD：无响应体，相关文件元信息与 GET 一致；下载不进行即时重新编码或模型推理。
- 同一个 job／stem 在有效期内保持不可变；需要更新输出时产生新任务或新版本，不覆盖正在下载的旧文件。
- 不在 gzip 等中间件中重新压缩这些已压缩音频响应，避免字节范围与长度失去意义。
- 下载路径只由已验证 job／stem 清单定位，不能接受任意磁盘路径；过期清理避开活动文件句柄，并给可识别的失效响应。

可优先评估框架 FileResponse，但须检查**实际安装版本和网关**的 Range／If-Range 行为，而非假设使用类名就保证正确；不要全文件 `read_bytes()` 后再拼响应。[FastAPI 文件响应](https://fastapi.tiangolo.com/advanced/custom-response/#fileresponse)。

当前 Mac 验证过强 ETag 和 Range 支持，故这部分先回归，避免无证据重写可用逻辑。客户端会校验文件和续传版本，并重试 GET；服务端仍需保证任务文件稳定到有效期结束。

### 可执行的传输验证示例

Windows PowerShell 使用 `curl.exe`，不要误用某些 PowerShell 版本中的同名别名。在 Windows 本机直接测回环服务，再从 Mac／手机测试现有 HTTPS 网关。下面任务 ID 和 stem ID 必须替换为**自己已完成、尚未过期**的任务，不创建新推理。

```powershell
$ApiBase = 'http://127.0.0.1:8000'
$JobId = 'REPLACE_WITH_EXISTING_JOB_ID'
$StemId = 'guitar'
$StemUrl = "$ApiBase/api/v1/separation/jobs/$JobId/files/$StemId"
curl.exe --fail --show-error --dump-header .\diagnostics\full.headers --output .\diagnostics\full.flac $StemUrl
```

为避免 PowerShell 不同版本对带双引号 ETag 的原生命令参数转义差异，条件续传校验使用下面 Python 脚本。保存为 `diagnostics/check_range.py`，执行 `python .\diagnostics\check_range.py $StemUrl`。它只 GET 已有输出，不启动算法；选用大于 1024 字节、不超过 16 MiB 的受控测试音轨。

```python
import hashlib
import sys
from urllib.error import HTTPError
from urllib.request import Request, ProxyHandler, build_opener

url = sys.argv[1]
limit = 16 * 1024 * 1024
# 仅本诊断请求直连，不更改系统代理；HTTPS 仍做正常证书验证。
opener = build_opener(ProxyHandler({}))

def fetch(headers=None):
    request = Request(url, headers={"Accept-Encoding": "identity", **(headers or {})})
    with opener.open(request, timeout=30) as response:
        body = response.read(limit + 1)
        assert len(body) <= limit, "请改用不超过 16 MiB 的测试音轨"
        return response.status, response.headers, body

status, headers, full = fetch()
assert status == 200 and len(full) > 1024
assert int(headers["Content-Length"]) == len(full)
etag = headers.get("ETag", "")
assert etag.startswith('"') and etag.endswith('"'), "需要强 ETag"
assert headers.get("Accept-Ranges", "").lower() == "bytes"
parts = []
for byte_range, start, end in [
    ("bytes=0-1023", 0, 1023),
    ("bytes=1024-", 1024, len(full) - 1),
]:
    status, h, body = fetch({"Range": byte_range, "If-Range": etag})
    assert status == 206, ("预期 206", status)
    assert h["Content-Range"] == f"bytes {start}-{end}/{len(full)}"
    assert int(h["Content-Length"]) == len(body) == end - start + 1
    assert h.get("ETag") == etag
    parts.append(body)
assert b"".join(parts) == full, "续传拼接与原文件不一致"

status, _, changed = fetch({"Range": "bytes=1024-", "If-Range": '"deliberately-different-version"'})
assert status == 200 and changed == full, "版本不符应返回完整文件"
try:
    fetch({"Range": f"bytes={len(full)}-", "If-Range": etag})
except HTTPError as error:
    try:
        assert error.code == 416, error.code
        assert error.headers.get("Content-Range") == f"bytes */{len(full)}"
    finally:
        error.close()
else:
    raise AssertionError("越界区间应返回 416")
print("Range / If-Range PASS", len(full), hashlib.sha256(full).hexdigest())
```

该验证脚本会把小样本读入内存，仅用于诊断，不是生产下载实现。再测试实际断网／暂停后续传。FLAC 解码后应与同次模型的未压缩 PCM16 输出帧数及样本一致；不要把不同推理运行间的数值变化误认作压缩失真。

## 7. 基准与验收

先保留修复前基线，再逐项比较。输入选自生成短样本及有权使用的 10／30／60／180 秒真实练习片段；每种配置至少一次冷启动和三次热运行。基准可反复推理，是明确的性能实验；普通 APP 的网络错误仍不应自动重传 POST。

```text
run_id,audio_sha256,duration_s,model_slug,checkpoint_sha256,config_sha256,
python,torch,cuda_runtime,driver,device,dtype,chunk,batch,
cold_start,queue_ms,decode_resample_ms,model_load_ms,inference_ms,
encode_ms,publish_ms,worker_total_ms,peak_gpu_allocated_bytes,
output_total_bytes,output_format,rtf,status
```

RTF 在本报告中定义为 `worker_total_seconds / audio_duration_seconds`，排队、HTTP 上传和下载另列；小于 1 表示 worker 处理比音频时长更短，不等于 APP 端到端耗时。报告热运行中位数与范围，长曲和冷启动分别列出，不承诺固定加速倍数。

完成条件：

1. 已证明实际分轨模型及输入使用预期 GPU，并记录无法使用 GPU 时的明确行为。
2. 热任务不重复加载权重；一项推理时状态／健康查询可用；两项任务有可靠队列且不重复执行。
3. 同样输入／模型／配置的阶段计时可对比，瓶颈与具体改动对应，长音频不会因内存持续增长或无限重试卡死。
4. FLAC 清单及采样格式真实，所有输出可解码，时长／帧数一致；Range 拼接与原文件完全相同，网关测试也通过。
5. 试听人声／吉他／伴奏，以及分块边界、尾部、静音和瞬态；新精度／分块配置有对照证据。无法完成音质比较的优化保持关闭。
6. Flutter 在原视频中下载、暂停续传、混音、0.01 倍速、定位、A-B、重开离线恢复正常；不额外产生练习会话。

最后生成 `diagnostics/repair_report.md`：列出真实根因、修改、实际启动命令、依赖／权重／配置版本、修复前后表格、未通过项和回退办法。报告提供给本项目后，再联调新增可选计时／设备字段；不要更改现有 v1 字段含义或将日志路径当成下载 URL。
