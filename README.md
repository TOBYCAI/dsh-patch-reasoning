# dsh-patch-reasoning

> 中文 | [English](./README.en.md)

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![Downloads](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/total?style=flat-square&color=14b8a6)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

一键重新应用 DeepSeek Harness 的「推理强度（reasoning effort）」补丁——**自动探测 dsh 安装目录下所有适配器，按 provider 对齐各主流模型的真实档位（DSH 升级后运行一次即可）**。补丁幂等：目标已满足预期则跳过，未满足则应用。

## 工作原理（自动探测 + 按 provider 对齐）

脚本启动时自动探测 dsh 安装目录下所有 `dsh-llm-*` 适配器，按 provider 类型分派「真实档位对齐」：

- **deepseek**：适配器代码写死档位。对齐官方真实 `off / low / high / max`
  （有效 effort 仅 `low`/`high`/`max` 三档，`medium`/`xhigh` 后端并到 `high`，`off` 关闭思考）。
  新版 dsh 已原生支持则跳过；旧版只有 `off/high/max` 则补齐 `low`。
- **pi-ai**：配置驱动网关，原生支持 7 档全集（`off/minimal/low/medium/high/xhigh/max`，见其 `THINKING_LEVELS`）。
  各模型可选档位由模型配置的 `reasoningEfforts` 声明决定，**无需改代码，跳过**。
- **retry 等包装层 / 未知 provider**：跳过并提示。

> 说明：DSH 的主流模型（OpenAI / Claude / Gemini / Qwen 等）经 pi-ai 网关，档位已为官方全集；唯一确定需代码层对齐的是 `dsh-llm-deepseek`。脚本泛化为「探测所有适配器」，便于未来安装独立 provider 适配器时也能自动对齐。各主流模型 reasoning 等级完整对照见 [REASONING_LEVELS.md](./REASONING_LEVELS.md)。

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

运行脚本即应用上述 reasoning 补丁，幂等可重复运行。

## 适用性

- **适配系统**：macOS / Linux（需 Bash）；**Windows 请在 Git Bash / WSL 中运行**（纯 bash 脚本，不适用于原生命令提示符）。
- 适用于 DeepSeek Harness（DSH）本地部署，需要能访问你使用的 provider/模型配置。
- 脚本是**幂等**的：重复运行不会重复打补丁。

## License

[MIT](./LICENSE) © TOBYCAI
