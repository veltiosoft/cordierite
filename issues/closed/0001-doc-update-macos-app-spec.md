# macOS アプリ仕様書を実装に合わせて更新する

- Priority: Medium
- Created: 2026-06-22
- Completed: 2026-06-23
- Model: Composer 2.5
- Branch: feature/change-update-macos-app-spec
- Polished: {YYYY-MM-DD}

## 目的

`docs/macos-app-spec.md` が whisper.cpp 実装・Recognition / Manage Models 分離・マイク権限 API など現状と乖離しており、以降の開発判断の一次資料として使えない。実装と一致させる。

## 優先度根拠

Medium。機能追加の前提となるドキュメントの正確性に直結するが、実行時の不具合は起こさない。

## 現状

- Whisper は「初期版に含めない」「mlx-whisper ヘルパー」と記載されているが、実装は whisper.cpp + Hugging Face 手動 DL
- 認識エンジン選択 UI の記載が統合前の想定のまま
- Milestone 6 が未完了扱いだが Whisper 統合は完了している
- マイク権限は `AVAudioApplication` を使用しているが仕様書に記載がない

## 設計方針

- 実装済みの内容を正とし、廃止した方針（mlx-whisper 等）は削除または「採用しなかった理由」として短く記す
- Whisper 設定項目・エラー分類・Manage Models の役割を追記する
- 収益化方針セクションとの整合を保つ

## 完了条件

- 仕様書を読むだけで、現在の Recognition / Manage Models / 権限 / Whisper の挙動が把握できる
- 実装と矛盾する記述が残っていない

## 解決方法

- `docs/macos-app-spec.md` を現行実装に合わせて全面更新した
- Whisper（whisper.cpp XCFramework）、Recognition / Manage Models の役割分担、エンジン別言語設定、`AVAudioApplication` によるマイク権限、二系統の認識パイプライン、`TextPostProcessor`、設定項目・エラー分類を追記した
- Milestone 6 を完了、Milestone 5 を未実施に更新し、mlx-whisper 不採用と whisper.cpp 採用理由を「採用判断」節に記載した
