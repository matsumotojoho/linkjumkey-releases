# LinkJumkey（リンクジャンキー）

よく使うURLをボタンにして、「次に確認すること」をメモとして残せるアプリです。プロジェクトごとにリンクを整理し、PC版ではファイルやアプリを開くボタンも作れます。

[公式サイト](https://linkjumkey.matsumotojoho.com/) · [登録不要の操作体験](https://linkjumkey.matsumotojoho.com/solutions/sales-start.html) · [English demo](https://linkjumkey.matsumotojoho.com/solutions/project-notes.html)

このリポジトリでは、LinkJumkey Desktop / Hostのインストーラーなどを配布しています。

## 今すぐ使う

| 使う場所 | 入口 | 補足 |
|---|---|---|
| Web | [Web版を開く](https://linkjumkey.matsumotojoho.com/app.html) | インストール不要。保存にはメール確認が必要です |
| Windows（x64） | [インストーラーをダウンロード](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest/download/LinkJumkey-Host-Windows-Setup.exe) | コード署名なし。SmartScreenの確認が表示される場合があります |
| macOS（Intel / Apple Silicon） | [DMGをダウンロード](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest/download/LinkJumkey-Host-macOS.dmg) | Universal版。署名・公証済み |
| iPhone / iPad | [App Storeで入手](https://apps.apple.com/jp/app/linkjumkey/id6790680825) | URL・メモの確認やスマホPadに |

初めての方は、[インストールと最初のボタンの作り方](https://linkjumkey.matsumotojoho.com/guide/getting-started.html)をご覧ください。更新内容・その他の配布ファイルは[最新リリース](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest)にあります。

## まず1つ、URLにメモを残す

1. [登録不要の体験ページ](https://linkjumkey.matsumotojoho.com/solutions/sales-start.html)を開きます。
2. ボタン名・URL・メモを入力します。たとえば「案件の議事録」に「次回：確認待ちの2点を聞く」と残します。
3. ボタンを作成し、押すと入力したURLが開きます。続けて使う場合はWeb版へ保存できます。

元のサイトや資料の閲覧権限は変わりません。自分がアクセスできるURLを使ってください。

## こんな使い方に

- 複数案件の要件書・タスク・成果物を、プロジェクトごとにまとめる
- よく検索する語句を入力し、必要な検索先のボタンを選ぶ
- PCのファイルやアプリを、仕事ごとのボタンから開く
- スマホをPCの左手デバイスとして使う（[Padの接続・操作ガイド](https://linkjumkey.matsumotojoho.com/guide/mobile-companion.html)）

Freeプランは30ボタンまで。有料プランの機能・価格・無料試用の適用条件は[公式料金ページ](https://linkjumkey.matsumotojoho.com/pricing.html)と購入画面で確認できます。購入経路によって価格・条件が異なります。

## AI連携（MCP）

Claude Desktop などのMCP対応AIツールから、LinkJumkey のプロジェクトを読んだり、URLボタンを追加したりできます。PC操作ボタン（アプリ起動・キー送信・Excelマクロなど）はAIが提案するだけで、PC版の承認画面で内容を確認してから保存します。ボタンの実行・完全削除・スクリプト作成はできません。

- 接続ファイル：[LinkJumkey.mcpb](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest/download/LinkJumkey.mcpb)（PC版のインストールと起動が必要です）
- 設定手順：[AIと作業を進め、メモから再開する](https://linkjumkey.matsumotojoho.com/guide/mcp-setup.html)
- 公式 MCP Registry：`io.github.matsumotojoho/linkjumkey`

## AIで外部ツールを作る

LinkJumkey Desktop 1.8.24以降では、同じPCの外部ツールからプロジェクトを選び、検索結果などのURLをボタンとして保存できます。AIに開発を依頼する場合は、次の仕様と完成サンプルを渡してください。公式サイトをAIが取得できない場合にも使えるよう、公開済みの資料をこのリポジトリの `docs/` にコピーしています。

AIには「このMarkdown仕様を読んで、外部ツールのプログラムを実装・検証して」と依頼します。一括登録JSONの作成やクリップボード取り込みは別の機能です。

- [外部ツールのAPI仕様・接続手順](https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/external-tools.md) / [AI向けRaw本文](https://raw.githubusercontent.com/matsumotojoho/linkjumkey-releases/main/docs/developers/external-tools.md)
- [機械可読OpenAPI](https://raw.githubusercontent.com/matsumotojoho/linkjumkey-releases/main/docs/developers/integrations-api.openapi.json)
- [検索語を外部スクリプトへ渡す契約](https://raw.githubusercontent.com/matsumotojoho/linkjumkey-releases/main/docs/guide/linkjumkey-input-arguments.txt)
- [WindowsのPowerShell＋SQLite完成サンプルと実行手順](https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/examples/customer-search/README.md) / [7ファイル入りZIP](https://raw.githubusercontent.com/matsumotojoho/linkjumkey-releases/main/docs/examples/customer-search.zip)
- [Webサイト・Notesから、利用者が確認して追加する方式](https://github.com/matsumotojoho/linkjumkey-releases/blob/main/docs/developers/add-button.md)

資料の正本と人向けの手順は[公式の外部ツール開発ガイド](https://linkjumkey.matsumotojoho.com/guide/external-tools.html)です。サンプルは架空の顧客DBを生成して使い、実データ・認証キー・実行結果は配布していません。接続先とキーは利用者のPCで確認し、キーをAIへ渡したり公開コードへ書き込んだりしないでください。

## English

Keep a note beside the links you use at work. Organize buttons by project, then open the link and see what to check next.

[Try the English demo](https://linkjumkey.matsumotojoho.com/solutions/project-notes.html): enter a label, URL and note, create a button, then press it. No sign-up is needed to try. Verify your email to save your buttons in the [Web app](https://linkjumkey.matsumotojoho.com/app.html?lang=en).

This repository distributes the desktop app. macOS builds are signed and notarized; the Windows installer is currently unsigned. See the [latest release](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest) for downloads and release notes.

MCP: Claude Desktop and other MCP clients can read your LinkJumkey projects and add http/https link buttons with notes. PC operation buttons are only proposed: they open an approval screen in the desktop app and are saved after you confirm. There are no run, delete, or custom-script tools. Requires LinkJumkey Desktop (macOS / Windows) running on the same PC. [Download LinkJumkey.mcpb](https://github.com/matsumotojoho/linkjumkey-releases/releases/latest/download/LinkJumkey.mcpb)

## ガイド・問い合わせ

[使い方](https://linkjumkey.matsumotojoho.com/guide/index.html) · [データの保存先と通信](https://linkjumkey.matsumotojoho.com/security.html) · [プライバシー](https://linkjumkey.matsumotojoho.com/privacy.html)

松本情報処理　松本優飛 · [ymatsumoto@matsumotojoho.com](mailto:ymatsumoto@matsumotojoho.com)
