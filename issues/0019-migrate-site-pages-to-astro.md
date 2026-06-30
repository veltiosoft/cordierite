# 製品サイトのページを Astro に移行する

- Priority: Medium
- Created: 2026-06-30
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/migrate-site-pages-to-astro-d91d
- Polished: {YYYY-MM-DD}

## 目的

**0018** で整備した Astro 雛形上に、現行 6 ページの本文を移行し、**Markdown（法務）** と **i18n オブジェクト（LP・共通 UI）** で管理する。
既存 URL と SEO メタを維持したまま、Cloudflare Workers Static Assets の配信元を `dist/` に切り替える。

## 優先度根拠

Medium。0018 の雛形ができてから着手する。本 issue 完了で Astro 移行が実運用可能になる。

## 前提

- **0018** 完了（Astro 雛形、レイアウト、i18n 型・キー構造、Content Collections スキーマ）

## 設計方針

### i18n オブジェクト（本文投入）

0018 で定義したキー構造に、現行 HTML の文言を移植する。

```text
site/src/i18n/
  landing.en.ts     … 現行 site/index.html の LP 文言
  landing.ja.ts     … 現行 site/ja/index.html の LP 文言
  ui.en.ts          … ヘッダー・フッター・skip-link 等
  ui.ja.ts          … 同上
```

- 英語 LP と日本語 LP は **同一 `LandingPage.astro`** から `locale` 引数で描画
- ナビ・言語切替リンクは `getRelativeLocaleUrl()` と i18n から生成

### Markdown（法務）

現行 HTML を Markdown に変換し Content Collection に投入する。

```text
site/src/content/legal/
  privacy.en.md
  privacy.ja.md
  terms.en.md
  terms.ja.md
```

- frontmatter: `title`, `description`, `updated`, `locale`
- 本文は現行 `<article class="legal-content">` 相当を Markdown 化
- `LegalLayout.astro` + `render()` / `<Content />` で表示

### ページルート

| URL | ファイル |
|---|---|
| `/` | `src/pages/index.astro` |
| `/ja/` | `src/pages/ja/index.astro` |
| `/privacy/` | `src/pages/privacy/index.astro` |
| `/terms/` | `src/pages/terms/index.astro` |
| `/ja/privacy/` | `src/pages/ja/privacy/index.astro` |
| `/ja/terms/` | `src/pages/ja/terms/index.astro` |

### デプロイ切替

- `wrangler.jsonc`: `assets.directory: "./dist"`
- `html_handling: "auto-trailing-slash"` を維持
- `package.json`: `deploy` = `astro build && wrangler deploy`
- 旧 HTML・未使用 `_includes/`・`.assetsignore` を削除

## 変更対象

| 種別 | パス |
|---|---|
| 更新 | `site/src/i18n/*.ts`（現行 HTML から文言移植） |
| 新規 | `site/src/content/legal/*.md` |
| 新規 | `site/src/pages/index.astro`, `site/src/pages/ja/index.astro` |
| 新規 | `site/src/pages/privacy/index.astro`, `site/src/pages/ja/privacy/index.astro` |
| 新規 | `site/src/pages/terms/index.astro`, `site/src/pages/ja/terms/index.astro` |
| 更新 | `site/wrangler.jsonc` |
| 更新 | `site/package.json`（`deploy` script） |
| 削除 | `site/index.html`, `site/ja/**`, `site/privacy/**`, `site/terms/**`, `site/styles.css`, `site/_includes/**`, `site/.assetsignore` |

## 完了条件

### ビルド・デプロイ

- [ ] `npm run build` が成功し、6 ページすべてが `dist/` に出力される
- [ ] `npm run deploy` で Cloudflare Workers にデプロイできる

### URL・SEO 互換

- [ ] 既存 6 URL がすべて 200（末尾スラッシュ含む）
- [ ] `<title>`, `description`, OG / Twitter meta が現行 HTML と実質同等
- [ ] `hreflang` および言語切替リンクが正しい
- [ ] favicon / `site.webmanifest` / `og-image.png` が従来どおり参照できる

### i18n オブジェクト

- [ ] LP・ヘッダー・フッターの文言が `site/src/i18n/` に集約され、Astro テンプレートに文言の直書きがない
- [ ] `landing.en.ts` と `landing.ja.ts` が同一キー構造を持ち、TypeScript で型チェックされる
- [ ] 英語 LP と日本語 LP が同一 `LandingPage.astro` から描画される

### Markdown（法務）

- [ ] privacy / terms の本文が `src/content/legal/*.md` に存在する
- [ ] frontmatter の `updated` が「Last updated」に反映される
- [ ] 現行 HTML の法務本文と Markdown 変換後に実質的な差分がない

### 品質

- [ ] モバイル（640px 以下）含め、現行 CSS と見た目が同等
- [ ] skip-link、`aria-label`、見出し階層などアクセシビリティ属性が維持される

## 実装方針

1. 現行 HTML から i18n オブジェクトへ文言を移植
2. privacy / terms HTML を Markdown に変換
3. 6 ページの Astro ルートを実装
4. `wrangler.jsonc` を `dist/` 向けに更新
5. 旧 HTML を削除
6. 全 URL の目視確認と meta 比較
7. デプロイ

## スコープ外

- Astro 雛形・レイアウト新規作成（**0018**）
- `/pro/welcome`, `/pro/canceled`, `/auth/verify`（**0015** Phase 3）
- サイト用 CI
- デザイン刷新・LP コピー変更

## 依存関係

- **0018** 完了が必須
- **0015** Phase 3 のサイトページは本 issue 完了後

## 検証手順

```bash
cd site
npm ci
npm run build
npx wrangler dev
```

確認項目:

- 6 URL の HTML 出力
- 言語切替リンク
- 法務ページの Markdown レンダリング
- OG 画像 URL（`https://cordierite.veltiosoft.com/og-image.png`）
