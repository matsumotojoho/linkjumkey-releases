# LinkJumkey: AIとの成果物・作業メモの保存と再開（Desktop 1.8.25以降）

人向け手順: https://linkjumkey.matsumotojoho.com/guide/ai-workspace.html
接続設定: https://linkjumkey.matsumotojoho.com/guide/mcp-setup.html
OpenAPI: https://linkjumkey.matsumotojoho.com/developers/workspace-handoff.openapi.json
既存の外部ツール開発契約: https://linkjumkey.matsumotojoho.com/developers/external-tools.md
確認日: 2026-10-24。接続方式の公式案内を確認した日であり、全AIサービス・全モデルでの動作試験日ではありません。

## 最初に目的を区別する

この仕様は、接続したAIまたは同じPCのツールが、成果物へのボタンと作業メモを保存し、翌日に同じカードを読み返して更新するためのものです。

- WebサイトやNotesへ「LinkJumkeyに追加」を実装するだけなら、キー不要の追加リンクの仕様を使います: https://linkjumkey.matsumotojoho.com/developers/add-button.md
- DB検索・CSV作成などの処理自体を作るなら、外部ツール開発契約も読みます。ボタン登録だけでは外部処理は完成しません。
- この手順では、AIがJSONをクリップボードへ置いたり、LinkJumkeyでCtrl+Vを押したりする必要はありません。
- 接続できない場合はその事実を伝えます。内部ファイルの書き換え、特殊な再起動、別形式のfile URLによる承認回避へ切り替えません。

## 接続と機能の確認

1. このPCのLinkJumkey Desktopを起動します。バージョンと、MCPで公開されるツール一覧を確認します。
2. 「≡ → ⚙設定 → MCP / AI連携」で生成した、このPC用の設定を使います。実行ファイル・args・環境変数・ポートを推測しません。
3. MCP経由では設定フォルダーの認証情報を自動で読みます。キーをAIチャットへ貼る手順は不要です。
4. ローカルAPIを直接使う実装だけは、同画面「ローカルAPI（開発者向け）」の接続先とキーを使います。Base URLは通常 `http://127.0.0.1:9634` ですが、画面の値を優先します。HTTPリクエストには `Authorization: Bearer <このPCのキー>` を付けます。
5. プロジェクト一覧を実際に取得します。未接続と、旧版に必要なツールがない状態を分けて報告します。

クラウドや別PCの `127.0.0.1` は利用者のPCではありません。公開WebページからローカルAPIを直接呼ぶ構成や、インターネット経由のMCPはこの契約の対象外です。

## 作成から翌日の更新まで

MCPツールは `save_work_package`、`update_note`、`get_write_status`、`get_item` を使います。引数は接続時に取得したツールスキーマに従ってください。

1. 保存先プロジェクトとフォルダー、既存カードを確認する。名前ではなく取得したIDで同一カードを追跡する。
2. 成果物・参照URL・作業メモを `save_work_package` でまとめて登録する。
3. ローカルファイルまたはフォルダーを含む場合、Desktopの一覧確認を待つ。保存先・対象・件数をまとめて確認して全件登録する。登録時にファイルを開いたり、コマンドを実行したりしない。
4. `get_write_status` で状態を確認する。`pending_approval` を保存済みとして報告しない。
5. `saved` の結果にある各カードを `get_item` で読み返し、ID・保存先・本文・参照先を照合する。
6. 翌日は同じIDを読み、`update_note` で今回の結果を追記する。本人のメモを取り除かない。
7. 応答が届かず再試行する場合は、同じrequestIdと同じ内容を使う。新しいrequestIdで同じカードを作り直さない。

## メモの扱い

- URLなしのメモカードにダミーURLは不要です。既存ライブラリでは `type: "item"`、`typeMode: "fixed"`、`url: ""` と非空の `note` で保持します。新しい `type: "note"` や `typeMode: "memo"` を勝手に追加しません。
- 新しい保存・更新APIのメモは平文です。HTMLを組み立てず、改行を含む文字列として渡します。保存側がエスケープします。
- メモ更新の標準は追記です。目的、成果物の版、確認済みの事実と出典、未確認事項、次の作業を分けて書きます。
- 全文を置き換える場合は、直前の読み返しで取得したrevisionを使います。競合したら再取得し、本人の追記を含めた最新内容で判断します。無条件の全文置換はしません。
- 個々の保存の成功は、このPCでの保存です。クラウド同期や別端末への反映成功と混同しません。

## 状態と再送

| 状態 | AI・外部ツールの扱い |
| --- | --- |
| `pending_approval` | Desktopでの確認待ち。保存完了を報告せず、同じ依頼IDで状態を確認する |
| `saved` | 保存済み。返されたIDで読み返して確認する |
| `cancelled` | 本人が取り消した依頼。新たな保存が必要なら意図を確認して新しい依頼にする |
| `failed` | 原因を確認。通信だけが不明なら先に同じ依頼IDの状態を照会する |
| `limit_exceeded` | 件数・利用上限を確認し、内容を調整して新しい依頼にする |

同じrequestIdへ別内容を送ると競合になります。AIが本文を更新する依頼と、既存依頼の通信再試行は別の操作です。承認状態・ID・保存結果は実際の応答を根拠にし、画面が出たことから推測しません。

## ローカルファイル・フォルダー

実在するパスと保存先を指定し、Desktopの確認一覧を通します。ファイルパスを `https:`、`file:`、別アプリのURL形式などへ変換して確認を回避しません。URLボタンの簡易API `POST /api/quick-add` は引き続きHTTP/HTTPS専用です。

ファイル登録と実行は別です。登録しただけでファイル・フォルダーを開きません。ライブラリ同期はファイル本体の転送ではなく、別PCに同じパスがあるとは限りません。PC固有の操作は登録PCに結び付きます。成果物を移動・改名した場合は、実在場所を確認して登録を見直します。

## AIクライアントごとの接続範囲

- ChatGPT Desktop / Codex CLI・IDE: ローカルstdio対応と設定共有は https://learn.chatgpt.com/docs/extend/mcp を確認します。通常のChatGPT Webチャットとは接続方式が異なります。
- Claude Desktop: ローカルMCPまたは接続用 `.mcpb` は https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop を確認します。
- Gemini CLI: ローカルstdioの設定は https://geminicli.com/docs/tools/mcp-server/ を確認します。通常のGemini Webチャットとは別です。

クライアントの提供状況、プラン、組織の制限、権限を確認してください。すべてのAI・全モデルでの実動作比較を完了したという意味ではありません。LinkJumkeyへ接続しても、AIにメール・ブラウザー・ファイル作成の権限が自動追加されるわけではありません。

## 完了判定

架空の制作案件で、URLなしメモカード・成果物ファイル・資料・フォルダーを通常のツールで登録します。保存先と登録対象を確認し、全件保存後に読み返します。本人がメモを追記してから、翌日の依頼で同じカードを更新し、本人追記・改行・同じID・重複なしを確認します。登録中に成果物が開かないこと、取り消し・上限超過・競合が保存済みにならないことも確認します。

試験に使ったAIクライアント・OS・アプリ版、実際に動かした範囲、未試験の範囲を分けて報告してください。合成応答のツール試験を、各社AIの実モデル試験と記載しないでください。

## HTTP APIの完全な契約

機械可読の定義: https://linkjumkey.matsumotojoho.com/developers/workspace-handoff.openapi.json

これらはDesktop **1.8.25以降**のローカルAPIです。ベースURLと認証キーをDesktop設定から取得したうえで、次の**末尾のパス**を付けます。POSTにクエリ文字列を付けません。GETでは不明なパラメーターや同じパラメーターの重複を拒否します。

| MCPツール | HTTPメソッドと末尾のパス | 目的 |
| --- | --- | --- |
| `save_work_package` | `POST /api/workspace/save` | 新しい成果物ボタン・メモ・フォルダーを一括登録 |
| `update_note` | `POST /api/workspace/note` | 保存済みIDのメモへ追記、またはrevisionを確認して置換 |
| `get_write_status` | `GET /api/workspace/status?requestId=...` | 依頼の保存・確認待ち・失敗状態を照会 |
| `get_item` | `GET /api/workspace/item?projectId=...&nodeId=...` | 現在のカードやフォルダーを読み返す |

すべて認証必須です。ヘッダーは `Authorization: Bearer <このPCのキー>`。POST本文はUTF-8のJSONで、`Content-Type: application/json; charset=utf-8` を使います。応答もUTF-8です。1リクエストの本文上限は **256 KiB（262,144バイト）**です。キーはサーバー設定・環境変数などから実行時に読み、公開サンプルや会話に埋め込みません。

プロジェクトは既存の `GET /api/projects`、フォルダーやカードのIDはMCPの `get_project` または既存の `GET /library` で確認できます。`projects` はオブジェクト配列なので、名前なら `projects[i].name`、IDなら `projects[i].id` を取り出します。オブジェクト全体を文字列化して渡しません。

### 保存リクエスト

`POST /api/workspace/save` の最小例です。`動画制作` は一覧で確認した既存名に置き換えてください。

```json
{
  "requestId": "video-notes-20261024-001",
  "project": "動画制作",
  "items": [
    {
      "key": "work",
      "kind": "note",
      "title": "作業メモ",
      "note": "完了: 構成案\n次: S02の試し録りを確認"
    }
  ]
}
```

| フィールド | 必須・形式・意味 |
| --- | --- |
| `requestId` | 必須。空白だけでない文字列、128 UTF-16コード単位以内。同じ操作の再送では同じ値と同じ内容を使う |
| `project` / `projectId` | どちらか一方だけ必須。正確な名前、または既存ID。名前の大文字・小文字、カナ、前後の空白を勝手に変更しない |
| `createProject` | 任意のboolean。既定は`false`。未存在の名前を明示的に作るときだけ`true`。`true`と`projectId`の併用不可（`false`は併用可）。新しい名前は120 UTF-16コード単位以内 |
| `folderId` | 任意。選択プロジェクト内の到達可能な既存フォルダーID、256 UTF-16コード単位以内。省略時はルート。不明なIDをルートへ置き換えない。新規プロジェクトでは省略 |
| `items` | 必須。1～50件。配列の順番で処理する。フォルダーは子より先に置く |

各`items[]`は次の形式です。ここにないフィールドは拒否します。

| フィールド | 必須・形式・意味 |
| --- | --- |
| `key` | 必須。依頼内で一意、128 UTF-16コード単位以内。成功応答で`nodeId`と対応付けるためのキー |
| `kind` | 必須。`note`、`url`、`file`、`localFolder`、`folder`のいずれか |
| `title` | 必須。空白だけでない文字列、入力時点で120 UTF-16コード単位以内。保存時に前後の空白を除く |
| `note` | 平文、20,000 UTF-16コード単位以内。`kind: "note"`では空白だけでない本文が必須。他の種類では省略・空文字列可 |
| `url` | `kind: "url"`だけで必須。完全なHTTP/HTTPS URL、4,096 UTF-16コード単位以内。認証情報・空白・制御文字・バックスラッシュは不可。他の種類では指定不可 |
| `path` | `kind: "file"`または`"localFolder"`だけで必須。このPCの絶対パス、4,096 UTF-16コード単位以内。他の種類では指定不可 |
| `parentKey` | 任意。同じ依頼で**先に出てくる**`kind: "folder"`の`key`を指定。省略時は`folderId`またはルート |

`folder`はLinkJumkey内で整理するフォルダーです。`localFolder`はPC上のフォルダーを開くボタンです。`file`と`localFolder`はDesktop確認が必要です。明示的なローカル参照の`path`に`file:`表記を渡した場合も、通常パスへ正規化して**同じ確認手順**を通します。`kind: "url"`へ`file:`を渡すことはできません。

文字数制限はJavaScriptの文字列長と同じUTF-16コード単位です。一部の絵文字は2単位になります。ID・パス・タイトルに改行や制御文字は使えません。メモではタブ・改行を扱えます。CRLF/CRはLFへ統一します。

`key`や`title`は別依頼との自動更新キーではありません。**新しいrequestIdでsaveを呼ぶと新規作成**になります。翌日の続きは保存済み`nodeId`へ`update_note`を使います。

### 保存応答とPCでの確認

URL・メモ・整理用フォルダーだけなら、検証と上限確認後にまとめて保存します。ローカルファイルまたはローカルフォルダーが1件でも含まれると、**同じ依頼のURL・メモも含めて全件が確認待ち**です。確認前に一部のカードや新規プロジェクトだけを保存することはありません。

確認待ちの応答例:

```json
{
  "ok": true,
  "requestId": "video-local-20261024-001",
  "status": "pending_approval",
  "replayed": false,
  "project": { "id": "prj_example", "name": "動画制作", "rootId": "root_example" },
  "folderId": "root_example",
  "items": [],
  "updatedAt": "2026-10-24T04:00:00.000Z"
}
```

Desktopの「AIからの登録」で保存先・フォルダー・各対象を本人が確認します。承認時にもパスの存在、ファイルとフォルダーの種類、保存先、現在の上限を再確認します。問題があれば全件の登録を中止します。確認待ちの間にログアウト・再ログイン・接続アカウントの変更があった場合も、旧依頼は`ACCOUNT_CHANGED`で保存せず、現在のアカウントを確認して新しい依頼を作ります（同じユーザーへの再ログインでも対象です）。HTTPにもMCPにも承認用エンドポイントはありません。`/api/workspace/approve`などを作ったつもりで呼び出しても承認されません。

保存済みの応答例（上のメモ1件を保存した場合）:

```json
{
  "ok": true,
  "requestId": "video-notes-20261024-001",
  "status": "saved",
  "replayed": false,
  "project": { "id": "prj_example", "name": "動画制作", "rootId": "root_example" },
  "folderId": "root_example",
  "items": [
    {
      "key": "work",
      "nodeId": "item_example",
      "kind": "note",
      "title": "作業メモ",
      "parent": "root_example",
      "revision": "保存時点の不透明なrevision文字列"
    }
  ],
  "snapshot": "library-保存前スナップショット名.json",
  "updatedAt": "2026-10-24T04:00:00.000Z"
}
```

ID・revision・snapshot名は例の文字列を使わず、実際の応答を保存してください。`replayed: true`は既存依頼の結果を返したことを示します。`items`が存在するだけで成功と判定せず、必ず`status`を確認します。登録時に動画・資料の再生、ファイルの実行、コマンド実行は行いません。

### 読み返しとメモ更新

`GET /api/workspace/item`には`nodeId`と、`project`または`projectId`のどちらかをクエリで渡します。名前・IDはURLエンコードします。例:

```http
GET /api/workspace/item?projectId=prj_example&nodeId=item_example
Authorization: Bearer <このPCのキー>
```

応答の形:

```json
{
  "ok": true,
  "project": { "id": "prj_example", "name": "動画制作", "rootId": "root_example" },
  "item": {
    "id": "item_example",
    "title": "作業メモ",
    "kind": "note",
    "url": "",
    "note": "<div>完了: 構成案<br>次: S02の試し録りを確認</div>",
    "noteText": "完了: 構成案\n次: S02の試し録りを確認",
    "revision": "現在の不透明なrevision文字列",
    "parent": "root_example"
  }
}
```

ローカル参照は`item.path`も返します。`note`は保存HTML（既存データでは平文の場合もあります）、`noteText`は改行と実体参照を変換した平文です。文字装飾などの情報は`note`に残っています。`noteText`だけで全文置換すると装飾・チェックボックスなどを失うため、作業の継続には追記を優先します。更新APIへ`note`のHTMLをそのまま渡すと平文としてエスケープされるので、追記する平文だけを`text`へ渡します。

`POST /api/workspace/note`の翌日追記例:

```json
{
  "requestId": "video-notes-20261025-001",
  "projectId": "prj_example",
  "nodeId": "item_example",
  "mode": "append",
  "text": "確認結果: S02を確認\n次の作業: 残りを録音"
}
```

`mode`省略時も`append`です。現在保存されている本人のHTMLメモを残して、追記を別のブロックへ追加します。以前に読んだ全文を送る必要はありません。`requestId`、保存先、`nodeId`、`text`は必須です。`nodeId`は256、`text`は20,000 UTF-16コード単位以内。空の`text`も受け付けます。合成後の保存HTMLが200,000 UTF-16コード単位を超える場合は拒否します。

全文を置き換えるときだけ`mode: "replace"`と`expectedRevision`を追加します。`expectedRevision`は128 UTF-16コード単位以内の文字列で、最新の`get_item`応答から取得した値です。自分で計算したり、固定値にしたりしません。本人がその間に編集していたら`409 REVISION_CONFLICT`で上書きしません。`append`でも`expectedRevision`を指定した場合は同じ一致確認を行います。`replace`で省略すると`409 REVISION_REQUIRED`です。

更新成功も`status: "saved"`の保存結果を返します。`items[]`には`nodeId`、`title`、`kind`、保存後の`revision`が入ります。更新には依頼内の`key`や新しいカードIDは付きません。保存後に同じ`nodeId`を再取得して本文を確認します。

### 状態照会・エラー・再送の限界

`GET /api/workspace/status?requestId=...`は依頼の保存結果を返します。HTTP 200、`ok: true`であっても、業務上の状態が`failed`や`limit_exceeded`なら保存成功ではありません。

| 応答 | 代表的なcode | 次の操作 |
| --- | --- | --- |
| HTTP 200 / `pending_approval` | なし | Desktopで本人の確認を待つ。URLやメモも未保存 |
| HTTP 200 / `saved` | なし | 応答IDで現在の内容を読み返す |
| HTTP 200 / `cancelled` | なし | 本人の取消として扱う。黙って新しい依頼を送らない |
| HTTP 200 / `limit_exceeded` | `LIMIT_EXCEEDED` | 全件未保存。件数や保存先を調整し、必要なら新しいrequestIdで依頼 |
| HTTP 200 / `failed` | `PATH_NOT_FOUND`、`PATH_KIND_MISMATCH`、`DESTINATION_CHANGED`、`ACCOUNT_CHANGED`など | `error`と`hint`を確認。対象・保存先を直した新しい依頼には新しいrequestIdを使う |
| HTTP 400 | `INVALID_INPUT`、`INVALID_JSON`、`INVALID_QUERY`、`NOTE_REQUIRED`、`INVALID_PARENT`、`DUPLICATE_KEY`など | 仕様に合わせて入力を直す。保存成功と扱わない |
| HTTP 401 / 403 | `AUTH_REQUIRED` / `ORIGIN_FORBIDDEN` | このPCの接続先・キー・実行場所を確認。認証を迂回しない |
| HTTP 404 | `PROJECT_NOT_FOUND`、`FOLDER_NOT_FOUND`、`ITEM_NOT_FOUND`、`REQUEST_NOT_FOUND` | 保存先や履歴を確認し、推測したIDで続けない |
| HTTP 405 | `METHOD_NOT_ALLOWED` | 上記4パスとメソッドを確認。POSTにクエリを付けない |
| HTTP 409 | `REQUEST_ID_CONFLICT`、`REVISION_REQUIRED`、`REVISION_CONFLICT`、`NOTE_LIMIT_EXCEEDED`など | 同じ依頼への別内容送信や古いメモの上書きを中止して再確認 |
| HTTP 413 | `PAYLOAD_TOO_LARGE` | 本文全体を256 KiB以下へ縮小 |
| HTTP 429 | `PENDING_LIMIT` | このPCにある確認待ち依頼を確認・取消してから新しい依頼を作る |
| HTTP 503 | `DESKTOP_STORAGE_INVALID`、`RECEIPT_STORAGE_INVALID`など | 保存状態を確認。空のライブラリだと決めつけて作り直さない |

非2xx応答の基本形は`{"ok":false,"error":"...","code":"...","hint":"...","status":"failed"}`です。認証・Originの拒否は経路に入る前なので`status`を省略する場合があります。HTTP 200の失敗結果も`code`・`error`・`hint`を持ちます。文面の一致ではなくHTTPステータス・`ok`・`status`・`code`で判定してください。入力エラーなどは永続的な結果が作られない場合があります。

requestIdは保存とメモ更新で共通の履歴を使います。同じIDと同じ正規化後の内容なら元の結果を返し、追記を重複しません。同じIDへ異なる内容や異なる種類の操作を送ると409になります。通信が途切れたら同じIDの状態を先に照会し、必要なら同じ内容で再送します。

履歴は**このPCに永続化する直近256件の完了依頼**と、**最大20件の確認待ち依頼**です。再起動やライブラリのスナップショット復元でも現在の履歴を維持します。256件から押し出された完了IDに永続的な重複防止保証はありません。そのIDを再送すると新規処理になり得ます。`REQUEST_NOT_FOUND`は「一度も保存していない」の証明ではありません。ID間違い、別PC、履歴範囲外などを調べ、プロジェクトと保存済みカードを確認してから判断します。

`saved`はその操作が過去に完了した記録です。その後本人がメモを編集・カードを削除・スナップショットを復元していても、同じ依頼を再送して復元・上書きはしません。現在の状態は`get_item`で確認します。削除済みなら`ITEM_NOT_FOUND`です。プロジェクト名変更後は保存しておいた`projectId`を使います。クラウドへの同期完了やファイル本体の存在を`saved`だけで保証しません。

既存プランの上限をそのまま適用します。Freeはボタン合計30、プロジェクト2、各プロジェクトのルートを除くフォルダー3が上限です。URLなしメモ、URL、ローカルファイル・フォルダーのボタンはボタン数に含みます。整理用`folder`はフォルダー数です。Pro/Deckのこれらの件数は無制限ですが、1依頼50件・本文256 KiBなどのAPI制限は共通です。既存メモの更新は新規ボタン数を増やしません。この連携用の別料金や追加権利は導入していません。

### 配布サンプルを使う

- Windows例（6本の架空動画・資料フォルダー・参考URL・メモ・整理用フォルダー）: https://linkjumkey.matsumotojoho.com/examples/workspace-handoff.json
- Mac例（同じ内容、Macの絶対パス）: https://linkjumkey.matsumotojoho.com/examples/workspace-handoff-mac.json

いずれもAPIのリクエスト本文そのものです。動画や資料本体、認証キー、実行コードは含みません。`C:\LinkJumkey-Demo\...`と`/Users/example/...`は架空のパスなので、登録前に利用者のPCに実在する成果物の絶対パスへ置き換えてください。JSONのWindowsパスはバックスラッシュを`\\`として記述します。

最初の送信前に`project`・各`title`・`note`・`path`・`url`を意図した内容へ変更し、その依頼だけの`requestId`へ変更します。`createProject: true`は新規作成を意図するときに使い、既存プロジェクトだけを対象とするなら省略または`false`にします。既存IDを使う場合は`project`と`createProject`を除き、`projectId`へ差し替えます。

送信にはMCPの`save_work_package`引数または`POST /api/workspace/save`本文として使います。JSONをクリップボードに置いてCtrl+Vで新規作成する手順ではありません。送信後の通信再試行ではrequestId・本文を変更しません。保存後は応答のprojectId・nodeIdを記録し、翌日の続きは上の追記APIへ進みます。
