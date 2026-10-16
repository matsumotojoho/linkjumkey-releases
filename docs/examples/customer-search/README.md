# LinkJumkeyから架空の顧客DBを検索するWindowsサンプル

[7ファイルをまとめてダウンロード](../customer-search.zip)し、ZIPを展開してください。実DB、キー、PythonやPowerShell本体、実行結果は含みません。

LinkJumkeyの検索語入力 → PowerShell → ローカル顧客API → SQLite検索 → CSVとHTMLレポート、まで実際に動くサンプルです。半角カナ・日本語・引用符を扱い、SQLへ文字列を連結しません。保存するデータは同梱の架空8顧客だけです。

必要なものはWindows PowerShell 5.1、Python 3.9以降、PCコードに検索語を渡せるLinkJumkey Desktopです。新しい保存APIを使うためDesktop 1.8.24以降が対象です。Pythonパッケージの追加はありません。

## 1. デモAPIを起動する

このフォルダを `C:\LinkJumkeyCustomerDemo` に置き、PowerShellで実行します。

```powershell
Set-Location 'C:\LinkJumkeyCustomerDemo'
python .\demo_adapter.py
```

このターミナルは開いたままにします。`http://127.0.0.1:8765` だけで待ち受け、`demo-data` に合成SQLite DB・デモ用キー・レポート保存先を用意します。既存の実DBには接続しません。デモ用キーはLinkJumkeyの認証キーとは別物です。

ポートが使われていれば `--port 18765` のように変更し、以下のPowerShellにも `-DemoBaseUrl 'http://127.0.0.1:18765'` を付けます。`--data-dir` を変えた場合は `-DemoTokenFile` と `-ReportDirectory` も同じ場所に合わせます。

## 2. PowerShellだけで検索する

別のPowerShellウィンドウで実行します。

```powershell
Set-Location 'C:\LinkJumkeyCustomerDemo'
.\Search-Customer.ps1 -Query 'ｻｸﾗ' -OpenReport
```

2件の架空顧客が見つかり、ブラウザでHTMLが開きます。CSVはHTML内のリンクから取得できます。`demo-data\reports` にUTF-8 BOM付きで保存されます。`O'Reilly & Sons` は引用符を含む検索、`ｶﾞﾗｽ` は半角濁点の検索に使えます。

空欄はエラーにします。存在しない語は0件とCSVヘッダーを出力します。入力の内部改行は分割しません。半角カナと全角カナ、英字の大小を区別せず、`%` と `_` はワイルドカードではなく文字として検索します。

CSVで数式になる文字を先頭に持つセルは、アポストロフィを追加します。たとえば `=HYPERLINK` の検索は、この対策の確認用です。HTML中の検索語と顧客データはエスケープします。

## 3. LinkJumkeyボタンにする

LinkJumkeyで「PCでコードを使う」→Windows PowerShellを選び、`LinkJumkey-PC-code.ps1` の内容を貼り付けます。設置先を変えた場合は、その固定パスだけ変更します。「検索語入力欄の内容をコードに渡す」を有効にし、内容を確認して保存します。

検索語入力欄に `ｻｸﾗ` を入れて「PCで試す」を実行すると、件数とCSV・レポートの場所が出力されます。通常のボタンからも同じ外部検索が動きます。デモAPIは先に起動しておいてください。

検索語をPowerShellコード文字列やコマンド文字列に埋め込まないでください。固定スクリプトへの値として `$env:LINKJUMKEY_INPUT` を渡します。`powershell.exe` の起動時引数に `{検索語}` を使う方法は公式仕様で拒否されるため、このPCコード方式を使います。

PowerShellファイルはUTF-8 BOM付きのまま保存してください。組織のスクリプト実行ポリシーで拒否される環境では、組織の承認済みの配布・署名方法を使います。

## 4. 任意：検索レポートをLinkJumkeyに登録する

通常の検索はLinkJumkeyライブラリへ書き込みません。登録するときだけ、設定画面の「MCP / AI連携 → ローカルAPI（開発者向け）」で確認した接続先、利用者が供給する認証キー、保存先プロジェクト名を渡します。このPOSTは確認画面を挟まず、そのライブラリにボタンを保存します。

先にDesktopで検証用プロジェクト「顧客調査」を作ります。次の例は接続先とキーを利用者が設定するものです。キーはコマンド履歴へ直接書かず、伏せ字の入力欄で渡します。サンプルがユーザープロファイルから自動収集することはありません。

```powershell
$base = 'http://127.0.0.1:9634' # 設定画面に表示された接続先へ合わせる
$secureKey = Read-Host 'ローカルAPIキー' -AsSecureString
$token = [Net.NetworkCredential]::new('', $secureKey).Password
Import-Module .\CustomerDemo.psm1 -Force
$destinations = Get-LinkJumkeyDemoProjects -BaseUrl $base -Token $token
$destinations.projects | Select-Object -ExpandProperty name
.\Search-Customer.ps1 -Query 'ｻｸﾗ' `
  -RegisterResult `
  -LinkJumkeyBaseUrl $base `
  -LinkJumkeyToken $token `
  -Project '顧客調査'
```

`GET /api/projects` の各オブジェクトの `name` を厳密比較して保存先を選び、取得したidを `POST /api/quick-add` の `projectId` に指定します。オブジェクト全体を文字列として渡しません。未知の名前のプロジェクトは作成しません。

結果HTMLの `http://127.0.0.1:8765/reports/...html` をfixedボタンとして保存し、応答の `project.name`、`project.id`、`button.id`、`button.url` を確認します。日本語JSONはUTF-8バイト列で送ります。トークンをURLやレポートへ入れません。

同じレポートURLから同じrequestIdを作るため、その登録の再送は同じボタンを返します。検索コマンド全体を再実行すると新しいレポートと新しいボタンを作ります。APIは直近256件のrequestIdを記録します。通信エラー後は新しい結果を無条件に作り直さず、保存先を確認してください。

このURLは同じPCでデモAPIが動いている間だけ開けます。別PCやスマートフォンで開く共有URLではありません。CSVファイル自体をfile:のURLボタンにはしません。企業内で共有する場合は、アクセス制御のある社内レポートサービスへ置き換える必要があります。

### 検索して登録するところまで1ボタンにする

最初のラッパーは検索・表示用です。登録も行う場合は、次をLinkJumkeyのPCコード欄へ貼り、「検索語入力欄の内容をコードに渡す」をONにします。固定の設置先、設定画面の接続先、既存の保存先名を自分の環境に合わせます。

利用者が設定画面でコピーしたキーを、自分で `C:\LinkJumkeyCustomerDemo\private\linkjumkey-key.txt` に保存してください。フォルダーとファイルは利用者が用意し、キーだけをUTF-8のテキストで入れます。このprivateフォルダーを共有、配布ZIP、AIへの添付へ含めないでください。コードにキーそのものを書く必要はありません。

```powershell
$ErrorActionPreference = 'Stop'
try {
    $install = 'C:\LinkJumkeyCustomerDemo'
    $keyFile = Join-Path $install 'private\linkjumkey-key.txt'
    $token = [IO.File]::ReadAllText($keyFile, [Text.Encoding]::UTF8).Trim()
    & (Join-Path $install 'Search-Customer.ps1') `
      -Query $env:LINKJUMKEY_INPUT -OpenReport -RegisterResult `
      -LinkJumkeyBaseUrl 'http://127.0.0.1:9634' `
      -LinkJumkeyToken $token -Project '顧客調査'
    if (-not $?) { exit 1 }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
```

これはボタンを押すたびに新しい検索レポートを作り、直接保存する設定です。試す時も実際にボタンが追加されるので、検証用プロジェクトを指定してください。

### CSVはできたが登録の応答が返らなかった場合

検索スクリプトは登録前にCSVの場所とレポートURLを表示します。まずそのURLのHTMLとCSVがあること、LinkJumkeyの指定プロジェクトに同じURLが既にあるかを確認します。検索全体をもう一度実行する必要はありません。

同じ登録だけを再送する場合は、元のレポートURLを使います。`Add-LinkJumkeyDemoResult` はそのURLから元と同じrequestIdを計算します。元と同じ保存先を指定してください。

```powershell
Set-Location 'C:\LinkJumkeyCustomerDemo'
Import-Module .\CustomerDemo.psm1 -Force
$token = [IO.File]::ReadAllText('.\private\linkjumkey-key.txt', [Text.Encoding]::UTF8).Trim()
$reportUrl = Read-Host '先ほど表示されたレポートURLをそのまま入力'
$saved = Add-LinkJumkeyDemoResult `
  -BaseUrl 'http://127.0.0.1:9634' -Token $token `
  -Project '顧客調査' -ResultUrl $reportUrl
$saved | Select-Object created, replayed, requestId
$saved.project.name
$saved.button.id
```

最初の保存が完了していれば `created: false`・`replayed: true` と同じボタンID、未保存なら `created: true` が返ります。409なら元の内容や保存先が変わっていないか確認します。直近256個の異なるrequestIdから元のキーが排除された後は重複抑止できないため、長期間後の再送は先に保存先の同じURLを確認してください。

## 5. 動作試験

デモAPIを起動した状態で：

```powershell
python -m unittest -v test_adapter
.\Test-WindowsDemo.ps1
```

人工トークン・隔離ライブラリのHostも用意した場合だけ、次を追加します。

```powershell
.\Test-WindowsDemo.ps1 `
  -LinkJumkeyBaseUrl $fixtureBaseUrl `
  -LinkJumkeyToken $fixtureToken `
  -Project '顧客調査'
```

Windows PowerShell 5.1とPowerShell 7で同じ試験を実行できます。最後に実行したアサーション数とPowerShellのバージョンを表示します。Python側は、DB接続が正常終了・途中エラーの両方で閉じられ、Windowsでも直後に試験ファイルを片づけられることを確認します。Desktopの画面で検索語を入力して押す試験は、CLI/API試験の成功と分けて確認してください。

## ファイル

| ファイル | 役割 |
| --- | --- |
| `Search-Customer.ps1` | 検索語を受け取る実行入口 |
| `CustomerDemo.psm1` | HTTP、CSV/HTML、任意のLinkJumkey登録 |
| `LinkJumkey-PC-code.ps1` | DesktopのPCコード欄に貼る固定ラッパー |
| `demo_adapter.py` | 合成SQLite検索API・結果HTML/CSV配信 |
| `Test-WindowsDemo.ps1` | PowerShell側の実通信と出力の試験 |
| `test_adapter.py` | Python・SQLite・HTTPの試験 |
| `README.md` | 必要環境、起動順、期待結果、保存APIの使い方 |

業務DBへ置き換える場合は、DB接続と認証、項目、権限、件数制限、データ保管方針を企業側の仕様に合わせます。サンプルの合成データ用APIをそのまま本番データ向けに公開する構成ではありません。

仕様: [外部ツール開発契約](../../developers/external-tools.md) · [GitHub版の仕様](https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/external-tools.md) · [手順ガイド](https://linkjumkey.matsumotojoho.com/guide/external-tools.html)
