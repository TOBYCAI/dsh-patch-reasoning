# dsh-patch-reasoning

> 中文 | English

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![Downloads](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/total?style=flat-square&color=14b8a6)
![Downloads@latest](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/latest/total?style=flat-square&color=14b8a6)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

One-command re-application of the DeepSeek Harness "model-tuning" patches (**run once after a DSH upgrade**). Each patch is idempotent: it skips the target file if already tagged, and applies it otherwise.

## Patches

1. **Widen DeepSeek reasoning levels**: `off/high/max` → `off/minimal/low/medium/high/xhigh/max`
   (the API accepts all values; the limit is only hard-coded in the adapter).
2. **Workflow sub-agents default model** → `deepseek-v4-flash` (an explicit `model` in your script still wins).
3. **Ralph worker default model** → `deepseek-v4-flash` (`RALPH_SCRIPT` is deployment-fixed, so it is patched).

> For a custom / third-party (OpenAI-compatible) model that wants multi-level reasoning: the `pi-ai` adapter supports 7 levels natively and needs no patch — just declare `reasoningEfforts` in the model config.

## Usage

```bash
bash ~/.dsh/bin/dsh-patch-reasoning.sh
```

Each patch can be toggled individually (see the comments and flags at the top of the script).

## Applicability

- **Supported platforms**: macOS / Linux (requires Bash); **on Windows run inside Git Bash or WSL** (a pure bash script, not for the native prompt).
- Targets a DeepSeek Harness (DSH) local deployment; needs access to your provider / model config.
- **Idempotent**: re-running will not double-apply patches.

## License

[MIT](./LICENSE) © TOBYCAI
