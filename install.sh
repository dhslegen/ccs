#!/usr/bin/env bash
# ccs 一键安装:
#   远程: curl -fsSL https://raw.githubusercontent.com/dhslegen/ccs/main/install.sh | bash
#   本地: git clone 后在仓库目录执行 ./install.sh(软链安装,git pull 即更新)
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/dhslegen/ccs/main/ccs"
BIN_DIR="${CCS_BIN_DIR:-$HOME/.local/bin}"

info() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }

# ---------- 依赖检测与自动安装 ----------
# 返回本机包管理器的安装命令前缀;无已知包管理器时返回空
pkg_cmd() {
  if command -v brew >/dev/null 2>&1;      then echo "brew install"
  elif command -v apt-get >/dev/null 2>&1; then echo "sudo apt install -y"
  elif command -v dnf >/dev/null 2>&1;     then echo "sudo dnf install -y"
  elif command -v pacman >/dev/null 2>&1;  then echo "sudo pacman -S --noconfirm"
  fi
}

check_missing() {
  missing=()
  for dep in zsh fzf jq; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  command -v rg >/dev/null 2>&1 || missing+=("ripgrep")
}

check_missing
if [ "${#missing[@]}" -gt 0 ]; then
  pm="$(pkg_cmd)"
  if [ -z "$pm" ]; then
    warn "缺少依赖: ${missing[*]},请用你的包管理器安装后重试"
    exit 1
  fi
  warn "缺少依赖: ${missing[*]}"
  # curl | bash 时 stdin 是脚本管道,交互必须读 /dev/tty;无终端(CI)则只提示
  if [ -t 1 ]; then
    printf '是否现在执行「%s %s」自动安装? [Y/n] ' "$pm" "${missing[*]}"
    read -r ans < /dev/tty || ans=n
    case "$ans" in
      [nN]*) warn "已跳过,先执行: $pm ${missing[*]}"; exit 1 ;;
    esac
    $pm "${missing[@]}"
    check_missing
    if [ "${#missing[@]}" -gt 0 ]; then
      warn "自动安装后仍缺少: ${missing[*]},请手动处理后重试"
      exit 1
    fi
  else
    warn "先执行: $pm ${missing[*]}"
    exit 1
  fi
fi
info "依赖齐全: zsh / fzf / rg / jq"

# 剪贴板工具(可选,缺失只影响 Ctrl-T/Ctrl-Y 复制)
if ! command -v pbcopy >/dev/null 2>&1 && ! command -v wl-copy >/dev/null 2>&1 \
   && ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
  warn "未检测到剪贴板工具(复制功能不可用),建议安装: $(pkg_hint wl-clipboard) 或 xclip"
fi

# ---------- 安装 ----------
mkdir -p "$BIN_DIR"

script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$script_dir" ] && [ -f "$script_dir/ccs" ]; then
  ln -sf "$script_dir/ccs" "$BIN_DIR/ccs"
  info "已软链: $BIN_DIR/ccs -> $script_dir/ccs(git pull 即更新)"
else
  curl -fsSL "$RAW_URL" -o "$BIN_DIR/ccs"
  chmod +x "$BIN_DIR/ccs"
  info "已下载安装: $BIN_DIR/ccs"
fi

# ---------- PATH 检查 ----------
case ":$PATH:" in
  *":$BIN_DIR:"*) info "安装完成,直接运行: ccs" ;;
  *)
    warn "$BIN_DIR 不在 PATH 中,请在 shell 配置(~/.zshrc 等)中追加:"
    printf '    export PATH="%s:$PATH"\n' "$BIN_DIR"
    ;;
esac
