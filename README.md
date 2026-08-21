# dsh-patch-reasoning

> 中文 | [English](./README.en.md)

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

一键重新应用 DeepSeek Harness 的「模型调优」补丁（**DSH 升级后运行一次即可**）。每个补丁独立幂等：目标文件已带标记则跳过，未带则应用。

## 补丁内容

1. **DeepSeek 推理强度拓宽**：`off/high/max` → `off/minimal/low/medium/high/xhigh/max`
   （API 实测接受全部值，档位限制只是适配器代码写死。）
2. **workflow 子 agent 默认模型** → 使用 `deepseek-v4-flash`（脚本内显式指定 `model` 仍优先）。
3. **ralph worker 默认模型** → `deepseek-v4-flash`（`RALPH_SCRIPT` 为部署固定，只能打补丁）。

> 自定义/第三方模型（OpenAI 兼容）若想用多档推理强度：`pi-ai` 适配器原生支持 7 档、无需补丁，在模型配置里声明 `reasoningEfforts` 即可。

## 用法

```bash
# 直接运行（默认打 DSH 相关文件补丁）
bash ~/.dsh/bin/dsh-patch-reasoning.sh
```

各补丁可单独开关（见脚本开头的说明与参数）。

## 适用性

- 适用于 DeepSeek Harness（DSH）本地部署，需要能访问你使用的 provider/模型配置。
- 脚本是**幂等**的：重复运行不会重复打补丁。

## License

[MIT](./LICENSE) © TOBYCAI
