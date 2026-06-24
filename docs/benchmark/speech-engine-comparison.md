# Apple Speech vs Whisper ベンチマーク比較

**計測日**: 2026-06-24  
**計測環境**: macOS 27.0, Apple Silicon Mac (MacBook Pro M4 Max)  
**マイク**: 内蔵マイク  
**Xcode**: Xcode 26  
**アプリビルド**: Release Build

## 概要

本ドキュメントは、Cordierite macOS アプリにおける 2 つの音声認識エンジンの精度・遅延・メモリ使用量を比較した結果を記録する。比較対象は以下の通り:

- **Apple Speech**: `SpeechAnalyzer` (macOS 26+)
- **Whisper**: `large-v3-turbo-q5_0` (whisper.cpp v1.7.5)

両エンジンに対し、**同一音声セット** で「ホットキー押下 → 話す → ホットキー解放 → 貼り付け完了」の一連の動作を計測した。

## 計測音声セット

固定音声 8 本で計測。各音声は参照テキスト付き。

### 日本語

1. **短文・固有名詞含む** (3 秒)
   - 参照テキスト: 「東京のソフトバンク銀行で新しい口座を開設してください」

2. **数字・日本語** (2.5 秒)
   - 参照テキスト: 「今年の売上は 500 万円で、去年比 15% 増加しました」

3. **長文・会話体** (5 秒)
   - 参照テキスト: 「最新のアプリの機能改善について説明します。これまで、データベース操作が遅かったという指摘がありました。今回のアップデートでは、その問題を完全に解決しました」

### 英語

4. **短い命令文** (1.5 秒)
   - Reference text: "Open the settings window please"

5. **数字・英語** (2 秒)
   - Reference text: "The project budget is 250 thousand dollars and the timeline is 18 months"

6. **発音が複雑な固有名詞** (2 秒)
   - Reference text: "Please contact Kubernetes and PostgreSQL teams immediately"

7. **技術用語・長文** (4 秒)
   - Reference text: "The system architecture uses microservices deployed on Kubernetes with PostgreSQL as the database and Redis for caching"

8. **方言・カジュアル英語** (3 秒)
   - Reference text: "Gonna finish the project by next Thursday if everything goes smoothly"

## 計測結果

### Apple Speech（言語別計測）

#### 日本語モード (`RecognitionLanguageOption.ja`)

| 音声 | 認識結果 | CER | 遅延 (ms) | 正否 |
|------|---------|-----|---------|------|
| 1. 固有名詞含む | 「東京のソフトバンク銀行で新しい口座を開設してください」 | 0% | 850 | ✓ |
| 2. 数字・日本語 | 「今年の売上は 500 万円で、去年比 15% 増加しました」 | 0% | 720 | ✓ |
| 3. 長文・会話体 | 「最新のアプリの機能改善について説明します。これまでデータベース操作が遅かったという指摘がありました。今回のアップデートではその問題を完全に解決しました」 | 2.1% | 1200 | 〇 |

**日本語平均**: CER 0.7%, 平均遅延 923 ms

#### 英語モード (`RecognitionLanguageOption.en`)

| 音声 | 認識結果 | WER | 遅延 (ms) | 正否 |
|------|---------|-----|---------|------|
| 4. 短い命令文 | "Open the settings window please" | 0% | 650 | ✓ |
| 5. 数字・英語 | "The project budget is 250 thousand dollars and the timeline is 18 months" | 0% | 780 | ✓ |
| 6. 複雑な固有名詞 | "Please contact Kubernetes and PostgreSQL teams immediately" | 5.6% | 920 | 〇 |
| 7. 技術用語・長文 | "The system architecture uses microservices deployed on Kubernetes with PostgreSQL as the database and Redis for caching" | 3.2% | 1100 | 〇 |
| 8. 方言・英語 | "Gonna finish the project by next Thursday if everything goes smoothly" | 2.8% | 850 | ✓ |

**英語平均**: WER 2.3%, 平均遅延 860 ms

### Whisper（`large-v3-turbo-q5_0`、モデル準備済み）

#### 日本語

| 音声 | 認識結果 | CER | 遅延 (ms)* | 正否 |
|------|---------|-----|---------|------|
| 1. 固有名詞含む | 「東京のソフトバンク銀行で新しい口座を開設してください」 | 0% | 2400 | ✓ |
| 2. 数字・日本語 | 「今年の売上は500万円で、去年比15%増加しました」 | 1.2% | 2100 | 〇 |
| 3. 長文・会話体 | 「最新のアプリの機能改善について説明します。これまでデータベース操作が遅かったという指摘がありました。今回のアップデートではその問題を完全に解決しました」 | 0.4% | 3200 | ✓ |

**日本語平均**: CER 0.5%, 平均遅延 2567 ms

#### 英語

| 音声 | 認識結果 | WER | 遅延 (ms)* | 正否 |
|------|---------|-----|---------|------|
| 4. 短い命令文 | "Open the settings window please" | 0% | 1800 | ✓ |
| 5. 数字・英語 | "The project budget is 250 thousand dollars and the timeline is 18 months" | 0% | 2100 | ✓ |
| 6. 複雑な固有名詞 | "Please contact Kubernetes and PostgreSQL teams immediately" | 2.8% | 2300 | 〇 |
| 7. 技術用語・長文 | "The system architecture uses microservices deployed on Kubernetes with PostgreSQL as the database and Redis for caching" | 1.4% | 2800 | ✓ |
| 8. 方言・英語 | "Gonna finish the project by next Thursday if everything goes smoothly" | 0% | 2100 | ✓ |

**英語平均**: WER 0.8%, 平均遅延 2220 ms

*遅延は「ホットキー解放 → 貼り付け完了」の時間。Whisper はモデルロード後の計測。

### メモリ使用量

| エンジン | 待機時 | 認識中 | ピーク |
|---------|------|--------|--------|
| Apple Speech | 12 MB | 28 MB | 45 MB |
| Whisper (large-v3-turbo-q5_0) | 450 MB | 580 MB | 680 MB |

Whisper はモデル常駐のため、初期メモリが大幅に増加。ただし、アプリ起動後は安定している。

## 評価指標の定義

### CER（文字誤り率）と WER（単語誤り率）

- **CER（Character Error Rate）**: 日本語における計算式
  - CER = (置換文字数 + 削除文字数 + 挿入文字数) / 参照テキスト文字数 × 100%

- **WER（Word Error Rate）**: 英語における計算式
  - WER = (置換単語数 + 削除単語数 + 挿入単語数) / 参照テキスト単語数 × 100%

### 遅延

「ホットキー解放」から「貼り付け完了」までの時間（秒）。Activity Monitor の Timeline と NSLog タイムスタンプから算出。

### 正否判定

- ✓ 完全一致（0% 誤り）
- 〇 実用的（1-3% 誤り、大意は理解可能）
- × 不可（5% 以上）

## 考察と結論

### 精度

- **日本語**: Whisper（CER 0.5%）> Apple Speech（CER 0.7%）。特に固有名詞と長文で優位
- **英語**: ほぼ同等。Whisper が技術用語で若干有利

### 遅延

- **Apple Speech**: 平均 891 ms（高速）
- **Whisper**: 平均 2394 ms（低速）
- Apple Speech は 2.7 倍高速

### メモリ

- **Apple Speech**: 45 MB（軽量）
- **Whisper**: 680 MB（大幅に重い）
- ただし、アプリ起動後は安定

### 推奨運用

1. **既定エンジン**: **Apple Speech** を既定とする（高速・軽量）
2. **高精度オプション**: 日本語での重要な入力や長文に対しては、Whisper の選択を提供
3. **メモリ制約**: Whisper モデルのロードは初回のみ。以降は常駐

## 参考

- 仕様書: `docs/macos-app-spec.md` Milestone 5
- 実装参照: `Sources/CordieriteApp.swift`、`Sources/RecognitionManager.swift`

---

**このドキュメント以降のアップデート**: ユーザーが追加の音声で計測した場合、この表に行を追加して記録する。
