#!/usr/bin/env bash
# dsh-patch-reasoning.sh — 重新应用 DSH「模型调优」补丁（dsh 更新后运行一次即可）。
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
#   1) 不再伪造 7 档。仅确保 DeepSeek 适配器暴露其真实档位 off / low / high / max
#      （新版 dsh 已原生支持；旧版只有 off/high/max，这里补齐 low）。
#   2) workflow 子 agent 默认用 deepseek-v4-flash（脚本显式指定 model 仍优先）。
#   3) ralph worker 默认用 deepseek-v4-flash（RALPH_SCRIPT 为部署固定，只能打补丁）。
#   4) 允许新会话不带工作区直接开始（Ungrouped）。
#   5) 工作区选择器加「无项目开始」选项。
#
# 每个补丁独立幂等：目标文件已带标记或已满足预期则跳过，未满足则应用。
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

# ---------------------------------------------------------------------------
# 2) workflow 子 agent 默认用 flash
# ---------------------------------------------------------------------------
WF="$BASE/dsh-workflow-worker-thread/lib/index.js"
if [ ! -f "$WF" ]; then
  echo "✗ 未找到 dsh-workflow-worker-thread: $WF" >&2
elif grep -q "DSH_WORKER_MODEL_FLASH" "$WF"; then
  echo "✓ 跳过(已应用): ${WF##*/} workflow flash"
else
  echo "→ 应用 workflow worker flash ..."
  "$PY" - "$WF" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = ('\t\t\t\t...request.provider !== void 0 || request.model !== void 0 ? { agentOptions: {\n'
       '\t\t\t\t\t...request.provider !== void 0 ? { provider: request.provider } : {},\n'
       '\t\t\t\t\t...request.model !== void 0 ? { model: request.model } : {}\n'
       '\t\t\t\t} } : {}')
new = ('\t\t\t\t// DSH_WORKER_MODEL_FLASH: 默认 workflow 子 agent 用 flash，脚本显式指定 model 仍优先\n'
       '\t\t\t\t...{\n'
       '\t\t\t\t\tagentOptions: {\n'
       '\t\t\t\t\t\t...request.provider !== void 0 ? { provider: request.provider } : {},\n'
       '\t\t\t\t\t\tmodel: request.model !== void 0 ? request.model : "deepseek-v4-flash"\n'
       '\t\t\t\t\t}\n'
       '\t\t\t\t}')
assert s.count(old) == 1, "workflow patch 匹配失败"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("applied workflow flash patch")
PY
  node --check "$WF" && echo "✓ workflow flash OK"
fi

# ---------------------------------------------------------------------------
# 3) ralph worker 默认用 flash
# ---------------------------------------------------------------------------
RL="$BASE/dsh-tool-ralph/lib/index.js"
if [ ! -f "$RL" ]; then
  echo "✗ 未找到 dsh-tool-ralph: $RL" >&2
elif grep -q "DSH_RALPH_MODEL_FLASH" "$RL"; then
  echo "✓ 跳过(已应用): ${RL##*/} ralph flash"
else
  echo "→ 应用 ralph worker flash ..."
  "$PY" - "$RL" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = ("  const rawReport = await agent(prompt, {\n"
       "    label: 'Ralph round ' + round,\n"
       "    phase: 'Fresh-agent rounds',\n"
       "    schema: reportSchema,\n"
       "  })")
new = ("  const rawReport = await agent(prompt, {\n"
       "    label: 'Ralph round ' + round,\n"
       "    phase: 'Fresh-agent rounds',\n"
       "    schema: reportSchema,\n"
       "    // DSH_RALPH_MODEL_FLASH: ralph worker 用 flash\n"
       "    model: 'deepseek-v4-flash',\n"
       "  })")
assert s.count(old) == 1, "ralph patch 匹配失败"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("applied ralph flash patch")
PY
  node --check "$RL" && echo "✓ ralph flash OK"
fi

# ---------------------------------------------------------------------------
# 4) Web 前端：允许新会话不带工作区直接开始（Ungrouped）
# ---------------------------------------------------------------------------
CF="$BASE/dsh-client-ui-conversation/lib/client.js"
if [ ! -f "$CF" ]; then
  echo "✗ 未找到 dsh-client-ui-conversation: $CF" >&2
elif grep -q "DSH_ALLOW_UNGROUPED" "$CF"; then
  echo "✓ 跳过(已应用): ${CF##*/} 允许无工作区新会话"
else
  echo "→ 应用 允许无工作区新会话 ..."
  "$PY" - "$CF" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "const inert = sessionId === void 0 || hero && chipTitle === void 0;"
new = "const inert = sessionId === void 0; // DSH_ALLOW_UNGROUPED: 允许新会话不带工作区直接开始（归入 Ungrouped）"
assert s.count(old) == 1, "conversation patch 匹配失败"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("applied allow-ungrouped patch")
PY
  echo "✓ 允许无工作区新会话 OK（刷新浏览器页面生效）"
fi

# ---------------------------------------------------------------------------
# 5) Web 前端：工作区选择器加「无项目开始（Ungrouped）」选项
#    （选择器菜单 + conversation 侧处理哨兵，创建无工作区会话）
# ---------------------------------------------------------------------------
WF="$BASE/dsh-client-ui-workspace/lib/client.js"
CV="$BASE/dsh-client-ui-conversation/lib/client.js"
if [ ! -f "$WF" ] || [ ! -f "$CV" ]; then
  echo "✗ 未找到前端插件文件 (workspace/conversation)" >&2
elif grep -q '"::ungrouped"' "$WF" && grep -q '"::ungrouped"' "$CV"; then
  echo "✓ 跳过(已应用): 无项目开始选项"
else
  echo "→ 应用 无项目开始选项 ..."
  "$PY" - "$WF" "$CV" <<'PY'
import sys
wf, cv = sys.argv[1], sys.argv[2]

# --- workspace picker ---
s = open(wf, encoding="utf-8").read()
old = '\t\tconst ADD_WORKSPACE = "::add-workspace";'
new = old + '\n\t\tconst UNGROUPED = "::ungrouped"; // DSH_UNGROUPED: 无项目开始'
assert s.count(old) == 1, "wf1"
s = s.replace(old, new)
old = '''\t\t\tconst items = pinAdd ? workspaces.map((workspace) => ({
\t\t\t\tid: workspace.workspaceId,
\t\t\t\tlabel: workspace.title,
\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconFolderClose16, { size: 16 }),
\t\t\t\tdisabled: flowBusy
\t\t\t})) : addEntries;'''
new = '''\t\t\tconst items = [{
\t\t\t\tid: UNGROUPED,
\t\t\t\tlabel: t("menu.startUngrouped"),
\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconFolderClose16, { size: 16 }),
\t\t\t\tdisabled: flowBusy
\t\t\t}, ...(pinAdd ? workspaces.map((workspace) => ({
\t\t\t\tid: workspace.workspaceId,
\t\t\t\tlabel: workspace.title,
\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconFolderClose16, { size: 16 }),
\t\t\t\tdisabled: flowBusy
\t\t\t})) : addEntries)];'''
assert s.count(old) == 1, "wf2"
s = s.replace(old, new)
old = '\t\t\t"menu.addWorkspace": "添加工作区…",'
assert s.count(old) == 1, "wf3zh"
s = s.replace(old, old + '\n\t\t\t"menu.startUngrouped": "无项目开始",')
old = '\t\t\t"menu.addWorkspace": "Add workspace…",'
assert s.count(old) == 1, "wf3en"
s = s.replace(old, old + '\n\t\t\t"menu.startUngrouped": "Start without a project",')
open(wf, "w", encoding="utf-8").write(s)
print("workspace picker patched")

# --- conversation: selectWorkspace + onPick ---
s = open(cv, encoding="utf-8").read()
old = '\t\t\t\t\tselectWorkspace: async (workspaceId) => {\n\t\t\t\t\t\tconst nextId = await workspaces.connectWorkspace(workspaceId);'
new = '\t\t\t\t\tselectWorkspace: async (workspaceId) => {\n\t\t\t\t\t\tconst nextId = workspaceId === "::ungrouped" ? (await sessions.create({})).value.sessionId : await workspaces.connectWorkspace(workspaceId);'
assert s.count(old) == 1, "cv1"
s = s.replace(old, new)
old = '\t\t\t\t\t\tonPick: (workspaceId) => {\n\t\t\t\t\t\t\tsetPickerOpen(false);\n\t\t\t\t\t\t\tsetPendingWorkspaceId(workspaceId);\n\t\t\t\t\t\t\tselectWorkspace(workspaceId).catch(() => {\n\t\t\t\t\t\t\t\tsetPendingWorkspaceId((current) => current === workspaceId ? void 0 : current);\n\t\t\t\t\t\t\t});\n\t\t\t\t\t\t},'
new = '\t\t\t\t\t\tonPick: (workspaceId) => {\n\t\t\t\t\t\t\tsetPickerOpen(false);\n\t\t\t\t\t\t\tsetPendingWorkspaceId(workspaceId === "::ungrouped" ? void 0 : workspaceId);\n\t\t\t\t\t\t\tselectWorkspace(workspaceId).catch(() => {\n\t\t\t\t\t\t\t\tsetPendingWorkspaceId((current) => current === workspaceId ? void 0 : current);\n\t\t\t\t\t\t\t});\n\t\t\t\t\t\t},'
assert s.count(old) == 1, "cv2"
s = s.replace(old, new)
open(cv, "w", encoding="utf-8").write(s)
print("conversation patched")
PY
  node --check "$WF" && node --check "$CV" && echo "✓ 无项目开始选项 OK（刷新浏览器生效）"
fi

echo "✓ 全部补丁处理完成。重启 dsh（或等待 HMR 自动重载）后生效。"
