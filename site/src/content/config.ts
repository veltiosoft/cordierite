import { defineCollection, z } from 'astro:content';

const legal = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    updated: z.coerce.date(),
    locale: z.enum(['en', 'ja']),
    document: z.enum(['privacy', 'terms']),
  }),
});

export const collections = { legal };
