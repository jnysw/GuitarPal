# MelPal 公网内测客户端

2026-11-03。客户端基于算法仓库 `codex/melpal-public-api` 的 `b91a300dc77485e7a2b877b8fbfa405c2981e63f` 接入。服务器定义见 [MELPAL_PUBLIC_API.md](https://github.com/jnysw/chordengine-algorithm-server/blob/b91a300dc77485e7a2b877b8fbfa405c2981e63f/MELPAL_PUBLIC_API.md)。域名接入包含个人令牌、任务归属、配额与受保护下载，不能只替换 URL。

## 使用

普通 Android 构建默认使用 `https://api.melpal.com.cn`，本机开发配置和环境变量仍可显式覆盖。终端用户不填写地址。

1. 安装本轮普通 Debug APK。
2. 在「我的 → 算法服务」保存自己的个人内测令牌或服务器签发的凭据 JSON。
3. 点「验证连接（不上传音频）」，成功后返回视频练习，按原来的和弦／分轨流程分析。

公网模式无需 Tailscale。内测凭据与 Supabase 应用登录分别管理，每位测试者使用自己的凭据；不能把 owner-test 共享给所有安装者。管理员在 Windows 按服务器文档签发凭据，安全传递给对应设备。不要把真实令牌放入聊天、Git、Dart define、APK 常量或普通配置文件。凭据页面存入系统安全存储，保存后清空输入，不回显令牌。

服务器现有 owner-test 文件位于 Windows 的 `F:\ChordEngine\server-data\public-secrets\owner-test.json`；文件本身不在 Git。客户端不从 GitHub 或服务器公共路径猜测／获取它，也不将 Cloudflare Tunnel token 或 Supabase session 当作算法凭据。

## 请求与状态

- 公网健康检查使用无认证 `GET /health`，不调用被隐藏的旧 health/diagnostics/OpenAPI 路径。
- 分析前先确认本机有凭据，再用健康检查和固定不存在任务 ID 的 GET 验证认证；不创建任务、提取或上传音频。公网归属检查 404 是该验证的预期结果；401、429、503 仍报告失败，不伪装通过。
- POST、状态／结果 GET 以及下载／Range 续传，共用精确 HTTPS origin 的 Bearer 认证。端口必须 443、无 userInfo，非目标域名和旧私网地址不收到该凭据。受保护请求禁止跟随重定向。
- 401 或本机凭据不可用会将已有远端任务设为 authorizationRequired，保留 job ID 并停止自动轮询。替换凭据后点「重新查询」只发 GET；同一用户的新令牌可访问原任务。404 可能表示过期、不存在或不属于当前测试者，不推断其它用户任务。
- 429 GET 沿用 Retry-After 退避；不自动重发 POST。503 submission_unavailable 保持接收状态未知，不能为立即重试而自动上传第二次。
- 下载的 401 不重试风暴，也不删除可续传部分；更换令牌后继续原 GET/Range/If-Range，SHA-256 和容器校验仍保留。完整缓存离线使用不读取凭据、不发请求。

录音和本地音轨仍保存在当前设备私有目录。内测令牌不是多账号本地缓存隔离机制，也不是正式产品登录；后续正式账号方案另行验收。

## 旧地址任务

每条任务保留创建时的 endpoint，不能把私网 job ID 直接改成公网读取，因为内部历史任务没有公网归属。已完成的缓存不变；缺失的旧私网音轨仍需原 Tailscale 通道。若要通过公网重新分析，必须由用户从原视频显式新建，客户端不自动迁移、删除或重复推理。

## 本轮验证边界

Flutter 全量 473 项与静态分析通过。最初个人凭据通过只读认证，随后因 530／1033 暂停；Tunnel 恢复后，Android 已完成 8 秒合成视频的真实认证和弦／分轨（各一次 POST）、自动采样映射、实际七轨摘要校验、受控中断续传、离线重开和原生混音时钟验收。未使用用户歌曲，不据此宣称实际乐器质量。证据见 [本日记录](live_validation_2026-11-03.md)，复发排查见 [Windows 指南](MELPAL_TUNNEL_RECOVERY.md)。个人真实令牌不编译入 APK，新设备仍需在应用内保存自己的凭据。
