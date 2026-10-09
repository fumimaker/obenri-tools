# obenri-tools

- keys.sh  
githubに登録したssh keyでローカルを更新してくれる太郎。


`curl -fsSL https://raw.githubusercontent.com/fumimaker/obenri-tools/main/keys.sh | bash -s fumimaker`

のように最後に鍵を追加したいgithubアカウント名を渡すことで鍵を入れ、すでに存在しない鍵は削除してくれます。
自分用。

`bash -s -- -n fumimaker` のように `-n` を付けると、変更せずに追加・削除される鍵だけを表示します。

- 対象は実行したユーザーの `$HOME/.ssh/authorized_keys` です（`sudo -s` で実行すると root の鍵が対象になります）。
- 変更前のファイルは `authorized_keys.bak.<日時>` として残します。
- GitHubから鍵を取得できなかったときや、鍵が1本も登録されていないときは何も変更しません。
