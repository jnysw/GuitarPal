# 2026-11-03：MelPal 公网认证接入

## 服务器依据与只读实测

读取算法仓库 `codex/melpal-public-api`，提交 `b91a300dc77485e7a2b877b8fbfa405c2981e63f`。`MELPAL_PUBLIC_API.md` 定义个人 Bearer、归属、配额、受保护 Range 下载以及 401／429／503；公网只开放通用 `/health`，不公开内部模型健康及 Swagger。服务端记录报告 Windows 112 项和真实 GPU 和弦／分轨验证通过；本轮未重新执行这些测试，也未修改 Windows 或 Cloudflare。

Mac 直连 `https://api.melpal.com.cn/health` 返回 HTTP 200，`status=ok`、`service=melpal-algorithm-api`。这是存活证据，不是带认证推理或音乐质量证据。

## Flutter

全量 **472 项通过**，静态分析无问题。新增 9 项覆盖：

- 系统安全存储边界、正确 origin 的凭据 JSON、错误域名／换行注入拒绝与清除；不回显输入。
- 精确 HTTPS 主机／端口／路径才附加 Bearer；健康、旧私网、相似恶意主机和其它端口不附加；重定向不跟随。
- 公网预检仅健康与固定不存在 ID 的 GET，不调用诊断或 POST；缺凭据在 HTTP 前阻止；401 本地化且不回显服务器任意 detail。
- multipart 上传、状态／结果与下载统一认证；429 Retry-After 保留；submission_unavailable 只发生一次 POST 并保留未知状态。
- 401 停止轮询、保留 job ID，恢复凭据后手动 GET 恢复，无第二次上传。
- 下载中断后遇 401 保留部分，更换令牌后使用原 Range／If-Range 完成；完整缓存离线无凭据可用，缓存 JSON 不保存令牌。
- 320px 双倍文字页面保存隐蔽输入、GET 验证和移除。

## Android

`melpal_public_access_test.dart` **1 项通过**：普通构建无需传 API Dart define 即读取公网部署地址，真实 HTTPS health 200、未认证状态 GET 401；缺凭据预检本机拦截。真实安全存储保存／重开读取／移除通过，页面用故意无效的非秘密测试令牌验证 401 提示，不上传音频、不调用推理。测试结束恢复设备此前凭据（如果存在），没有将其输出或写入 fixture。

`local_video_analysis_workspace_test.dart`（AUTO_CHORD_TIMELINE=true）**1 项通过**，继续覆盖原生提取、自动绑定、自动／人工时间轴、滚动与选区、A-B、全屏和唯一统计，使用隔离替身算法，不调用模型。全部集成回归后重新执行 `flutter build apk --debug --no-pub --dart-define-from-file=config/supabase.local.json`，普通 Debug APK 构建成功。公网地址由原生部署配置读取，真实令牌没有编译入 APK；不交付测试入口。本轮没有有效个人令牌，真实带认证上传／推理仍待安全配置后的联调，不把替身测试或无效令牌测试称为通过真实模型验收。
