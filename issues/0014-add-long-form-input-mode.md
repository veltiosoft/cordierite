# 長文入力モード（Pro 想定）を設計する

- Priority: Low
- Created: 2026-06-22
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/add-long-form-input-mode
- Polished: 2026-06-24

## 目的

仕様書 Pro 機能「長文入力モード」（`docs/macos-app-spec.md` 133–135 行）の要件を整理し、既存 Hold to Talk / Toggle との共存方針と状態機械拡張案を文書化する。

## 優先度根拠

Low。MVP のホットキー短文入力（`maxRecordingSeconds` 既定 120 秒、`SilenceDetector` による無音破棄）とは別 UX。課金ゲートは `0015` 実装後。

## 現状

- 録音はホットキー押下中（Hold）または Toggle の 2 モードのみ（`InputMode`）
- `AppState`: loading / ready / starting / recording / processing / needsSetup（`Core/AppState.swift`）。長文専用状態なし
- `RecordingController` は `maxRecordingSeconds` で上限、`SilenceDetector`（最短 0.3 秒、RMS 閾値 0.003）で無音破棄
- Whisper は停止後バッチ transcribe（`WhisperEngine`）。長時間 PCM 蓄積のメモリ上限は未設計
- 仕様書: 長文は通常入力より長い上限、段落分割・強めの post-processing

## 設計方針

- **起動方法（設計メモで 1 案に絞る）**
  - 案 A: Settings で **Long Form Mode** トグル（Pro ゲート）
  - 案 B: 別ホットキー（例: F13 長押し）— ホットキー競合の検討が必要
- **録音上限**: 通常 `maxRecordingSeconds`（10–300、既定 120）とは別に `longFormMaxRecordingSeconds`（例: 600–1800）を `AppConfiguration` に追加する案
- **無音処理**: 長文モードでは `SilenceDetector.shouldDiscard` を緩和するか、段落区切り（無音 2 秒）で partial finalize するかを設計メモで比較
- **Whisper**: 長時間 PCM は `WhisperPCMBuffer.Accumulator` のメモリ上限・チャンク分割 transcribe を設計。Apple Speech は partial ストリームを段落単位で flush する案
- **UI**: 長文モード中は MenuBar を **Long Recording** 等に表示。Toggle との相互作用（長文中に Toggle 停止）を定義
- **Pro ゲート**: 0015 の `ProCapabilities.longFormInput` stub 連動を設計メモに記載。本 issue ではゲート実装しない

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `docs/long-form-input-mode.md` |

## 完了条件

- [ ] `docs/long-form-input-mode.md` に UX フロー（開始・停止・キャンセル）が書かれている
- [ ] `AppState` / `RecordingController` / `SilenceDetector` / `WhisperEngine` への影響範囲が表形式で列挙されている
- [ ] 録音上限・無音閾値・メモリ上限の推奨値と根拠がある
- [ ] 実装用 follow-up issue 分割案（状態機械、UI、Whisper チャンク、Pro ゲート）がある

## 実装方針

1. 仕様書 Pro 節と現行 `AppModel` / `RecordingController` を読み、設計メモを書く
2. Hold to Talk との共存（長文モード中も同じホットキーか別キーか）を 1 案に決める
3. follow-up issue 案を末尾に列挙する

## スコープ外

- 長文モードの本実装
- Stripe 課金基盤（0015。`docs/billing-design.md` 参照）
- 音声ファイル一括文字起こし（仕様書 Pro の別機能）
