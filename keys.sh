#!/bin/bash

# GitHubユーザー名
GITHUB_USER="fumimaker"

# authorized_keysのファイルパス
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

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