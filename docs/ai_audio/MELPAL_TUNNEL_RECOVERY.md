# 公网 HTTP 530 / Cloudflare 1033 排查

2026-11-03。Mac 的初次只读检查为 health=200、携带个人凭据的固定不存在任务查询=404，符合网关契约。随后 Android 在健康检查阶段得到 HTTP 530；Mac 复查同样得到 530，页面包含 Error 1033。该次中断尚未发送分析 POST。随后 Tunnel 已恢复，Android 合成音频双算法、分轨续传与原生播放验收均通过，详情见 [本日记录](live_validation_2026-11-03.md)。以下保留排查步骤供复发时使用。

[Cloudflare 官方说明](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1033/)：1033 表示 Cloudflare 找不到健康的 cloudflared 实例接收该 Tunnel 的请求。需要检查运行连接器的 Windows 主机及网络；客户端更换令牌不会恢复 Tunnel。

## Windows 先做只读检查

确认主机已开机，并在 PowerShell 执行：

```powershell
Get-Service Cloudflared
Invoke-RestMethod http://127.0.0.1:20241/ready
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health/ping
Invoke-RestMethod http://127.0.0.1:8001/health
```

在 Cloudflare 控制台查看当前 Tunnel 是否 Active / Healthy。若 Cloudflared 服务已停止，可在管理员 PowerShell 运行 `Start-Service Cloudflared`。若服务仍运行但 `/ready` 失败，检查连接器日志和 Windows 外网连接，再复查 Tunnel 状态。

如果本机 8000 或 8001 未响应，使用原有脚本启动对应进程：

```powershell
cd F:\ChordEngine
.\start-algorithm-server.ps1
.\start-public-probe.ps1
```

当前算法及公网入口沿用用户登录后的启动配置，主机开机但尚未登录时也要检查这些进程是否实际运行。Cloudflared 是独立的 Windows 服务。

## 恢复判据

```powershell
Invoke-RestMethod https://api.melpal.com.cn/health
```

应返回 `status=ok`、`service=melpal-algorithm-api`。此后才能继续客户端认证及合成音频联调。路由仍沿用 `api.melpal.com.cn → HTTP 127.0.0.1:8001`。

若后续再次执行联调，先检查上次日志是否已有 job ID；有编号的任务通过 GET 找回，不重复 POST。首次失败发生在 health，没有编号或上传；恢复后新建的两条合成任务编号见本日记录。不要将个人令牌、Tunnel token 或包含它们的进程命令行粘贴进日志／聊天。已有个人凭据只在系统安全存储或私密签发文件中管理。

未远程更改 Windows 服务、Cloudflare 配置或模型。客户端现在将 530 显示为服务暂时离线，保留原任务及缓存。
