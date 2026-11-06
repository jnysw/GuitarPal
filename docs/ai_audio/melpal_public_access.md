# MelPal 公网内测客户端

2026-11-03。客户端基于算法仓库 `codex/melpal-public-api` 的 `b91a300dc77485e7a2b877b8fbfa405c2981e63f` 接入。服务器定义见 [MELPAL_PUBLIC_API.md](https://github.com/jnysw/chordengine-algorithm-server/blob/b91a300dc77485e7a2b877b8fbfa405c2981e63f/MELPAL_PUBLIC_API.md)。域名接入包含个人令牌、任务归属、配额与受保护下载，不能只替换 URL。

## 访客使用

新版 Android 在本地视频练习页直接开始和弦分析或分轨。应用自动建立设备会话并存入系统安全存储。已有有效的个人内测会话可继续使用。「我的 → 算法服务」提供连接检查。

Windows 需要更新公网网关。`GET /health` 返回 `guest_access: true` 后，设备可用访客会话提交任务。每台访客设备在滚动 24 小时内最多提交 10 次，全部访客共 40 次。查询和续传使用同一设备会话。[Windows 访客接入](https://github.com/jnysw/chordengine-algorithm-server/blob/codex/melpal-guest-access/MELPAL_GUEST_ACCESS.md)

## 请求与状态

- 公网健康检查使用无认证 `GET /health`，不调用被隐藏的旧 health/diagnostics/OpenAPI 路径。
- 分析前用健康检查识别访客支持，再通过固定不存在任务 ID 的 GET 验证会话。已过期的个人会话在支持访客的网关上自动切换为访客，切换发生在上传前。
- POST、状态／结果 GET 以及下载／Range 续传，共用精确 HTTPS origin 的 Bearer 认证。端口必须 443、无 userInfo，非目标域名和旧私网地址不收到该凭据。受保护请求禁止跟随重定向。
- 401 或本机安全存储不可用时，已有远端任务暂停轮询并保留编号。「重新查询」发起 GET。过期或归属不同的远端任务可查看已有本机结果。
- 429 GET 沿用 Retry-After 退避；不自动重发 POST。503 submission_unavailable 保持接收状态未知，不能为立即重试而自动上传第二次。
- 下载的 401 不重试风暴，也不删除可续传部分；更换令牌后继续原 GET/Range/If-Range，SHA-256 和容器校验仍保留。完整缓存离线使用不读取凭据、不发请求。

录音和本地音轨仍保存在当前设备私有目录。内测令牌不是多账号本地缓存隔离机制，也不是正式产品登录；后续正式账号方案另行验收。

## 旧地址任务

每条任务保留创建时的 endpoint，不能把私网 job ID 直接改成公网读取，因为内部历史任务没有公网归属。已完成的缓存不变；缺失的旧私网音轨仍需原 Tailscale 通道。若要通过公网重新分析，必须由用户从原视频显式新建，客户端不自动迁移、删除或重复推理。

## 本轮验证边界

个人内测会话此前已完成 Android 真实和弦、分轨、七轨摘要校验和中断续传。[11 月 3 日验收](live_validation_2026-11-03.md)

访客版已通过 Flutter 484 项测试、Android 安全存储及连接页验收、网关 18 项回归。Android 使用模拟网关响应验证首次建立会话，实际公网访客推理等待 Windows 更新。
