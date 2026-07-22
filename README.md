# ccs — Claude Code Session Search

按关键词实时搜索 Claude Code 历史会话,fzf 交互选择后一键恢复(`claude --resume`)。

## 特性

- **实时搜索**:fzf 内边打字边搜,多个关键词为 AND 关系,中文友好
- **高性能**:启动时增量抽取纯文本索引(mtime 比对,无变化时约 30ms),每次按键只 rg 扫几 MB 索引
- **只搜对话**:仅索引你和 Claude 的消息文本,过滤工具输出、system-reminder、hook 等噪声
- **预览**:右侧实时渲染完整会话对话轮次,关键词高亮
- **零新依赖**:只用 fzf(≥0.40)、ripgrep、jq

> 运行环境:macOS + zsh(复制功能用 pbcopy;Linux 可自行替换为 xclip/wl-copy)

## 安装

```bash
ln -s ~/Developer/Personal/ccs/ccs ~/.local/bin/ccs
```

(确保 `~/.local/bin` 在 `PATH` 中)

## 用法

```bash
ccs [关键词...]   # 实时搜索全部会话
ccs -p [关键词]   # 限定当前所在项目
ccs --rebuild     # 强制全量重建索引
ccs --update      # 仅增量更新索引(可挂 cron)
```

列表顺序(fzf 自底向上增长,越新越靠底部、紧贴光标):
- 项目分组不穿插,按最近活跃度排序,最新项目在最底部
- 项目内会话按时间排序,会话之间有分割线(分割线不可选中,搜索时自动隐藏)
- 会话内消息同样越新越靠底,整个列表自底向上就是完整时间线
- 每个会话的项目名/恢复目录统一取该会话**最后的 cwd**(`/cd` 会让 Claude Code
  把会话文件搬到新项目目录,恢复会话必须去最终 cwd)

搜索框内直接敲项目名即可缩小到某项目(项目名就在每行行首,参与匹配)。

搜索语义:
- 只在**可见列**(项目名/日期/角色/消息文本)内匹配,sessionId、文件路径等隐藏列不参与,不会产生"看不到关键词的假命中"
- 相同 项目+角色+文本 的消息**去重保留最新**(`claude --resume` 会把历史复制进新会话文件,同一消息会存在于多个文件)
- 英文忽略大小写,多个关键词为 AND 关系

### 键位

| 键 | 动作 |
|---|---|
| `⏎` | cd 到项目目录并 `claude --resume` 该会话 |
| `Ctrl-O` | 全屏查看完整会话 |
| `Ctrl-F` | 预览窗口全屏/还原切换(方便鼠标选取预览文本) |
| `Ctrl-T` | 复制完整会话纯文本到剪贴板 |
| `Ctrl-Y` | 复制 sessionId 到剪贴板 |
| `Ctrl-P` | 把当前项目名追加进搜索词 |
| `Esc` | 退出 |

## 工作原理

```
~/.claude/projects/<项目>/<sessionId>.jsonl      (数据源,仅主会话,排除 subagents)
        │ 启动时增量抽取(jq,只处理 mtime 变化的文件)
        ▼
~/.cache/ccs/index/<项目>%<sessionId>.tsv        (纯文本索引分片,继承源文件 mtime)
        │ fzf --disabled + change:reload(rg 粗筛 → awk 精筛:可见列 AND + 去重)
        ▼
实时列表 + 右侧预览 → ⏎ cd 项目 && claude --resume
```

索引行格式(TAB 分隔):`项目名 日期 sessionId 角色 消息全文 cwd 源文件路径 预览行号`,
fzf 只展示前 4 列可见信息,后 4 列供动作使用:第 8 列是该消息在渲染后预览中的行号
(索引时用 jq foreach 跨消息累加算出),`--preview-window '+{8}'` 据此把选中消息
锚定到预览窗口顶部——选中同一会话的不同消息,预览会分别跳到各自位置。

消息全文入索引、不截断,保证从预览里看到的任何一句话都能搜到;
索引格式版本变化时(`.format` 文件)自动全量重建。

## 测试

```bash
./tests/smoke.sh
```
