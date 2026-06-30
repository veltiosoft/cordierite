# 課金基盤（Pro サブスクリプション）を整備する

- Priority: Low
- Created: 2026-06-22
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/add-billing-foundation-fc6f
- Polished: 2026-06-24
- Updated: 2026-06-30（Stripe + マジックリンク + Cloudflare Workers に方針変更）

## 目的

仕様書 Pro 機能（辞書拡張・プロファイル・長文モード等）を提供するため、**Stripe サブスクリプション**と**マジックリンク認証**による entitlement 管理、および Feature gate 基盤を整える。

詳細設計: [docs/billing-design.md](../docs/billing-design.md)（[アカウント登録戦略](../docs/billing-design.md#アカウント登録戦略) 節）

## 優先度根拠

Low。機能 MVP 完成後の収益化フェーズ。Stripe Dashboard で Product 登録と Cloudflare Workers デプロイが必要。

## 現状

- 課金コード・Entitlement 管理なし
- 仕様書: 無料 / Pro 分界、USD 5/month 案（`docs/macos-app-spec.md` 68–149 行）。MVP では課金処理を実装しないと明記
- `0013` / `0014` / `0007` Pro 拡張はすべて本 issue 後にゲート可能な設計とする
- 配布は Developer ID 直接配布を想定（StoreKit / Mac App Store は対象外）

## 設計方針

- **決済**: Stripe Billing（Checkout + Customer Portal + Webhooks）
- **認証**: マジックリンク主軸（パスワードなし、ライセンスキーは使わない）
- **バックエンド**: Cloudflare Workers + D1（`workers/billing/`）
- **デバイス数制限**: なし
- **モジュール構成（アプリ）**
  - `Billing/AuthManager.swift`: magic-link 要求、URL スキーム受信、セッション Keychain 保存
  - `Billing/SubscriptionManager.swift`: entitlement API、オフライン cache、Pro 判定
  - `Billing/ProCapabilities.swift`: feature flag enum（例: `unlimitedDictionary`, `appProfiles`, `longFormInput`）
  - `Billing/BillingAPIClient.swift`: Workers REST クライアント
- **状態公開**: `@Observable` な `SubscriptionManager` を `AppModel` または Environment 経由で Settings / 各機能から参照
- **Stripe Price**: 環境変数 `STRIPE_PRICE_ID_PRO_MONTHLY`（test / prod で別 ID）
- **Settings UI**: Pro セクション — 現在のプラン、Upgrade to Pro、Restore Pro、Manage subscription
- **stub ゲート**: 少なくとも 1 機能を Pro 限定にする
  - 推奨: ユーザー辞書 21 件目（0007 実装後）または Profiles プレビュー（0013 stub）
  - 未実装機能の場合: Settings に **Pro (Preview)** トグルで `ProCapabilities` の dry-run 表示でも可
- **オフライン**: 最後に確認した entitlement を Keychain に cache。`current_period_end` + 猶予（例: 3 日）まで Pro 維持
- **URL スキーム**: `cordierite://auth?token=…` でアプリに戻す

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `docs/billing-design.md` |
| 新規 | `workers/billing/`（Worker + D1 schema + Stripe Webhook） |
| 新規 | `Cordierite/Cordierite/Billing/AuthManager.swift` |
| 新規 | `Cordierite/Cordierite/Billing/SubscriptionManager.swift` |
| 新規 | `Cordierite/Cordierite/Billing/ProCapabilities.swift` |
| 新規 | `Cordierite/Cordierite/Billing/BillingAPIClient.swift` |
| 新規 | `Cordierite/Cordierite/Billing/KeychainStore.swift` |
| 更新 | `Cordierite/Cordierite/Settings/SettingsView.swift`（Pro セクション） |
| 更新 | `Cordierite/Cordierite/Core/AppModel.swift`（AuthManager / SubscriptionManager 保持） |
| 更新 | Xcode プロジェクト（URL スキーム `cordierite`、Billing ファイル追加） |
| 更新 | `site/`（`/pro/welcome`, `/auth/verify` 等。Phase 3。**0019** Astro ページ移行完了後） |
| 更新 | `README.md`（Stripe test mode・ローカル Worker 開発概要） |

## 完了条件

### バックエンド（Workers）

- [ ] Stripe test mode で Checkout 完了後、Webhook 経由で subscription が D1 に `active` で保存される
- [ ] `POST /auth/magic-link` → `POST /auth/verify` でセッションが発行される
- [ ] `GET /entitlement` が Bearer セッションで `isPro` を返す
- [ ] Customer Portal セッション URL が発行できる
- [ ] 解約 Webhook 後に `isPro: false` になる

### アプリ

- [ ] Checkout → マジックリンク → アプリ起動で Pro 状態が UI に反映される
- [ ] Restore Pro（メール再送）で再インストール後も Pro を復元できる
- [ ] `ProCapabilities` 経由で少なくとも 1 機能が Pro 未加入時にブロックまたは案内される
- [ ] オフライン猶予内は Pro を維持し、猶予超過後は Free に戻る
- [ ] API エラー時にユーザー向け英語メッセージが表示される

### ドキュメント

- [ ] `docs/billing-design.md` に API・フロー・D1 schema が記載されている
- [ ] README に Stripe test mode と Worker ローカル開発の概要がある（秘密情報なし）

## 実装方針

1. `workers/billing` を追加し、D1 schema + Stripe Webhook + auth / entitlement API を実装する
2. Stripe Dashboard（test mode）で Product / Price / Webhook を設定する
3. アプリに `AuthManager` / `SubscriptionManager` / URL スキームを追加する
4. Settings に Pro UI を追加する
5. 1 機能に gate を接続する（0007 辞書上限が最も自然）
6. サイトの welcome / verify ページと Privacy / Terms 更新（Phase 3、別 PR 可）

## スコープ外

- Mac App Store 審査提出・StoreKit 実装
- デバイス数制限・デバイス登録 UI
- ライセンスキー認証
- Stripe 本番環境への切替作業（手順は doc に記載、実施はリリース時）
- 0013 / 0014 の本実装

## 依存関係

- **0007** 完了後: 辞書 21 件目 gate が最も意味のある stub
- 0007 未完了でも **Pro Preview** stub で完了条件を満たせる
- Cloudflare アカウント・Stripe アカウント（test mode で開発可能）
