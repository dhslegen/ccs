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

# 2. 每行 8 列
print -r -- "$out" | awk -F'\t' 'NF != 8 { exit 1 }' || fail "存在非 8 列的行"

# 3. 内容断言
print -r -- "$out" | head -1 | grep -q $'proj-a\t07-22\ttest-session-0001\t🧑\t帮我修复登录 bug\t/Users/demo/proj-a' \
  || fail "第 1 行用户消息格式不符"
print -r -- "$out" | sed -n 2p | grep -q '好的,我先看代码 然后修复' || fail "助手消息换行未压平"
print -r -- "$out" | sed -n 3p | grep -q '真实命令意图' || fail "command 标签内容未保留"

# 4. 预览行号(第 8 列):每条消息渲染为 空行+头行+文本行
#    消息1(1行文本)头行=2;消息2(2行文本)头行=3+2=5;消息3(1行文本)头行=7+2=9
offsets="$(print -r -- "$out" | cut -f8 | paste -sd, -)"
[[ "$offsets" == "2,5,9" ]] || fail "预览行号错误: 期望 2,5,9 实际 $offsets"

# 5. 噪声不应出现
for noise in "file contents noise" "内部提醒噪声" "meta 噪声" "会话摘要噪声" "Request interrupted"; do
  print -r -- "$out" | grep -q "$noise" && fail "噪声泄漏: $noise"
done

# 6. 全文入索引,不截断:构造一条 1200 字符消息,断言尾部内容可被搜到
LONG_FIXTURE="${FIXTURE:h}/long-session-0002.jsonl"
long_text="$(printf 'x%.0s' {1..1100})尾部独特关键词ZZYY"
print -r -- "{\"type\":\"user\",\"cwd\":\"/Users/demo/proj-a\",\"timestamp\":\"2026-07-22T11:00:00.000Z\",\"message\":{\"role\":\"user\",\"content\":\"$long_text\"}}" > "$LONG_FIXTURE"
./ccs --extract "$LONG_FIXTURE" | grep -q "尾部独特关键词ZZYY" || fail "超长消息被截断,尾部内容搜不到"

print "✓ 冒烟测试全部通过 (3 行 / 8 列 / 行号 / 噪声过滤 / 标签剥离 / 全文不截断)"
