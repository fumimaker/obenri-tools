#!/bin/bash
# GitHubに登録したSSH公開鍵で ~/.ssh/authorized_keys を同期する。
# GitHubにない鍵と重複した鍵は削除し、変更前のファイルは authorized_keys.bak.<日時> に残す。
set -euo pipefail

usage() {
  echo "Usage: $0 [--just-view] <github-username>" >&2
  echo "  --just-view, -n  変更せずに、追加・削除される鍵だけを表示する" >&2
  exit 1
}

DRY_RUN=0
if [ "${1:-}" = "--just-view" ] || [ "${1:-}" = "-n" ]; then
  DRY_RUN=1
  shift
fi
if [ $# -ne 1 ] || [ -z "$1" ]; then
  usage
fi

GITHUB_USER="$1"

# 端末に出力するときだけ git diff のように色を付ける(NO_COLOR が設定されていれば付けない)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  RESET=""
fi

# .sshディレクトリとauthorized_keysのパス
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 一時ファイルは毎回別の名前で作り、終了時に必ず消す
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
GITHUB_KEYS="$WORK_DIR/github_keys"
NEW_KEYS="$WORK_DIR/authorized_keys"
STATS="$WORK_DIR/stats"

# GitHubからSSH公開鍵を取得。失敗したら何も変更せずに終了する
if ! curl -fsSL --max-time 30 "https://github.com/${GITHUB_USER}.keys" -o "$GITHUB_KEYS"; then
  echo "${RED}Error: GitHubから '$GITHUB_USER' の鍵を取得できませんでした。何も変更していません。${RESET}" >&2
  exit 1
fi

# 取得した内容がすべて公開鍵の形式かを確認する
if grep -vqE '^$|^(ssh-|ecdsa-|sk-)[^ ]+ AAAA[^ ]+' "$GITHUB_KEYS"; then
  echo "${RED}Error: GitHubから取得した内容に公開鍵ではない行があります。何も変更していません。${RESET}" >&2
  exit 1
fi

# 鍵が1本もないと全部削除してしまうので中止する
if ! grep -qE '^(ssh-|ecdsa-|sk-)' "$GITHUB_KEYS"; then
  echo "${RED}Error: '$GITHUB_USER' にはGitHubに鍵が登録されていません。何も変更していません。${RESET}" >&2
  exit 1
fi

CURRENT_KEYS="$AUTHORIZED_KEYS"
if [ ! -f "$CURRENT_KEYS" ]; then
  CURRENT_KEYS=/dev/null
fi

# 鍵本体(AAAA...の部分)で比較し、コメントやオプションの違いは無視する。
# 既存の行はオプション付きのまま残し、GitHubにしかない鍵は末尾に追加する。
awk -v out="$NEW_KEYS" -v stats="$STATS" -v red="$RED" -v green="$GREEN" -v reset="$RESET" '
  function blob(s,   n, f, i) {
    n = split(s, f, /[ \t]+/)
    for (i = 1; i <= n; i++) if (f[i] ~ /^AAAA/) return f[i]
    return ""
  }
  function short(s,   n, f, i) {
    n = split(s, f, /[ \t]+/)
    for (i = 1; i <= n; i++) if (f[i] ~ /^AAAA/) return f[i-1] " " substr(f[i], 1, 32) "... " f[i+1]
    return s
  }
  FNR == NR {
    b = blob($0)
    if (b != "" && !(b in gh)) { gh[b] = $0; order[++count] = b }
    next
  }
  /^[ \t]*(#|$)/ { print > out; next }
  {
    b = blob($0)
    if (b in seen) { print red "- " short($0) " (重複)" reset; removed++; next }
    if (!(b in gh)) { print red "- " short($0) reset; removed++; next }
    seen[b] = 1
    print > out
  }
  END {
    for (i = 1; i <= count; i++) {
      b = order[i]
      if (!(b in seen)) { print gh[b] > out; print green "+ " short(gh[b]) reset; added++ }
    }
    printf "%d %d\n", added, removed > stats
  }
' "$GITHUB_KEYS" "$CURRENT_KEYS"

touch "$NEW_KEYS"
read -r added_count removed_count < "$STATS"

echo "${GREEN}Added $added_count new keys.${RESET}"
echo "${RED}Removed $removed_count old keys.${RESET}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}(just view: $AUTHORIZED_KEYS は変更していません)${RESET}"
  exit 0
fi

if [ "$added_count" -eq 0 ] && [ "$removed_count" -eq 0 ]; then
  exit 0
fi

# .sshディレクトリが存在しない場合は作成
if [ ! -d "$SSH_DIR" ]; then
  echo "Creating $SSH_DIR directory..."
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
fi

# 変更前のファイルを残しておく
if [ -f "$AUTHORIZED_KEYS" ]; then
  BACKUP="$AUTHORIZED_KEYS.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$AUTHORIZED_KEYS" "$BACKUP"
  echo "Backup: $BACKUP"
fi

# 同じディレクトリに書き出してから置き換え、途中で失敗しても壊れないようにする
TMP_KEYS="$(mktemp "$SSH_DIR/.authorized_keys.XXXXXX")"
cat "$NEW_KEYS" > "$TMP_KEYS"
chmod 600 "$TMP_KEYS"
if [ -f "$AUTHORIZED_KEYS" ]; then
  chown --reference="$AUTHORIZED_KEYS" "$TMP_KEYS" 2>/dev/null || true
fi
mv -f "$TMP_KEYS" "$AUTHORIZED_KEYS"
