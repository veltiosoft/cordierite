# アプリ別プロファイル・文体プリセット（Pro 想定）を設計する

- Priority: Low
- Created: 2026-06-22
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/add-app-profile-presets-pro
- Polished: 2026-06-24

## 目的

仕様書 Pro 機能「アプリ別プロファイル・文体プリセット」（`docs/macos-app-spec.md` 103–131 行）の要件を整理し、MVP 後の実装に向けたデータモデルと UI 方針を定める。

## 優先度根拠

Low。収益化・差別化機能であり、現 MVP には必須ではない。課金ゲートは `0015-add-billing-foundation` 実装後。

## 現状

- 単一の `AppConfiguration`（`Settings/Models/AppConfiguration.swift`）のみ。プロファイル切替なし
- `TextPostProcessor` は global 設定（`removeFillerWords`）のみ
- 仕様書 Pro 節: bundle identifier 単位のアプリ別プロファイル、文体プリセット（Plain / Slack / Email / Markdown / GitHub Issue / Git Commit Message）
- ユーザー辞書（0007）は global 想定。Pro では「適用範囲」拡張を将来検討

## 設計方針

- **本 issue の成果物は設計 + 最小スケルトン**。フル Pro 機能実装は別 issue とする
- **プロファイル定義**: 1 プロファイル = 次のバンドル
  - 認識エンジン選択（`RecognitionEngineOption` + whisper model）
  - 言語設定（Apple Speech / Whisper 各々）
  - post-processing 設定（`removeFillerWords`、将来の文体プリセット ID）
  - 辞書スコープ（global / app-specific — 0007 完了後）
  - 貼り付け方法（`PasteMethodOption`）
- **アクティブプロファイル解決**: フォアグラウンドアプリの bundle ID（`NSWorkspace.shared.frontmostApplication`）から自動選択。マッチなしは Default プロファイル
- **データ永続化**: `Application Support/Cordierite/profiles.json` + `AppConfiguration` に `activeProfileID` を追加する案を設計メモに記載
- **UI 方針**: Settings に Profiles タブ（または Section）のワイヤ。Pro 未加入時は read-only プレビュー + upgrade 案内（0015 後）
- **課金**: 本 issue では `ProCapabilities` への依存を型コメント程度に留め、実ゲートは 0015 後

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `docs/app-profiles-design.md` |
| 新規（任意） | `Cordierite/Cordierite/Settings/Models/InputProfile.swift`（stub 型のみ） |
| 新規（任意） | Settings の placeholder Section |

## 完了条件

- [ ] `docs/app-profiles-design.md` にデータモデル、永続化、フォアグラウンドアプリ解決、仕様書 Pro 節との対応表がある
- [ ] 文体プリセット 6 種の初期定義と post-processing への適用方針が書かれている
- [ ] 実装着手用の follow-up issue 分割案（例: プロファイル CRUD、自動切替、Pro ゲート）が設計メモ末尾にある
- [ ] （任意）`InputProfile` stub 型がコンパイル可能

## 実装方針

1. 仕様書 Pro 節を読み、設計メモを書く
2. 必要なら `InputProfile` 空 struct / enum を追加する
3. follow-up issue 案を設計メモに列挙する（`create-issue` はユーザー承認後）

## スコープ外

- Stripe 課金基盤（0015。`docs/billing-design.md` 参照）
- プロファイル自動切替の本実装
- LLM 整形
