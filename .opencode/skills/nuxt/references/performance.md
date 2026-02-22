# Nuxt Performance Reference

Comprehensive reference for all performance optimization techniques in Nuxt 4 applications. Focus on Core Web Vitals (LCP, CLS, INP) and bundle size reduction.

## Table of Contents

1. [Core Web Vitals Targets](#core-web-vitals-targets)
2. [Bundle Size Reduction](#bundle-size-reduction)
3. [Image Optimization](#image-optimization)
4. [Font Optimization](#font-optimization)
5. [Third-Party Scripts](#third-party-scripts)
6. [Data Fetching Patterns](#data-fetching-patterns)
7. [Vue Performance Primitives](#vue-performance-primitives)
8. [Plugin Audit Checklist](#plugin-audit-checklist)
9. [Profiling Workflow](#profiling-workflow)
10. [Progressive Enhancement](#progressive-enhancement)

---

## Core Web Vitals Targets

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5–4.0s | > 4.0s |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 |
| INP (Interaction to Next Paint) | ≤ 200ms | 200–500ms | > 500ms |

**LCP** — Optimize the largest above-the-fold element: preload hero images, use `<NuxtImg preload loading="eager" fetch-priority="high">`, minimize render-blocking resources.

**CLS** — Prevent layout shift: always specify `width`/`height` on images and media, use `@nuxt/fonts` fallback metrics, avoid inserting content above existing content after load.

**INP** — Minimize JavaScript execution during interactions: lazy-load non-critical components, use `@nuxt/scripts` for deferred third-party loading, prefer `shallowRef` for large reactive objects.

---

## Bundle Size Reduction

### nuxi analyze

Run bundle analysis before and after optimizations:

```bash
npx nuxi analyze
```

Generates a visual treemap (`vite-bundle-visualizer`). Interpret results:

- **Large module block with many sub-modules** → import only needed parts rather than the whole library
- **Large standalone block** → candidate for lazy-loading (`LazyMyComponent`) or dynamic `import()`
- **Duplicate modules** → check for version mismatches in `package.json`

### Remove Unused Dependencies

```bash
# Find packages referenced in package.json but never imported
npx depcheck

# Or manually audit
cat package.json | grep dependencies
```

Remove packages that are not imported anywhere in source code. Also search for unused composables and utility functions:

```bash
# Example: check if a composable is used anywhere
grep -r "useMyComposable" app/
```

### Code Splitting with Dynamic Imports

For utilities or heavy libraries used only in specific user flows, use dynamic imports:

```ts
// Loaded only when needed
const { jsPDF } = await import('jspdf')
```

For components, use the `Lazy` prefix instead of manual `defineAsyncComponent`.

---

## Image Optimization

Install `@nuxt/image`:

```bash
npx nuxi module add image
```

### Priority Classification

Classify every image by render priority before choosing attributes:

**Critical (above fold / LCP candidate):**
```html
<NuxtImg
  src="/hero.jpg"
  format="webp"
  preload
  loading="eager"
  fetch-priority="high"
  width="1200"
  height="600"
  sizes="100vw sm:100vw md:1200px"
/>
```

**Non-critical (below fold):**
```html
<NuxtImg
  src="/feature.jpg"
  format="webp"
  loading="lazy"
  fetch-priority="low"
  width="600"
  height="400"
/>
```

### Responsive Images

Use the `sizes` prop to generate a `srcset` for different breakpoints:

```html
<NuxtImg
  src="/card.jpg"
  sizes="sm:100vw md:50vw lg:400px"
  format="webp"
  width="400"
  height="300"
/>
```

### Format Selection

- Default to `webp` for broad compatibility and ~30% smaller files vs JPEG
- Use `avif` for cutting-edge environments (smaller than WebP, slower encode)
- Always set `width` and `height` to reserve space and prevent CLS

---

## Font Optimization

Install `@nuxt/fonts`:

```bash
npx nuxi module add fonts
```

The module automatically:

1. Resolves `font-family` declarations in CSS
2. Self-hosts fonts under `/_fonts` (no external DNS lookups)
3. Generates `@font-face` with correct `font-display` settings
4. Creates fallback font metrics via `fontaine` to minimize CLS
5. Bundles fonts with content-hashed filenames for long-lived caching

No additional configuration is required for Google Fonts or Bunny Fonts — just declare the font family in CSS or Tailwind config as usual.

**Manual preloading (if not using @nuxt/fonts):**
```html
<!-- app/app.vue or layout -->
<Head>
  <Link
    rel="preload"
    as="font"
    type="font/woff2"
    href="/fonts/inter.woff2"
    crossorigin
  />
</Head>
```

---

## Third-Party Scripts

Install `@nuxt/scripts`:

```bash
npx nuxi module add scripts
```

### Deferred Loading Pattern

Never load analytics or embeds eagerly — they block INP and LCP:

```ts
// Google Analytics — manual trigger
const { proxy, onLoaded } = useScriptGoogleAnalytics({
  id: 'G-XXXXXXXX',
  scriptOptions: { trigger: 'manual' },
})
// Queue events safely before script loads
proxy.gtag('config', 'G-XXXXXXXX')

// Trigger load after page is interactive
onNuxtReady(() => proxy.$script.load())
```

### Common Triggers

| Trigger | Use case |
|---|---|
| `manual` | Full control; load on user consent or after TTI |
| `'nuxtReady'` | Load after Nuxt finishes hydrating |
| `'visibility'` | Load when element enters viewport |
| `'mousedown'` | Load on first user interaction |

---

## Data Fetching Patterns

### useFetch vs $fetch

| | `useFetch` / `useAsyncData` | `$fetch` |
|---|---|---|
| SSR data transfer | Serialized to payload, no double fetch | Runs again on client |
| Reactivity | Returns reactive `data`, `status`, `error` | Raw response |
| Caching/dedup | Built-in via key | Manual |
| Use in setup | Required | Flexible |

Always prefer `useFetch` in page and component `<script setup>`.

### Keying and Refresh

```ts
// Custom key prevents duplicate fetches for same endpoint
const { data, refresh } = await useFetch('/api/items', { key: 'items' })

// Refresh on demand (e.g., after mutation)
await refresh()
```

### Server-Only Fetch

Use `$fetch` inside `server/api/` routes — these never run on the client and have access to private environment variables:

```ts
// server/api/products.get.ts
export default defineEventHandler(async () => {
  return await $fetch('https://internal-api/products', {
    headers: { Authorization: process.env.API_SECRET },
  })
})
```

---

## Vue Performance Primitives

Nuxt apps are Vue apps. Apply Vue-level optimizations inside components:

### shallowRef / shallowReactive

Use when object structure changes (not deep property values):

```ts
// Bad: deeply tracks every nested property
const config = ref({ nested: { deeply: { value: 1 } } })

// Good: only tracks top-level reference
const config = shallowRef({ nested: { deeply: { value: 1 } } })
```

### v-once

Render a subtree exactly once and skip future updates:

```html
<!-- Footer links never change -->
<footer v-once>
  <nav>...</nav>
</footer>
```

### v-memo

Skip re-render when listed dependencies are unchanged:

```html
<!-- Only re-render list item when `item.id` or `selected` changes -->
<div v-for="item in list" :key="item.id" v-memo="[item.id, selected === item.id]">
  <HeavyItemCard :item="item" :selected="selected === item.id" />
</div>
```

### computed vs methods in templates

Always use `computed` for derived values in templates — results are cached until dependencies change:

```ts
// Good: cached
const total = computed(() => cart.value.reduce((sum, i) => sum + i.price, 0))

// Bad: recalculated on every render
function total() {
  return cart.value.reduce((sum, i) => sum + i.price, 0)
}
```

---

## Plugin Audit Checklist

Run this audit before every major release:

- [ ] List all files in `app/plugins/`
- [ ] For each plugin, ask: does this need to run globally at startup?
  - No → move logic to a composable in `app/composables/` or a utility in `app/utils/`
  - Yes → keep as plugin, but ensure it completes synchronously or does not block hydration
- [ ] Avoid async plugins unless strictly necessary (`defineNuxtPlugin(async () => {...})`)
- [ ] Check for heavy initialization (e.g., loading large libraries) — lazy-load inside the relevant component instead
- [ ] Confirm plugin has correct `mode` if it only applies to server or client:

```ts
// Client-only plugin (avoids SSR import of browser-only APIs)
export default defineNuxtPlugin({
  name: 'my-client-plugin',
  enforce: 'post',
  setup() {
    // browser-only code
  },
})
```

---

## Profiling Workflow

### 1. Local Development

```bash
# Bundle analysis
npx nuxi analyze

# Run with production build locally to test SSR performance
npx nuxi build && npx nuxi preview
```

Use **Nuxt DevTools** (auto-enabled in dev mode):
- **Timeline tab** — find slow component initialization
- **Inspect tab** — see all files, sizes, and evaluation times
- **Render Tree** — identify unnecessarily eager component loads

### 2. Staging / Production Audit

**Chrome DevTools — Performance tab:**
1. Open DevTools → Performance
2. Click record → reload page → stop
3. Inspect LCP, CLS markers on the timeline
4. Look for long tasks (>50ms) blocking the main thread

**Chrome DevTools — Lighthouse tab:**
1. Select "Performance" category
2. Run audit
3. Act on failing audits in priority order

**PageSpeed Insights:**
- URL: https://pagespeed.web.dev
- Provides both lab (controlled) and CrUX field data (real users)
- Use "Mobile" results as primary target — most traffic is mobile

**WebPageTest:**
- URL: https://www.webpagetest.org
- Test from multiple regions (closest to real user base)
- Use "Film Strip" view to identify visual progression and LCP element

### 3. Iterative Optimization Cycle

1. Identify worst metric (LCP, CLS, or INP) in PageSpeed Insights
2. Use Chrome DevTools to trace the root cause
3. Apply fix (see relevant section above)
4. Re-run `nuxi analyze` to confirm bundle impact
5. Deploy to staging and re-audit with PageSpeed Insights
6. Repeat until all Core Web Vitals are "Good"

---

## Progressive Enhancement

Load content in priority order to maximize perceived performance:

1. **Render critical HTML first** — universal rendering ensures above-the-fold content arrives with the initial HTML
2. **Defer non-critical JS** — use `Lazy` prefix and `hydrate-on-visible`
3. **Defer third-party scripts** — use `@nuxt/scripts` with `manual` or `nuxtReady` trigger
4. **Prefetch next navigation** — `<NuxtLink>` handles this automatically for visible links
5. **Cache at the right layer** — use `routeRules` with `swr` or `isr` to avoid server processing on repeat visits
