#!/usr/bin/env bash
# dsh-patch-reasoning.sh — 重新应用 DSH「推理强度(reasoning effort)」补丁（dsh 更新后运行一次即可）。
#
# 推理强度（reasoning effort）档位说明（v2 重点）：
#   不同主流模型的 reasoning 档位并不通用。经核对各官方文档（详见 REASONING_LEVELS.md）：
#   - DeepSeek：真实仅 3 档有效 effort —— low / high / max
#     （medium、xhigh 会被后端并到 high；off / none 用于关闭思考）。
#   - OpenAI：reasoning.effort 支持 none/minimal/low/medium/high/xhigh，但分模型。
#   - Anthropic Claude：thinking + budget_tokens（或新版 adaptive + effort low/medium/high/max）。
#   - Google Gemini：thinkingLevel（MINIMAL/LOW/MEDIUM/HIGH）或 thinkingBudget（token）。
#   - Qwen：enable_thinking + thinking_budget（token）或 reasoning_effort（分模型）。
#
# 本脚本 v2 的变化：
#   不再伪造 7 档。仅确保 DeepSeek 适配器暴露其真实档位 off / low / high / max
#   （新版 dsh 已原生支持；旧版只有 off/high/max，这里补齐 low）。
#
# 补丁幂等：目标文件已带标记或已满足预期则跳过，未满足则应用。
# 用法：bash ~/.dsh/bin/dsh-patch-reasoning.sh
# ============================================================================
set -euo pipefail

PY=/Library/Frameworks/Python.framework/Versions/3.10/bin/python3

# 定位当前 dsh 安装目录（取最新 npx 缓存）
BASE="$(ls -dt "$HOME"/.npm/_npx/*/node_modules/@deepseek-ai 2>/dev/null | head -1 || true)"
if [ -z "${BASE:-}" ]; then
  echo "✗ 未找到 dsh 安装目录（$HOME/.npm/_npx/*/node_modules/@deepseek-ai）" >&2
  exit 1
fi
echo "dsh 安装目录: $BASE"

# ---------------------------------------------------------------------------
# 1) DeepSeek 推理强度：确保暴露真实档位（off / low / high / max）
#    DeepSeek 官方 API 仅有 3 档有效 effort：low / high / max
#     （medium、xhigh 会被后端并到 high；off 关闭思考）。
#    新版 dsh-llm-deepseek 已原生支持 off/low/high/max；旧版只有 off/high/max。
#    本补丁：若已含 low 则跳过；若缺 low 则补齐；若残留 v1 的 7 档伪造补丁则提示先升级 dsh。
# ---------------------------------------------------------------------------
FILE="$BASE/dsh-llm-deepseek/lib/index.js"
if [ ! -f "$FILE" ]; then
  echo "✗ 未找到 dsh-llm-deepseek: $FILE" >&2
elif grep -q "DSH_REASONING_WIDEN_PATCH" "$FILE"; then
  echo "⚠ 检测到 v1 的 7 档伪造补丁（DSH_REASONING_WIDEN_PATCH）。请先升级 dsh（会重置适配器），再重跑本脚本。跳过推理强度补丁。"
elif grep -q 'effort === "off" || effort === "low" || effort === "high" || effort === "max"' "$FILE"; then
  echo "✓ 跳过(上游已原生支持 off/low/high/max，与 DS 官方 low/high/max 一致): ${FILE##*/}"
else
  echo "→ 应用 推理强度真实档位（旧版适配器补齐 low）..."
  "$PY" - "$FILE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
n = 0
old1 = '\tif (effort === "off" || effort === "high" || effort === "max") return effort;'
new1 = '\t// DSH_REASONING_V2_PATCH: 补齐真实档位 low（DS 官方 API 仅 low/high/max 三档有效）\n\tif (effort === "off" || effort === "low" || effort === "high" || effort === "max") return effort;'
assert s.count(old1) in (0, 1), "r1"
if s.count(old1) == 1:
    s = s.replace(old1, new1); n += 1
old2 = '\tif (effort === "high" || effort === "max") return {'
new2 = '\tif (effort === "low" || effort === "high" || effort === "max") return {'
assert s.count(old2) in (0, 1), "r2"
if s.count(old2) == 1:
    s = s.replace(old2, new2); n += 1
old3 = '''const REASONING_EFFORTS = [
\t{
\t\tid: OFF_REASONING_EFFORT,
\t\tname: "Off"
\t},
\t{
\t\tid: HIGH_REASONING_EFFORT,
\t\tname: "High"
\t},
\t{
\t\tid: MAX_REASONING_EFFORT,
\t\tname: "Max"
\t}
];'''
new3 = '''const REASONING_EFFORTS = [
\t{
\t\tid: OFF_REASONING_EFFORT,
\t\tname: "Off"
\t},
\t{
\t\tid: LOW_REASONING_EFFORT,
\t\tname: "Low"
\t},
\t{
\t\tid: HIGH_REASONING_EFFORT,
\t\tname: "High"
\t},
\t{
\t\tid: MAX_REASONING_EFFORT,
\t\tname: "Max"
\t}
];'''
assert s.count(old3) in (0, 1), "r3"
if s.count(old3) == 1:
    s = s.replace(old3, new3); n += 1
old4 = '''\treasoningEffort: z.union([
\t\t"off",
\t\t"high",
\t\t"max"
\t]),'''
new4 = '''\treasoningEffort: z.union([
\t\t"off",
\t\t"low",
\t\t"high",
\t\t"max"
\t]),'''
assert s.count(old4) in (0, 1), "r4"
if s.count(old4) == 1:
    s = s.replace(old4, new4); n += 1
old5 = '\t\t\t\tdefaultEffort: connection.defaults.reasoningEffort === "off" ? OFF_REASONING_EFFORT : connection.defaults.reasoningEffort === "max" ? MAX_REASONING_EFFORT : HIGH_REASONING_EFFORT'
new5 = '\t\t\t\tdefaultEffort: connection.defaults.reasoningEffort === "off" ? OFF_REASONING_EFFORT : connection.defaults.reasoningEffort === "low" ? LOW_REASONING_EFFORT : connection.defaults.reasoningEffort === "max" ? MAX_REASONING_EFFORT : HIGH_REASONING_EFFORT'
assert s.count(old5) in (0, 1), "r5"
if s.count(old5) == 1:
    s = s.replace(old5, new5); n += 1
open(p, "w", encoding="utf-8").write(s)
print("applied %d/5 replacements (old adapter -> 真实档位 off/low/high/max)" % n)
PY
  node --check "$FILE" && echo "✓ 推理强度真实档位 OK"
fi

echo "✓ reasoning 补丁处理完成。重启 dsh（或等待 HMR 自动重载）后生效。"
