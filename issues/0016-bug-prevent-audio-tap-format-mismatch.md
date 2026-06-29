# 音声入力 tap の format mismatch クラッシュを防ぐ

- Priority: High
- Created: 2026-06-24
- Completed: 2026-06-29
- Model: GPT 5.5
- Branch: feature/fix-audio-tap-format-mismatch
- Polished: 2026-06-24

## 目的

録音開始時に `AVAudioNode.installTap` が format mismatch で `NSException` を投げ、アプリがクラッシュする経路をなくす。
tap format は入力デバイスのハードウェア互換形式を使い、16 kHz への変換は既存の `AudioBufferConverter` 後段に任せる。

## 優先度根拠

High。ホットキー録音開始時に発生し、ユーザー操作でアプリが落ちる。`RecordingFeedback` より前に `NSException` で終了するため復旧 UI を示せない。

## 現状

- クラッシュログ: `AVAudioEngineGraph InstallTapOnNode` が入力 48 kHz に対し client format 16 kHz で tap 作成を試みて失敗
- スタック: `AudioCaptureSession.start` → `inputNode.installTap` → `RecordingController.startAudioCapture`（`Core/RecordingController.swift` 114–138 行）
- Xcode 上 `CordieriteApp.swift` の `MenuBarExtra` 行に `EXC_BAD_ACCESS` と出ることがあるが、ログ上の原因は tap 作成失敗。SwiftUI Scene 行は二次的な停止表示
- **現行コード**（`Audio/AudioCaptureSession.swift` 93–101 行）: `inputNode.outputFormat(forBus: 0)` を tap format に使用。16 kHz を直接渡す経路は **ない**
- **残るリスク**
  - `AudioCaptureSession` は `AVAudioEngine` インスタンスを使い回す。`setDefaultInputDevice`（131–191 行）直後に `outputFormat` が実ハードウェアと stale になる可能性
  - 前回 capture 失敗後の tap / engine 状態が不完全に残る可能性
  - `installTap` 失敗は Swift `catch` 不可（Objective-C exception）
- 後段変換: `SpeechAnalyzerEngine` / `WhisperPCMBuffer` が `AudioBufferConverter`（`Audio/AudioConverterPipeline.swift`）で 16 kHz 等に変換

## 設計方針

- **Engine リフレッシュ**: `setDefaultInputDevice` 後、または device UID 変更時は `AVAudioEngine` を再生成する（または `stop` + input node reset）。stale format を避ける
- **tap format 検証**: `installTap` 直前に次を `NSLog` で記録する
  - 選択 device UID
  - `inputNode.outputFormat(forBus: 0)` の sample rate / channel count
  - 16 kHz が tap format に入っていないことの assert（Debug）
- **16 kHz 禁止**: tap format に認識エンジン都合の固定レートを渡さない。`WhisperPCMBuffer` / `SpeechAnalyzerEngine` 側 converter のみが resample する
- **NSException 対策**: Swift からは catch できないため、**事前検証** で mismatch を防ぐ
  - `AVAudioFormat` の sample rate > 0、channel count > 0
  - 必要なら `inputNode.inputFormat(forBus: 0)` と `outputFormat(forBus: 0)` の整合チェック
  - 検証失敗時は `AudioCaptureError.engineStartFailed` を throw し、`RecordingFeedback.startFailed` で表示
- **リトライ**: 既存の `RecordingController.startAudioCapture` の 150 ms リトライ（136–137 行）は `noInputReceived` のみ。format 問題向けに engine 再生成後 1 回リトライを検討
- **マイク切替直後**: `AppModel` で microphone 変更 → 次回 `startRecording` までに engine がリフレッシュされること

## 変更対象

| 種別 | パス |
|---|---|
| 更新 | `Cordierite/Cordierite/Audio/AudioCaptureSession.swift` |
| 更新 | `Cordierite/Cordierite/Core/RecordingController.swift`（必要なら） |
| 新規 | `Cordierite/CordieriteTests/AudioCaptureFormatTests.swift`（format 検証 pure logic が切り出せる場合） |

## 完了条件

- [ ] 48 kHz 入力デバイスで録音開始しても `Failed to create tap due to format mismatch` でクラッシュしない
- [ ] Apple Speech / Whisper いずれでも tap は hardware 互換 format、認識エンジンには converter 経由の buffer が渡る
- [ ] マイク選択変更直後の録音開始でもクラッシュしない
- [ ] tap 作成直前の format 診断ログ（device UID、sample rate、channels）が Console に出力される
- [ ] format 検証失敗時は `RecordingFeedback` でユーザーに復旧案内が出る（クラッシュしない）

## 手動検証手順

1. System Settings で 48 kHz マイクを選択
2. Cordierite で当該マイクを指定し、Apple Speech / Whisper それぞれで Hold to Talk 録音
3. Settings でマイクを切り替え直後に録音開始
4. Console で tap format ログを確認

## 実装方針

1. `AudioCaptureSession` に engine 再生成と format 検証を追加する
2. 検証失敗 path で `AudioCaptureError` を throw する
3. 診断ログを追加する
4. 手動検証手順どおり確認する

## スコープ外

- Objective-C exception bridge（事前検証で十分なら不要）
- 新規 `AudioCaptureError` 以外の RecordingFeedback 文言の全面見直し
