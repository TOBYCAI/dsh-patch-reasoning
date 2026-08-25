#!/usr/bin/env bash
# dsh-patch-reasoning.sh — 自动探测 dsh 适配器并对齐各主流模型的真实推理强度(reasoning effort)档位。
#
# 工作原理（v2.1，自动探测版）：
#   1) 自动探测 dsh 安装目录（最新 npx 缓存）下所有 dsh-llm-* 适配器包。
#   2) 按 provider 类型分派「真实档位对齐」补丁：
#        - deepseek：适配器代码写死档位；对齐官方真实 off / low / high / max
#          （新版 dsh 已原生支持则跳过；旧版只有 off/high/max 则补齐 low；
#           残留 v1 的 7 档伪造补丁则提示先升级 dsh）。
#        - pi-ai：配置驱动网关，原生支持 7 档全集（THINKING_LEVELS：
#          off/minimal/low/medium/high/xhigh/max），档位由模型配置的 reasoningEfforts
#          声明决定 → 无需改代码，跳过。
#        - retry 等包装层 / 未知 provider：跳过并提示。
#   3) 运行时输出「各主流模型官方真实档位表」作为自动匹配的参考依据。
#
# 说明：DSH 的主流模型（OpenAI / Claude / Gemini / Qwen 等）经 pi-ai 网关，
#        其可选档位已为官方全集；唯一确定需代码层对齐的是 dsh-llm-deepseek。
#        脚本泛化为「探测所有适配器」以便未来安装独立 provider 适配器也能自动对齐。
#
# 幂等：目标文件已带标记或已满足预期则跳过，未满足则应用。
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
echo

# ---------------------------------------------------------------------------
# 各主流模型官方真实 reasoning 档位（核对自各官方文档，详见 REASONING_LEVELS.md）
# ---------------------------------------------------------------------------
print_reference() {
  cat <<'EOF'
📌 各主流模型官方真实 reasoning 档位（自动匹配依据）：
   DeepSeek : low / high / max              (medium、xhigh 后端并到 high；off 关闭思考)
   OpenAI   : none/minimal/low/medium/high/xhigh（分模型；o 系列支持）
   Claude   : off / low / medium / high / max（adaptive effort；或 thinking + budget_tokens）
   Gemini   : MINIMAL/LOW/MEDIUM/HIGH（或 thinkingBudget token；2.5/3 各不同）
   Qwen     : 关闭 / 低 / 中 / 高（enable_thinking + thinking_budget；或 reasoning_effort 分模型）
   (经 pi-ai 网关时，档位由模型配置的 reasoningEfforts 声明决定，pi-ai 原生支持全集)

EOF
}

# ---------------------------------------------------------------------------
# deepseek：确保适配器暴露真实档位（off / low / high / max）
# ---------------------------------------------------------------------------
patch_deepseek() {
  local AD="$1"
  local FILE="$AD/lib/index.js"
  if [ ! -f "$FILE" ]; then
    echo "✗ 未找到 dsh-llm-deepseek: $FILE" >&2
    return
  fi
  if grep -q "DSH_REASONING_WIDEN_PATCH" "$FILE"; then
    echo "⚠ [deepseek] 检测到 v1 的 7 档伪造补丁（DSH_REASONING_WIDEN_PATCH）。请先升级 dsh（会重置适配器），再重跑本脚本。跳过 DeepSeek 推理强度补丁。"
    return
  fi
  if grep -q 'effort === "off" || effort === "low" || effort === "high" || effort === "max"' "$FILE"; then
    echo "✓ [deepseek] 跳过(上游已原生支持 off/low/high/max): ${FILE##*/}"
    return
  fi
  echo "→ [deepseek] 应用 推理强度真实档位（旧版适配器补齐 low）..."
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
  node --check "$FILE" && echo "✓ [deepseek] 推理强度真实档位 OK"
}

# ---------------------------------------------------------------------------
# pi-ai：配置驱动网关，原生 7 档全集，无需改代码
# ---------------------------------------------------------------------------
skip_piai() {
  echo "• [pi-ai] 跳过：pi-ai 为配置驱动网关，原生支持 7 档全集"
  echo "           (off/minimal/low/medium/high/xhigh/max，见 THINKING_LEVELS)；"
  echo "           各模型可选档位由模型配置的 reasoningEfforts 声明决定，无需补丁代码。"
}

# ---------------------------------------------------------------------------
# 自动探测 + 分派
# ---------------------------------------------------------------------------
print_reference
echo "=== 自动探测 dsh-llm-* 适配器 ==="
FOUND=0
while IFS= read -r AD; do
  [ -z "$AD" ] && continue
  NAME="$(grep -m1 '"name"' "$AD/package.json" 2>/dev/null | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  PROV="${NAME#*dsh-llm-}"   # 取 dsh-llm- 之后的 provider 名（deepseek / pi-ai / retry ...）
  echo "→ 检测到适配器: $NAME (provider: $PROV)"
  case "$PROV" in
    deepseek) patch_deepseek "$AD" ;;
    pi-ai)    skip_piai "$AD" ;;
    retry)    echo "• [$NAME] 跳过（重试包装层，非 reasoning provider）" ;;
    *)        echo "⚠ [$NAME] 未知 provider，暂不自动补丁（如需支持请在仓库提 issue）" ;;
  esac
  FOUND=1
done < <(find "$BASE" -maxdepth 2 -type d -name 'dsh-llm-*' 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
  echo "⚠ 未探测到任何 dsh-llm-* 适配器（可能 dsh 尚未初始化）。"
fi

echo
echo "✓ reasoning 补丁处理完成。重启 dsh（或等待 HMR 自动重载）后生效。"
