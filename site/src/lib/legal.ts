import { getCollection, render } from 'astro:content';
import type { Locale } from '../i18n';

export type LegalDocument = 'privacy' | 'terms';

export async function getLegalPage(document: LegalDocument, locale: Locale) {
  const entries = await getCollection('legal', ({ data }) => {
    return data.document === document && data.locale === locale;
  });
  const entry = entries[0];

  if (!entry) {
    throw new Error(`Missing legal entry: ${document} (${locale})`);
  }

  const rendered = await render(entry);
  return { entry, ...rendered };
}
