# GuitarPal Supabase 配置

GuitarPal Android 客户端使用 Supabase Auth 完成邮箱 Magic Link 和 Google OAuth 登录。应用仍是 local-first：没有构建配置、网络异常或 Supabase 初始化失败时会自动退回本地模式，不影响练习、录音和计划。

## 客户端构建配置

项目 URL 与 publishable key 通过 Flutter 的构建参数注入，不写进 Dart 源码：

```bash
cp config/supabase.example.json config/supabase.local.json
flutter run --dart-define-from-file=config/supabase.local.json
```

`config/supabase.local.json` 已加入 `.gitignore`。该文件只允许填写项目 URL、`sb_publishable_` key 和登录方式开关；不能填写数据库密码、`service_role` key 或 `sb_secret_` key。

当前 Android 登录回调为：

```text
com.guitarpal.app://login-callback/
```

该地址已精确加入 Supabase Dashboard 的 **Authentication → URL Configuration → Redirect URLs** 允许列表。Android Manifest 已注册相同 scheme 和 host，Supabase SDK 只处理匹配该地址的认证回调；若以后调整 scheme 或 host，必须同步修改 Dashboard、Manifest 和客户端运行时配置。

## 邮箱 Magic Link

邮箱 Provider 启用后，账号页会收集邮箱并调用 Supabase `signInWithOtp`。登录邮件必须在安装 GuitarPal 的设备上打开，回调后 SDK 会完成 PKCE 授权码交换并恢复会话。

当前实现不收集或保存用户密码。会话和 PKCE verifier 使用 Android Keystore / iOS Keychain 支持的安全存储，不使用普通 SharedPreferences。

## Google 登录

Google 登录需要先在 Google Auth Platform 创建 **Web application** OAuth Client，再把以下 Supabase 回调加入 Google 的 Authorized redirect URIs：

```text
https://igvkotsbaoaqsbgwwteo.supabase.co/auth/v1/callback
```

之后在 Supabase **Authentication → Sign In / Providers → Google** 中填写 Client ID 和 Client Secret，并把本机配置改为：

```json
"SUPABASE_ENABLE_GOOGLE": "true"
```

在 Provider 尚未启用时不要打开该开关；客户端会继续显示 Google“未配置”，避免启动必然失败的授权。

## Supabase CLI（后续数据库迁移使用）

认证客户端本身不要求 Supabase CLI。进入跨设备同步和数据库迁移阶段后再执行：

```bash
supabase login
supabase init
supabase link --project-ref igvkotsbaoaqsbgwwteo
```

数据库密码只在 CLI 的安全提示中输入，不写进命令、配置文件、Git 或移动端。所有客户端可访问的业务表必须先开启 Row Level Security，并按 `auth.uid()` 建立最小权限策略。
