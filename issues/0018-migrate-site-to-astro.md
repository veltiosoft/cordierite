# 製品サイトを Astro に移行する

- Priority: Medium
- Created: 2026-06-30
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/migrate-site-to-astro-d91d
- Polished: {YYYY-MM-DD}

## 目的

`site/` の静的 HTML を **Astro** ベースに移行し、レイアウト・メタ情報・多言語文言の共通化と、法務ページの **Markdown 管理**を可能にする。
既存 URL（`/`, `/ja/`, `/privacy/`, `/terms/` 等）と SEO メタを維持したまま、Cloudflare Workers Static Assets へのデプロイ方式は継続する。

## 優先度根拠

Medium。現行サイトは 6 ページの静的 HTML で運用可能だが、英日複製によるメンテナンスコストが高い。
課金基盤（`0015` Phase 3）で `/pro/welcome`, `/auth/verify` 等の追加が予定されており、移行を先に済ませるとサイト拡張の土台が整う。

## 現状

- `site/` は HTML 6 ページ + `styles.css` 1 本。ビルドステップなし
- デプロイ: `wrangler deploy`（`assets.directory: "."`）
- 英語（ルート）と日本語（`/ja/`）で HTML を手書き複製
- `_includes/footer-*.html` は存在するが未使用（各 HTML にフッターをインライン）
- カスタムドメイン: `cordierite.veltiosoft.com`（`wrangler.jsonc`）

## 設計方針

### Astro

- **出力**: `output: 'static'`（現状どおり静的サイト。SSR / `@astrojs/cloudflare` アダプターは不要）
- **デプロイ**: `astro build` → `dist/` を Wrangler Static Assets で配信
- **URL 互換**: Astro i18n で `prefixDefaultLocale: false`（英語 `/`、日本語 `/ja/`）。`html_handling: "auto-trailing-slash"` を維持

### i18n オブジェクト

LP・共通 UI 文言は **TypeScript の i18n オブジェクト**に集約する。HTML / Astro テンプレートへの直書きは避ける。

```text
site/src/i18n/
  index.ts          … Locale 型、getTranslations(locale)、共通定数
  landing.en.ts     … LP 文言（en）
  landing.ja.ts     … LP 文言（ja）
  ui.en.ts          … ヘッダー・フッター・skip-link 等（en）
  ui.ja.ts          … 同上（ja）
```

- 各オブジェクトは **同一キー構造**を持ち、`Locale` ユニオン（`'en' | 'ja'`）で型安全に参照する
- ナビ・言語切替リンクは `getRelativeLocaleUrl()` と i18n オブジェクトから生成し、URL のハードコードを最小化する
- 英語 LP と日本語 LP は **同一 `LandingPage.astro`** から `locale` 引数で描画する

### Markdown（Content Collections）

法務ページ（privacy / terms）は **Content Collections + Markdown** で管理する。

```text
site/src/content/legal/
  privacy.en.md
  privacy.ja.md
  terms.en.md
  terms.ja.md
```

- frontmatter: `title`, `description`, `updated`（Last updated 表示用）, `locale`
- 本文は現行 HTML の `<article class="legal-content">` 相当を Markdown に変換
- レンダリング: `<Content />` または `render()` + `LegalLayout.astro`

### レイアウト・コンポーネント

| ファイル | 責務 |
|---|---|
| `BaseLayout.astro` | `<html lang>`, CSS, skip-link |
| `LandingLayout.astro` | LP 用ヘッダー（セクションナビ） |
| `LegalLayout.astro` | 法務用ヘッダー（ロゴにホームリンク） |
| `SiteMeta.astro` | title, description, OG, Twitter, hreflang |
| `SiteHeader.astro` | ロゴ・ナビ（i18n + locale props） |
| `SiteFooter.astro` | フッター（i18n + locale props） |
| `LandingPage.astro` | LP セクション描画（i18n オブジェクト参照） |

### ページルート

| URL | ファイル |
|---|---|
| `/` | `src/pages/index.astro` |
| `/ja/` | `src/pages/ja/index.astro` |
| `/privacy/` | `src/pages/privacy/index.astro` |
| `/terms/` | `src/pages/terms/index.astro` |
| `/ja/privacy/` | `src/pages/ja/privacy/index.astro` |
| `/ja/terms/` | `src/pages/ja/terms/index.astro` |

### スタイル・静的アセット

- `styles.css` → `src/styles/global.css`（見た目は現行維持）
- favicon / og-image / manifest / logo → `public/`

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `site/astro.config.mjs` |
| 新規 | `site/tsconfig.json` |
| 新規 | `site/src/layouts/*.astro` |
| 新規 | `site/src/components/*.astro` |
| 新規 | `site/src/i18n/*.ts` |
| 新規 | `site/src/content/legal/*.md` |
| 新規 | `site/src/content/config.ts`（legal collection 定義） |
| 新規 | `site/src/pages/index.astro`, `site/src/pages/ja/index.astro` |
| 新規 | `site/src/pages/privacy/index.astro`, `site/src/pages/ja/privacy/index.astro` |
| 新規 | `site/src/pages/terms/index.astro`, `site/src/pages/ja/terms/index.astro` |
| 新規 | `site/public/`（静的アセット移動） |
| 更新 | `site/package.json`（astro 依存、`build` / `dev` / `deploy` scripts） |
| 更新 | `site/wrangler.jsonc`（`assets.directory: "./dist"`） |
| 更新 | `.gitignore`（`site/dist/`） |
| 削除 | 移行完了後: ルートの `site/index.html`, `site/ja/**`, `site/privacy/**`, `site/terms/**`, `site/styles.css`, `site/_includes/**`, `site/.assetsignore` |

## 完了条件

### ビルド・デプロイ

- [ ] `site/` で `npm run build` が成功し、`dist/` に 6 ページすべてが出力される
- [ ] `npm run deploy`（`astro build && wrangler deploy`）で Cloudflare Workers にデプロイできる
- [ ] ローカルで `npm run dev` により全ページをプレビューできる

### URL・SEO 互換

- [ ] 既存 6 URL がすべて 200（末尾スラッシュ含む）: `/`, `/ja/`, `/privacy/`, `/terms/`, `/ja/privacy/`, `/ja/terms/`
- [ ] 各ページの `<title>`, `description`, OG / Twitter meta が現行 HTML と実質同等
- [ ] `hreflang` および言語切替リンク（`/ja/` ↔ `/`）が正しい
- [ ] favicon / `site.webmanifest` / `og-image.png` が従来どおり参照できる

### i18n オブジェクト

- [ ] LP・ヘッダー・フッターの文言が `site/src/i18n/` に集約され、Astro テンプレートに文言の直書きがない
- [ ] `landing.en.ts` と `landing.ja.ts` が同一キー構造を持ち、TypeScript で型チェックされる
- [ ] 英語 LP と日本語 LP が同一 `LandingPage.astro` から描画される

### Markdown（法務）

- [ ] privacy / terms の本文が `src/content/legal/*.md` に存在する
- [ ] frontmatter の `updated` がページ上の「Last updated」に反映される
- [ ] 現行 HTML の法務本文と Markdown 変換後の内容に実質的な差分がない（段落・見出し・リンク）

### 品質

- [ ] モバイル（640px 以下）含め、現行 CSS と見た目が同等
- [ ] skip-link、`aria-label`、見出し階層などアクセシビリティ属性が維持される

## 実装方針

1. Astro プロジェクトを `site/` に初期化（TypeScript、`output: 'static'`）
2. `public/` へ静的アセットを移動し、`global.css` を移植
3. `SiteMeta` / `BaseLayout` / `SiteHeader` / `SiteFooter` を現行 `index.html` から抽出
4. `src/i18n/` に LP・UI 文言オブジェクトを定義し、`LandingPage.astro` を実装
5. 現行 privacy / terms HTML を Markdown に変換し Content Collection を設定
6. 6 ページを Astro ルートとして実装
7. `wrangler.jsonc` を `dist/` 向けに更新し、旧 HTML を削除
8. 全 URL の目視確認と meta 比較

## スコープ外

- `/pro/welcome`, `/pro/canceled`, `/auth/verify`（`0015` Phase 3 で別途追加）
- `workers/billing/` API Worker
- サイト用 CI（必要なら別 issue）
- デザイン刷新・LP コピー変更
- `@astrojs/cloudflare` 導入・SSR 化

## 依存関係

- **0015** Phase 3 のサイトページ追加は、本 issue 完了後に Astro 上で実装する（本 issue では placeholder 不要）
- Cloudflare アカウント・既存 `cordierite-site` Worker 設定（変更は `assets.directory` のみ想定）

## 検証手順

```bash
cd site
npm ci
npm run build
npx wrangler dev   # dist を配信して URL 確認
```

確認項目:

- 6 URL の HTML 出力
- 言語切替リンク
- 法務ページの Markdown レンダリング
- OG 画像 URL（`https://cordierite.veltiosoft.com/og-image.png`）
