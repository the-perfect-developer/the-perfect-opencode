# Performance Optimization — Next.js & React

## Table of Contents

1. [Bundle Analysis](#bundle-analysis)
2. [Code Splitting and Dynamic Imports](#code-splitting-and-dynamic-imports)
3. [Image Optimization](#image-optimization)
4. [Font Optimization](#font-optimization)
5. [JavaScript Performance Patterns](#javascript-performance-patterns)
6. [Core Web Vitals](#core-web-vitals)
7. [Re-render Optimization](#re-render-optimization)

---

## Bundle Analysis

Identify bundle size regressions before they reach production.

### Setup `@next/bundle-analyzer`

```bash
npm install @next/bundle-analyzer
```

```js
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
})

module.exports = withBundleAnalyzer({
  // ...other config
})
```

```bash
ANALYZE=true next build
```

### What to look for

- Large shared chunks with rarely-used libraries
- Duplicate packages at different versions
- Client bundle containing server-only code
- Unintentional inclusion of heavy dependencies (e.g., `moment`, full `lodash`)

### Lightweight alternatives

| Heavy library | Lightweight alternative |
|---|---|
| `moment` | `date-fns` or `dayjs` |
| Full `lodash` | `lodash/debounce` or native equivalents |
| `axios` | `fetch` (native) |
| `react-icons` (full) | `lucide-react` (tree-shakeable) |

---

## Code Splitting and Dynamic Imports

Next.js automatically code-splits at the page level. Apply additional splits for:

### Client-only or heavy UI components

```tsx
import dynamic from 'next/dynamic'

// Heavy visualization library — only load when rendered
const RichTextEditor = dynamic(() => import('@/components/RichTextEditor'), {
  loading: () => <div className="h-40 animate-pulse bg-gray-200 rounded" />,
  ssr: false,        // editor uses browser APIs
})

// Load only when a modal is opened
const VideoPlayer = dynamic(() => import('@/components/VideoPlayer'), {
  ssr: false,
})
```

### Conditional feature loading

```tsx
'use client'
import dynamic from 'next/dynamic'
import { useState } from 'react'

const AnalyticsPanel = dynamic(() => import('@/components/AnalyticsPanel'))

export function AdminPage() {
  const [showAnalytics, setShowAnalytics] = useState(false)

  return (
    <div>
      <button onClick={() => setShowAnalytics(true)}>Show Analytics</button>
      {showAnalytics && <AnalyticsPanel />}   {/* loaded on demand */}
    </div>
  )
}
```

### Named exports with dynamic

```tsx
const { Component: MapComponent } = dynamic(
  () => import('@/components/Map').then(mod => ({ default: mod.MapComponent }))
)
```

### Avoid barrel re-exports for large packages

```ts
// Bad: pulls in entire package
import { debounce, merge, cloneDeep } from 'lodash'

// Good: only debounce is bundled
import debounce from 'lodash/debounce'
import merge from 'lodash/merge'
```

---

## Image Optimization

Always use `next/image` over a raw `<img>` tag.

```tsx
import Image from 'next/image'

// Static image — size known at build time
import heroImage from '@/public/hero.jpg'

export function Hero() {
  return (
    <Image
      src={heroImage}
      alt="Hero banner showing our product"
      priority               // LCP image — preload it
      placeholder="blur"     // shows blurred placeholder during load
    />
  )
}

// Remote image — declare dimensions
export function Avatar({ src, name }: { src: string; name: string }) {
  return (
    <Image
      src={src}
      alt={`${name}'s avatar`}
      width={48}
      height={48}
      className="rounded-full"
    />
  )
}
```

Allow remote hostnames in `next.config.js`:

```js
module.exports = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'cdn.example.com' },
    ],
  },
}
```

### Key rules

- Set `priority` on the Largest Contentful Paint image (typically hero or above-the-fold image).
- Never set `priority` on below-the-fold images.
- Provide `alt` on all images; use `alt=""` for purely decorative images.
- Use `sizes` prop to describe responsive widths for `fill` mode:
  ```tsx
  <Image src={src} alt="" fill sizes="(max-width: 768px) 100vw, 50vw" />
  ```

---

## Font Optimization

Use `next/font` to eliminate layout shift from custom fonts.

```tsx
// app/layout.tsx
import { Inter, JetBrains_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

const mono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${mono.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```

Use local fonts for complete control:

```tsx
import localFont from 'next/font/local'

const brandFont = localFont({
  src: [
    { path: './BrandFont-Regular.woff2', weight: '400' },
    { path: './BrandFont-Bold.woff2', weight: '700' },
  ],
  variable: '--font-brand',
})
```

`next/font` inlines the `@font-face` rule and serves fonts from the same origin, removing third-party network requests.

---

## JavaScript Performance Patterns

### Combine loop iterations over the same data

Multiple passes over the same array waste CPU cycles, especially for large lists:

```ts
// Bad: 4 separate passes
const active = users.filter(u => u.active)
const admins = users.filter(u => u.role === 'admin')
const recent = users.filter(u => isRecent(u.createdAt))
const total = users.reduce((sum, u) => sum + u.score, 0)

// Good: single pass
const { active, admins, recent, total } = users.reduce(
  (acc, u) => {
    if (u.active) acc.active.push(u)
    if (u.role === 'admin') acc.admins.push(u)
    if (isRecent(u.createdAt)) acc.recent.push(u)
    acc.total += u.score
    return acc
  },
  { active: [], admins: [], recent: [], total: 0 }
)
```

### Avoid unnecessary async / await chains

```ts
// Bad: wraps a sync value in a Promise unnecessarily
async function getLabel(key: string) {
  return labels[key]    // sync lookup, no await needed
}

// Good: return synchronously
function getLabel(key: string) {
  return labels[key]
}
```

### Parallelize independent database calls

```ts
// Bad: ~300ms (sequential)
const user = await db.users.findUnique({ where: { id } })
const posts = await db.posts.findMany({ where: { authorId: id } })
const tags = await db.tags.findMany({ where: { userId: id } })

// Good: ~100ms (parallel)
const [user, posts, tags] = await Promise.all([
  db.users.findUnique({ where: { id } }),
  db.posts.findMany({ where: { authorId: id } }),
  db.tags.findMany({ where: { userId: id } }),
])
```

---

## Core Web Vitals

| Metric | Target | Primary cause |
|---|---|---|
| LCP (Largest Contentful Paint) | < 2.5s | Slow resource load, no `priority` on hero image |
| INP (Interaction to Next Paint) | < 200ms | Long tasks on main thread, excessive re-renders |
| CLS (Cumulative Layout Shift) | < 0.1 | Missing image dimensions, late font swap |

### LCP improvements

1. Set `priority` on the hero `<Image>` component.
2. Preload critical resources with `<link rel="preload">` in `<head>`.
3. Move large data fetches to server; ship HTML with content, not a loading shell.

### INP improvements

1. Break up long tasks with `scheduler.yield()` (or `setTimeout(fn, 0)`).
2. Defer non-critical event handler work.
3. Avoid synchronous layout reads (e.g., `element.offsetHeight`) inside event handlers.

### CLS improvements

1. Always provide `width` and `height` on `<Image>` (or use `fill` with a sized container).
2. Use `next/font` to avoid flash of unstyled text.
3. Reserve space for dynamic content (ads, embeds) with explicit `min-height`.

---

## Re-render Optimization

Address after fixing waterfalls and bundle bloat — these are rarely the top performance issue.

### `memo` — skip re-renders when props are unchanged

```tsx
import { memo } from 'react'

const ProductCard = memo(function ProductCard({ product }: { product: Product }) {
  return (
    <div>
      <h3>{product.name}</h3>
      <p>{product.price}</p>
    </div>
  )
})
```

### `useMemo` — cache expensive calculations

```tsx
import { useMemo } from 'react'

function FilteredList({ items, query }: Props) {
  const filtered = useMemo(
    () => items.filter(item => item.name.toLowerCase().includes(query.toLowerCase())),
    [items, query]   // recalculates only when items or query changes
  )

  return <ul>{filtered.map(item => <li key={item.id}>{item.name}</li>)}</ul>
}
```

### `useCallback` — stable function references for memoized children

```tsx
import { useCallback } from 'react'

function Parent() {
  const [count, setCount] = useState(0)

  const handleDelete = useCallback((id: string) => {
    setItems(prev => prev.filter(item => item.id !== id))
  }, [])   // stable reference — MemoizedChild won't re-render due to this prop

  return <MemoizedChild onDelete={handleDelete} />
}
```

### When NOT to memoize

- Simple components that render quickly — the overhead of comparison exceeds the savings.
- Components that receive new props on every render anyway.
- Top-level pages — memoizing a page component provides no benefit.

Profile with React DevTools Profiler before adding `memo` / `useMemo` to confirm the targeted component is actually a bottleneck.
