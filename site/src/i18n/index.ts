import { landingEn } from './landing.en';
import { landingJa } from './landing.ja';
import { uiEn } from './ui.en';
import { uiJa } from './ui.ja';

export const SITE_URL = 'https://cordierite.veltiosoft.com';

export type Locale = 'en' | 'ja';

export type PageKey = 'home' | 'privacy' | 'terms';

export type LandingTranslations = typeof landingEn;
export type UiTranslations = typeof uiEn;

const landingByLocale = {
  en: landingEn,
  ja: landingJa,
} as const satisfies Record<Locale, LandingTranslations>;

const uiByLocale = {
  en: uiEn,
  ja: uiJa,
} as const satisfies Record<Locale, UiTranslations>;

const pagePaths: Record<PageKey, Record<Locale, string>> = {
  home: { en: '/', ja: '/ja/' },
  privacy: { en: '/privacy/', ja: '/ja/privacy/' },
  terms: { en: '/terms/', ja: '/ja/terms/' },
};

export function getLandingTranslations(locale: Locale): LandingTranslations {
  return landingByLocale[locale];
}

export function getUiTranslations(locale: Locale): UiTranslations {
  return uiByLocale[locale];
}

export function getPagePath(pageKey: PageKey, locale: Locale): string {
  return pagePaths[pageKey][locale];
}

export function getAlternateLocale(locale: Locale): Locale {
  return locale === 'en' ? 'ja' : 'en';
}

export function getAlternatePagePath(pageKey: PageKey, locale: Locale): string {
  return getPagePath(pageKey, getAlternateLocale(locale));
}

export function getHomePath(locale: Locale): string {
  return getPagePath('home', locale);
}

export function formatLegalUpdatedDate(date: Date, locale: Locale): string {
  if (locale === 'ja') {
    return new Intl.DateTimeFormat('ja-JP', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      timeZone: 'UTC',
    }).format(date);
  }

  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}

export function getOgLocale(locale: Locale): string {
  return locale === 'ja' ? 'ja_JP' : 'en_US';
}

export function getOgLocaleAlternate(locale: Locale): string {
  return locale === 'ja' ? 'en_US' : 'ja_JP';
}
