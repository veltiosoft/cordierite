# Cordierite macOS アプリ仕様書

作成日：2026-06-21

## 目的

本アプリは、macOS 上で常駐するローカル音声入力アプリである。

ユーザーは任意のアプリでテキスト入力欄にフォーカスを置き、ホットキーを押して話す。
アプリは音声をオンデバイスで文字起こしし、必要な整形を行い、結果をカーソル位置に貼り付ける。

初期版は `SpeechAnalyzer` と `SpeechTranscriber` を使う。
Whisper は初期版に含めず、後から追加できる認識エンジンとして設計に残す。

## 開発方針

初期版は Swift ネイティブの macOS アプリとして作る。

音声認識は macOS 26 以上の `SpeechAnalyzer` を使う。
macOS 27 以上では `AnalyzerInputConverter` や `CaptureInputSequenceProvider` を使えるが、macOS 26 でも動かすために `AVAudioEngine` と `AVAudioConverter` の経路を基本実装とする。

アプリは音声データと文字起こし結果を永続化しない。
設定値だけを `Application Support` 配下に保存する。

## 対象環境

- macOS 26 以上
- Apple Silicon Mac
- Xcode 26 以上
- Swift 6 系
- AppKit または SwiftUI を使ったメニューバーアプリ

## MVP の範囲

MVP は次の中核体験を実装する。

- メニューバー常駐
- ホットキーによる録音開始と停止
- 入力モードの切り替え
- マイク入力の録音
- `SpeechAnalyzer` による文字起こし
- 文字起こし結果のカーソル位置への貼り付け
- クリップボード文字列の復元
- マイク権限、入力監視、アクセシビリティ権限の案内
- 英語と日本語の明示的な言語選択
- 無音と短すぎる録音の抑制
- 設定保存

MVP では次を含めない。

- Whisper 認識エンジン
- LLM による整形
- クラウド音声認識
- 音声ファイルの一括文字起こし
- 文字起こし履歴
- セキュア入力欄への入力

## ユーザー体験

アプリはメニューバーに状態を表示する。

| 状態 | 表示 | 説明 |
|---|---|---|
| 起動中 | Loading | 音声認識モデルと権限状態を準備している |
| 待機中 | Ready | ホットキー入力を待っている |
| 録音中 | Recording | マイク入力を受け付けている |
| 処理中 | Processing | 最終結果の確定と貼り付けを実行している |
| エラー | Needs Setup | 権限や音声認識モデルに問題がある |

入力モードは二つ用意する。

- **Hold to Talk**：ホットキーを押している間だけ録音する。
- **Toggle**：一回押すと録音開始、もう一回押すと録音停止する。

初期ホットキーは Right Option とする。
設定で Right Command と F13 に変更できる。

## メニュー構成

メニューバーのメニューは次の項目を持つ。

- Start Recording または Stop Recording
- Input Mode
- Language
- Microphone
- Hotkey
- Recognition Engine
- Paste Method
- Permission Doctor
- Open Settings
- Quit

`Recognition Engine` は初期版では `Apple Speech` のみ表示する。
Whisper 対応後は `Apple Speech` と `Whisper` を選択できる。

## 言語設定

初期版の言語設定は次の三つにする。

- System Default
- English
- Japanese

`SpeechTranscriber` はロケールを指定して使う。
`System Default` は `Locale.current` に近いサポート済みロケールへ解決する。
英語は `en-US`、日本語は `ja-JP` を既定候補にする。

Whisper 追加後は `Auto Detect` を追加できる。
Apple Speech での自動言語判定は、API の挙動と認識品質を実測してから採用する。

## 権限

アプリは次の権限を扱う。

| 権限 | 用途 | 初期案内 |
|---|---|---|
| Microphone | 音声入力 | 初回録音時に要求する |
| Input Monitoring | グローバルホットキー | Permission Doctor で案内する |
| Accessibility | クリップボード貼り付け用の Command V 送信 | Permission Doctor で案内する |

`SpeechAnalyzer` の経路では `NSSpeechRecognitionUsageDescription` は要求しない。
マイク入力があるため `NSMicrophoneUsageDescription` は必須である。

## 音声認識パイプライン

MVP の音声認識パイプラインは次の構成にする。

```text
Global Hotkey
  -> Recording Controller
  -> AVAudioEngine
  -> AVAudioConverter
  -> AnalyzerInput
  -> SpeechAnalyzer
  -> SpeechTranscriber.results
  -> Transcript Buffer
  -> Paste Controller
```

`SpeechTranscriber.results` は `for try await` で読む。
結果は volatile と final を分けて保持する。
volatile 結果をそのまま累積すると重複するため、final のみを確定バッファへ追加する。

停止時は録音を止め、入力ストリームを閉じ、`finalizeAndFinishThroughEndOfInput()` を呼ぶ。
この処理が終わってから貼り付ける。

## 無音判定

短すぎる録音と小さすぎる入力は文字起こしに送らない。

初期値は次の通りにする。

| 項目 | 値 |
|---|---|
| 最小録音時間 | 0.3 秒 |
| 最小 RMS | 実測で決定 |
| 最大録音時間 | 120 秒 |

RMS の初期値は `0.003` を参考値にする。
`AVAudioEngine` の入力形式と正規化後の値で実測し、設定値を決める。

## 貼り付け

貼り付けは `NSPasteboard` と `CGEvent` による Command V で行う。
合成タイピングではなく貼り付けを使う。
長文と日本語 IME 入力で安定しやすいためである。

貼り付け前に既存のクリップボード文字列を退避する。
貼り付け後、ペーストボードの `changeCount` が変わっていなければ退避した文字列を復元する。
ユーザーが処理中にクリップボードを変更した場合は復元しない。

初期版では文字列クリップボードだけを復元対象にする。
画像、ファイル、リッチテキストの復元は対象外にする。

## 認識エンジンの抽象化

後から Whisper を追加するため、音声認識は抽象化する。

```swift
enum RecognitionEvent {
    case partial(String)
    case final(String)
}

protocol SpeechRecognitionEngine {
    func prepare() async throws
    func start(language: RecognitionLanguage) async throws -> AsyncThrowingStream<RecognitionEvent, Error>
    func stop() async throws
}
```

`SpeechAnalyzerEngine` は録音中に partial と final を返す。
`WhisperEngine` は録音停止後に final だけを返す実装でもよい。
UI と貼り付け処理は `RecognitionEvent` だけを読む。

## Whisper 対応の追加方針

Whisper は次の段階で追加する。

1. `mlx-whisper` をヘルパープロセスとして呼ぶ。
2. Whisper の精度と SpeechAnalyzer の精度を同じ音声セットで比較する。
3. 必要であれば Swift から直接呼べる実装へ置き換える。

初期の Whisper 対応は高精度モードとして扱う。
既定は Apple Speech のままにする。
Whisper を有効にした場合だけモデルダウンロードと追加メモリを許容する。

## テキスト整形

MVP では LLM cleanup を実装しない。
`SpeechTranscriber` の結果をそのまま貼り付ける。

次の段階で軽量な整形を追加する。

- 前後空白の除去
- 末尾改行の除去
- 日本語と英語の句読点補正
- フィラー除去

LLM cleanup は Whisper 対応後の別機能として扱う。
Foundation Models を使う場合も、音声認識とは別の後処理として実装する。

## 設定項目

設定は `~/Library/Application Support/Cordierite/config.json` に保存する。

| 項目 | 型 | 初期値 |
|---|---|---|
| inputMode | string | hold |
| hotkey | string | rightOption |
| language | string | system |
| microphoneDeviceID | string optional | nil |
| recognitionEngine | string | appleSpeech |
| pasteMethod | string | pasteboardCommandV |
| maxRecordingSeconds | number | 120 |
| restoreClipboardText | boolean | true |

将来の Whisper 設定は別名前空間に置く。

```json
{
  "whisper": {
    "model": "large-v3-turbo",
    "language": "auto",
    "cleanupEnabled": false
  }
}
```

## エラー表示

エラーはユーザーが次に取る行動で分類する。

| 分類 | 表示例 | 操作 |
|---|---|---|
| 権限不足 | Microphone permission is required | System Settings を開く |
| 入力監視不足 | Enable Input Monitoring for hotkeys | Permission Doctor を開く |
| アクセシビリティ不足 | Enable Accessibility to paste text | Permission Doctor を開く |
| モデル未導入 | Downloading Apple Speech assets | 進捗を表示する |
| マイク不在 | No microphone input device found | デバイス再読み込み |
| 認識失敗 | Could not transcribe this recording | 再試行 |

## テスト計画

MVP では次のテストを行う。

- ホットキー押下と解放で状態が遷移すること。
- Toggle モードで録音開始と停止が交互に動くこと。
- マイク権限がないときに録音を開始しないこと。
- Input Monitoring がないときに Permission Doctor が案内を出すこと。
- Accessibility がないときに貼り付けを試みないこと。
- 無音入力で貼り付けが行われないこと。
- 日本語音声が日本語として貼り付けられること。
- 英語音声が英語として貼り付けられること。
- クリップボード文字列が復元されること。
- 処理中にクリップボードが変わった場合に復元しないこと。

精度評価では、同じ音声セットを Apple Speech と Whisper で比較する。
評価指標は CER、WER、キー解放から貼り付けまでの時間、常駐メモリ、失敗率とする。

## 実装マイルストーン

### Milestone 1

メニューバーアプリ、設定保存、権限案内を実装する。

### Milestone 2

ホットキー、録音、無音判定を実装する。

### Milestone 3

`SpeechAnalyzerEngine` を実装し、文字起こし結果をログに出す。

### Milestone 4

貼り付けとクリップボード復元を実装する。

### Milestone 5

日本語と英語の実音声で精度と遅延を測る。

### Milestone 6

Whisper 対応の必要性を判断し、必要なら `WhisperEngine` を追加する。

## 採用判断

初期版は SpeechAnalyzer だけで始める。

この判断は、Swift ネイティブ化、配布の簡素化、常駐メモリの削減、低遅延化を優先するためである。
ただし、音声入力アプリの価値は最終的に認識精度で決まる。
そのため、認識エンジンの抽象化と比較用テストセットを最初から仕様に含める。
