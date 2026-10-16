# LinkJumkey 外部追加リンク v1

外部アプリ・Webサイト・AI実装者向けの公開仕様です。名前と完成済みURLを渡し、利用者がLinkJumkeyの確認画面でボタンを保存します。

**追加リンク方式では、LinkJumkeyの待受ポート、exeの保存先、ローカルAPIのエンドポイントを利用者が設定する必要はありません。** PCへ直接渡す入口は `linkjumkey://add?`、Web経由の入口は `https://linkjumkey.matsumotojoho.com/import.html#add=1&` です。完全な例と確認手順は「接続先と末尾の確認」にあります。ローカルHTTP APIは別方式です。

**外部ツールへ「LinkJumkeyに追加」を実装する依頼では、クリックできる機能と、そのクリックで追加リンクを開くコードを成果物にしてください。** JSONファイルの生成やJSONのクリップボードへのコピーだけでは連携は完成していません。SDKのoptionsオブジェクトはコード内の入力値であり、利用者へ渡すJSONファイルではありません。

### クリップボードを使うときの操作場所

「クリップボードの文字をタイトルにする」場合も、読み取るのは**開発する外部ツール**です。次の流れを実装してください。

| 場所 | 操作・処理 |
| --- | --- |
| 外部ツール | 利用者のクリックでクリップボードの文字を読み、`title` の値にする。完成済みURLは元アプリから別途取得する。 |
| 外部ツール | `title` と `url` から追加リンクを生成し、そのリンクをブラウザまたはOSのURLハンドラーで開く。 |
| LinkJumkey | 開いた取り込み確認画面で、利用者が内容・保存先を確認して保存する。 |

**この外部連携の受け取り手順として「LinkJumkeyへCtrl+V（Control+V／Macの⌘V）すると新規作成できる」と案内しないでください。** 名前・URL・JSONをクリップボードへ書いて利用者に貼り付けさせる処理や、貼り付けキーの自動送信に置き換えないでください。クリップボードが読めなければ、利用者が**外部ツールの名前入力欄**へ手入力・貼り付けしてから、外部ツールの追加ボタンを押します。通常の入力欄で文字を貼り付けることと、追加リンクを開いて受け渡すことは別の操作です。

ガイドの「仕様全文をコピー」は**AIとの会話へ仕様を渡すため**の機能です。コピーした仕様をLinkJumkeyへ貼り付けてボタンを作る機能ではありません。

用途ごとの入口:

- **外部アプリ・Notesツール・Webサイトに追加機能を実装する**: この仕様を使います。入力取得 → リンク生成 → 利用者のクリックでリンクを開く → LinkJumkeyで確認・保存、までを設計します。MCP設定やAPIキーは不要です。
- **AIにリンク集を一度に考えてもらい、データを一括取り込みする**: [一括JSON作成ガイド](https://linkjumkey.matsumotojoho.com/guide/ai-buttons.html)。この用途ではJSONの出力が適切です。
- **接続したAIに現在のライブラリを読んでもらい、追加・整理する**: [MCPガイド](https://linkjumkey.matsumotojoho.com/guide/mcp-setup.html)。外部ツールの追加ボタンを作るだけなら、この接続は不要です。

- 人向けガイド: https://linkjumkey.matsumotojoho.com/guide/add-button.html
- この仕様: https://linkjumkey.matsumotojoho.com/developers/add-button.md
- JSON Schema（SDK options）: https://linkjumkey.matsumotojoho.com/developers/add-button.schema.json
- ブラウザ用SDK: https://linkjumkey.matsumotojoho.com/add-button-link.js
- 動くHTMLサンプル: https://linkjumkey.matsumotojoho.com/examples/add-button.html
- 対応PC版: **Desktop 1.8.21以降**。通常ウィンドウとMulti-Paneに対応します。

English implementation contract: Deliver working source code with an “Add to LinkJumkey” control. Obtain a title and complete `http:`, `https:` or `notes:` URL from the source app or explicit user input. For websites, call `createLink(options)` and open its returned HTTPS URL on click. For native / Notes tools, call `createDesktopLink(options)` and open the returned `linkjumkey://add` URI through the OS URL handler on click. Generating a JSON file, copying JSON to the clipboard, or merely displaying a URI does not complete an integration. The JSON Schema validates the SDK options object; it is not an import-file format. If clipboard title input is requested, the external tool reads it; if denied, the user enters or pastes text into that external tool's Title field and clicks its Add control. Never describe Ctrl+V / Control+V / Cmd+V in LinkJumkey as this integration's button-creation or receiving mechanism, write the payload to the clipboard, or simulate paste keystrokes. The handoff is opening the generated add link, followed by user-confirmed save in LinkJumkey. The guide's “Copy full specification” button is only for pasting documentation into an AI conversation. LinkJumkey does not scrape the source app. Do not invent source-app APIs or construct a Notes URL from a document ID alone.

Parameters are named, not positional. Desktop add links need no account, MCP setup, API key or local Host token, and no separate localhost server setup, port selection or executable-path configuration. The complete receiving prefixes are `linkjumkey://add?` (open through the OS, not HTTP) and `https://linkjumkey.matsumotojoho.com/import.html#add=1&` (browser navigation, not a JSON POST). Never append a port, slash or extra path to the outer `linkjumkey://add` URI. Paths and ports inside the target `url` value remain part of that target URL. Direct add URIs and Notes imports require Desktop 1.8.21+. Notes uses `fixed` mode and the Desktop flow only. `project` defaults to `外部サイト`: import into the root of that named project, creating it if absent. Keep the default merge mode for addition; replacing a same-name project can remove its existing contents. This contract cannot select an arbitrary destination folder. The user handles OS launch prompts and confirms the final save in LinkJumkey. Test that clicking reaches the import preview, then test user-confirmed save and cancellation; report any environment you could not test. There is no save-result callback. The separate local HTTP API uses authenticated `POST /library/apply` for direct changes, and its `createButton` accepts http/https only, not Notes. Do not switch a Notes add-link integration to that API. For one-off bulk JSON generation or an AI connected to the library, use the separate guides above.

## 1. 受け口

### Webサイト向け（推奨）

```text
https://linkjumkey.matsumotojoho.com/import.html#add=1&title=Example%20Docs&url=https%3A%2F%2Fexample.com%2Fdocs
```

`#` 以降は `URLSearchParams` 形式です。`add=1` がこの形式の識別子です。`title` と `url` は必須です。利用者がリンクを押すと取り込みページが開き、「LinkJumkey で開く（PC）」からアプリの確認画面へ進みます。JSONのコピーや貼り付けは不要です。`http` / `https` のボタンはWeb版へ保存することもできます。Web版への継続保存にはメール確認が必要です。NotesはPC版へ取り込んでください。

リンクを開いただけでは保存も実行もしません。PC版への引き渡し後も、利用者がプレビューと保存先を確認して取り込みます。外部サイトに保存結果を返すコールバックはありません。

### PCアプリ・Notesツール向け（直接追加）

```text
linkjumkey://add?title=Example%20Docs&url=https%3A%2F%2Fexample.com%2Fdocs
```

同じ項目を `?` 以降に指定して、OSのURLハンドラーで開きます。直接形式には `add=1` を付けません。JSONの作成・Webページは不要です。Desktop 1.8.21以降が必要で、利用者の確認・保存は省略しません。未インストール時の案内が必要ならHTTPS形式を使います。

**第1引数・第2引数のような位置指定ではありません。** `title` がボタン名、`url` が保存対象です。項目の順序を変えても同じです。アプリ起動時の `argv[1]` / `argv[2]` へ生の名前とURLを渡す契約ではありません。

### 接続先と末尾の確認

| 方式 | 完全な入口・末尾 | 呼び出し方 | LinkJumkeyのポート・アプリパス |
| --- | --- | --- | --- |
| PCへの直接追加 | `linkjumkey://add?title=...&url=...` | 利用者のクリックからOSのURLハンドラーで開く。HTTPリクエストではない。 | 指定不要。OSに登録されたアプリを使う。 |
| Webページ経由の追加 | `https://linkjumkey.matsumotojoho.com/import.html#add=1&title=...&url=...` | ブラウザで開く。ページへのGETと、`#`以降の項目を読む処理。JSONのPOST先ではない。 | 指定不要。PC版で保存するときは「LinkJumkey で開く（PC）」へ進む。 |
| 別方式のローカルHTTP API | 画面に表示された接続先（既定 `http://127.0.0.1:9634`）+ `/library/apply` | 同じPCのローカルツールから認証付きPOST。確認画面を経由せず変更を保存する。 | この別方式を選んだ開発者だけが確認する。`createButton` はhttp/httpsのみでNotesには使わない。 |

`linkjumkey://add` の `add` はアプリが受け取る処理名です。`http://localhost:ポート/add` に書き換えたり、`linkjumkey://add/`・`linkjumkey://add:9634` のように末尾の `/`・パス・ポートを付けたりしないでください。一方、**ボタンに保存する `url` 値**に含まれる本来のパスやポートはそのまま渡します。

Windowsでの確認手順:

1. このPCのLinkJumkeyを一度起動します。「≡（プロジェクト管理）→ ⚙設定 → アップデート → Desktop version」で1.8.21以降か確認します。
2. PowerShellで次の固定テストを実行します。exeパスやポートは入力しません。

   ```powershell
   Start-Process -FilePath 'linkjumkey://add?title=Connection%20Test&url=https%3A%2F%2Fexample.com%2F'
   ```

3. LinkJumkeyで `Connection Test` と `https://example.com/` の取り込み確認が開けば、追加リンクの受け渡しは成功です。確認だけならキャンセルします。起動しただけで保存済みとは判定しません。
4. 対応アプリが見つからない・アプリ選択が出る場合は、[公式Windowsインストーラ](https://linkjumkey.matsumotojoho.com/#download)でインストールし、一度起動してから再確認します。インストール済みでも登録されない場合は同インストーラを再実行してください。会社PCで起動が制限されている場合は、表示されたエラーを管理者へ確認します。
5. 固定テストは成功するのに作成したツールでは開かない場合は、開発者が生成したURIとクリック時の起動処理を確認します。SDKの返したリンクを実際に開いているか、ブラウザ・OSの起動確認を拒否していないかを調べます。利用者に推測でポートを合わせさせる手順へ変更しません。
6. ボタンを保存できた後にNotes文書が開けない場合は、Notesクライアント・`notes:`の関連付け・完成済み文書URL・アクセス権を確認します。LinkJumkeyの追加リンクとは別の段階です。

macOSでは同じテストURIを `open 'linkjumkey://add?title=Connection%20Test&url=https%3A%2F%2Fexample.com%2F'` で開けます。ブラウザから試す場合は[固定URLの追加例](https://linkjumkey.matsumotojoho.com/guide/add-button.html#quickstart)を使い、Web確認画面から「LinkJumkey で開く（PC）」を押します。

**別方式を明示的に選んだ場合の確認先:** MCPは「設定 → MCP / AI連携 → 接続設定の内容」で、そのPCの実行ファイル・スクリプト・接続先を含む設定を確認・コピーします。ローカルHTTP APIは同じ画面の「ローカルAPI（開発者向け）→ 接続先」を使い、[エンドポイントと確認手順](https://linkjumkey.matsumotojoho.com/guide/integrations.html#local-api)を参照します。HTTPの `/add` や `/api/buttons` を推測で作らないでください。外部ツール自身の開発用Webサーバーのポートや、保存対象URLのパスを尋ねる場合は、開発者が対象を区別し、確認する画面・起動コマンド・完全なURL・期待結果を示してください。

## 2. 項目

| 名前 | 必須 | 初期値 | 内容 |
| --- | --- | --- | --- |
| `title` | はい | なし | ボタン名。空白だけは不可。120文字まで。 |
| `url` | はい | なし | 完成済みの `http://` / `https://` / `notes://` URL。4096文字まで。相対URL、認証情報付きURLは不可。 |
| `project` | いいえ | `外部サイト` | 追加先のプロジェクト名。120文字まで。同名プロジェクトのルートへ追加し、なければ新規作成する。 |
| `note` | いいえ | 空文字 | メモ。2000文字まで。プレーンテキストとして扱い、改行を保持し、HTML文字列はエスケープする。 |
| `typeMode` | いいえ | `fixed` | `fixed` または `template`。`notes` は `fixed` のみ。 |

- 各値は文字列です。名前付き項目は各1回だけ指定します。未知の項目・重複した項目・不正なパーセントエンコードは拒否します。
- 文字数はJavaScriptのUTF-16コード単位（`string.length`）で数えます。`title` / `project` は前後の空白を除いて検証し、明示した空欄は拒否します。`note` の上限は改行正規化前です。
- `title` / `project` にASCII制御文字、`url` に生のASCII制御文字や空白は指定できません。URL中の空白は元のURLで `%20` などへエンコードしてください。`note` はTAB・LF・CRを除くASCII制御文字を拒否し、CRLF / CRをLFへそろえます。
- `project` の予約名（大文字小文字を区別、前後空白除去後）は `constructor`, `__defineGetter__`, `__defineSetter__`, `hasOwnProperty`, `__lookupGetter__`, `__lookupSetter__`, `isPrototypeOf`, `propertyIsEnumerable`, `toString`, `valueOf`, `__proto__`, `toLocaleString`, `prototype` です。省略時は `外部サイト` を使います。
- URLの大文字小文字・クエリを勝手に書き換えず、入力元から受け取った完成済みURLを渡してください。
- `fixed`: 保存したURLをそのまま開くボタンを提案します。
- `template`: 利用者が後からLinkJumkeyの共通入力欄へ入れた文字をURL用にエンコードし、URL末尾へ追加して開くボタンを提案します。例: `https://example.com/search?q=`。
- `{検索語}` や `%s` を置換する仕様ではありません。検索先URLは入力を付加したい位置で終わらせます。
- `file:`, `javascript:`, `data:`, その他の独自URIスキーム、起動引数、スクリプト、Host実行フィールドはこの簡易形式の対象外です。
- 保存時のボタン数上限は通常の取り込みと同じです。Freeの上限をこのリンクで回避できません。

### 保存先と取り込みモード

`project` を省略すると `外部サイト` という名前のプロジェクトへ追加します。指定した名前のプロジェクトがあればそのルート直下、なければ新しく作られた同名プロジェクトのルート直下が保存先です。現在開いているプロジェクトやフォルダへ自動的に入る仕様ではありません。

確認画面の既定は**合併**です。通常の追加ではこのまま確認して保存します。**まるごと置き換え**を選ぶと、同名プロジェクトの既存内容が置き換わるため注意してください。この簡易リンクには `folder` 項目や、任意の保存先フォルダを選ぶ機能はありません。

## 3. Webサイトの最小実装

HTMLだけでもリンクを置けます。HTML属性内の `&` は `&amp;` と書きます。

```html
<a href="https://linkjumkey.matsumotojoho.com/import.html#add=1&amp;title=Example%20Docs&amp;url=https%3A%2F%2Fexample.com%2Fdocs">LinkJumkeyに追加</a>
```

動的な名前やURLには `URLSearchParams` を使います。元の文字列を渡し、先に `encodeURIComponent` を掛けないでください。日本語・絵文字・`&`・`#`・空白を一度だけエンコードします。

```js
const fields = new URLSearchParams({
  add: "1",
  title: "製品マニュアル",
  url: "https://example.com/docs?lang=ja&view=quick",
  project: "製品情報",
  note: "導入時に確認するページです。",
  typeMode: "fixed"
});
const href = "https://linkjumkey.matsumotojoho.com/import.html#" + fields;
document.querySelector("#add-to-linkjumkey").href = href;
```

リンクを押す操作は利用者に任せます。ページ読込時に自動でPCアプリを起動しないでください。

## 4. 任意のJavaScript SDK

SDKを使う場合も、返されたURLを実際に開く処理が必要です。次はWebサイトのボタンを押すと取り込みページへ進む最小例です。元アプリに組み込む際は、固定値を元アプリの選択中データや入力欄から取得する値へ置き換えます。

```html
<button id="add-to-linkjumkey" type="button">Add to LinkJumkey</button>
<p id="add-status" role="status"></p>
<script src="https://linkjumkey.matsumotojoho.com/add-button-link.js"></script>
<script>
document.querySelector("#add-to-linkjumkey").addEventListener("click", () => {
  try {
    const href = LinkJumkeyAddButton.createLink({
      title: "Example Docs",
      url: "https://example.com/docs",
      project: "Product",
      typeMode: "fixed"
    });
    window.location.assign(href);
  } catch (error) {
    document.querySelector("#add-status").textContent = error.message;
  }
});
</script>
```

どちらも検証済みURL文字列を返します。保存・クリップボード読取・ネットワーク送信・アプリ起動は行いません。不正な項目や上限超過は例外として扱い、呼出側で表示してください。`createLink` と `createDesktopLink` の引数は同じoptionsオブジェクトです。

JSON Schemaはこのoptionsオブジェクトを検証するための資料です。JSONファイルの作成・コピー・手動貼付を実装手順へ追加する必要はありません。

## 5. Notes文書の追加

外部アプリ側で、ボタン名と**完成済みNotes URL**を取得してください。たとえば、既に取得した文書オブジェクトのLotusScript `NotesDocument.NotesURL`、Domino JavaScript `getNotesURL()` を使います。これらはNotes / Domino APIであり、一般のブラウザに存在するAPIではありません。URLが空なら追加せず、取得元で原因を確認してください。[HCL NotesURL](https://help.hcl-software.com/dom_designer/14.0.0/basic/H_NOTESURL_PROPERTY_DOCUMENT_COM.html)、[HCL getNotesURL()](https://help.hcl-software.com/dom_designer/14.0.0/reference/r_domino_Document_NotesURL.html)。

文書IDだけを `notes://` へつなげても十分ではありません。データベース名またはレプリカID、必要なサーバー情報、文書のUNID等が必要です。NoteIDはレプリカ間で変わるため、正式なAPIが返すURLを優先してください。LinkJumkeyはIDからサーバーやデータベースを推測しません。[HCL Domino URLの構成](https://help.hcl-software.com/dom_designer/14.0.0/reference/r_domino_Session_resolve.html)。

次は完成済みNotes URLと名前を入力できる、ブラウザ／Web画面内の実装例です。追加を押すとPC版を開くURIへ遷移します。ブラウザやOSが起動の許可を求めた場合は、利用者が確認します。ネイティブアプリでは、同じURIをその開発環境のOS URLハンドラーで開いてください。

```html
<label>Title <input id="notes-title" required></label>
<label>Complete Notes URL <input id="notes-url" required></label>
<button id="add-notes" type="button">Add to LinkJumkey</button>
<p id="notes-status" role="status"></p>
<script src="https://linkjumkey.matsumotojoho.com/add-button-link.js"></script>
<script>
document.querySelector("#add-notes").addEventListener("click", () => {
  try {
    const href = LinkJumkeyAddButton.createDesktopLink({
      title: document.querySelector("#notes-title").value,
      url: document.querySelector("#notes-url").value,
      project: "Notes",
      typeMode: "fixed"
    });
    window.location.assign(href);
  } catch (error) {
    document.querySelector("#notes-status").textContent = error.message;
  }
});
</script>
```

- PC版1.8.21以降で追加内容を確認して保存します。Notes文書を開くのは、保存後に利用者がそのボタンを押したときです。
- Notesクライアント、OSの `notes:` ハンドラー、文書へのアクセス権は利用者の環境側に必要です。ボタンを保存できても対象文書を開けることまでは保証しません。
- Notesリンクは `fixed` のみで、Web版への保存導線は使えません。
- Notesの画面操作、文書取得、タイトル取得、クリップボード読取は外部アプリ側の仕事です。LinkJumkeyが自動取得するAPIはありません。

### 任意：依頼された場合だけクリップボードを名前の入力に使う

通常は元アプリのタイトルや入力欄を使います。「クリップボードの文字を名前にする」と依頼された場合に限り、外部ツールが読み取る次の入力補助を上の例へ追加できます。ブラウザでの読み取りにはHTTPS・許可が必要です。拒否や未対応なら、利用者に**外部ツールの名前入力欄 `#notes-title`**へ手入力・貼り付けしてもらいます。クリップボードは名前の入力元であり、JSONや追加リンクの出力先にはしません。LinkJumkeyへのCtrl+Vを受け渡し操作にしないでください。

```html
<button id="read-notes-title" type="button">Use clipboard as title</button>
<script>
document.querySelector("#read-notes-title").addEventListener("click", async () => {
  const titleInput = document.querySelector("#notes-title");
  const status = document.querySelector("#notes-status");
  try {
    if (!window.isSecureContext || !navigator.clipboard?.readText) {
      throw new Error("Clipboard unavailable");
    }
    titleInput.value = (await navigator.clipboard.readText()).trim();
    status.textContent = "Review the title, then select Add to LinkJumkey.";
  } catch {
    status.textContent = "Enter or paste the title into this external tool's Title field, then select Add to LinkJumkey.";
    titleInput.focus();
  }
});
</script>
```

読み取り後も、上の追加ボタンから同じ `createDesktopLink` 処理へ進みます。動く例は [HTMLサンプル](https://linkjumkey.matsumotojoho.com/examples/add-button.html#notes) を参照してください。

### Windowsの外部ツールから渡す例

この例は外部ツールが受け取った名前を `-Title`、完成済みNotes URLを `-NotesUrl` 引数で渡し、実際にURIを開きます。呼び出しは利用者の追加操作から行ってください。起動の許可とLinkJumkeyでの保存は利用者が行います。

```powershell
param(
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$NotesUrl
)
$title = $Title.Trim()
if (-not $title) { throw 'Supply a button title.' }
if (-not $NotesUrl.StartsWith('notes://', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Supply the complete Notes URL obtained from the source app.'
}
$fields = [ordered]@{ title = $title; url = $NotesUrl; project = 'Notes'; typeMode = 'fixed' }
$query = ($fields.GetEnumerator() | ForEach-Object {
  [Uri]::EscapeDataString([string]$_.Key) + '=' + [Uri]::EscapeDataString([string]$_.Value)
}) -join '&'
Start-Process -FilePath ('linkjumkey://add?' + $query)
```

## 6. 長さ・エンコード・情報の扱い

個別項目の上限に加えて、生成するHTTPSリンク / 直接追加URIの全体は8000文字までです。さらに、PC版へ渡すUTF-8 JSONのBase64URLエンコード結果（`d`）も8000文字までです。どちらの上限も満たす必要があります。日本語・絵文字・メモ・URLの組合せにより、個別上限内でも合計で超えることがあります。SDKの検証結果を最終判断にし、超える場合は値を短くするか既存のJSONファイル取り込みを使ってください。

HTTPSリンクの `#` 以降は通常のHTTPリクエストには送られません。ただし、共有したリンクを受け取る人、ブラウザ、取り込みページ内のスクリプトからは読めます。機密情報・トークン・パスワードを入れないでください。元のサイトURLのクエリに機密情報がないかも確認してください。

この契約は「ボタンの提案・追加」です。URLの即時実行、任意スクリプト実行、既存ライブラリ読取、確認なしの保存、既存ボタンの上書き・削除、保存成功通知は提供しません。利用者の未保存入力を消す前提の実装にしないでください。

## 7. 別用途：既存の複数ボタンJSON形式

リンク集を一括配布・移行するときの形式です。単一ボタンの外部連携を実装する通常の手順は上の追加リンクで完結します。JSONを利用者のクリップボードへ出力する処理へ置き換えないでください。

`https://linkjumkey.matsumotojoho.com/import.html#d=<Base64URL(UTF-8 JSON)>` と、PC版の `linkjumkey://import?d=<同じ値>` は既存の取り込み形式です。`#add=1` と `#d=` を同時に指定しないでください。

PC / Web共通には、`files[project]` が `root` と `nodes` を持つversion 2のツリーを推奨します。古い `files[project] = [items]` の配列形式はDesktopでは扱えてもWebでは扱えないため、新規の連携では生成しないでください。SDKを使うと単一ボタンのツリー構造やIDを外部側で作る必要はありません。

Desktop 1.8.20で利用する場合は、HTTPSの取り込みページから通常ウィンドウへ `http` / `https` ボタンを渡します。Notesと直接 `linkjumkey://add` は1.8.21以降が必要です。

## 8. AIへの依頼テンプレート

```text
目的: 外部アプリ／Webサイトに、実際に使える「LinkJumkeyに追加」機能を実装してください。
リンク集のJSONを一度だけ生成する依頼ではありません。
公式仕様とSDK options検証用のJSON Schema:
https://linkjumkey.matsumotojoho.com/developers/add-button.md
https://linkjumkey.matsumotojoho.com/developers/add-button.schema.json
仕様URLを取得できない場合は読めなかった旨を報告して、仕様をAIとの会話へ貼り付けるよう依頼してください。古いJSON方式や架空APIへ推測で切り替えないでください。

入力:
- 元アプリが取得した名前をtitle、完成済みURLをurlとして渡します。
- 開発言語、元アプリAPI、入力の取得方法が不明なら確認し、架空のAPIを作らないでください。
- Notesは正式APIのNotesURL/getNotesURL()を優先し、文書IDだけからURLを推測しないでください。
- クリップボードは私が名前の入力元に指定した場合だけ、外部ツールが読み取ってtitleへ使います。拒否・未対応・空文字の場合は、外部ツールの名前入力欄へ手入力・貼り付けできます。

処理:
- 使用する方式、完全な受け取りURL、HTTPメソッド（PC直接形式はHTTPなし）、開いたときの期待結果を示してください。
- 追加リンクのlocalhostポート、実行ファイルのパス、APIトークンを利用者へ要求せず、末尾のパスを推測させないでください。
- Webはhttps://linkjumkey.matsumotojoho.com/import.html#add=1&…へブラウザでGET、PC直接はlinkjumkey://add?title=…&url=…をOSで開きます。
- WebサイトはcreateLink(options)、Notes／PCツールはcreateDesktopLink(options)で追加リンクを作ります。
- 名前付き項目を使い、元の文字列を一度だけエンコードします。
- 利用者が外部ツールの追加ボタンを押したら、生成したリンクをlocation.assignやOSのURLハンドラーで実際に開きます。
- projectは指定した同名プロジェクトのルート、未指定なら「外部サイト」です。なければ新規作成されます。
- 合併を既定として案内し、置き換えの影響を説明します。このリンクで任意フォルダは選べません。

成果物:
- 元アプリへ組み込めるコード、追加ボタン、入力エラー表示、導入・動作確認手順をください。
- SDK optionsはコード内で使います。JSONファイルの生成だけや、名前・URL・JSON・追加リンクのクリップボード出力だけでは完成としないでください。
- LinkJumkeyへCtrl+Vして新規作成する手順は案内しないでください。この外部連携は追加リンクを開いて確認・保存する手順です。

完了条件:
- 外部ツールの追加ボタンのクリックからLinkJumkeyの取り込み確認画面まで進むことを確認してください。
- ブラウザ／OSの起動許可と最終保存は利用者が行います。自動保存・URLの自動実行は追加しません。
- 利用者が保存すると指定プロジェクトに追加され、キャンセルすると追加されないことを確認してください。
- 実行環境がなく未確認の項目は、確認済みと分けて報告してください。保存成功コールバックはありません。
```

## 9. 実装時の確認例

1. 日本語名、`&` / `#` / `%20`を含むURLを往復して、名前（前後空白除去後）とURLが変わらないこと。
2. 名前とURLの順序を入れ替えて同じボタンになること。
3. 初期表示だけではアプリ起動・保存・クリップボード読取が起きないこと。
4. Notes URLを文字列のまま渡し、文書IDだけの不完全な値を組み立てないこと。
5. クリップボード入力を依頼された場合は、外部ツールが名前として読み取り、拒否・API未対応・空文字でも外部ツールの名前欄へ手入力できること。データのクリップボード出力、LinkJumkeyへのCtrl+V案内、貼り付けキーの自動送信を追加していないこと。
6. 長い入力・不正なスキーム・Notesのtemplate指定を拒否すること。
7. Desktop通常画面とMulti-Paneで確認し、キャンセル時に保存せず、保存後の再起動でも1件だけ残ること。
8. 実装した追加ボタンを押して、生成した文字列を表示するだけで終わらず、取り込み確認画面へ進めること。Web経由では利用者が「LinkJumkey で開く（PC）」を押すところも確認すること。
9. `project` 省略、既存の同名プロジェクト、存在しないプロジェクトで、合併による追加先が仕様どおりであること。
