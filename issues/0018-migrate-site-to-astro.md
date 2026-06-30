# 製品サイトの Astro 雛形を整備する

- Priority: Medium
- Created: 2026-06-30
- Completed: {YYYY-MM-DD}
- Model: Composer 2.5
- Branch: feature/migrate-site-to-astro-d91d
- Polished: {YYYY-MM-DD}

## 目的

`site/` に **Astro プロジェクトの土台**（ビルド設定、レイアウト、共通コンポーネント、i18n オブジェクト構造、Content Collections 定義）を整備する。
ページ本文の移行と本番デプロイ切替は **0019** で行う。

## 優先度根拠

Medium。0019（全ページ移行）の前提となる。雛形を先に分離することで、レイアウトレビューとページ移行を並行しやすくする。

## 現状

- `site/` は HTML 6 ページ + `styles.css` 1 本。ビルドステップなし
- デプロイ: `wrangler deploy`（`assets.directory: "."`）
- 英語（ルート）と日本語（`/ja/`）で HTML を手書き複製
- `_includes/footer-*.html` は存在するが未使用

## 設計方針

### Astro

- **出力**: `output: 'static'`
- **アダプター**: 不要（`@astrojs/cloudflare` は導入しない）
- **URL 互換（設定のみ）**: Astro i18n で `prefixDefaultLocale: false`（英語 `/`、日本語 `/ja/`）

### i18n オブジェクト（構造のみ）

LP・共通 UI 文言用の **TypeScript モジュール骨格**を用意する。文言の移植は 0019。

```text
site/src/i18n/
  index.ts          … Locale 型、getTranslations(locale)、共通定数
  landing.en.ts     … LP 文言（en）— 0019 で本文を投入
  landing.ja.ts     … LP 文言（ja）— 0019 で本文を投入
  ui.en.ts          … ヘッダー・フッター・skip-link 等（en）
  ui.ja.ts          … 同上（ja）
```

- 各オブジェクトは **同一キー構造**を持ち、`Locale` ユニオン（`'en' | 'ja'`）で型安全に参照する
- 0018 時点ではキー定義と型のみ。値はプレースホルダーまたは最小限のサンプルでよい

### Content Collections（定義のみ）

法務ページ用 collection の **スキーマ定義**を用意する。Markdown 本文の変換は 0019。

```text
site/src/content/config.ts   … legal collection 定義
site/src/content/legal/      … 0019 で *.md を追加
```

- frontmatter 想定: `title`, `description`, `updated`, `locale`

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

### スタイル・静的アセット

- `styles.css` → `src/styles/global.css`（現行 CSS を移植）
- favicon / og-image / manifest / logo → `public/` に移動

## 変更対象

| 種別 | パス |
|---|---|
| 新規 | `site/astro.config.mjs` |
| 新規 | `site/tsconfig.json` |
| 新規 | `site/src/layouts/*.astro` |
| 新規 | `site/src/components/*.astro` |
| 新規 | `site/src/i18n/*.ts`（型・キー構造） |
| 新規 | `site/src/content/config.ts` |
| 新規 | `site/src/pages/index.astro`（プレースホルダー可） |
| 新規 | `site/public/`（静的アセット移動） |
| 更新 | `site/package.json`（astro 依存、`dev` / `build` scripts） |
| 更新 | `.gitignore`（`site/dist/`） |

## 完了条件

- [ ] `site/` で `npm run build` が成功する（プレースホルダー 1 ページで可）
- [ ] `npm run dev` でローカルプレビューできる
- [ ] `BaseLayout`, `SiteMeta`, `SiteHeader`, `SiteFooter`, `LandingLayout`, `LegalLayout`, `LandingPage` が存在する
- [ ] `src/i18n/` に `Locale` 型と en/ja 同一キー構造のオブジェクト骨格がある
- [ ] `src/content/config.ts` に legal collection スキーマが定義されている
- [ ] `global.css` が現行 `styles.css` と同等
- [ ] 静的アセットが `public/` に配置されている
- [ ] 現行の本番デプロイ（旧 HTML 直配信）は **まだ切り替えない**

## 実装方針

1. Astro プロジェクトを `site/` に初期化（TypeScript、`output: 'static'`）
2. `public/` へ静的アセットを移動し、`global.css` を移植
3. レイアウト・共通コンポーネントを現行 `index.html` から抽出
4. i18n オブジェクトの型・キー構造を定義
5. Content Collections スキーマを定義
6. プレースホルダー LP で `astro build` が通ることを確認

## スコープ外

- 6 ページ本文の移行（**0019**）
- 法務 Markdown の変換・投入（**0019**）
- `wrangler.jsonc` の `dist/` 切替・旧 HTML 削除（**0019**）
- `/pro/welcome`, `/auth/verify` 等（**0015** Phase 3）

## 依存関係

- **0019** が本 issue に依存（雛形完了後にページ移行）
- **0015** Phase 3 は **0019** 完了後

## 検証手順

```bash
cd site
npm ci
npm run dev
npm run build
```
