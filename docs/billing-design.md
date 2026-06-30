# Cordierite 課金設計（Stripe + マジックリンク）

作成日：2026-06-30  
関連: [macos-app-spec.md](macos-app-spec.md) 収益化節、[issues/0015-add-billing-foundation.md](../issues/0015-add-billing-foundation.md)

## 目的

Cordierite Pro（月額サブスクリプション）の課金・認証・ entitlement 管理の設計を定める。

- **決済**: Stripe（Checkout + Customer Portal + Billing）
- **認証**: マジックリンク主軸（パスワードなし）
- **バックエンド**: Cloudflare Workers + D1
- **配布**: Developer ID 直接配布（Mac App Store / StoreKit は対象外）
- **デバイス数制限**: なし（同一アカウントで複数 Mac を許可）

## 非目標

- Mac App Store 課金（StoreKit）
- デバイス台数制限・デバイス登録 UI
- ライセンスキーによる通常ログイン（復元はマジックリンク再送のみ）
- 音声データ・文字起こし結果のクラウド同期

## アカウント登録戦略

Pro 契約に必要な「アカウント登録」を、**独立したサインアップ画面ではなく決済とログインの一本化**として設計する。

### 原則

| 原則 | 内容 |
|---|---|
| 無料版は登録不要 | 基本音声入力・Whisper 基本利用はアカウントなしで完結する |
| 登録 = 決済時のメール | Stripe Checkout で入力したメールがアカウント ID になる |
| パスワードなし | マジックリンクのみ。パスワード設定・リセット UI は持たない |
| ライセンスキーなし | 復元は **Restore Pro** から同じメールへマジックリンク再送 |
| デバイス制限なし | 同一購読で複数 Mac を許可する |
| サーバーは entitlement のみ | メール・購読状態だけを D1 に保存。音声・辞書・設定はローカルのみ |
| 録音フローを妨げない | ログイン要求は Pro 機能利用時または Settings の Pro セクションに限定する |

### 「アカウント登録」の定義

本プロジェクトでは次を **アカウント登録** とみなす。

1. Stripe Checkout でメールを入力し決済する（`users` 行が作成される）
2. 完了メールまたは success ページのマジックリンクをクリックする
3. アプリが `POST /api/auth/verify` でセッションを Keychain に保存する

**事前の Sign up フォームは設けない。** 無料ユーザーはアカウントを意識しない。

### 採用しない方式

| 方式 | 採用しない理由 |
|---|---|
| パスワード + サインアップフォーム | メニューバー常駐アプリでは重い。リセット運用・サポート負荷が増える |
| ライセンスキー | 紛失・入力ミス・問い合わせが増える |
| Sign in with Apple 必須 | Stripe 決済メールとの紐づけが複雑 |
| デバイス台数制限 | 自宅・仕事 Mac など複数端末利用に不便 |
| Mac App Store / StoreKit 課金 | Developer ID 直接配布方針と矛盾 |
| 常時オンライン必須 | オフライン cache + 猶予期間で Pro を一時維持する |

### 参考: Obsidian との比較

Obsidian も「本体無料・登録不要、有料は Web で購入」だが、認証は **メール + パスワード**、有料は **クラウド Sync/Publish** が中心である。Cordierite は Pro が **ローカル feature gate** なので、マジックリンク + 薄い entitlement API が向く。

| 観点 | Obsidian | Cordierite |
|---|---|---|
| 無料版 | アカウント不要 | アカウント不要 |
| 有料の中身 | Sync / Publish（クラウド） | 辞書・プロファイル等（ローカル） |
| 認証 | メール + パスワード | マジックリンク |
| 購入 | Web ダッシュボード | Stripe Checkout |
| アプリ連携 | Settings → Log in | マジックリンク → `cordierite://auth` |
| 請求管理 | 自社 Web UI | Stripe Customer Portal |
| デバイス制限 | なし | なし |

Cordierite が Obsidian から取り入れるのは **無料は登録不要・Web で決済・アプリで entitlement・デバイス制限なし**。**パスワードログインとアカウント種別の増殖**（本番 / フォーラム / 別パスワード等）は避ける。

## 全体構成

```text
Cordierite.app (macOS)
  ├─ AuthManager          … マジックリンク要求・URL スキーム受信・セッション Keychain 保存
  ├─ SubscriptionManager  … entitlement 取得・オフライン cache・Pro 判定
  └─ ProCapabilities      … feature gate

Cloudflare Workers (billing API)
  ├─ REST API             … auth / entitlement / checkout
  ├─ Stripe Webhooks      … subscription 状態同期
  ├─ D1                   … users / subscriptions / tokens
  └─ メール送信            … マジックリンク（Resend 等）

Stripe
  ├─ Checkout             … 新規購読
  ├─ Customer Portal      … 解約・カード変更・請求履歴
  └─ Webhooks             … Workers へ POST
```

## プラン定義

| 項目 | 値 |
|---|---|
| プラン名 | Cordierite Pro |
| 価格 | USD 5 / month（仕様書案に準拠。Stripe Price で管理） |
| 無料プラン | 基本音声入力・Whisper 基本利用・辞書 20 件まで（`0007` 参照） |
| Pro プラン | 仕様書 Pro 節の機能（辞書無制限、プロファイル、長文モード等） |

Stripe 側の識別子（実装時に Dashboard で作成）:

| 種別 | 命名例 |
|---|---|
| Product | `cordierite_pro` |
| Price（月額） | `price_…`（環境変数 `STRIPE_PRICE_ID_PRO_MONTHLY`） |
| Webhook endpoint | Workers URL + `/webhooks/stripe` |

## ユーザーフロー

### 新規購読

1. アプリ Settings → **Upgrade to Pro**
2. アプリが `POST /api/checkout/session` を呼び、Checkout URL を取得
3. 既定ブラウザで Stripe Checkout を開く（メールは Checkout で入力）
4. 決済完了 → Stripe が Webhook で Workers に通知
5. Workers が `users` / `subscriptions` を upsert
6. Checkout の `success_url`（または完了メール）にマジックリンクを含める
7. ユーザーがリンクをクリック → `cordierite://auth?token=<magic>` でアプリ起動
8. アプリが `POST /api/auth/verify` でセッショントークンを取得し Keychain に保存
9. `GET /api/entitlement` で Pro 有効を確認し UI 反映

### Pro 復元（再インストール・別 Mac）

1. Settings → **Restore Pro** → メールアドレス入力
2. `POST /api/auth/magic-link` でリンク送信（**active な購読があるメールのみ** 実際に送信）
3. レスポンスは常に「送信しました」相当（アカウント列挙の緩和）
4. リンククリック以降は新規購読と同じ

### 解約・請求管理

1. Settings → **Manage subscription** → Customer Portal URL（`POST /api/portal/session`）
2. 解約・支払い失敗は Stripe Webhook で D1 を更新
3. アプリは起動時・フォアグラウンド復帰時に entitlement を再取得
4. オフライン cache 期限切れ後は Free 扱い

## マジックリンク仕様

| 項目 | 値 |
|---|---|
| 配信 | メール（Resend 等） |
| リンク形式（メール内） | `https://cordierite.veltiosoft.com/auth/verify?token=<opaque>` |
| アプリ起動 | 上記ページまたはリダイレクトで `cordierite://auth?token=<opaque>` |
| トークン有効期限 | 15 分 |
| 使用回数 | 1 回限り（使用後失効） |
| 対象 | `subscriptions.status` が `active` または `trialing` のユーザーのみ |

### セッショントークン

| 項目 | 値 |
|---|---|
| 保存先 | macOS Keychain |
| 有効期限 | 90 日（実装定数。満了前に `/entitlement` で延長） |
| 送信 | `Authorization: Bearer <session>` |
| 失効 | ログアウト、Stripe 解約、手動 revoke（将来） |

## オフライン動作

アプリは最後に確認した entitlement を Keychain に cache する。

| フィールド | 用途 |
|---|---|
| `isPro` | UI と feature gate |
| `currentPeriodEnd` | 請求期間終了（Unix epoch） |
| `cachedAt` | 最終サーバー確認時刻 |
| `graceUntil` | `currentPeriodEnd` + オフライン猶予（例: 3 日） |

判定ルール:

1. ネットワーク利用可能時は `/entitlement` を優先し cache を更新
2. オフライン時は `now < graceUntil` なら Pro を維持
3. 猶予超過後は Free。Settings に「接続して Pro 状態を確認してください」を表示

## Cloudflare Workers

### リポジトリ配置

```text
workers/billing/
  package.json
  wrangler.toml
  src/
    index.ts              … ルーティング
    routes/
      auth.ts
      checkout.ts
      entitlement.ts
      portal.ts
      webhooks/stripe.ts
    db/
      schema.sql
      queries.ts
    email/
      send-magic-link.ts
```

製品サイト（`site/`）とは **別 Worker** とする。ルートは例として `cordierite.veltiosoft.com/api/*` にバインドする。

### D1 スキーマ

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  stripe_customer_id TEXT UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE subscriptions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  stripe_subscription_id TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  current_period_end INTEGER NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);

CREATE TABLE magic_link_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL,
  used_at TEXT
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
```

トークン本体は DB に平文保存しない。SHA-256 ハッシュのみ保存する。

### API 一覧

ベース URL 例: `https://cordierite.veltiosoft.com/api`

| メソッド | パス | 認証 | 説明 |
|---|---|---|---|
| `POST` | `/checkout/session` | 不要 | Stripe Checkout Session 作成。body: `{ "successUrl", "cancelUrl" }` |
| `POST` | `/portal/session` | Bearer | Customer Portal Session URL。body 空で可 |
| `POST` | `/auth/magic-link` | 不要 | body: `{ "email" }`。レート制限あり |
| `POST` | `/auth/verify` | 不要 | body: `{ "token" }`。セッション発行 |
| `GET` | `/entitlement` | Bearer | Pro 状態を返す |
| `POST` | `/auth/logout` | Bearer | セッション失効（任意） |
| `POST` | `/webhooks/stripe` | Stripe 署名 | Webhook 受信 |

### `GET /entitlement` レスポンス

```json
{
  "isPro": true,
  "status": "active",
  "currentPeriodEnd": 1782777600,
  "email": "user@example.com"
}
```

`isPro` は `status` が `active` または `trialing` のとき `true`。

### Stripe Webhook（処理対象）

| イベント | 動作 |
|---|---|
| `checkout.session.completed` | `customer` / `email` を user に紐づけ |
| `customer.subscription.created` | subscription 行を upsert |
| `customer.subscription.updated` | status / `current_period_end` 更新 |
| `customer.subscription.deleted` | status を `canceled` に |
| `invoice.payment_failed` | status を `past_due` 等に（猶予後 Free） |

Webhook ハンドラは **べき等** に実装する（同一 `event.id` の再送に耐える）。

### 環境変数（Workers Secrets）

| 名前 | 用途 |
|---|---|
| `STRIPE_SECRET_KEY` | Stripe API |
| `STRIPE_WEBHOOK_SECRET` | Webhook 署名検証 |
| `STRIPE_PRICE_ID_PRO_MONTHLY` | Checkout 用 Price ID |
| `RESEND_API_KEY` | マジックリンクメール送信 |
| `MAGIC_LINK_SIGNING_SECRET` | トークン生成用（任意。ランダム opaque でも可） |
| `SESSION_SIGNING_SECRET` | セッショントークン生成用 |

公開設定（`wrangler.toml` vars）:

| 名前 | 例 |
|---|---|
| `APP_URL_SCHEME` | `cordierite` |
| `PUBLIC_SITE_URL` | `https://cordierite.veltiosoft.com` |
| `CHECKOUT_SUCCESS_PATH` | `/pro/welcome` |
| `CHECKOUT_CANCEL_PATH` | `/pro/canceled` |

### セキュリティ

- Stripe Webhook: `stripe.webhooks.constructEvent` で署名検証
- `POST /auth/magic-link`: IP + email 単位でレート制限（例: 5 回 / 15 分）
- CORS: `cordierite://` は不要。HTTPS API のみ。アプリは URLSession から呼ぶ
- ログにマジックリンクトークン・セッショントークンを出力しない
- D1 にはメールと Stripe ID のみ。音声・辞書データは保存しない

## macOS アプリ

### 新規モジュール

| パス | 責務 |
|---|---|
| `Billing/AuthManager.swift` | magic-link 要求、URL スキーム、`ASWebAuthenticationSession` は使わず外部ブラウザ + ディープリンク |
| `Billing/SubscriptionManager.swift` | API クライアント、cache、Pro 判定 |
| `Billing/ProCapabilities.swift` | feature flag enum |
| `Billing/BillingAPIClient.swift` | Workers REST 呼び出し |
| `Billing/KeychainStore.swift` | セッション・cache の Keychain 读写 |

### Info.plist / URL スキーム

- `CFBundleURLTypes` に `cordierite` スキームを登録
- `AppDelegate` または SwiftUI `onOpenURL` で `cordierite://auth?token=` を `AuthManager` に渡す

### Settings UI（Pro セクション）

| 要素 | 動作 |
|---|---|
| 現在のプラン | Free / Pro（`SubscriptionManager.isPro`） |
| Upgrade to Pro | Checkout をブラウザで開く |
| Restore Pro | メール入力 → magic-link 送信 |
| Manage subscription | Portal をブラウザで開く（Pro のみ表示） |
| Sign out | セッション削除（任意） |

### ProCapabilities（初期）

```swift
enum ProCapability {
  case unlimitedDictionary
  case appProfiles
  case longFormInput
  case dictionaryImportExport
}
```

`0015` 完了時点では **1 機能** を gate する（推奨: 辞書 21 件目、または Pro Preview stub）。

### エラーメッセージ（英語・ユーザー向け）

| 状況 | メッセージ例 |
|---|---|
| ネットワーク不可 | Could not reach Cordierite billing. Check your connection. |
| マジックリンク期限切れ | This sign-in link has expired. Request a new one. |
| 購読なし | No active Pro subscription was found for this email. |
| Checkout 失敗 | Could not start checkout. Try again later. |

## サイト連携

| パス | 用途 |
|---|---|
| `/pro/welcome` | Checkout 成功後。マジックリンク送信案内または自動リダイレクト |
| `/pro/canceled` | Checkout キャンセル |
| `/auth/verify` | メール内リンクの着地点 → アプリへリダイレクト |

`site/privacy/` と `site/terms/` は Pro 提供開始前に更新する。

- Privacy: Stripe（決済）、メールアドレス、Resend（送信）の記載
- Terms: 自動更新、解約、返金方針

## 実装フェーズ

### Phase 1 — バックエンド

1. `workers/billing` 雛形と D1 schema
2. Stripe Webhook + subscription 同期
3. `POST /auth/magic-link`, `POST /auth/verify`, `GET /entitlement`
4. `POST /checkout/session`, `POST /portal/session`
5. Stripe Dashboard（test mode）で Product / Price / Webhook 設定

### Phase 2 — アプリ

1. URL スキーム `cordierite://`
2. `AuthManager` + `SubscriptionManager` + Keychain
3. Settings Pro UI
4. `ProCapabilities` gate を 1 箇所接続

### Phase 3 — サイト・法務

1. `/pro/welcome`, `/auth/verify` ページ
2. Privacy / Terms 更新
3. Stripe 本番切替手順のドキュメント化

## テスト

### Stripe test mode

- テストカード `4242 4242 4242 4242`
- Webhook は Stripe CLI `stripe listen --forward-to localhost:8787/api/webhooks/stripe` でローカル検証
- magic-link は Mailpit / Resend test / ログ出力（dev のみ）で確認

### 手動確認項目

- [ ] Checkout 完了後に Webhook で subscription が `active`
- [ ] マジックリンクでアプリが Pro になる
- [ ] Restore で別環境から同じメールで Pro 復元
- [ ] Portal で解約後、entitlement が `isPro: false`
- [ ] オフライン猶予内は Pro 維持、超過後 Free
- [ ] 未購読メールへの magic-link 要求が列挙情報を漏らさない

## 将来拡張（本設計のスコープ外）

- Stripe Tax による税金計算
- 年額プラン
- チーム / ボリュームライセンス
- リカバリーキー（マジックリンク補助）
- Admin による手動 grant / revoke

## 参照

- [Stripe Checkout](https://docs.stripe.com/checkout)
- [Stripe Customer Portal](https://docs.stripe.com/customer-management)
- [Stripe Webhooks](https://docs.stripe.com/webhooks)
- [Cloudflare Workers](https://developers.cloudflare.com/workers/)
- [Cloudflare D1](https://developers.cloudflare.com/d1/)
