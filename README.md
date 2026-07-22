# ccs — Claude Code Session Search

按关键词实时搜索 Claude Code 历史会话,fzf 交互选择后一键恢复(`claude --resume`)。

## 特性

- **实时搜索**:fzf 内边打字边搜,多个关键词为 AND 关系,中文友好
- **高性能**:启动时增量抽取纯文本索引(mtime 比对,无变化时约 30ms),每次按键只 rg 扫几 MB 索引
- **只搜对话**:仅索引你和 Claude 的消息文本,过滤工具输出、system-reminder、hook 等噪声
- **预览**:右侧实时渲染完整会话对话轮次,关键词高亮
- **零新依赖**:只用 fzf(≥0.40)、ripgrep、jq

## 安装

```bash
ln -s ~/Developer/Personal/ccs/ccs ~/.local/bin/ccs
```

(确保 `~/.local/bin` 在 `PATH` 中)

## 用法

```bash
ccs [关键词...]   # 实时搜索全部会话(按时间倒序)
ccs -p [关键词]   # 限定当前所在项目
ccs --rebuild     # 强制全量重建索引
ccs --update      # 仅增量更新索引(可挂 cron)
```

搜索框内直接敲项目名即可缩小到某项目(项目名就在每行行首,参与匹配)。

### 键位

| 键 | 动作 |
|---|---|
| `⏎` | cd 到项目目录并 `claude --resume` 该会话 |
| `Ctrl-O` | 全屏查看完整会话 |
| `Ctrl-Y` | 复制 sessionId 到剪贴板 |
| `Ctrl-P` | 把当前项目名追加进搜索词 |
| `Esc` | 退出 |

## 工作原理

```
~/.claude/projects/<项目>/<sessionId>.jsonl      (数据源,仅主会话,排除 subagents)
        │ 启动时增量抽取(jq,只处理 mtime 变化的文件)
        ▼
~/.cache/ccs/index/<项目>%<sessionId>.tsv        (纯文本索引分片,继承源文件 mtime)
        │ fzf --disabled + change:reload(rg 多词 AND 过滤)
        ▼
实时列表 + 右侧预览 → ⏎ cd 项目 && claude --resume
```

索引行格式(TAB 分隔):`项目名 日期 sessionId 角色 消息文本 cwd 源文件路径`,
fzf 只展示前 4 列可见信息,后 3 列供动作使用。

## 测试

```bash
./tests/smoke.sh
```
