#!/usr/bin/env bash
# ccs 一键安装:
#   远程: curl -fsSL https://raw.githubusercontent.com/dhslegen/ccs/main/install.sh | bash
#   本地: git clone 后在仓库目录执行 ./install.sh(软链安装,git pull 即更新)
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/dhslegen/ccs/main/ccs"

# 安装目录选择:优先已在 PATH 中的位置,减少用户手动配 PATH 的负担
# 1) CCS_BIN_DIR 显式指定 > 2) ~/.local/bin(已在 PATH) > 3) /usr/local/bin(已在 PATH) > 4) 回退 ~/.local/bin
pick_bin_dir() {
  if [ -n "${CCS_BIN_DIR:-}" ]; then echo "$CCS_BIN_DIR"; return; fi
  case ":$PATH:" in *":$HOME/.local/bin:"*) echo "$HOME/.local/bin"; return ;; esac
  case ":$PATH:" in *":/usr/local/bin:"*)   echo "/usr/local/bin";   return ;; esac
  echo "$HOME/.local/bin"
}
BIN_DIR="$(pick_bin_dir)"

# 目标目录不可写时借 sudo(如普通用户装 /usr/local/bin;家目录内永不需要)
SUDO=""
if [[ "$BIN_DIR" != "$HOME"/* ]]; then
  if { [ -d "$BIN_DIR" ] && [ ! -w "$BIN_DIR" ]; } \
     || { [ ! -d "$BIN_DIR" ] && [ ! -w "$(dirname "$BIN_DIR")" ]; }; then
    command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  fi
fi

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

# ---------- fzf 版本门禁(需 ≥ 0.40,发行版源常见老版本) ----------
fzf_version_ok() {
  fv="$(fzf --version 2>/dev/null | awk '{print $1}')"
  [ -n "$fv" ] || return 1
  fmaj="${fv%%.*}"; fmin="${fv#*.}"; fmin="${fmin%%.*}"
  [ "${fmaj:-0}" -gt 0 ] 2>/dev/null || [ "${fmin:-0}" -ge 40 ] 2>/dev/null
}

install_fzf_binary() {
  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/junegunn/fzf/releases/latest)"
  ver="${latest_url##*/v}"
  arch="$(uname -m)"
  case "$arch" in
    x86_64)         arch=amd64 ;;
    aarch64|arm64)  arch=arm64 ;;
    *) warn "未适配的架构: $arch,请手动安装新版 fzf: https://github.com/junegunn/fzf/releases"; return 1 ;;
  esac
  tmpd="$(mktemp -d)"
  curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${ver}/fzf-${ver}-linux_${arch}.tar.gz" \
    | tar -xz -C "$tmpd"
  $SUDO mkdir -p "$BIN_DIR"
  $SUDO install -m 755 "$tmpd/fzf" "$BIN_DIR/fzf"
  rm -rf "$tmpd"
  info "已安装 fzf v${ver} -> $BIN_DIR/fzf"
}

if ! fzf_version_ok; then
  cur="$(fzf --version 2>/dev/null | awk '{print $1}')"
  warn "fzf 版本过旧(${cur:-未知}),ccs 需要 ≥ 0.40(发行版源的 fzf 通常太老)"
  if [ "$(uname -s)" = "Darwin" ]; then
    warn "请执行: brew upgrade fzf"
    exit 1
  fi
  if [ -t 1 ]; then
    printf '是否从 GitHub 下载官方最新 fzf 二进制到 %s? [Y/n] ' "$BIN_DIR"
    read -r ans < /dev/tty || ans=n
    case "$ans" in
      [nN]*) warn "已跳过,请手动升级 fzf ≥ 0.40 后重试"; exit 1 ;;
    esac
    install_fzf_binary || exit 1
  else
    warn "请手动升级 fzf ≥ 0.40: https://github.com/junegunn/fzf/releases"
    exit 1
  fi
fi

# 剪贴板工具(可选,缺失只影响 Ctrl-T/Ctrl-Y 复制)
if ! command -v pbcopy >/dev/null 2>&1 && ! command -v wl-copy >/dev/null 2>&1 \
   && ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
  warn "未检测到剪贴板工具(复制功能不可用),建议安装: wl-clipboard 或 xclip($(pkg_cmd) wl-clipboard)"
fi

# ---------- 安装 ----------
$SUDO mkdir -p "$BIN_DIR"

script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$script_dir" ] && [ -f "$script_dir/ccs" ]; then
  $SUDO ln -sf "$script_dir/ccs" "$BIN_DIR/ccs"
  info "已软链: $BIN_DIR/ccs -> $script_dir/ccs(git pull 即更新)"
else
  tmp="$(mktemp)"
  curl -fsSL "$RAW_URL" -o "$tmp"
  $SUDO install -m 755 "$tmp" "$BIN_DIR/ccs"
  rm -f "$tmp"
  info "已下载安装: $BIN_DIR/ccs"
fi

# ---------- PATH 收尾 ----------
case ":$PATH:" in
  *":$BIN_DIR:"*)
    info "安装完成,直接运行: ccs"
    ;;
  *)
    # 仅回退分支会走到这里(PATH 中既无 ~/.local/bin 也无 /usr/local/bin)
    export_line="export PATH=\"$BIN_DIR:\$PATH\""
    rc=""
    case "$(basename "${SHELL:-}")" in
      zsh)  rc="$HOME/.zshrc" ;;
      bash) rc="$HOME/.bashrc" ;;
    esac
    if [ -n "$rc" ] && [ -t 1 ]; then
      printf '%s 不在 PATH 中,是否自动追加到 %s? [Y/n] ' "$BIN_DIR" "$rc"
      read -r ans < /dev/tty || ans=n
      case "$ans" in
        [nN]*)
          warn "已跳过,请手动追加: $export_line"
          ;;
        *)
          printf '\n# ccs (由 install.sh 追加)\n%s\n' "$export_line" >> "$rc"
          info "已追加到 $rc,重开终端或执行 source $rc 后运行: ccs"
          ;;
      esac
    else
      warn "$BIN_DIR 不在 PATH 中,请在 shell 配置中追加: $export_line"
    fi
    ;;
esac
