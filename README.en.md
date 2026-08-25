# dsh-patch-reasoning

> 中文 | English

![GitHub stars](https://img.shields.io/github/stars/TOBYCAI/dsh-patch-reasoning?style=flat-square&color=facc15)
![Downloads](https://img.shields.io/github/downloads/TOBYCAI/dsh-patch-reasoning/total?style=flat-square&color=14b8a6)
![License](https://img.shields.io/badge/license-MIT-3b82f6?style=flat-square)
![Script](https://img.shields.io/badge/type-script-4d6bfe?style=flat-square)

One-command re-application of the DeepSeek Harness adapter's "reasoning effort" patch (**run once after a DSH upgrade**). The patch is idempotent: it skips the target file if already tagged or already meets the expectation, and applies it otherwise.

## Patches

1. **DeepSeek reasoning: align with the real official levels (`off` / `low` / `high` / `max`)**. Per the official docs, DeepSeek only has three effective efforts — `low` / `high` / `max` (`medium` and `xhigh` are folded into `high`; `off` disables thinking). v2 no longer fakes 7 levels: on a new dsh adapter that already supports `off/low/high/max` it skips; on an old adapter with only `off/high/max` it adds `low`. See [REASONING_LEVELS.md](./REASONING_LEVELS.md) for the per-model reasoning-level reference.

> For a custom / third-party (OpenAI-compatible) model that wants multi-level reasoning: the `pi-ai` adapter supports 7 levels natively and needs no patch — just declare `reasoningEfforts` in the model config.

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
