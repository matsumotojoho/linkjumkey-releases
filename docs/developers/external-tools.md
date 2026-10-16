# LinkJumkey 外部ツール開発契約（Desktop 1.8.24以降）

人向け手順: https://linkjumkey.matsumotojoho.com/guide/external-tools.html
完成サンプル: https://linkjumkey.matsumotojoho.com/examples/customer-search/README.md
機械可読OpenAPI: https://linkjumkey.matsumotojoho.com/developers/integrations-api.openapi.json
検索語の厳密な契約: https://linkjumkey.matsumotojoho.com/guide/linkjumkey-input-arguments.txt

公式サイトを取得できないAI向けに、同じ公開資料をGitHubにも掲載しています。接続エラー時にAPIのパスや仕様を推測せず、次の代替URLを使ってください。

- この仕様: https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/external-tools.md
- プレーンテキスト: https://raw.githubusercontent.com/matsumotojoho/linkjumkey-releases/main/docs/developers/external-tools.md
- API仕様: https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/integrations-api.openapi.json
- 完成サンプルと実行手順: https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/examples/customer-search/README.md
- 追加リンクの仕様: https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/add-button.md
- 入力契約: https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/guide/linkjumkey-input-arguments.txt

## 1. 成果物から経路を選ぶ

- ボタン1つやボタン集を作りたい: +Auto / AIボタン取り込み。確認して保存する下書きを作る。
- WebサイトやNotesに「LinkJumkeyに追加」を実装したい: 追加リンクの契約 https://linkjumkey.matsumotojoho.com/developers/add-button.md 。元ツールでタイトルと完成済みURLを取得し、利用者のクリックで追加リンクを実際に開く。トークン不要、プレビューで利用者が保存する。
- 検索語→DB/業務システム照会→CSV/レポートなどのツールを作りたい: 同じPCの外部スクリプトを作り、検索語をデータとして渡す。このページのWindows完成例を使える。
- そのローカルツールからHTTP/HTTPSの結果URLを指定プロジェクトへ直接保存したい: 下記のローカルAPI。Bearerトークンが必要で、POSTはプレビューなしで保存する。
- AIに現在のライブラリを読み書きさせたい: MCP。https://linkjumkey.matsumotojoho.com/guide/mcp-setup.html

ローカルAPIへnotes://やfile://を送らない。Notesは既存の追加リンクと利用者の確認を使う。ローカルファイルはDesktopの「ファイルを開く」または+Autoで内容を確認してPC操作として保存する。直接APIでPC操作や任意コードを作成・実行する経路にはしない。

Google Apps Script、クラウド版Power Automate、クラウド上のAIやサーバーにとって127.0.0.1はその実行環境自身であり、利用者のPCには届かない。クラウドからは利用者が開く追加リンクを返すか、承認したPC側のツールが結果を取りに行く設計にする。ローカルAPIキーをクラウド、AIチャット、生成URLへ埋め込まない。公開Webページからの直接呼出しはCORSで許可されない。

## 2. PC・接続先・キーを確認する

1. LinkJumkey Desktop 1.8.24以降を起動。
2. 「≡（プロジェクト管理）→ ⚙設定 → MCP / AI連携 → ローカルAPI（開発者向け）」を開く。
3. 表示された「接続先」をBase URLにする。通常は `http://127.0.0.1:9634`。9634を決め打ちせず表示値を優先する。
4. 同画面の「ローカルAPIキーをコピー」を使う。キーは初回起動時に自動作成される。MCP接続設定やペアコードとは別の値。
5. まずGET /statusで接続、次に認証付きGET /api/projectsで認証と保存先を確認する。

キーをソースコードに固定しない。利用者がPC内の設定や入力欄から渡す。ログやエラー表示にも出さない。配布例、スクリーンショット、問い合わせへ実キーを添付しない。

| メソッド | 正確なパス | 認証 | 用途 |
|---|---|---|---|
| GET | /status | 不要 | 接続だけを確認。保存しない |
| GET | /api/projects | Authorization: Bearer TOKEN | 保存先一覧。保存しない |
| POST | /api/quick-add | Authorization: Bearer TOKEN | HTTP/HTTPSのボタンを直接保存 |
| GET | /library | Authorization: Bearer TOKEN | 既存の詳細ライブラリAPI。引き続き利用可能 |
| POST | /library/apply | Authorization: Bearer TOKEN | 既存の変更セットAPI。引き続き利用可能 |

Base URLに表のパスをそのまま付ける。`/library` を `/api/library` に変えない。末尾のスラッシュやクエリを足さない。`linkjumkey://add` はHTTP APIのパスではない。

## 3. GET /api/projects

成功HTTP 200、`Content-Type: application/json; charset=utf-8`。

```json
{
  "ok": true,
  "projects": [
    { "id": "prj_example", "name": "顧客調査", "rootId": "root_example" }
  ],
  "projectNames": ["顧客調査"]
}
```

`projects` は文字列の配列ではなく、オブジェクトの配列。名前は必ず各 `object.name`、つまり `projects[i].name` から取り出す。オブジェクト全体を文字列化してprojectに送らない。PowerShellでは `$response.projects | Select-Object -ExpandProperty name`。一覧選択UIではnameを表示し、idを保持すると名前の取り違えを避けられる。`projectNames` は名前だけ必要な場合の補助配列。

## 4. POST /api/quick-add

リクエストはUTF-8のJSON、`Content-Type: application/json; charset=utf-8`。必須はtitle、url、projectまたはprojectIdの片方。

```json
{
  "title": "顧客検索結果",
  "url": "https://crm.example/reports/123",
  "project": "顧客調査",
  "note": "検索結果のレポート",
  "requestId": "customer-report-123"
}
```

| フィールド | 型・上限 | 意味 |
|---|---|---|
| title | string、必須、1〜120文字 | 前後空白を取り除いたボタンの表示名 |
| url | string、必須、最大4096文字 | 完成済みhttp/https URL。認証情報・空白・制御文字は不可 |
| project | string | GETで得た正確な名前。projectIdと併用不可 |
| projectId | string、最大256文字 | GETで得たid。projectと併用不可 |
| note | string、任意、最大2000文字 | メモ。CRLF/CRはLFへそろえる |
| folderId | string、任意、最大256文字 | 指定project内の既存フォルダーid。省略時はルート |
| createProject | boolean、任意、既定false | 未知のproject名を明示的に新規作成する場合だけtrue |
| requestId | string、任意、1〜128文字 | 同じ操作の再送を識別するキー |

文字数上限はUTF-16コード単位で数える。project名は厳密一致。半角/全角カナ、大文字/小文字、前後空白を勝手に変換しない。既存名は120文字を超えても指定でき、新規作成名だけ120文字以内。Object.prototype由来の予約名、prototype、[object Object]、PowerShellの@{…}表現は拒否する。未知の名前は既定で404。新規作成はproject名と `createProject: true` を明示する。未知のprojectIdは作成せず常に404。folderIdは同じプロジェクト内の既存フォルダーを指す必要があり、名前からの推測や暗黙作成はしない。projectId・folderId・requestId・urlも勝手にtrimしない。

成功HTTP 200:

```json
{
  "ok": true,
  "created": true,
  "replayed": false,
  "project": { "id": "prj_example", "name": "顧客調査", "rootId": "root_example" },
  "folderId": "root_example",
  "button": { "id": "item_example", "title": "顧客検索結果", "url": "https://crm.example/reports/123", "typeMode": "fixed" },
  "requestId": "customer-report-123",
  "snapshot": "snapshot_example.json"
}
```

`ok: true` に加え、`button.id`、`button.url`、`project.id/name` と意図した保存先を確認する。これは保存成功の応答で、URL先のページが開けることまでは保証しない。APIはブラウザを開かず、登録したボタンも実行しない。

同じrequestId・同じ正規化後の内容を再送すると同じbutton.idを返し、`created: false, replayed: true`。直近256個の異なるrequestIdを同じ保存領域へ永続化する。古いキーが排除された後の再送は新規扱いになる。requestIdを別内容に使い回すと409 REQUEST_ID_CONFLICT。保存済みの対象が削除・移動・変更されていれば409 REQUEST_TARGET_MISSING。通信エラー時は同じrequestIdで再送するか保存先を確認し、新しいキーで無条件に繰り返さない。256件より前の再送を重複抑止できる保証はない。

## 5. エラーと期待結果

```json
{
  "ok": false,
  "error": "Destination project was not found.",
  "code": "PROJECT_NOT_FOUND",
  "hint": "Choose a project from GET /api/projects."
}
```

error/hintの文章は表示案内、分岐にはHTTP statusとcodeを使う。

| HTTP | code例 | 次に確認すること |
|---|---|---|
| 400 | PROJECT_REQUIRED / UNKNOWN_FIELD / INVALID_JSON / INVALID_INPUT / INVALID_PROJECT / INVALID_URL | JSONの型、名前・IDの片方指定、完全なURLと上限 |
| 401 | AUTH_REQUIRED | コピーしたローカルAPIキー、Bearerヘッダー |
| 403 | ORIGIN_FORBIDDEN | 公開Webページから直接呼んでいないか |
| 404 | PROJECT_NOT_FOUND / FOLDER_NOT_FOUND | GETの正確なname/id、同一project内のfolderId |
| 404 | — | 正確なパス・Desktopのバージョン |
| 405 | METHOD_NOT_ALLOWED | GET/POSTの指定 |
| 409 | AMBIGUOUS_PROJECT / REQUEST_ID_CONFLICT / REQUEST_TARGET_MISSING | 保存先の一意性、同じキーの内容、以前保存した対象の状態 |

### 既存 /library/apply との違い

既存GET /libraryのprojects[]は `{name,buttonCount,folderCount}`。名前はここでもobject.nameから取り出す。既存POST /library/applyのcreateButtonは、未知のstring projectを従来どおり暗黙作成する。project省略または空文字は「AI作成」、null/objectなど非stringは拒否する。新しいquick-addは保存先が必須で、未知の名前を既定で拒否する。

既存の送信例:
```json
{"changes":[{"op":"createButton","project":"顧客調査","button":{"title":"顧客検索結果","url":"https://crm.example/reports/123","typeMode":"fixed"}}]}
```
既存の成功応答の主要フィールド:
```json
{"ok":true,"applied":[{"op":"createButton","project":"顧客調査","id":"item_example","title":"顧客検索結果"}]}
```
`applied[].id` とprojectを確認する。quick-addの `button.id` 応答と混同しない。既存のメモや変更セットの操作は、それぞれ既存APIの契約を引き続き使う。

## 6. Windows PowerShell 5.1のUTF-8

日本語を含む `.ps1` / `.psm1` はUTF-8 BOM付きで保存する。APIへ送るJSON文字列を明示的にUTF-8バイト列へ変換する。日本語を文字コードの既定値に任せない。

```powershell
$json = @{ title = '顧客検索結果'; url = 'https://crm.example/reports/123'; project = '顧客調査' } | ConvertTo-Json -Compress
$body = [Text.Encoding]::UTF8.GetBytes($json)
$saved = Invoke-RestMethod -Method Post -Uri "$base/api/quick-add" `
  -Headers @{ Authorization = "Bearer $token" } `
  -ContentType 'application/json; charset=utf-8' -Body $body
$saved.project.name
$saved.button.id
```

上の `$base` と `$token` は同じPCの設定から取得した値。レスポンスにも `charset=utf-8` が付く1.8.24以降を使う。PowerShell 5.1でAPI応答の日本語が崩れる場合は、最初にDesktopのバージョンを確認する。

## 7. 検索語からDB検索までの完成例

https://linkjumkey.matsumotojoho.com/examples/customer-search/README.md

Windows PowerShell 5.1/7 + Python 3.9以降の標準sqlite3で、架空8顧客を検索し、CSVとHTMLを保存する。追加Pythonパッケージ不要。必要ファイルと起動順、期待件数、試験コマンドをREADMEに掲載。実キー、実DB、ランタイム本体、実行結果は配布しない。

LinkJumkeyのPCコードは `$env:LINKJUMKEY_INPUT` を固定スクリプトの引数へ渡す。`passInput: true` が必要。空入力を処理し、内側改行は1つの値として保持する。入力をSQLやシェル命令へ連結しない。DB検索はパラメータ束縛、HTMLはエスケープ、CSVはUTF-8 BOMと数式対策を使う。

Macで作る場合、AppleScriptは `on run argv` の `item 1 of argv` で受け取り、外部プロセスへは `quoted form of` で渡す。`system attribute` で検索語を読むと日本語が崩れる。Excel/VBAは `Sub SearchWord(word As String)` の第1引数。Excelの編集可能なライセンスと対象ブックが必要。VBAサンプルを配っただけで実行確認済みと扱わない。

## AIへの依頼に含めること

対象OS、必要な実行環境、入力の取得元、読むデータ、書く場所、保存先の選び方、空/0件/エラー時の動き、再実行時の扱いを指定する。コードの納品だけで終わらず、架空データで実行し、出力とAPI成功応答を確認した範囲を報告する。実行していないOS、UI操作、VBAは明示する。
