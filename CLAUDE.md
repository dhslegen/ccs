# ccs — Claude Code Session Search

## 定位

单文件 zsh CLI:按关键词实时搜索 Claude Code 历史会话(`~/.claude/projects/**/*.jsonl`),
fzf 选择后 `claude --resume` 恢复。详细用法与原理见 README.md。

## 怎么跑

```bash
./ccs                # 主交互(需真实终端)
./ccs --grep <词>    # 非交互搜索,调试用
./ccs --rebuild      # 全量重建索引
./tests/smoke.sh     # 冒烟测试,改动 jq 抽取逻辑后必跑
```

## 技术栈与结构

- 纯 zsh + jq + ripgrep + fzf + awk,无包管理器、无构建
- `ccs` — 全部逻辑(jq 程序、索引器、fzf 交互都在这一个文件)
- `tests/smoke.sh` — 用 fixture jsonl 断言抽取行为
- 索引缓存在 `~/.cache/ccs/index/`,每会话一个 8 列 TSV 分片

## 关键约定(改代码前必读)

- **索引列结构或过滤规则变化时,必须递增脚本内 `INDEX_FORMAT`**,否则旧分片不会重建
- 索引与预览共用 `JQ_COMMON` 过滤;`JQ_PREVIEW_PLAIN` 与彩色版行结构必须保持一致(行号互用)
- 搜索语义:只匹配可见列(1/2/4/5),按 项目+角色+文本 去重;分隔行以第 3 列为空标记
- 会话的项目名/恢复目录取**最后一个**非空 cwd(`/cd` 会搬移会话文件)
- subagents/*.jsonl 是子代理侧链,故意不索引

## 当前状态(2026-07-22)

功能完整可用,已安装(软链 `~/.local/bin/ccs`)。潜在改进:折行导致的
预览定位微偏、Linux 剪贴板适配。
