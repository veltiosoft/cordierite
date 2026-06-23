# Cordierite macOS アプリ仕様書

作成日：2026-06-21
最終更新：2026-06-23

## 目的

本アプリは、macOS 上で常駐するローカル音声入力アプリである。

ユーザーは任意のアプリでテキスト入力欄にフォーカスを置き、ホットキーを押して話す。
アプリは音声をオンデバイスで文字起こしし、必要な整形を行い、結果をカーソル位置に貼り付ける。

認識エンジンは **Apple Speech**（`SpeechAnalyzer` / `SpeechTranscriber`）と **Whisper**（whisper.cpp）の二系統をサポートする。
既定は Apple Speech。Whisper は Manage Models でモデルをダウンロードしたうえで Recognition から選択する。

## 開発方針

Swift ネイティブの macOS メニューバーアプリとして実装する。

Apple Speech は macOS 26 以上の `SpeechAnalyzer` を使う。
macOS 27 以上では `AnalyzerInputConverter` や `CaptureInputSequenceProvider` を使えるが、macOS 26 でも動かすために `AVAudioEngine` と `AVAudioConverter` の経路を基本実装とする。

Whisper は whisper.cpp v1.7.5 の XCFramework を Swift Package 経由で組み込み、録音停止後にバッチ文字起こしする。
モデルファイルは Hugging Face（`ggerganov/whisper.cpp`）から手動ダウンロードし、`Application Support` 配下に保存する。

アプリは音声データと文字起こし結果を永続化しない。
設定値と Whisper モデルファイルだけを `Application Support` 配下に保存する。

## 対象環境

- macOS 26 以上
- Apple Silicon Mac
- Xcode 26 以上
- Swift 6 系
- SwiftUI を使ったメニューバーアプリ

## MVP の範囲

MVP は次の中核体験を実装する。

- メニューバー常駐
- ホットキーによる録音開始と停止
- 入力モードの切り替え（Hold to Talk / Toggle）
- マイク入力の録音
- Apple Speech による文字起こし（partial / final）
- Whisper による文字起こし（final のみ）
- 認識エンジン選択（Apple Speech / ダウンロード済み Whisper モデル）
- Whisper モデルの Manage Models によるダウンロード・削除
- 軽量テキスト整形（trim・句読点 spacing・フィラー除去）
- 文字起こし結果のカーソル位置への貼り付け
- クリップボード文字列の復元
- マイク権限、入力監視、アクセシビリティ権限の案内
- 英語と日本語の明示的な言語選択（エンジン別）
- 無音と短すぎる録音の抑制
- 録音・認識失敗時のユーザー向けフィードバック
- 設定保存

MVP では次を含めない。

- LLM による整形
- クラウド音声認識
- 音声ファイルの一括文字起こし
- 文字起こし履歴
- セキュア入力欄への入力
- 課金処理
- ユーザー辞書（仕様上は無料枠 20 件を想定するが未実装）

## 収益化方針

初期版は基本無料で配布する。
無料版だけで、日常の短文音声入力が完結する状態を製品の前提にする。

収益化は、音声認識エンジンそのものではなく、入力結果を安定させる設定とワークフローに置く。
Whisper はローカルで実行できる基盤機能なので、Whisper の基本利用そのものを Pro 限定にしない。

Pro プランは、業務で毎日使うユーザーが固有名詞、文体、アプリごとの入力先に合わせて結果を調整するためのプランとする。
初期価格案は USD 5/month とする。
この価格で出す場合は、辞書機能だけではなく、アプリ別プロファイル、整形プリセット、長文入力支援をまとめて提供する。

MVP では課金処理を実装しない。

### 無料プランの範囲

無料プランでは次を提供する。

- Apple Speech による基本音声入力
- Whisper による基本的なローカル文字起こし
- ホットキーによる録音開始と停止
- Hold to Talk と Toggle の切り替え
- 英語と日本語の明示的な言語選択
- 文字起こし結果のカーソル位置への貼り付け
- クリップボード文字列の復元
- 前後空白と末尾改行の除去
- フィラー除去（設定で ON/OFF 可能、既定 ON）
- 小規模なユーザー辞書（未実装）

小規模なユーザー辞書は無料に含める。
固有名詞の補正は音声入力の基本品質に関わるため、辞書機能を完全に Pro 限定にしない。
無料プランの辞書上限は、初期案として 20 件とする。

### Pro プランの範囲

Pro プランでは次を提供する。

- 無制限のユーザー辞書
- アプリ別辞書
- プロジェクト別辞書
- 辞書の import と export
- 文体プリセット
- アプリ別プロファイル
- カスタム置換ルール
- 長文入力モード
- 音声ファイルの一括文字起こし
- 早期アクセス機能

ユーザー辞書は、認識結果の後処理と LLM cleanup の両方から参照できる設計にする。
辞書項目は、入力語、置換後の語、言語、適用範囲、優先度を持つ。
適用範囲は、全体、アプリ別、プロジェクト別を想定する。

アプリ別プロファイルは、入力先アプリごとに言語、辞書、整形プリセット、貼り付け方法を切り替える機能とする。
対象アプリは bundle identifier で識別する。

文体プリセットは、文字起こし結果を用途に合わせて整える機能とする。
初期候補は次の通りにする。

- Plain Text
- Slack
- Email
- Markdown
- GitHub Issue
- Git Commit Message

長文入力モードは、通常入力より長い録音を扱うためのモードとする。
通常入力の最大録音時間とは別に上限を持つ。
長文入力では、段落分割、句読点補正、フィラー除去を強めに適用できる。

### Pro に含めないもの

次の機能は Pro 限定にしない。

- 基本的な音声入力
- 基本的な Whisper 利用
- 基本的な貼り付け
- 権限案内
- セキュリティ修正
- バグ修正

無料版の体験を意図的に不便にして Pro へ誘導しない。
Pro は制限解除ではなく、入力結果を安定させるための追加機能として設計する。

## ユーザー体験

アプリはメニューバーに状態を表示する。

| 状態 | 表示 | 説明 |
|---|---|---|
| 起動中 | Loading | 音声認識モデルと権限状態を準備している |
| 待機中 | Ready | ホットキー入力を待っている |
| 開始中 | Starting | 録音開始処理中（マイク権限取得直後など） |
| 録音中 | Recording | マイク入力を受け付けている |
| 処理中 | Processing | 最終結果の確定と貼り付けを実行している |
| エラー | Needs Setup | 権限や音声認識モデルに問題がある |

入力モードは二つ用意する。

- **Hold to Talk**：ホットキーを押している間だけ録音する。
- **Toggle**：一回押すと録音開始、もう一回押すと録音停止する。

初期ホットキーは Right Option とする。
設定で Right Command と F13 に変更できる。

Whisper 選択時、選択モデルが未ダウンロードまたは未ロードの場合はメニューバーにセットアップ案内を表示する。
録音開始は Whisper モデルが ready になるまでブロックする。

## メニュー構成

メニューバーのメニューは次の項目を持つ。

- Start Recording または Stop Recording
- Input Mode
- Language（選択中エンジンに応じて項目が変わる）
- Microphone
- Hotkey
- Recognition: …（現在選択中のエンジン名）
- Manage Models
- Permission Doctor
- Open Settings
- Quit

### Recognition と Manage Models の役割分担

| UI | 役割 |
|---|---|
| **Recognition** | 録音に使うエンジンを選ぶ。Apple Speech と、**ダウンロード済み** Whisper モデルのみ表示する。 |
| **Manage Models** | 全 Whisper モデルのダウンロード・削除を行う。未ダウンロードモデルはここから取得する。 |

Recognition から未ダウンロードの Whisper モデルは選べない。
Manage Models でダウンロードしたモデルだけが Recognition に現れる。

設定に未ダウンロードの Whisper が残っている場合（削除後など）は Apple Speech に自動フォールバックする。

## 言語設定

言語設定は認識エンジンごとに分かれる。

### Apple Speech 選択時

- System Default
- English
- Japanese

`SpeechTranscriber` はロケールを指定して使う。
`System Default` は `Locale.current` に近いサポート済みロケールへ解決する。
英語は `en-US`、日本語は `ja-JP` を既定候補にする。
System Default 選択時、メニューには解決後ロケール名を併記する。

### Whisper 選択時

- Auto Detect
- English
- Japanese

Auto Detect では whisper.cpp に language パラメータを渡さず、モデルに任せる。
English / Japanese はそれぞれ `en` / `ja` にマップする。

Apple Speech 用の言語設定（`language`）と Whisper 用（`whisper.language`）は設定ファイル上も独立している。

## 権限

アプリは次の権限を扱う。

| 権限 | 用途 | 確認 API | 初期案内 |
|---|---|---|---|
| Microphone | 音声入力 | `AVAudioApplication.shared.recordPermission` | 初回録音時に `AVAudioApplication.requestRecordPermission()` で要求する |
| Input Monitoring | グローバルホットキー | `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` | Permission Doctor で案内する |
| Accessibility | クリップボード貼り付け用の Command V 送信 | `AXIsProcessTrusted()` | Permission Doctor で案内する |

`SpeechAnalyzer` の経路では `NSSpeechRecognitionUsageDescription` は要求しない。
マイク入力があるため `NSMicrophoneUsageDescription` は必須である。

録音開始には Microphone・Input Monitoring・Accessibility の三つがすべて granted である必要がある。
Microphone が notDetermined の場合は録音開始時に要求し、拒否された場合は Permission Doctor へ誘導する。

## 音声認識パイプライン

録音制御はエンジン共通の `RecordingController` が担う。
エンジンごとに partial / final の扱いが異なる。

### Apple Speech

```text
Global Hotkey
  -> Recording Controller
  -> AVAudioEngine
  -> AVAudioConverter
  -> AnalyzerInput
  -> SpeechAnalyzer
  -> SpeechTranscriber.results
  -> Transcript Buffer (partial / final)
  -> Text Post-Processor
  -> Paste Controller
```

`SpeechTranscriber.results` は `for try await` で読む。
結果は volatile と final を分けて保持する。
volatile 結果をそのまま累積すると重複するため、final のみを確定バッファへ追加する。
録音中は partial をメニューバーに表示できる。

停止時は録音を止め、入力ストリームを閉じ、`finalizeAndFinishThroughEndOfInput()` を呼ぶ。
この処理が終わってから post-processing と貼り付けを行う。

初回利用時は Apple Speech アセットのダウンロードが走る。
メニューバー Loading 状態で進捗（%）を表示する。

### Whisper

```text
Global Hotkey
  -> Recording Controller
  -> AVAudioEngine
  -> AVAudioConverter (16 kHz mono float)
  -> PCM Accumulator
  -> (録音停止後) WhisperCppRunner.transcribe
  -> Text Post-Processor
  -> Paste Controller
```

Whisper は録音中に partial を返さない。
停止後に蓄積 PCM を whisper.cpp へ渡し、final テキストだけを得る。

1 秒未満の入力はゼロパディングして最低 16,000 サンプル（1 秒）に揃えてから transcribe する。

Whisper モデルは起動時または Recognition 切替時にロードする。
Manage Models からのダウンロード中は進捗（%）をメニューバーに表示する。

## 無音判定

短すぎる録音と小さすぎる入力は文字起こしに送らない。

| 項目 | 値 |
|---|---|
| 最小録音時間 | 0.3 秒 |
| 最小 RMS | 0.003 |
| 最大録音時間 | 120 秒（設定で 10〜300 秒に変更可能） |

無音破棄時はメニューバーに「No speech detected」を表示する。
post-processing 後にテキストが空になった場合（フィラー除去で全削除など）は「Nothing left to paste」を表示する。

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

音声認識は `SpeechRecognitionEngine` プロトコルで抽象化する。

```swift
enum RecognitionEvent {
    case partial(String)
    case final(String)
}

@MainActor
protocol SpeechRecognitionEngine: AnyObject {
    var downloadProgress: Progress? { get }
    var liveDisplayText: String { get }
    var loadingStatusMessage: String { get }

    func prepare(language: RecognitionLanguageOption) async throws
    func start(language: RecognitionLanguageOption) async throws -> AsyncThrowingStream<RecognitionEvent, Error>
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws
    func stop() async throws -> String
    func cancelSession() async
    func shutdown() async
}
```

`SpeechAnalyzerEngine` は録音中に partial と final を返す。
`WhisperEngine` は `start` で空ストリームを返し、`stop` で final テキストを返す。
UI と貼り付け処理は `RecordingController` 経由でエンジン差を吸収する。

`SpeechEngineFactory` が `RecognitionEngineOption` に応じてエンジンインスタンスを生成する。

## Whisper 実装

### 採用技術

Whisper は **whisper.cpp**（XCFramework v1.7.5）を Swift Package `WhisperCpp` 経由で組み込む。
`mlx-whisper` ヘルパープロセス案は採用しなかった（後述「採用判断」参照）。

GPU（Metal）と flash attention を有効にして推論する。

### 利用可能モデル

| ID | 表示名 | ファイル名 | おおよそのサイズ |
|---|---|---|---|
| `large-v3-turbo-q5_0` | Large v3 Turbo Q5_0 | `ggml-large-v3-turbo-q5_0.bin` | ~500 MB |
| `large-v3-turbo-q8_0` | Large v3 Turbo Q8_0 | `ggml-large-v3-turbo-q8_0.bin` | ~800 MB |
| `large-v3-turbo` | Large v3 Turbo | `ggml-large-v3-turbo.bin` | ~1.5 GB |
| `base` | Base | `ggml-base.bin` | ~140 MB |

既定モデルは `large-v3-turbo-q5_0`。
旧設定で `mlx-community/…` 形式の model ID が残っている場合は既定モデルへ正規化する。

### モデル保存場所

`~/Library/Application Support/Cordierite/whisper-models/`

ダウンロード元は Hugging Face の `ggerganov/whisper.cpp` リポジトリ。
HTTP ダウンロード中は `Content-Length` または推定サイズで進捗を更新する。

### モデル整合性

現状はファイル存在のみでダウンロード済みとみなす。
サイズ検証・checksum・破損ファイル検出は未実装（将来対応）。

### エラー分類（Whisper 関連）

| 状況 | ユーザー向けメッセージ |
|---|---|
| モデル未ダウンロードで録音 | Whisper model is not ready |
| ダウンロード失敗 | Could not download the Whisper model. |
| ロード失敗 | Whisper is not available on this device. |
| 文字起こし失敗 | Could not transcribe this recording. |

## テキスト整形

MVP では LLM cleanup を実装しない。
認識結果は `TextPostProcessor` で軽量整形してから貼り付ける。

常時適用:

- 前後空白の除去
- 連続空白の正規化
- 日本語・英語の句読点 spacing 調整

設定 `removeFillerWords`（既定 ON）で追加適用:

- 日本語フィラー（えー、ええと、うー 等）の除去
- 英語フィラー（uh、um、er 等）の除去

LLM cleanup は Whisper 対応後の別機能として扱う。
Foundation Models を使う場合も、音声認識とは別の後処理として実装する。

## 設定項目

設定は `~/Library/Application Support/Cordierite/config.json` に保存する。

| 項目 | 型 | 初期値 | 説明 |
|---|---|---|---|
| inputMode | string | hold | `hold` または `toggle` |
| hotkey | string | rightOption | `rightOption` / `rightCommand` / `f13` |
| language | string | system | Apple Speech 用。`system` / `english` / `japanese` |
| microphoneDeviceID | string optional | nil | 省略時は System Default |
| recognitionEngine | string | appleSpeech | `appleSpeech` または `whisper` |
| whisper.model | string | large-v3-turbo-q5_0 | Whisper モデル ID |
| whisper.language | string | auto | `auto` / `english` / `japanese` |
| pasteMethod | string | pasteboardCommandV | 現状この値のみ |
| maxRecordingSeconds | number | 120 | 10〜300 |
| restoreClipboardText | boolean | true | 貼り付け後に文字列クリップボードを復元 |
| removeFillerWords | boolean | true | フィラー除去の ON/OFF |

設定例:

```json
{
  "inputMode": "hold",
  "hotkey": "rightOption",
  "language": "system",
  "recognitionEngine": "whisper",
  "whisper": {
    "model": "large-v3-turbo-q5_0",
    "language": "auto"
  },
  "pasteMethod": "pasteboardCommandV",
  "maxRecordingSeconds": 120,
  "restoreClipboardText": true,
  "removeFillerWords": true
}
```

## エラー表示

エラーはユーザーが次に取る行動で分類する。

| 分類 | 表示例 | 操作 |
|---|---|---|
| 権限不足（マイク） | Microphone permission is required | Permission Doctor / System Settings |
| 入力監視不足 | Enable Input Monitoring for hotkeys | Permission Doctor |
| アクセシビリティ不足 | Enable Accessibility to paste text | Permission Doctor |
| Apple Speech アセット DL 中 | Downloading Apple Speech assets… N% | 待機 |
| Whisper モデル DL 中 | Downloading Whisper … N% | 待機 |
| Whisper 未準備 | Whisper model is not ready | Manage Models で DL |
| マイク不在 | No microphone input device found | Reload Devices |
| マイク未アクティブ | Microphone input did not become active | デバイス変更 |
| 無音破棄 | No speech detected | 再録音 |
| 整形後空 | Nothing left to paste | Remove Filler Words を OFF |
| 認識失敗 | Could not transcribe this recording | 再試行 |

## テスト計画

MVP では次のテストを行う。

- ホットキー押下と解放で状態が遷移すること。
- Toggle モードで録音開始と停止が交互に動くこと。
- マイク権限がないときに録音を開始しないこと。
- Input Monitoring がないときに Permission Doctor が案内を出すこと。
- Accessibility がないときに貼り付けを試みないこと。
- 無音入力で貼り付けが行われないこと。
- 日本語音声が日本語として貼り付けられること（Apple Speech / Whisper それぞれ）。
- 英語音声が英語として貼り付けられること（Apple Speech / Whisper それぞれ）。
- クリップボード文字列が復元されること。
- 処理中にクリップボードが変わった場合に復元しないこと。
- Whisper モデル未 DL 時に Recognition に未 DL モデルが表示されないこと。
- Manage Models から DL したモデルが Recognition に現れること。
- フィラー除去 ON/OFF が post-processing に反映されること。

精度評価では、同じ音声セットを Apple Speech と Whisper で比較する（未実施）。
評価指標は CER、WER、キー解放から貼り付けまでの時間、常駐メモリ、失敗率とする。

## 実装マイルストーン

### Milestone 1（完了）

メニューバーアプリ、設定保存、権限案内を実装する。

### Milestone 2（完了）

ホットキー、録音、無音判定を実装する。

### Milestone 3（完了）

`SpeechAnalyzerEngine` を実装し、文字起こし結果をログに出す。

### Milestone 4（完了）

貼り付けとクリップボード復元を実装する。

### Milestone 5（未実施）

日本語と英語の実音声で Apple Speech と Whisper の精度と遅延を測る。

### Milestone 6（完了）

Whisper 対応として `WhisperEngine` と Manage Models を実装する。

### 追加実装（マイルストーン外）

- 軽量テキスト整形（`TextPostProcessor`）
- Whisper モデル DL 進捗表示
- 録音・認識失敗時のメニューバーフィードバック
- Recognition にダウンロード済み Whisper モデルのみ表示

## 採用判断

### Apple Speech を既定エンジンとする理由

Swift ネイティブ化、配布の簡素化、常駐メモリの削減、低遅延化（partial 表示）を優先するため、既定は Apple Speech とする。

### whisper.cpp を採用した理由

Whisper 統合では次の案を検討した。

1. `mlx-whisper` をヘルパープロセスとして呼ぶ
2. whisper.cpp を XCFramework として Swift から直接呼ぶ

採用したのは **2** である。理由は次の通り。

- 追加プロセス管理・配布物の複雑化を避けられる
- Apple Silicon 向け Metal 推論が whisper.cpp で利用できる
- Hugging Face 上の ggml 形式モデルをそのまま取得できる
- `SpeechRecognitionEngine` 抽象化の内側に閉じ込めやすい

`mlx-whisper` は MLX ランタイム依存が大きく、メニューバー常駐アプリの配布サイズと起動コストの観点で見送った。

### 二系統併用の位置づけ

Apple Speech は低遅延・軽量、Whisper は特に日本語を含む認識精度の選択肢として併用する。
音声入力アプリの価値は最終的に認識精度で決まるため、認識エンジンの抽象化と比較用テストセット（Milestone 5）を仕様に残す。
