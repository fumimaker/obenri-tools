#!/bin/bash

# 引数からGitHubユーザー名を取得。指定されていない場合はエラーメッセージを表示。
if [ -z "$1" ]; then
  echo "Usage: $0 <github-username>"
  exit 1
fi

GITHUB_USER="$1"

# .sshディレクトリとauthorized_keysのパス
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# .sshディレクトリが存在しない場合は作成
if [ ! -d "$SSH_DIR" ]; then
  echo "Creating $SSH_DIR directory..."
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
fi

# authorized_keysファイルが存在しない場合は作成
if [ ! -f "$AUTHORIZED_KEYS" ]; then
  echo "Creating $AUTHORIZED_KEYS file..."
  touch "$AUTHORIZED_KEYS"
  chmod 600 "$AUTHORIZED_KEYS"
fi

# GitHubからSSH公開鍵を取得
curl -s https://github.com/$GITHUB_USER.keys > /tmp/github_keys

# 追加・削除されたキーを追跡する変数
added_count=0
removed_count=0

# authorized_keysに存在しないキーを追加
while read -r new_key; do
  if ! grep -Fq "$new_key" $AUTHORIZED_KEYS; then
    echo "$new_key" >> $AUTHORIZED_KEYS
    ((added_count++))
  fi
done < /tmp/github_keys

# authorized_keysにあるがGitHubに存在しないキーを削除
while read -r existing_key; do
  if ! grep -Fq "$existing_key" /tmp/github_keys; then
    grep -vF "$existing_key" $AUTHORIZED_KEYS > /tmp/tmp_authorized_keys && mv /tmp/tmp_authorized_keys $AUTHORIZED_KEYS
    ((removed_count++))
  fi
done < $AUTHORIZED_KEYS

# 結果を表示
echo "Added $added_count new keys."
echo "Removed $removed_count old keys."

# 一時ファイルを削除
rm /tmp/github_keys