# Nuxt Rendering Modes Reference

Complete reference for Nuxt 4 rendering strategies, hybrid rendering configuration, hydration patterns, and deployment targets.

## Table of Contents

1. [Rendering Mode Comparison](#rendering-mode-comparison)
2. [Universal Rendering (Default)](#universal-rendering-default)
3. [Client-Side Rendering (SPA)](#client-side-rendering-spa)
4. [Hybrid Rendering with routeRules](#hybrid-rendering-with-routerules)
5. [Hydration Patterns and Pitfalls](#hydration-patterns-and-pitfalls)
6. [Edge-Side Rendering](#edge-side-rendering)
7. [Deployment Targets](#deployment-targets)

---

## Rendering Mode Comparison

| Mode | HTML on load | SEO | Interactivity | Cost |
|---|---|---|---|---|
| Universal (SSR) | Full HTML | Excellent | After hydration | Server required |
| Static (prerender) | Full HTML | Excellent | After hydration | None (CDN) |
| SPA (ssr: false) | Empty shell | Poor | Immediate (no hydration) | None (CDN) |
| ISR / SWR | Full HTML (cached) | Excellent | After hydration | Minimal (cache hits) |
| Edge SSR | Full HTML | Excellent | After hydration | Low (edge compute) |

**Choose by use case:**

| Use case | Recommended mode |
|---|---|
| Blog / documentation | `prerender: true` |
| Product pages (frequent updates) | `swr: 3600` or `isr: 3600` |
| Homepage | `prerender: true` |
| Admin dashboard | `ssr: false` |
| User feed / personalized content | SSR (default, no rule) |
| E-commerce product detail | `isr: true` or `swr` |

---

## Universal Rendering (Default)

Nuxt renders the Vue component tree on the server, returns a fully-formed HTML document, then re-runs JavaScript in the browser to attach event listeners (hydration).

**Configuration (explicit):**
```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: true, // default, can be omitted
})
```

**Execution environment per code location:**

| Location | Server | Client |
|---|---|---|
| `<script setup>` | Yes (initial) | Yes (hydration) |
| Event handlers (`@click`) | No | Yes |
| `onMounted` lifecycle | No | Yes |
| `server/api/` routes | Yes | No |
| Plugins with `{ server: false }` | No | Yes |

**Guard browser-only APIs:**

```ts
// Bad: window is undefined on server
const width = window.innerWidth

// Good: run only on client
const width = ref(0)
onMounted(() => { width.value = window.innerWidth })

// Or use process.client
if (process.client) {
  // browser-only code
}
```

**Use `<ClientOnly>` for components that cannot SSR:**

```html
<template>
  <ClientOnly>
    <MapboxMap />
    <template #fallback>
      <div class="map-skeleton" />
    </template>
  </ClientOnly>
</template>
```

Always provide a `#fallback` slot to avoid CLS from content appearing after hydration.

---

## Client-Side Rendering (SPA)

The server returns an empty HTML shell; Vue renders everything in the browser. Use for internal tools, dashboards, or apps behind authentication where SEO is irrelevant.

**Enable globally:**
```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: false,
})
```

**Enable per route (hybrid):**
```ts
export default defineNuxtConfig({
  routeRules: {
    '/admin/**': { ssr: false },
  },
})
```

**SPA loading template** — provide a loading indicator shown before Vue hydrates:

```html
<!-- spa-loading-template.html -->
<div id="app-loading">
  <div class="spinner"></div>
</div>
```

**Static SPA deployment** — generate a minimal set of files:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: false,
  hooks: {
    'prerender:routes'({ routes }) {
      routes.clear() // Only generate index.html, 200.html, 404.html
    },
  },
})
```

Then deploy the `.output/public` directory to any static host (Netlify, Vercel, Cloudflare Pages, S3).

---

## Hybrid Rendering with routeRules

Define per-route rendering and caching behavior in `nuxt.config.ts`. Nuxt and Nitro apply rules automatically — no middleware boilerplate required.

### Full routeRules Reference

```ts
export default defineNuxtConfig({
  routeRules: {
    // Prerendered at build time — fastest possible delivery
    '/': { prerender: true },
    '/about': { prerender: true },

    // SWR: cached for 1 hour, regenerated in background on stale request
    '/products/**': { swr: 3600 },

    // ISR: cached on CDN until next deployment (Vercel / Netlify)
    '/blog/**': { isr: true },

    // ISR with TTL: revalidated hourly on CDN
    '/news/**': { isr: 3600 },

    // Client-side only — no SSR for this subtree
    '/dashboard/**': { ssr: false },

    // CORS headers for API routes
    '/api/**': { cors: true },

    // Custom response headers (e.g., long cache for immutable assets)
    '/_nuxt/**': { headers: { 'cache-control': 'max-age=31536000, immutable' } },

    // Server-side redirect
    '/old-blog/**': { redirect: '/blog/**' },

    // Disable Nuxt scripts on specific pages (e.g., minimal embed page)
    '/embed/**': { noScripts: true },
  },
})
```

### SWR vs ISR

| | SWR | ISR |
|---|---|---|
| Cache location | Server / reverse proxy | CDN edge |
| Revalidation | Background on stale hit | Background on stale hit |
| Reset on deploy | No (TTL-based) | Yes (`isr: true`) |
| Platform required | Any Nitro-compatible server | Vercel or Netlify |
| Best for | Server-hosted apps with frequent updates | CDN-deployed apps |

### Notes on routeRules and payload files

Routes using `isr` or `swr` generate a `_payload.json` alongside each HTML file. During client-side navigation, Nuxt fetches the payload instead of re-running data composables. Ensure dynamic route patterns match correctly:

```ts
// pages/[...slug].vue → rule must use glob
'/blog/**': { isr: true }
```

### Hybrid Rendering Limitations

- Not available with `nuxt generate` (static generation only)
- `ssr: false` route rules apply to the Vue app layer only — Nitro server routes are unaffected
- Middleware defined in `server/middleware/` always runs regardless of `ssr: false` rules

---

## Hydration Patterns and Pitfalls

Hydration re-runs the component tree on the client using server-rendered HTML as the base. Mismatches between server and client output cause visible flicker or console warnings.

### Common Hydration Mismatches

**Random / time-based values:**
```ts
// Bad: different on server vs client
const id = Math.random()
const now = new Date().toISOString()

// Good: use useId() for stable IDs
const id = useId()
```

**Browser-only APIs used in render:**
```ts
// Bad: localStorage is undefined on server
const saved = localStorage.getItem('theme')

// Good: access in onMounted
const saved = ref(null)
onMounted(() => { saved.value = localStorage.getItem('theme') })
```

**Conditional rendering based on environment:**
```html
<!-- Bad: client renders true, server renders false -->
<div v-if="process.client">Client content</div>

<!-- Good: use ClientOnly component -->
<ClientOnly>
  <ClientOnlyContent />
</ClientOnly>
```

### Lazy Hydration Strategies (Nuxt 3.16+)

Control when components become interactive:

```html
<!-- Hydrate when component enters viewport -->
<LazyMyComponent hydrate-on-visible />

<!-- Hydrate when browser is idle (after critical tasks) -->
<LazyMyComponent hydrate-on-idle />

<!-- Hydrate on first user interaction with the page -->
<LazyMyComponent hydrate-on-interaction />

<!-- Hydrate when a media query matches -->
<LazyMyComponent hydrate-on-media-query="(min-width: 768px)" />

<!-- Never hydrate — server-rendered static content -->
<LazyMyComponent hydrate-never />
```

Combine `Lazy` prefix (deferred JS load) with hydration triggers for maximum TTI improvement.

---

## Edge-Side Rendering

Nuxt (via Nitro) can render on CDN edge servers, placing rendering compute close to end users. No code changes required — only a different build preset.

### Supported Platforms

| Platform | Preset | Command |
|---|---|---|
| Cloudflare Workers | `cloudflare-pages` | `nuxi build` (auto-detected on CF Pages) |
| Vercel Edge | `vercel-edge` | `NITRO_PRESET=vercel-edge nuxi build` |
| Netlify Edge | `netlify-edge` | `NITRO_PRESET=netlify-edge nuxi build` |
| Deno Deploy | `deno-deploy` | `NITRO_PRESET=deno-deploy nuxi build` |

### Constraints

Edge runtimes have restrictions compared to Node.js:
- No filesystem access at runtime (only during build)
- No Node.js-specific APIs (`fs`, `path`, `crypto` may differ)
- Cold start budget is tighter — keep server bundles small
- Some npm packages with native bindings are incompatible

Use `defineEventHandler` in `server/api/` and avoid Node-specific imports to ensure edge compatibility.

### Combining Edge + Hybrid Rendering

Edge-Side Rendering and hybrid `routeRules` are fully compatible. A typical high-performance setup:

```ts
export default defineNuxtConfig({
  routeRules: {
    '/': { prerender: true },       // served as static from CDN
    '/blog/**': { isr: true },      // generated on demand, cached on CDN
    '/app/**': { ssr: false },       // SPA, no server cost
  },
})
```

With a Vercel or Cloudflare deployment, prerendered routes are served from the CDN cache, ISR routes are generated at the edge on first request and cached, and SPA routes are static files — no server involvement at all.

---

## Deployment Targets

### Static Hosting

```bash
# Generate all prerendered routes
npx nuxi generate
# Output: .output/public — deploy to any CDN or static host
```

Suitable for fully prerendered sites. No server component deployed.

### Node.js Server

```bash
npx nuxi build
# Output: .output/ — run with: node .output/server/index.mjs
```

Required for SSR, API routes, and dynamic `routeRules` (SWR/ISR without CDN support).

### Serverless / Edge

```bash
NITRO_PRESET=vercel npx nuxi build
NITRO_PRESET=netlify npx nuxi build
NITRO_PRESET=cloudflare-pages npx nuxi build
```

Each preset generates a platform-optimized output. Vercel and Netlify also handle ISR routing rules natively when the correct preset is used.

### Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY .output ./
EXPOSE 3000
ENV NITRO_PORT=3000
CMD ["node", "server/index.mjs"]
```

Copy only `.output/` — the production build is self-contained and does not need `node_modules`.
