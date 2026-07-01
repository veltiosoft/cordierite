# AGENTS.md

Cordierite リポジトリで作業する Coding Agent 向けの索引。詳細は各リンク先を参照すること。

## プロジェクト概要

macOS 用のローカル音声入力メニューバーアプリ。ホットキーで録音し、オンデバイスで文字起こししてカーソル位置に貼り付ける。

- ユーザー向け概要・初回セットアップ: [README.md](README.md)
- アプリ仕様・設計: [docs/macos-app-spec.md](docs/macos-app-spec.md)
- 変更履歴: [CHANGES.md](CHANGES.md)

## ドキュメント索引

| ドキュメント | 用途 |
|---|---|
| [README.md](README.md) | ビルド要件、初回セットアップ、基本操作、Whisper モデル |
| [docs/macos-app-spec.md](docs/macos-app-spec.md) | アプリ仕様、MVP 範囲、モジュール構成、テスト計画 |
| [docs/billing-design.md](docs/billing-design.md) | Pro 課金・**アカウント登録戦略**（Stripe + マジックリンク + Cloudflare Workers） |
| [docs/benchmark/speech-engine-comparison.md](docs/benchmark/speech-engine-comparison.md) | Apple Speech vs Whisper の精度・遅延・メモリ比較 |
| [CHANGES.md](CHANGES.md) | リリース前の変更履歴 |
| [issues/](issues/) | 未対応・対応中の作業一覧（`issues/SEQUENCE` で次番号を管理） |

## 要件

- macOS 26 以上
- Apple Silicon Mac
- Xcode 26 以上
- Swift 6

## ビルド

Swift ファイルを修正した後は `xcodebuild` でビルドし、エラーがないことを確認する。コミット前のビルド確認を省略しない。

### コマンドライン

```bash
xcodebuild \
  -project Cordierite/Cordierite.xcodeproj \
  -scheme Cordierite \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

ビルド成果物は DerivedData 配下。Xcode の **Product → Show Build Folder in Finder** から `Cordierite.app` を起動できる。

### テスト

`CordieriteTests` ターゲットは未作成（[issues/0008-test-xctest-mvp-plan.md](issues/0008-test-xctest-mvp-plan.md) 参照）。追加後は次で実行する。

```bash
xcodebuild \
  -project Cordierite/Cordierite.xcodeproj \
  -scheme Cordierite \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

## 製品サイト (`site/`)

製品 LP は [`site/`](site/) 配下の静的 HTML。本番デプロイは Cloudflare **Workers Builds** が `main` への push（`site/` 変更時）で自動実行する。

- Coding Agent は **`npm run deploy` および `wrangler deploy` を実行しない**（手動デプロイも行わない）
- ローカル確認のみ `cd site && npm run dev`（`wrangler dev`）を使う

## Git 運用

- 既定ブランチ: `main`
- commit を作成する場合は `agent-commit-policy` SKILL を参照すること
- ユーザーから明示的に依頼されない限り commit / push しない

## 関連 SKILL

Cordierite の実装で参照する SKILL。

| SKILL | 用途 |
|---|---|
| `apple-speech-transcription` | Apple Speech / SpeechAnalyzer 連携 |
| `apple-foundation-models` | Apple Intelligence 連携（将来用） |
| `review-diff-code` | 差分レビュー |
| `review-code` | コードベース全体レビュー |

