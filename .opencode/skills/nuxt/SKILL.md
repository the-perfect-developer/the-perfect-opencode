---
name: nuxt
description: This skill should be used when the user asks to "build a Nuxt app", "optimize Nuxt performance", "configure Nuxt rendering", "follow Nuxt best practices", or needs guidance on Nuxt 4 development patterns, hybrid rendering, or Core Web Vitals optimization.
---

# Nuxt Best Practices

Guidance for building high-performance Nuxt 4 applications following official best practices. Covers rendering strategies, performance optimization, data fetching, component patterns, and profiling.

## Rendering Strategies

### Choose the Right Rendering Mode per Route

Nuxt 4 supports hybrid rendering via `routeRules`. Assign rendering strategies per route rather than using a single global mode:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  routeRules: {
    '/': { prerender: true },          // Static at build time
    '/products/**': { swr: 3600 },     // Cached, revalidated in background
    '/blog': { isr: 3600 },            // CDN-cached, revalidated hourly
    '/admin/**': { ssr: false },        // Client-side only
    '/api/**': { cors: true },
  },
})
```

**Route rule reference:**
- `prerender: true` — generate at build time, serve as static asset
- `swr: N` — server/proxy cache for N seconds, stale-while-revalidate
- `isr: N` — CDN cache until next deploy (Vercel/Netlify); `isr: true` means persist indefinitely
- `ssr: false` — browser-only rendering (SPA mode for that route)
- `redirect: '/new'` — server-side redirect
- `headers: {}` — add custom response headers (e.g., long cache on assets)

### Default to Universal Rendering

Universal rendering (SSR + hydration) is the default and best choice for content-oriented apps (blogs, e-commerce, marketing sites). It delivers:
- Immediate HTML visible to users and crawlers
- Full interactivity after hydration
- Better Core Web Vitals scores (LCP, CLS)

### Edge-Side Rendering

Deploy to CDN edge servers (Cloudflare Workers, Vercel Edge, Netlify Edge) for reduced latency. Nuxt's Nitro engine supports these out of the box — no code changes required, only a different build preset.

See `references/rendering.md` for a full breakdown of trade-offs and deployment targets.

## Component Best Practices

### Lazy-Load Non-Critical Components

Prefix any component with `Lazy` to defer its JavaScript until needed. This directly reduces initial bundle size and improves Time to Interactive (TTI):

```html
<script setup lang="ts">
const show = ref(false)
</script>

<template>
  <div>
    <button @click="show = true">Load list</button>
    <LazyMountainsList v-if="show" />
  </div>
</template>
```

### Use Lazy Hydration (Nuxt 3.16+)

Defer hydration of components until they enter the viewport or the browser is idle. This improves TTI without sacrificing SSR-rendered content:

```html
<template>
  <!-- Hydrate only when scrolled into view -->
  <LazyCommentSection hydrate-on-visible />

  <!-- Hydrate when browser is idle -->
  <LazyAnalyticsWidget hydrate-on-idle />

  <!-- Hydrate on user interaction -->
  <LazyChatWidget hydrate-on-interaction />
</template>
```

### Avoid Overusing Plugins

Plugins execute during the hydration phase and block interactivity. Audit plugins regularly — if logic does not need to run globally at startup, move it to a composable or utility function instead.

## Data Fetching

### Use `useFetch` and `useAsyncData`

These composables deduplicate server-side fetches. Data fetched on the server is serialized into the page payload and reused by the client — no double fetch:

```ts
// Good: data transferred via payload, no duplicate network request
const { data } = await useFetch('/api/products')

// Bad: runs separately on server and client
const data = await $fetch('/api/products')
```

### Keep Composables Synchronous at the Top Level

Vue and Nuxt composables rely on a synchronous lifecycle context. Do not call composables after an `await` outside of `<script setup>`, `defineNuxtComponent`, `defineNuxtPlugin`, or `defineNuxtRouteMiddleware`:

```ts
// Bad
const data = await someAsyncOperation()
const config = useRuntimeConfig() // context lost

// Good — call composable before await, or inside <script setup>
const config = useRuntimeConfig()
const data = await someAsyncOperation()
```

## Performance Optimization

### Images: Use `<NuxtImg>`

Replace all `<img>` tags with `<NuxtImg>` (requires `@nuxt/image`). It auto-converts to WebP/Avif, resizes, and generates responsive `sizes`:

```html
<!-- Above-the-fold / LCP image -->
<NuxtImg
  src="/hero.jpg"
  format="webp"
  preload
  loading="eager"
  fetch-priority="high"
  width="1200"
  height="600"
/>

<!-- Below-the-fold image -->
<NuxtImg
  src="/feature.jpg"
  format="webp"
  loading="lazy"
  fetch-priority="low"
  width="600"
  height="400"
/>
```

Always set `width` and `height` to prevent layout shift (CLS).

### Fonts: Use Nuxt Fonts

Add `@nuxt/fonts` to automatically self-host fonts, inject `@font-face` rules, and generate fallback metrics that minimize CLS. No manual `<link rel="preload">` required.

### Third-Party Scripts: Use Nuxt Scripts

Add `@nuxt/scripts` to load analytics, embeds, and social widgets without blocking the main thread. Scripts support deferred triggers and typed proxies:

```ts
const { proxy } = useScriptGoogleAnalytics({
  id: 'G-XXXXXXXX',
  scriptOptions: { trigger: 'manual' },
})
// Safe to call before script loads — events are queued
proxy.gtag('event', 'page_view')
```

### Leverage Smart Prefetching via `<NuxtLink>`

`<NuxtLink>` automatically prefetches JavaScript for in-viewport links. To reduce bandwidth on large sites, switch to interaction-based prefetching:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  experimental: {
    defaults: {
      nuxtLink: { prefetchOn: 'interaction' },
    },
  },
})
```

### Apply Vue-Level Optimizations

Nuxt apps are Vue apps — apply Vue performance primitives:
- `shallowRef` / `shallowReactive` for large objects not needing deep reactivity
- `v-once` for static subtrees that never change
- `v-memo` to skip re-renders when dependencies are unchanged
- `computed` to cache derived state rather than recalculating in templates

## Auto-Imports

Nuxt auto-imports components from `app/components/`, composables from `app/composables/`, and utilities from `app/utils/`. Only used exports appear in the production bundle — no manual tree-shaking needed.

Place server-only utilities in `server/utils/` — they are also auto-imported within the `server/` directory.

To make imports explicit (useful for clarity or monorepos), use the `#imports` alias:

```ts
import { ref, computed, useFetch } from '#imports'
```

## Common Pitfalls

| Problem | Solution |
|---|---|
| Double data fetch (server + client) | Use `useFetch` / `useAsyncData` instead of raw `$fetch` |
| Plugins blocking hydration | Move non-global logic to composables |
| Large bundles | Run `nuxi analyze`; lazy-load large components |
| Layout shift from images | Always set `width`/`height` on `<NuxtImg>` |
| Unoptimized fonts | Add `@nuxt/fonts` |
| INP degradation from third-party scripts | Add `@nuxt/scripts` with deferred triggers |
| Deep reactivity on large objects | Use `shallowRef` / `shallowReactive` |
| Composable called after `await` | Call composables synchronously before async operations |
| Unused dependencies bloating bundle | Audit `package.json`; remove unused packages |

## Profiling Workflow

1. **Bundle analysis** — `npx nuxi analyze` generates a visual treemap; identify large dependencies.
2. **Nuxt DevTools** — Timeline, Render Tree, and Inspect tabs reveal component render costs and file sizes.
3. **Chrome DevTools** — Performance panel shows LCP/CLS live; Lighthouse gives actionable scores.
4. **PageSpeed Insights** — Combine lab + real-world field data for production auditing.
5. **WebPageTest** — Test from multiple global regions and network conditions.

## Additional Resources

### Reference Files

- **`references/performance.md`** — Detailed breakdown of all performance techniques, `routeRules` options, and Core Web Vitals targets
- **`references/rendering.md`** — In-depth rendering mode trade-offs, hydration mismatch prevention, and deployment targets
