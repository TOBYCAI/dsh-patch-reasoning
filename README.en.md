# dsh-patch-reasoning

> 中文 | English

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![Downloads](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/total?style=flat-square&color=14b8a6)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

One-command re-application of the DeepSeek Harness "reasoning effort" patch — **auto-detects every adapter under your dsh install and aligns each provider's real reasoning levels (run once after a DSH upgrade)**. The patch is idempotent: it skips a target that already meets the expectation, and applies it otherwise.

## How it works (auto-detect + per-provider alignment)

On startup the script auto-detects every `dsh-llm-*` adapter under your dsh install and dispatches a "real-level alignment" patch by provider type:

- **deepseek**: the adapter hard-codes its levels. Aligns to the official real `off / low / high / max`
  (only `low`/`high`/`max` are effective — `medium` and `xhigh` are folded into `high`; `off` disables thinking).
  Skips if a new dsh adapter already supports `off/low/high/max`; adds `low` on an old adapter with only `off/high/max`.
- **pi-ai**: a config-driven gateway that natively supports the full 7 levels (`off/minimal/low/medium/high/xhigh/max`, see its `THINKING_LEVELS`).
  Each model's selectable levels are decided by the model config's `reasoningEfforts` declaration, so **no code patch is needed — skipped**.
- **retry wrapper / unknown provider**: skipped with a note.

> Note: DSH's mainstream models (OpenAI / Claude / Gemini / Qwen, etc.) go through the pi-ai gateway and already expose the official full level set; the only provider that definitively needs code-level alignment is `dsh-llm-deepseek`. The script is generalized to "detect all adapters" so future standalone provider adapters also get aligned automatically. The full per-model reasoning-level reference is in [REASONING_LEVELS.md](./REASONING_LEVELS.md).

## Get it

```bash
# Option 1: git clone (recommended)
git clone https://github.com/TOBYCAI/dsh-patch-reasoning.git
cd dsh-patch-reasoning

# Option 2: download the source zip from Releases
#   https://github.com/TOBYCAI/dsh-patch-reasoning/releases
```

The script is a single file `dsh-patch-reasoning.sh` with no external dependencies.

## Usage

```bash
# Run the script directly from the cloned repo (see "Get it" above)
bash dsh-patch-reasoning.sh

# Or run it from DSH's bin directory after placing it there
bash ~/.dsh/bin/dsh-patch-reasoning.sh
```

Running the script applies the reasoning patch above; it is idempotent and safe to re-run.

## Applicability

- **Supported platforms**: macOS / Linux (requires Bash); **on Windows run inside Git Bash or WSL** (a pure bash script, not for the native prompt).
- Targets a DeepSeek Harness (DSH) local deployment; needs access to your provider / model config.
- **Idempotent**: re-running will not double-apply patches.

## License

[MIT](./LICENSE) © TOBYCAI
