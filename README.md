# dsh-patch-reasoning

> 中文 | [English](./README.en.md)

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![Downloads](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/total?style=flat-square&color=14b8a6)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

一键重新应用 DeepSeek Harness 的「模型调优」补丁（**DSH 升级后运行一次即可**）。每个补丁独立幂等：目标文件已带标记则跳过，未带则应用。

## 补丁内容

1. **DeepSeek 推理强度：对齐官方真实档位（off / low / high / max）**。经核对官方文档，DeepSeek 有效
   effort 仅 `low` / `high` / `max` 三档（`medium`、`xhigh` 会被后端并到 `high`；`off` 关闭思考）。v2 不再伪造
   7 档——新版 dsh 适配器已原生支持 `off/low/high/max` 则跳过；旧版只有 `off/high/max` 则补齐 `low`。
   各主流模型 reasoning 等级对照见 [REASONING_LEVELS.md](./REASONING_LEVELS.md)。
2. **workflow 子 agent 默认模型** → 使用 `deepseek-v4-flash`（脚本内显式指定 `model` 仍优先）。
3. **ralph worker 默认模型** → `deepseek-v4-flash`（`RALPH_SCRIPT` 为部署固定，只能打补丁）。

> 自定义/第三方模型（OpenAI 兼容）若想用多档推理强度：`pi-ai` 适配器原生支持 7 档、无需补丁，在模型配置里声明 `reasoningEfforts` 即可。

## 获取

```bash
# 方式一：git clone（推荐）
git clone https://github.com/TOBYCAI/dsh-patch-reasoning.git
cd dsh-patch-reasoning

# 方式二：从 Releases 下载源码包
#   https://github.com/TOBYCAI/dsh-patch-reasoning/releases
```

脚本为单文件 `dsh-patch-reasoning.sh`，无需安装依赖。

## 用法

```bash
# 直接运行仓库里的脚本（先按「获取」clone / 下载）
bash dsh-patch-reasoning.sh

# 或放到 DSH 的 bin 目录后运行
bash ~/.dsh/bin/dsh-patch-reasoning.sh
```

各补丁可单独开关（见脚本开头的说明与参数）。

## 适用性

- **适配系统**：macOS / Linux（需 Bash）；**Windows 请在 Git Bash / WSL 中运行**（纯 bash 脚本，不适用于原生命令提示符）。
- 适用于 DeepSeek Harness（DSH）本地部署，需要能访问你使用的 provider/模型配置。
- 脚本是**幂等**的：重复运行不会重复打补丁。

## License

[MIT](./LICENSE) © TOBYCAI
