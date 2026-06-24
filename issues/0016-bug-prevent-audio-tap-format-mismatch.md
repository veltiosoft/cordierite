# 音声入力 tap の format mismatch クラッシュを防ぐ

- Priority: High
- Created: 2026-06-24
- Completed: {YYYY-MM-DD}
- Model: GPT 5.5
- Branch: feature/fix-audio-tap-format-mismatch
- Polished: {YYYY-MM-DD}

## 目的

録音開始時に `AVAudioNode.installTap` が `format mismatch` で例外を投げ、アプリがクラッシュする経路をなくす。
音声入力の tap は認識エンジン向けの 16 kHz ではなく、現在の入力デバイスのハードウェア形式と互換のある形式で作成し、16 kHz 変換は既存の後段変換に任せる。

## 優先度根拠

High。ホットキー録音開始時に発生し、ユーザー操作でアプリが落ちる可能性がある。
既存の録音失敗フィードバックより前に `NSException` として落ちるため、ユーザーに復旧方法を示せない。

## 現状

- エラーログでは `AVAudioEngineGraph InstallTapOnNode` が、入力ハードウェア 48 kHz に対して client format 16 kHz で tap を作ろうとして失敗している
- スタックトレースは `AudioCaptureSession.start(deviceUID:tapHandler:)` の `inputNode.installTap(onBus:bufferSize:format:block:)` と `RecordingController.startAudioCapture` を指している
- Xcode 上では `CordieriteApp.swift` の `MenuBarExtra` 行で `Task 79: EXC_BAD_ACCESS` と表示されることがあるが、この行は SwiftUI Scene のトップレベルであり、ログ上の録音開始スタックとは直接対応していない
- 現行実装では `AudioCaptureSession` が `inputNode.outputFormat(forBus: 0)` を tap format に渡し、`WhisperPCMBuffer` / `SpeechAnalyzerEngine` が `AudioBufferConverter` で後段変換する構成になっている
- 選択マイクへ `setDefaultInputDevice` した直後や、入力デバイスの実体が変わった直後に、`AVAudioEngine` / `inputNode` から得た format が実ハードウェアとずれている可能性がある
- `installTap` の失敗は Swift の `throw` ではなく `NSException` として表面化するため、現状の `do/catch` や `RecordingFeedback` では吸収できない

## 設計方針

- `AudioCaptureSession` は tap を作る前に、選択済み入力デバイスと `AVAudioEngine` の input format が一致していることを保証する
- マイク切り替え直後の stale な format を避けるため、必要なら `AVAudioEngine` を作り直す、または input node の再取得・format 検証を行う
- tap format には認識エンジン都合の 16 kHz を渡さない。録音 buffer のリサンプリングは `AudioBufferConverter` に集約する
- format mismatch を再現できる範囲でログを追加し、少なくとも device UID、tap format、input node format を確認できるようにする

## 完了条件

- 48 kHz 入力デバイスで録音開始しても `Failed to create tap due to format mismatch` でクラッシュしない
- Xcode が `MenuBarExtra` 行で停止する場合でも、録音開始時の full stack trace とログから tap 作成失敗の有無を確認できる
- Apple Speech と Whisper のどちらを選んでも、tap は入力デバイス互換形式で作成され、認識エンジンには既存の変換済み buffer が渡る
- マイク選択を変更した直後の録音開始でもクラッシュしない
- 再現が難しい場合でも、tap 作成直前の format 診断ログから原因を追える

## 解決方法

- `AudioCaptureSession.start` で `setDefaultInputDevice` 後に `AVAudioEngine` / `inputNode` の状態をリフレッシュし、tap format が実入力形式とずれないようにする
- `installTap` 直前に `inputNode.outputFormat(forBus: 0)` の sample rate / channel count を記録し、16 kHz が tap format として入る経路が残っていないか確認する
- `RecordingController` の音声供給経路は、tap で得た hardware format buffer をそのまま `SpeechRecognitionEngine.processAudioBuffer` に渡し、各 engine 側の `AudioBufferConverter` で変換する方針を維持する
- 可能なら `AudioBufferConverter` 付近のユニットテスト、または手動検証手順として 48 kHz マイク + Apple Speech / Whisper の録音開始を追加する
