# GuitarPal 音频服务基础

当前交付是 M0/M1 的领域规则、模型登记校验和 API 契约草案。尚无可部署 API、持久任务系统或真实模型推理服务。现有 App 的 Supabase 身份会作为后续 API 的认证来源。

从仓库根目录运行无依赖规则测试：

```bash
PYTHONPATH=server python3 -m unittest discover -s server/tests -v
```

校验 JSON Schema、共享样例、OpenAPI 组件引用和模型配置：

```bash
python3 -m venv server/.venv
server/.venv/bin/python -m pip install -r server/requirements-contracts.txt
PYTHONPATH=server server/.venv/bin/python -m guitarpal_audio.check_contracts
```

Python 规则与 Flutter 使用同一份 `contracts/audio/fixtures/chords_offset_v1.json`。它是手工编写的协议测试数据，含 30–50 秒区间、首部无和弦、间隙、未知标签、转位及分轨失败；其中零哈希、空调性/BPM 均不代表已运行模型。

`model_manifest.json` 保留规划指定的上游提交，但两个 profile 都关闭。只有实际权重、参数、词表、授权资料和基准证据补齐后才能启用。当前校验只验证登记结构；后续 worker 还必须对实际制品重新计算 SHA256，并执行真实音频预热/基准。

`contracts.py` 的状态转换仅为领域约束。M1 后续会使用 PostgreSQL 的状态版本和 lease 条件更新、事务 outbox、Celery/Redis 以及恢复协调器落实并发语义。它不能替代持久队列，也未完成取消/删除竞态的集成验收。

下一步及已知依赖见 [阶段进度](../docs/ai_audio/progress.md)。
