# 軽量テキスト整形（trim・句読点・フィラー）を追加する

- Priority: Medium
- Created: 2026-06-22
- Completed: 2026-06-23
- Model: Composer 2.5
- Branch: feature/add-text-post-processing
- Polished: {YYYY-MM-DD}

## 目的

認識結果を貼り付け前に軽く整え、口語の「えー」「あの」などを減らし、前後空白を除去する。仕様書の「軽量テキスト整形」に対応する。

## 優先度根拠

Medium。Whisper 導入で認識品質は上がったが、貼り付けテキストの体裁は未整備。

## 現状

- `AppModel` は認識テキストをそのまま `TextInjector` に渡す
- 仕様書は trim・句読点・フィラー除去を MVP 後半〜初期版で想定

## 設計方針

- 純関数の post-processor を `Speech/` または `Core/` に置く
- 設定で ON/OFF 可能にする（既定 ON または OFF は実装時に決定）
- 過度な NLP は入れない

## 完了条件

- 認識結果に trim が適用される
- 設定でフィラー除去の有無を切り替えられる（または MVP 最小は trim のみでも可 — issue 実装時に Polished で確定）

## 解決方法

- `Core/TextPostProcessor.swift` に純関数の post-processor を追加し、trim・連続空白正規化・句読点 spacing 調整を常時適用する
- `AppConfiguration.removeFillerWords`（既定 ON）と Settings の **Remove Filler Words** トグルでフィラー除去を切り替え可能にした
- `AppModel.stopRecording` の貼り付け前に post-processor を通し、整形後に空になった場合は無音破棄として扱う
