#!/usr/bin/env bash
# dsh-patch-reasoning.sh — 重新应用 DSH「模型调优」补丁（dsh 更新后运行一次即可）。
#
# 1) DeepSeek 推理强度拓宽：off/high/max  ->  off/minimal/low/medium/high/xhigh/max
#    （API 实测接受全部值，档位限制只是适配器代码写死的。）
# 2) workflow 子 agent 默认用 deepseek-v4-flash（脚本显式指定 model 仍优先）。
# 3) ralph worker 默认用 deepseek-v4-flash（RALPH_SCRIPT 为部署固定，只能打补丁）。
#
# 每个补丁独立幂等：目标文件已带标记则跳过，未带则应用。
# 用法：bash ~/.dsh/bin/dsh-patch-reasoning.sh
#
# 自定义/第三方模型（OpenAI 兼容）推理强度说明：pi-ai 适配器原生支持 7 档，无需补丁，
# 在模型配置里声明 reasoningEfforts 即可，例如：
#   providers:
#     acme-gateway:
#       apiKeyEnv: ACME_API_KEY
#       baseURL: https://gateway.example/v1
#       api: openai-completions
#       models:
#         - id: acme-large
#           reasoningEfforts:
#             off:
#             minimal: minimal
#             low: low
#             medium: medium
#             high: high
#             xhigh: xhigh
#             max: max
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
# 1) DeepSeek 推理强度拓宽
# ---------------------------------------------------------------------------
FILE="$BASE/dsh-llm-deepseek/lib/index.js"
if [ ! -f "$FILE" ]; then
  echo "✗ 未找到 dsh-llm-deepseek: $FILE" >&2
elif grep -q "DSH_REASONING_WIDEN_PATCH" "$FILE"; then
  echo "✓ 跳过(已应用): ${FILE##*/} 推理强度拓宽"
else
  echo "→ 应用 推理强度拓宽 ..."
  "$PY" - "$FILE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
n = 0
old1 = '\tif (effort === "off" || effort === "high" || effort === "max") return effort;'
new1 = '\t// DSH_REASONING_WIDEN_PATCH: widened effort set\n\tif (effort === "off" || effort === "minimal" || effort === "low" || effort === "medium" || effort === "high" || effort === "xhigh" || effort === "max") return effort;'
assert s.count(old1) == 1, "r1"
s = s.replace(old1, new1); n += 1
old2 = '\tif (effort === "high" || effort === "max") return {'
new2 = '\tif (effort !== void 0) return {'
assert s.count(old2) == 1, "r2"
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
\t\tid: ReasoningEffortId("minimal"),
\t\tname: "Minimal"
\t},
\t{
\t\tid: ReasoningEffortId("low"),
\t\tname: "Low"
\t},
\t{
\t\tid: ReasoningEffortId("medium"),
\t\tname: "Medium"
\t},
\t{
\t\tid: HIGH_REASONING_EFFORT,
\t\tname: "High"
\t},
\t{
\t\tid: ReasoningEffortId("xhigh"),
\t\tname: "XHigh"
\t},
\t{
\t\tid: MAX_REASONING_EFFORT,
\t\tname: "Max"
\t}
];'''
assert s.count(old3) == 1, "r3"
s = s.replace(old3, new3); n += 1
old4 = '''\treasoningEffort: z.union([
\t\t"off",
\t\t"high",
\t\t"max"
\t]),'''
new4 = '''\treasoningEffort: z.union([
\t\t"off",
\t\t"minimal",
\t\t"low",
\t\t"medium",
\t\t"high",
\t\t"xhigh",
\t\t"max"
\t]),'''
assert s.count(old4) == 1, "r4"
s = s.replace(old4, new4); n += 1
old5 = '\t\t\t\tdefaultEffort: connection.defaults.reasoningEffort === "off" ? OFF_REASONING_EFFORT : connection.defaults.reasoningEffort === "max" ? MAX_REASONING_EFFORT : HIGH_REASONING_EFFORT'
new5 = '\t\t\t\tdefaultEffort: ({ off: OFF_REASONING_EFFORT, minimal: ReasoningEffortId("minimal"), low: ReasoningEffortId("low"), medium: ReasoningEffortId("medium"), high: HIGH_REASONING_EFFORT, xhigh: ReasoningEffortId("xhigh"), max: MAX_REASONING_EFFORT })[connection.defaults.reasoningEffort] ?? HIGH_REASONING_EFFORT'
assert s.count(old5) == 1, "r5"
s = s.replace(old5, new5); n += 1
open(p, "w", encoding="utf-8").write(s)
print("applied %d/5 replacements" % n)
PY
  node --check "$FILE" && echo "✓ 推理强度拓宽 OK"
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
