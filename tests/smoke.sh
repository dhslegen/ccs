#!/usr/bin/env zsh
# ccs 冒烟测试:用固定样例 jsonl 验证抽取逻辑(TSV 格式、噪声过滤、标签剥离)
set -euo pipefail
cd "${0:A:h}/.."

FIXTURE="$(mktemp -d)/test-session-0001.jsonl"
trap 'rm -rf "${FIXTURE:h}"' EXIT

cat > "$FIXTURE" <<'EOF'
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:00:00.000Z","message":{"role":"user","content":"帮我修复登录 bug"}}
{"type":"assistant","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"好的,我先看代码\n然后修复"},{"type":"tool_use","id":"x","name":"Read","input":{}}]}}
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:01:00.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","content":"file contents noise"}]}}
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:02:00.000Z","message":{"role":"user","content":[{"type":"text","text":"<system-reminder>内部提醒噪声</system-reminder>"}]}}
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:03:00.000Z","isMeta":true,"message":{"role":"user","content":"meta 噪声"}}
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:04:00.000Z","message":{"role":"user","content":[{"type":"text","text":"<command-message>foo</command-message><command-args>真实命令意图</command-args>"}]}}
{"type":"summary","summary":"会话摘要噪声"}
{"type":"user","cwd":"/Users/demo/proj-a","timestamp":"2026-07-22T10:05:00.000Z","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
EOF

out="$(./ccs --extract "$FIXTURE")"
lines=$(print -r -- "$out" | wc -l | tr -d ' ')

fail() { print -u2 "✗ $1"; print -u2 "--- 实际输出 ---"; print -u2 -r -- "$out"; exit 1 }

# 1. 应恰好 3 行:用户提问、助手回复、剥标签后的命令意图
[[ "$lines" == "3" ]] || fail "期望 3 行,实际 $lines 行"

# 2. 每行 7 列
print -r -- "$out" | awk -F'\t' 'NF != 7 { exit 1 }' || fail "存在非 7 列的行"

# 3. 内容断言
print -r -- "$out" | head -1 | grep -q $'proj-a\t07-22\ttest-session-0001\t🧑\t帮我修复登录 bug\t/Users/demo/proj-a' \
  || fail "第 1 行用户消息格式不符"
print -r -- "$out" | sed -n 2p | grep -q '好的,我先看代码 然后修复' || fail "助手消息换行未压平"
print -r -- "$out" | sed -n 3p | grep -q '真实命令意图' || fail "command 标签内容未保留"

# 4. 噪声不应出现
for noise in "file contents noise" "内部提醒噪声" "meta 噪声" "会话摘要噪声" "Request interrupted"; do
  print -r -- "$out" | grep -q "$noise" && fail "噪声泄漏: $noise"
done

print "✓ 冒烟测试全部通过 (3 行 / 7 列 / 噪声过滤 / 标签剥离)"
