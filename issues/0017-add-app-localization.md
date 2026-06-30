# アプリ表示言語を英語・日本語に対応させる

- Priority: Medium
- Created: 2026-06-25
- Completed: {YYYY-MM-DD}
- Model: GPT 5.5
- Branch: feature/add-app-localization
- Polished: {YYYY-MM-DD}

## 目的

アプリのメニュー、設定画面、権限案内、確認ダイアログなどのユーザー向け文言を英語と日本語で表示できるようにする。
初回起動時のアプリ表示言語は英語を既定とし、ユーザーが必要に応じて日本語へ切り替えられるようにする。

## 優先度根拠

Medium。現状の UI 文言は英語で直書きされており、日本語ユーザー向けの案内が不足している。
一方で録音・文字起こしの中核機能をブロックする不具合ではないため、クラッシュ修正や認識品質改善よりは優先度を下げる。

## 現状

- Xcode project の `developmentRegion` は `en` で、`knownRegions` は `en` / `Base` のみ
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` だが、現時点で `Localizable.xcstrings` 等のローカライズ資源はない
- `MenuBarView` / `SettingsView` / `PermissionDoctorView` / `AppState` / `SetupIssue` などにユーザー向け英語文字列が直書きされている
- `AppConfiguration` にアプリ表示言語の設定はない
- 既存の `RecognitionLanguageOption` / `WhisperLanguageOption` は音声認識対象言語の設定であり、アプリ表示言語とは別責務

## 設計方針

- **表示言語設定**: `AppLanguageOption`（English / Japanese）を追加し、`AppConfiguration.appLanguage` の既定値は `.english` にする
- **既存設定互換**: 既存 `config.json` に `appLanguage` が無い場合は `.english` として読み込む
- **UI 配置**: Settings の General または新しい Appearance / Language セクションに **App Language** Picker を追加する
- **文言管理**: SwiftUI / AppKit の直書き文言をローカライズキー経由に寄せ、英語・日本語の翻訳を `Localizable.xcstrings` など Xcode 26 の方針に合う資源へ集約する
- **対象範囲**: メニューバー、設定画面、権限案内、録音フィードバック、Whisper モデルの Download / Delete 確認ダイアログを対象にする
- **音声認識言語とは分離**: Apple Speech / Whisper の Language 設定（System / English / Japanese、Auto Detect 等）は既存どおり維持する

## 変更対象

| 種別 | パス |
|---|---|
| 更新 | `Cordierite/Cordierite.xcodeproj/project.pbxproj` |
| 新規 | `Cordierite/Cordierite/Resources/Localizable.xcstrings`（配置は実装時に確定） |
| 更新 | `Cordierite/Cordierite/Settings/Models/AppConfiguration.swift` |
| 更新 | `Cordierite/Cordierite/Settings/SettingsView.swift` |
| 更新 | `Cordierite/Cordierite/UI/MenuBarView.swift` |
| 更新 | `Cordierite/Cordierite/UI/StatusLabel.swift` |
| 更新 | `Cordierite/Cordierite/Core/AppState.swift` |
| 更新 | `Cordierite/Cordierite/Permissions/PermissionDoctorView.swift` |
| 更新 | `Cordierite/Cordierite/Permissions/SetupIssue.swift` |
| 更新 | `Cordierite/Cordierite/Speech/WhisperModelDownloadPrompt.swift` |
| 更新 | `Cordierite/Cordierite/Speech/WhisperModelDeletePrompt.swift` |
| 更新 | `docs/macos-app-spec.md` |
| 更新 | `README.md` |

## 完了条件

- [ ] 初回起動時、アプリ表示言語が英語として扱われる
- [ ] Settings からアプリ表示言語を English / Japanese で切り替えられる
- [ ] メニューバー、設定画面、権限案内、録音フィードバック、Whisper モデル確認ダイアログの主要文言が英語・日本語で表示できる
- [ ] Apple Speech / Whisper の音声認識言語設定と、アプリ表示言語設定が UI / 設定モデル上で混同されない
- [ ] 既存 `config.json` に `appLanguage` が無い環境でも起動でき、英語既定で migration される
- [ ] `docs/macos-app-spec.md` と `README.md` に表示言語設定の説明が追加されている

## 実装方針

1. `AppLanguageOption` と `AppConfiguration.appLanguage` を追加し、decode 時は欠損を `.english` にフォールバックする
2. Xcode project に `ja` を `knownRegions` として追加し、英語・日本語のローカライズ資源を追加する
3. `String(localized:)` / `LocalizedStringKey` / 共通 helper のいずれかで SwiftUI と AppKit alert の文言を翻訳可能にする
4. Settings に App Language Picker を追加し、表示文言の切り替えタイミングを確認する
5. README / 仕様書に、アプリ表示言語と音声認識言語が別設定であることを明記する

## スコープ外

- 英語・日本語以外の言語追加
- 音声認識対象言語の追加
- 文字起こし結果の翻訳
- App Store のローカライズメタデータ（直接配布のため対象外）
