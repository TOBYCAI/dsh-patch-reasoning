# 各主流模型 Reasoning 等级对照（dsh-patch-reasoning v2 参考）

不同模型的「推理强度 / 思考深度」**不是一套通用枚举**。下面按各官方文档核对真实参数与取值。
在 DSH 里为某个模型配置 reasoning 档位时，应使用该模型**真实支持**的取值，避免传入「假档位」
（后端并档或忽略，UI 上看着有、实际不生效）。

> 数据核对时间：2026-08-25，来源为各厂商官方 API 文档。

## DeepSeek（已核实，最关键）

- 官方文档：`api-docs.deepseek.com/guides/thinking_mode`
- OpenAI 格式参数：`reasoning_effort`，取值 **`low` / `high` / `max`**（默认 `high`）。
- Responses API 格式：`reasoning.effort`，取值 **`none` / `low` / `high` / `max`**（`none` 关闭思考）。
- **用户传入 → 后端实际映射**（deepseek-v4-flash / deepseek-v4-pro 一致）：

  | 传入 effort | 实际生效 |
  |---|---|
  | `low` | `low` |
  | `medium` | **`high`** |
  | `high` | `high` |
  | `xhigh` | **`high`** |
  | `max` | `max` |

- **结论：有效 effort 只有 `low` / `high` / `max` 三档**；`medium`、`xhigh` 会被后端并到 `high`；
  `off` / `none` 用于关闭思考。
- DSH 现状：`dsh-llm-deepseek` 新版已原生支持 `off / low / high / max`（`off` 走 `thinking: "disabled"`）。
  本补丁 v2 **不再伪造 7 档**，仅在旧版适配器（只有 `off/high/max`）上补齐 `low`，使其与官方三档对齐。

## OpenAI

- 官方文档：`platform.openai.com/docs/guides/reasoning`
- 参数：`reasoning.effort`（Responses API）或 `reasoning_effort`（Chat Completions，旧版）。
- 取值（**分模型**、可包括）：**`none` / `minimal` / `low` / `medium` / `high` / `xhigh`**。
- 分模型支持（实测对照节选）：
  - GPT-5.2 系列：`none` / `low` / `medium` / `high` / `xhigh`（gpt-5.2-pro 仅 `medium` / `high` / `xhigh`）。
  - 早期推理模型（o 系列、初代 gpt-5）：仅 `low` / `medium` / `high`。
  - `gpt-5.5` 默认 `medium`。
- `none`：让模型以非推理方式工作（延迟敏感场景）。

## Anthropic Claude

- 官方文档：`docs.anthropic.com`（Extended Thinking）
- 旧 / 手动模式：`thinking: { type: "enabled", budget_tokens: N }`（令牌预算，最小 1024；新模型已弃用）。
- 新 / 自适应（Opus 4.7+、Sonnet 4.6 推荐）：`thinking: { type: "adaptive" }` + `output_config: { effort: low/medium/high/max }`。
- `effort`：`low` / `medium` / `high` / `max`（`max` 仅 Opus 系列）。
- 注意：Claude 不是固定枚举档，而是「令牌预算」或「自适应强度」。

## Google Gemini

- 官方文档：`ai.google.dev/gemini-api/docs/generate-content/thinking`
- **Gemini 3**：`thinkingConfig.thinkingLevel` → **`MINIMAL` / `LOW` / `MEDIUM` / `HIGH`**（4 档）。
- **Gemini 2.5**：`thinkingConfig.thinkingBudget`（整数令牌；`0` 关闭，`-1` 动态）。范围因模型而异。
- 不支持同时设置 `thinkingLevel` 与 `thinkingBudget`。

## Qwen（通义千问）

- 官方文档：`docs.qwencloud.com`
- `enable_thinking`：混合思考开关（true / false）；部分模型为「仅思考」不可关。
- `thinking_budget`：思维链令牌预算（Qwen3.x 支持）。
- `reasoning_effort`：分级控制（**分模型**，例如 qwen3.8-max 支持 `low` / `medium` / `xhigh`，默认 `xhigh`）。
- 注：`enable_thinking` 与 `reasoning_effort` 不能同时传。

## 在 DSH 里为不同模型配置正确档位

- **DeepSeek**：无需额外配置。适配器原生 `off / low / high / max` 即对应官方三档 + 关闭；
  本补丁仅确保旧版也补齐 `low`。
- **OpenAI 兼容（pi-ai 适配器）**：通过 provider 的 `reasoningEfforts` 映射，把 DSH 规范档位映射到
  该模型真实接受的值。示例：

  ```yaml
  providers:
    acme-gateway:
      apiKeyEnv: ACME_API_KEY
      baseURL: https://gateway.example/v1
      api: openai-completions
      models:
        - id: acme-gpt52
          reasoningEfforts:
            off:
            none: none
            low: low
            medium: medium
            high: high
            xhigh: xhigh
            max: max
  ```

  （若目标模型不支持其中某些值，删掉对应行即可；例如仅支持 `low/medium/high` 的模型就不要配 `none/xhigh/max`。）

- **Claude / Gemini / Qwen**：走各自适配器或其原生参数（`thinking` / `output_config` / `thinkingConfig` /
  `enable_thinking` 等），DSH 透传；按上表填真实取值。

## 统一建议（canonical vocabulary）

若要跨模型统一 UI，建议 DSH 规范档位取 **`off` / `low` / `medium` / `high` / `max`** 五档，再按上表映射到各模型真实值：

- DeepSeek：`off` → 关；`low` → `low`；`medium` → `high`；`high` → `high`；`max` → `max`。
- OpenAI：`off` → `none`（或省略）；其余原样（视模型支持）。
- Claude：`off` → thinking disabled；`low/medium/high` → `effort` 原样；`max` → `max`（Opus）。
- Gemini 3：`low/medium/high` → 对应 `LEVEL`；`off` → `budget` 0。
- Qwen：`low/medium/high` → 对应（视模型）；`off` → `enable_thinking` false。
