# obenri-tools

- keys.sh  
githubに登録したssh keyでローカルを更新してくれる太郎。


`curl -fsSL https://raw.githubusercontent.com/fumimaker/obenri-tools/main/keys.sh | bash -s fumimaker`

のように最後に鍵を追加したいgithubアカウント名を渡すことで鍵を入れ、すでに存在しない鍵は削除してくれます。
自分用。

`bash -s -- --just-view fumimaker` のように `--just-view` を付けると、変更せずに追加・削除される鍵だけを表示できる

- 対象は実行したユーザーの `$HOME/.ssh/authorized_keys` です（`sudo -s` で実行すると root の鍵が対象）
- 変更前のファイルは `authorized_keys.bak.<日時>` としてバックアップされる
- GitHubから鍵を取得できなかったときや、鍵が登録されていないときはなにも動かない
