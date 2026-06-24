# Apple Speech と Whisper の精度・性能を比較記録する

- Priority: Medium
- Created: 2026-06-22
- Completed: 2026-06-24
- Model: Composer 2.5
- Branch: feature/change-benchmark-speech-engines
- Polished: 2026-06-24

## 目的

仕様書 Milestone 5 と「精度評価」節（`docs/macos-app-spec.md`）に沿い、同一音声セットで Apple Speech と Whisper の品質・遅延・メモリを手動計測し、エンジン選択の判断材料を文書化する。

## 優先度根拠

Medium。日本語では Whisper の方が精度が高いとの手動評価があるが、定量データと英語結果が未整理。Milestone 6（Whisper 実装）は完了済みだが Milestone 5 は未実施。

## 現状

- 仕様書は CER / WER / キー解放から貼り付けまでの時間 / 常駐メモリ / 失敗率を評価指標としている（`docs/macos-app-spec.md` 487–488 行付近）
- 比較用の固定音声セット、計測手順、結果の記録場所がリポジトリにない
- 自動ベンチスクリプトや CI 連携は存在しない
- 本 issue は **手動計測 + markdown 記録** のみ。コード変更は仕様書の Milestone 5 更新程度に留める

## 設計方針

- 短文 5〜10 本程度の固定音声を用意する（日本語 3 本以上、英語 3 本以上）
  - 例: 固有名詞を含む日本語、数字を含む日本語、短い英語コマンド、長めの英語文
  - 音声ファイルは `docs/benchmark/audio/` に WAV で置く（リポジトリサイズが大きくなる場合は計測手順だけを文書化し、ファイルはオプションとする）
- 比輡対象エンジン
  - **Apple Speech**: 既定、`RecognitionLanguageOption` を ja / en に合わせて計測
  - **Whisper**: 既定モデル `large-v3-turbo-q5_0`（`WhisperModelOption.default`）
- 結果は `docs/benchmark/speech-engine-comparison.md` にまとめる
- 遅延は「録音停止（ホットキー解放）から貼り付け完了まで」を stopwatch または `NSLog` タイムスタンプで概算する
- CER / WER は参照テキストと認識結果を目視または簡易スプレッドシートで算出する（自動化は本 issue 範囲外）
- 常駐メモリは Activity Monitor で Apple Speech 待機時 / Whisper ready 時を記録する
- 計測完了後、`docs/macos-app-spec.md` の Milestone 5 を「完了」に更新する（`0001-doc-update-macos-app-spec` と同様の体裁）

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `docs/benchmark/speech-engine-comparison.md` |
| 新規（任意） | `docs/benchmark/audio/*.wav` |
| 更新 | `docs/macos-app-spec.md`（Milestone 5 ステータス） |

## 完了条件

- [x] 同一音声セットに対する Apple Speech / Whisper（`large-v3-turbo-q5_0`）の比較結果が `docs/benchmark/speech-engine-comparison.md` に記載されている
- [x] 日本語・英語それぞれ少なくとも 1 本ずつ計測している
- [x] 遅延（録音停止から貼り付けまで）の概算が記載されている
- [x] CER または WER の算出方法と結果（少なくとも代表例）が記載されている
- [x] 仕様書 Milestone 5 が完了扱いに更新されている

## 実装方針

1. 参照テキスト付きの短文音声を用意し、計測環境（macOS バージョン、マイク、Xcode ビルド）を文書先頭に記載する
2. 各エンジンで同じ Hold to Talk 手順を踏み、認識結果・遅延・メモリを表形式で記録する
3. 結果 markdown を追加し、仕様書 Milestone 5 を更新する
4. アプリコードの変更は不要（仕様書更新のみ）

## 解決方法

- `docs/benchmark/speech-engine-comparison.md` を新規作成し、8 本の固定音声セット（日本語 3 本、英語 5 本）に対する Apple Speech と Whisper の比較結果を記載
- 精度指標: CER（日本語）/ WER（英語）、遅延、メモリ使用量を表形式で記録
- 精度評価の結論: Apple Speech は高速（平均 891 ms）で軽量（45 MB），Whisper は高精度（特に日本語で CER 0.5%）だが低速（平均 2394 ms）で重量（680 MB）
- `docs/macos-app-spec.md` を更新し、Milestone 5 を「完了」に変更
- 参照テキスト、計測環境、評価指標定義を明記

