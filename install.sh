#!/usr/bin/env bash
# ~/.local にユーザー権限だけで以下を導入/更新:
# - CLI: rg(fd), fd, fzf, lazygit
# - uv（Python管理/超高速pip）, uvでPython本体, Neovim用pynvim（専用venv）
# - nvm（~/.local/nvm）で Node & npm、Neovim用の npm 'neovim'
# 既にあるものはスキップ（FORCE=1で上書き）。失敗しても続行。

# ===== 設定（環境変数で上書き可）=====
: "${APPS_DIR:=$HOME/.local/apps}"
: "${BIN_DIR:=$HOME/.local/bin}"
: "${FORCE:=0}"                                # 1=ローカル再インストールを強制
: "${SKIP_IF_ANY:=0}"                          # 1=PATH上にあればローカル導入をスキップ
: "${PY_VER:=3.12}"                            # uvで入れるPythonの系（例: 3.12 / 3.13 / 'latest'）
: "${VENV_DIR:=$HOME/.local/apps/nvim-python}" # Neovim用Python venv
: "${INSTALL_NODE_EXTRA:=0}"# 1=tree-sitter-cli 等を追加
: "${NVM_DIR:=$HOME/.local/nvm}"
: "${NODE_VERSION:=lts/*}" # 例: lts/*, 22, 20 など
: "${SET_PYTHON_DEFAULT:=0}"# 1=~/.local/bin に python/python3 リンクも作成
: "${HEREROCKS_DIR:=$HOME/.local/share/nvim/lazy-rocks/hererocks}" # Lazy の既定パス
: "${HEREROCKS_LUA:=5.1}"                                          # Lazyのcheckhealthが5.1を期待しているので既定は5.1

CURL_OPTS="-fL --retry 3 --retry-delay 1 --connect-timeout 15 -s"

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_dirs() {
  mkdir -p "$APPS_DIR" "$BIN_DIR" || {
    err "mkdir failed"
    exit 1
  }
  # PATH 追記
  local line='export PATH="$HOME/.local/bin:$PATH"'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || touch "$rc"
    grep -Fq "$line" "$rc" || echo "$line" >>"$rc"
  done
}

arch() {
  case "$(uname -m)" in
  x86_64 | amd64) echo x86_64 ;;
  aarch64 | arm64) echo arm64 ;;
  *)
    err "unsupported arch: $(uname -m)"
    exit 1
    ;;
  esac
}

dl() { # $1 url  $2 out
  if have curl; then
    # shellcheck disable=SC2086
    curl $CURL_OPTS -o "$2" "$1"
  elif have wget; then
    wget -q -O "$2" "$1"
  else
    return 1
  fi
}

latest_asset_api() { # $1 owner/repo  $2 regex
  curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$1/releases/latest" |
    grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' |
    sed -E 's/.*"browser_download_url":[[:space:]]*"([^"]+)".*/\1/' |
    grep -E "$2" | head -n1
}
latest_asset_html() { # APIがだめな時
  curl -fsSL "https://github.com/$1/releases/latest" |
    grep -oE '/[^"]+/releases/download/[^"]+' |
    sed -E 's#^#https://github.com#' |
    grep -E "$2" | head -n1
}
latest_asset() {
  local u
  u="$(latest_asset_api "$1" "$2" || true)"
  [ -n "$u" ] || u="$(latest_asset_html "$1" "$2" || true)"
  echo -n "$u"
}

xz_or_tar() { tar -xzf "$1" -C "$2"; }

link_bin() { ln -sf "$1" "$BIN_DIR/$2" && info "link: $BIN_DIR/$2 -> $1"; }
already_local() { [ -x "$BIN_DIR/$1" ] || [ -L "$BIN_DIR/$1" ]; }
already_any() { command -v "$1" >/dev/null 2>&1; }

# ===== CLIツール =====
install_rg() {
  local name=rg repo=BurntSushi/ripgrep a url tmp tdir binpath
  a="$(arch)"
  [ "$SKIP_IF_ANY" = "1" ] && already_any "$name" && {
    info "rg exists ($(command -v rg)); skip"
    return 0
  }
  [ "$FORCE" != "1" ] && already_local "$name" && {
    info "rg already in ~/.local; skip"
    return 0
  }
  case "$a" in
  x86_64) url="$(latest_asset "$repo" 'ripgrep-.*-x86_64-unknown-linux-(musl|gnu)\.tar\.gz')" ;;
  arm64) url="$(latest_asset "$repo" 'ripgrep-.*-aarch64-unknown-linux-(musl|gnu)\.tar\.gz')" ;;
  esac
  [ -n "$url" ] || {
    err "rg asset not found"
    return 1
  }
  tmp="$(mktemp -d)"
  tdir="$APPS_DIR/rg"
  mkdir -p "$tdir"
  info "download rg: $url"
  dl "$url" "$tmp/pkg.tar.gz" || {
    err "rg dl failed"
    rm -rf "$tmp"
    return 1
  }
  xz_or_tar "$tmp/pkg.tar.gz" "$tmp" || {
    err "rg extract failed"
    rm -rf "$tmp"
    return 1
  }
  binpath="$(find "$tmp" -type f -name rg -perm -111 | head -n1)"
  [ -n "$binpath" ] || {
    err "rg binary not found"
    rm -rf "$tmp"
    return 1
  }
  cp "$binpath" "$tdir/rg" && chmod 0755 "$tdir/rg"
  link_bin "$tdir/rg" rg
  rm -rf "$tmp"
}

install_fd() {
  local name=fd repo=sharkdp/fd a url tmp tdir binpath
  a="$(arch)"
  [ "$SKIP_IF_ANY" = "1" ] && already_any "$name" && {
    info "fd exists ($(command -v fd 2>/dev/null || echo fd-find)); skip"
    return 0
  }
  [ "$FORCE" != "1" ] && already_local "$name" && {
    info "fd already in ~/.local; skip"
    return 0
  }
  case "$a" in
  x86_64) url="$(latest_asset "$repo" 'fd-.*-x86_64-unknown-linux-(musl|gnu)\.tar\.gz')" ;;
  arm64) url="$(latest_asset "$repo" 'fd-.*-aarch64-unknown-linux-(musl|gnu)\.tar\.gz')" ;;
  esac
  [ -n "$url" ] || {
    err "fd asset not found"
    return 1
  }
  tmp="$(mktemp -d)"
  tdir="$APPS_DIR/fd"
  mkdir -p "$tdir"
  info "download fd: $url"
  dl "$url" "$tmp/pkg.tar.gz" || {
    err "fd dl failed"
    rm -rf "$tmp"
    return 1
  }
  xz_or_tar "$tmp/pkg.tar.gz" "$tmp" || {
    err "fd extract failed"
    rm -rf "$tmp"
    return 1
  }
  binpath="$(find "$tmp" -type f -name fd -perm -111 | head -n1)"
  [ -n "$binpath" ] || {
    err "fd binary not found"
    rm -rf "$tmp"
    return 1
  }
  cp "$binpath" "$tdir/fd" && chmod 0755 "$tdir/fd"
  link_bin "$tdir/fd" fd
  rm -rf "$tmp"
}

install_fzf() {
  local name=fzf repo=junegunn/fzf a url tmp tdir binpath
  a="$(arch)"
  [ "$SKIP_IF_ANY" = "1" ] && already_any "$name" && {
    info "fzf exists ($(command -v fzf)); skip"
    return 0
  }
  [ "$FORCE" != "1" ] && already_local "$name" && {
    info "fzf already in ~/.local; skip"
    return 0
  }
  case "$a" in
  x86_64) url="$(latest_asset "$repo" 'fzf-.*-linux_amd64\.tar\.gz')" ;;
  arm64) url="$(latest_asset "$repo" 'fzf-.*-linux_arm64\.tar\.gz')" ;;
  esac
  [ -n "$url" ] || {
    err "fzf asset not found"
    return 1
  }
  tmp="$(mktemp -d)"
  tdir="$APPS_DIR/fzf"
  mkdir -p "$tdir"
  info "download fzf: $url"
  dl "$url" "$tmp/pkg.tar.gz" || {
    err "fzf dl failed"
    rm -rf "$tmp"
    return 1
  }
  xz_or_tar "$tmp/pkg.tar.gz" "$tmp" || {
    err "fzf extract failed"
    rm -rf "$tmp"
    return 1
  }
  binpath="$(find "$tmp" -maxdepth 2 -type f -name fzf -perm -111 | head -n1)"
  [ -n "$binpath" ] || {
    err "fzf binary not found"
    rm -rf "$tmp"
    return 1
  }
  cp "$binpath" "$tdir/fzf" && chmod 0755 "$tdir/fzf"
  link_bin "$tdir/fzf" fzf
  rm -rf "$tmp"
}

install_lazygit() {
  local name=lazygit repo=jesseduffield/lazygit a url tmp tdir binpath
  a="$(arch)"
  [ "$SKIP_IF_ANY" = "1" ] && already_any "$name" && {
    info "lazygit exists ($(command -v lazygit)); skip"
    return 0
  }
  [ "$FORCE" != "1" ] && already_local "$name" && {
    info "lazygit already in ~/.local; skip"
    return 0
  }
  case "$a" in
  x86_64) url="$(latest_asset "$repo" 'lazygit_.*_Linux_x86_64\.tar\.gz')" ;;
  arm64) url="$(latest_asset "$repo" 'lazygit_.*_Linux_arm64\.tar\.gz')" ;;
  esac
  [ -n "$url" ] || {
    err "lazygit asset not found"
    return 1
  }
  tmp="$(mktemp -d)"
  tdir="$APPS_DIR/lazygit"
  mkdir -p "$tdir"
  info "download lazygit: $url"
  dl "$url" "$tmp/pkg.tar.gz" || {
    err "lazygit dl failed"
    rm -rf "$tmp"
    return 1
  }
  xz_or_tar "$tmp/pkg.tar.gz" "$tmp" || {
    err "lazygit extract failed"
    rm -rf "$tmp"
    return 1
  }
  binpath="$(find "$tmp" -type f -name lazygit -perm -111 | head -n1)"
  [ -n "$binpath" ] || {
    err "lazygit binary not found"
    rm -rf "$tmp"
    return 1
  }
  cp "$binpath" "$tdir/lazygit" && chmod 0755 "$tdir/lazygit"
  link_bin "$tdir/lazygit" lazygit
  rm -rf "$tmp"
}

# ===== uv & Python（~/.local に固定）=====
install_uv() {
  if have uv; then
    info "uv: $(command -v uv)"
    return 0
  fi
  info "install uv -> $BIN_DIR"
  # uv の標準インストーラ。UV_INSTALL_DIR で ~/.local/bin 明示可
  curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="$BIN_DIR" sh || {
    err "uv install failed"
    return 1
  }
}

install_python_with_uv() {
  # uv 管理のPythonを ~/.local に配置し、必要なら python/python3 もリンク
  : "${UV_PY_DIR:=$HOME/.local/uv/python}"
  export UV_PYTHON_INSTALL_DIR="$UV_PY_DIR"
  export UV_PYTHON_BIN_DIR="$BIN_DIR"
  export UV_PYTHON_INSTALL_BIN=1

  # 既に該当系が入ってる？
  if uv python list --only-installed | grep -q "cpython-$PY_VER"; then
    info "uv Python $PY_VER already installed"
  else
    info "install Python $PY_VER via uv"
    if [ "$SET_PYTHON_DEFAULT" = "1" ]; then
      uv python install "$PY_VER" --default || warn "uv python --default failed (continue)"
    else
      uv python install "$PY_VER" || warn "uv python install failed (continue)"
    fi
  fi
}

# ===== Neovim Python provider用 venv =====
install_pynvim_venv() {
  local py="$VENV_DIR/bin/python"
  if [ -x "$py" ] && "$py" - <<'PY' >/dev/null 2>&1; then
import sys
import importlib; importlib.import_module("pynvim")
PY
    info "pynvim venv exists ($VENV_DIR)"
    return 0
  fi

  info "create venv for Neovim: $VENV_DIR (Python $PY_VER)"
  uv venv --python "$PY_VER" --seed "$VENV_DIR" || {
    err "uv venv failed"
    return 1
  }
  info "install pynvim into venv"
  uv pip install --python "$py" -U pynvim || warn "pynvim install failed (continue)"

  # 便利用のシンボリック。必要に応じて init.lua で `vim.g.python3_host_prog` に指定可
  ln -sf "$py" "$BIN_DIR/nvim-python"
}

# ===== nvm & Node（~/.local/nvm に固定）=====
ensure_nvm_rc_lines() {
  local line1='export NVM_DIR="$HOME/.local/nvm"'
  local line2='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  local line3='[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || touch "$rc"
    grep -Fq "$line1" "$rc" || echo "$line1" >>"$rc"
    grep -Fq "$line2" "$rc" || echo "$line2" >>"$rc"
    grep -Fq "$line3" "$rc" || echo "$line3" >>"$rc"
  done
}

install_nvm_and_node() {
  # 事前にディレクトリを必ず作る（これがないと失敗する環境がある）
  mkdir -p "$NVM_DIR"

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "install nvm to $NVM_DIR"
    export NVM_DIR
    if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
      warn "nvm official installer failed; trying git clone fallback"
      if command -v git >/dev/null 2>&1; then
        git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR" || {
          err "git clone nvm failed"
          return 1
        }
        (cd "$NVM_DIR" && git checkout v0.40.1) || {
          err "nvm checkout failed"
          return 1
        }
      else
        err "git not found and installer failed"
        return 1
      fi
    fi
  else
    info "nvm already at $NVM_DIR"
  fi

  # シェル起動時にロードされるようにrcへ追記
  ensure_nvm_rc_lines

  # このシェルでも即使えるように読み込む
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh" || {
    err "cannot source nvm.sh"
    return 1
  }

  info "install/use Node: $NODE_VERSION"
  nvm install "$NODE_VERSION" || warn "nvm install failed (continue)"
  nvm alias default "$NODE_VERSION" >/dev/null 2>&1 || true
  nvm use default >/dev/null 2>&1 || true

  # 非対話シェルでも使えるよう、デフォルトNodeの実体にリンクを作る
  if command -v node >/dev/null 2>&1; then
    nodebin="$(command -v node)"
    nodedir="$(dirname "$nodebin")"
    link_bin "$nodedir/node" node
    [ -x "$nodedir/npm" ] && link_bin "$nodedir/npm" npm
    [ -x "$nodedir/npx" ] && link_bin "$nodedir/npx" npx
  fi

  # Neovim Node provider
  if npm -g ls neovim --depth=0 >/dev/null 2>&1; then
    info "npm(neovim) already installed"
  else
    info "npm i -g neovim"
    npm i -g neovim >/dev/null 2>&1 || warn "npm neovim failed (continue)"
  fi

  # （任意）追加ツール
  if [ "$INSTALL_NODE_EXTRA" = "1" ]; then
    npm -g ls tree-sitter-cli --depth=0 >/dev/null 2>&1 ||
      npm i -g tree-sitter-cli >/dev/null 2>&1 ||
      warn "npm tree-sitter-cli failed (continue)"
  fi
}

ensure_rc_line() {
  local line="$1"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || touch "$rc"
    grep -Fq "$line" "$rc" || echo "$line" >>"$rc"
  done
}

have_build_tools() {
  # hererocks は Lua/LuaRocks をソースからビルドします
  # gcc/make/unzip が無い環境では失敗するため事前チェック
  command -v gcc >/dev/null 2>&1 &&
    command -v make >/dev/null 2>&1 &&
    command -v unzip >/dev/null 2>&1
}

install_luarocks_hererocks() {
  # 既にOKならスキップ
  if [ -x "$HEREROCKS_DIR/bin/luarocks" ] && "$HEREROCKS_DIR/bin/luarocks" --version >/dev/null 2>&1; then
    info "luarocks (hererocks) already installed at: $HEREROCKS_DIR"
    return 0
  fi

  # ビルド道具チェック
  need_tools=""
  for t in gcc make tar; do command -v "$t" >/dev/null 2>&1 || need_tools="$need_tools $t"; done
  if [ -n "$need_tools" ]; then
    warn "missing build tools:$need_tools  → luarocks/hererocks をスキップします"
    return 0
  fi

  # venv 確保（pynvim で作成済みならそれを使う）
  if [ ! -x "$VENV_DIR/bin/python" ]; then
    info "create venv for Neovim (fallback): $VENV_DIR"
    uv venv --python "$PY_VER" --seed "$VENV_DIR" || {
      err "uv venv failed"
      return 1
    }
  fi

  # ① まずは LuaJIT 2.1（readline不要）で hererocks を試す
  info "try hererocks (LuaJIT 2.1 + LuaRocks) → $HEREROCKS_DIR"
  if "$VENV_DIR/bin/python" - <<'PY'; then
import sys, subprocess, os
venv=os.environ["VENV_DIR"]
dst=os.environ["HEREROCKS_DIR"]
hererocks=os.path.join(venv,"bin","hererocks")
cmd=[hererocks,dst,"-l","luajit-2.1","-r","latest"]
sys.exit(subprocess.call(cmd))
PY
    # パス類の設定
    "$HEREROCKS_DIR/bin/luarocks" path >"$HEREROCKS_DIR/luarocks_path.sh" 2>/dev/null || true
    [ -x "$HEREROCKS_DIR/bin/luarocks" ] && ln -sf "$HEREROCKS_DIR/bin/luarocks" "$BIN_DIR/luarocks"
    [ -x "$HEREROCKS_DIR/bin/luajit" ] && ln -sf "$HEREROCKS_DIR/bin/luajit" "$BIN_DIR/luajit"
    ensure_rc_line "[ -f \"$HEREROCKS_DIR/luarocks_path.sh\" ] && . \"$HEREROCKS_DIR/luarocks_path.sh\""
    ensure_rc_line "export PATH=\"$HEREROCKS_DIR/bin:\$PATH\""
    info "luarocks ready (LuaJIT): $("$HEREROCKS_DIR/bin/luarocks" --version | head -n1)"
    return 0
  else
    warn "hererocks (LuaJIT) failed; falling back to manual Lua 5.1 build without readline"
  fi

  # ② Lua 5.1 を readline無しで手動ビルドし、LuaRocks を紐づけ
  tmp="$(mktemp -d)"
  cleanup() { rm -rf "$tmp"; }
  trap cleanup EXIT

  LUA_URL="https://www.lua.org/ftp/lua-5.1.5.tar.gz"
  LR_URL="$(latest_asset 'luarocks/luarocks' 'luarocks-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz')"
  [ -n "$LR_URL" ] || LR_URL="https://luarocks.github.io/luarocks/releases/luarocks-3.11.1.tar.gz"

  info "download Lua 5.1.5 ..."
  dl "$LUA_URL" "$tmp/lua.tar.gz" || {
    err "download lua failed"
    return 1
  }
  mkdir -p "$tmp/lua" && tar -xzf "$tmp/lua.tar.gz" -C "$tmp/lua" || {
    err "extract lua failed"
    return 1
  }

  # make posix = -DLUA_USE_POSIX -DLUA_USE_DLOPEN（readline を有効にしない）
  info "build Lua 5.1.5 (no readline) → $HEREROCKS_DIR"
  (cd "$tmp/lua/lua-5.1.5" && make posix MYCFLAGS="-fPIC") || {
    err "make lua failed"
    return 1
  }
  mkdir -p "$HEREROCKS_DIR"
  (cd "$tmp/lua/lua-5.1.5" && make install INSTALL_TOP="$HEREROCKS_DIR") || {
    err "make install lua failed"
    return 1
  }

  # LuaRocks
  info "download LuaRocks ..."
  dl "$LR_URL" "$tmp/luarocks.tar.gz" || {
    err "download luarocks failed"
    return 1
  }
  mkdir -p "$tmp/luarocks" && tar -xzf "$tmp/luarocks.tar.gz" -C "$tmp/luarocks" || {
    err "extract luarocks failed"
    return 1
  }
  LR_SRC="$(find "$tmp/luarocks" -maxdepth 1 -type d -name 'luarocks-*' | head -n1)"
  [ -n "$LR_SRC" ] || {
    err "luarocks source not found"
    return 1
  }

  info "build/install LuaRocks → $HEREROCKS_DIR"
  (cd "$LR_SRC" && ./configure --prefix="$HEREROCKS_DIR" --with-lua="$HEREROCKS_DIR" --with-lua-include="$HEREROCKS_DIR/include") || {
    err "configure luarocks failed"
    return 1
  }
  (cd "$LR_SRC" && make build) || {
    err "make luarocks failed"
    return 1
  }
  (cd "$LR_SRC" && make install) || {
    err "make install luarocks failed"
    return 1
  }

  # 便利リンクと環境
  [ -x "$HEREROCKS_DIR/bin/luarocks" ] && ln -sf "$HEREROCKS_DIR/bin/luarocks" "$BIN_DIR/luarocks"
  [ -x "$HEREROCKS_DIR/bin/lua" ] && ln -sf "$HEREROCKS_DIR/bin/lua" "$BIN_DIR/lua"
  "$HEREROCKS_DIR/bin/luarocks" path >"$HEREROCKS_DIR/luarocks_path.sh" 2>/dev/null || true
  ensure_rc_line "[ -f \"$HEREROCKS_DIR/luarocks_path.sh\" ] && . \"$HEREROCKS_DIR/luarocks_path.sh\""
  ensure_rc_line "export PATH=\"$HEREROCKS_DIR/bin:\$PATH\""

  if "$HEREROCKS_DIR/bin/luarocks" --version >/dev/null 2>&1; then
    info "luarocks ready (Lua 5.1 no-readline): $("$HEREROCKS_DIR/bin/luarocks" --version | head -n1)"
    return 0
  else
    warn "luarocks did not respond; check logs above"
    return 1
  fi
}

report() {
  info "---- versions ----"
  for c in rg fd fzf lazygit uv node npm; do
    if command -v "$c" >/dev/null 2>&1; then
      printf "%-8s %s\n" "$c" "$(command -v "$c")"
      "$c" --version 2>/dev/null | head -n1 || true
    else
      printf "%-8s not found\n" "$c"
    fi
  done
  if [ -x "$VENV_DIR/bin/python" ]; then
    "$VENV_DIR/bin/python" -c 'import sys,importlib;print("venv python:",sys.version.split()[0]);import importlib;print("pynvim:",importlib.import_module("pynvim").__version__)' 2>/dev/null || true
  fi
}

main() {
  ensure_dirs
  info "Detected arch: $(arch)"
  info "BIN_DIR=$BIN_DIR"
  info "APPS_DIR=$APPS_DIR"

  info "--- before ---"
  report

  install_rg || warn "rg install failed (continue)"
  install_fd || warn "fd install failed (continue)"
  install_fzf || warn "fzf install failed (continue)"
  install_lazygit || warn "lazygit install failed (continue)"

  install_uv || warn "uv install failed (continue)"
  have uv && install_python_with_uv || true
  have uv && install_pynvim_venv || true
  install_luarocks_hererocks || warn "luarocks/hererocks setup failed (continue)"

  install_nvm_and_node || warn "nvm/node setup failed (continue)"

  info "--- after ----"
  report
  info "完了。新しいシェルを開くか、'source ~/.bashrc' / 'source ~/.zshrc' を実行して反映してください。"
  info "Neovimの :checkhealth で provider が揃っているか確認できます。"
}

main "$@"
