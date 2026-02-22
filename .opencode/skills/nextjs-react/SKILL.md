---
name: nextjs-react
description: This skill should be used when the user asks to "write a Next.js app", "follow React best practices", "optimize a Next.js application", "build with the App Router", or needs guidance on modern React and Next.js patterns for 2025.
---

# Next.js & React Best Practices

Provides production-grade patterns for React and Next.js applications using the App Router, covering rendering strategies, data fetching, state management, and performance optimization ordered by impact.

## Rendering Strategy: Server First

Default to Server Components. Move to Client Components only when the component requires browser APIs, event listeners, or React hooks (`useState`, `useEffect`).

```tsx
// Server Component (default) - no 'use client' directive needed
async function ProductList() {
  const products = await db.products.findMany() // direct DB access
  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>
}

// Client Component - only when interactivity is required
'use client'
function AddToCartButton({ productId }: { productId: string }) {
  const [added, setAdded] = useState(false)
  return <button onClick={() => setAdded(true)}>{added ? 'Added' : 'Add'}</button>
}
```

**Composition pattern**: push `'use client'` boundaries to leaf nodes. Wrap only the interactive slice, not the whole page.

```tsx
// Correct: Server Component renders most of the tree
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await getProduct(params.id)
  return (
    <div>
      <h1>{product.name}</h1>          {/* stays on server */}
      <p>{product.description}</p>     {/* stays on server */}
      <AddToCartButton productId={product.id} /> {/* only this is client */}
    </div>
  )
}
```

## Data Fetching: Eliminate Waterfalls (CRITICAL)

Sequential awaits that do not depend on each other create avoidable latency. Run independent fetches in parallel.

```tsx
// Bad: 600ms sequential wait
const user = await getUser(id)
const posts = await getPosts(id)      // waits for user unnecessarily
const stats = await getStats(id)      // waits for posts unnecessarily

// Good: ~200ms parallel fetch
const [user, posts, stats] = await Promise.all([
  getUser(id),
  getPosts(id),
  getStats(id),
])
```

Avoid blocking fetches before a branch that exits early:

```tsx
// Bad: fetches userData even when skipping
async function handleRequest(userId: string, skipProcessing: boolean) {
  const userData = await fetchUserData(userId)
  if (skipProcessing) return { skipped: true }
  return processUserData(userData)
}

// Good: fetch only when needed
async function handleRequest(userId: string, skipProcessing: boolean) {
  if (skipProcessing) return { skipped: true }
  const userData = await fetchUserData(userId)
  return processUserData(userData)
}
```

### Fetch data where it is needed

Next.js automatically deduplicates `fetch` calls with the same URL within a single request. Fetch in the component that needs the data; do not thread props down.

```tsx
// Both components call getUser — only one network request is made
async function Header() {
  const user = await getUser()
  return <nav>{user.name}</nav>
}

async function ProfilePage() {
  const user = await getUser()        // deduplicated automatically
  return <Header />, <main>{user.bio}</main>
}
```

Use `React.cache` for non-`fetch` data sources (ORM calls, SDK calls):

```ts
import { cache } from 'react'
import 'server-only'

export const getUser = cache(async (id: string) => {
  return db.users.findUnique({ where: { id } })
})
```

### Streaming with Suspense

Wrap slow data-dependent subtrees in `<Suspense>` to unblock the rest of the page:

```tsx
export default async function Dashboard() {
  return (
    <>
      <StaticHeader />
      <Suspense fallback={<Skeleton />}>
        <SlowAnalyticsWidget />     {/* streams in when ready */}
      </Suspense>
      <Suspense fallback={<Skeleton />}>
        <SlowActivityFeed />        {/* independent stream */}
      </Suspense>
    </>
  )
}
```

Use a `loading.tsx` route file at the route segment level for page-wide skeletons.

### Preload pattern

Kickstart a fetch before an async check completes:

```tsx
import Item, { preload } from '@/components/Item'

export default async function Page({ params }: { params: { id: string } }) {
  preload(params.id)                         // starts immediately
  const isAvailable = await checkIsAvailable()
  return isAvailable ? <Item id={params.id} /> : null
}
```

## State Management: Right Tool for the Scope

Choose state tooling based on scope—over-engineering global state is a common source of bundle bloat.

| Scenario | Recommended tool |
|---|---|
| Local component state | `useState` / `useReducer` |
| Shared UI state (theme, modals) | `useContext` + `useReducer` |
| Complex client state sharing | Zustand or Jotai |
| Server data + caching on client | TanStack Query |
| Form state | React Hook Form |

Lazy-initialize expensive state to avoid per-render recalculation:

```tsx
// Bad: JSON.parse runs on every render
const [config, setConfig] = useState(JSON.parse(localStorage.getItem('config') ?? '{}'))

// Good: callback runs once at mount
const [config, setConfig] = useState(() => JSON.parse(localStorage.getItem('config') ?? '{}'))
```

## Bundle Size: Reduce JavaScript Sent to the Client

Large bundles are a persistent tax on every user session. Audit with `next build --debug` or `@next/bundle-analyzer`.

### Dynamic imports for non-critical code

```tsx
import dynamic from 'next/dynamic'

const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <Skeleton />,
  ssr: false,              // client-only libraries (e.g., chart.js)
})
```

### Avoid barrel file re-exports for large libraries

```tsx
// Bad: imports entire lodash
import { debounce } from 'lodash'

// Good: imports only debounce
import debounce from 'lodash/debounce'
```

### Mark server-only modules

```ts
import 'server-only'   // throws at build time if imported from a Client Component
```

## Re-render Optimization

Address re-renders after eliminating waterfalls and reducing bundle size; micro-optimizations rarely move real-world metrics.

- Use `memo` to skip re-rendering a component whose props have not changed.
- Use `useMemo` for expensive pure calculations that depend on props/state.
- Use `useCallback` to stabilize function references passed to memoized children.
- Combine multiple loop passes over the same array into a single `reduce`.

```tsx
// Bad: scans messages 8 separate times
const unread = messages.filter(m => !m.read)
const pinned = messages.filter(m => m.pinned)
const recent = messages.filter(m => isRecent(m))

// Good: single pass
const { unread, pinned, recent } = messages.reduce(
  (acc, m) => {
    if (!m.read) acc.unread.push(m)
    if (m.pinned) acc.pinned.push(m)
    if (isRecent(m)) acc.recent.push(m)
    return acc
  },
  { unread: [], pinned: [], recent: [] }
)
```

## Server Actions for Mutations

Use Server Actions for form submissions and data mutations. They run on the server with direct data-layer access and no extra API route needed.

```tsx
// app/actions.ts
'use server'
import { revalidatePath } from 'next/cache'

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string
  await db.posts.create({ data: { title } })
  revalidatePath('/posts')
}

// app/posts/new/page.tsx
import { createPost } from '../actions'

export default function NewPostPage() {
  return (
    <form action={createPost}>
      <input name="title" required />
      <button type="submit">Create</button>
    </form>
  )
}
```

Call `revalidatePath` or `revalidateTag` after mutations to invalidate cached data.

## Security: Protect Sensitive Data

Never pass sensitive objects or values as props to Client Components. Use React taint APIs to enforce this at development time:

```ts
// next.config.js
module.exports = { experimental: { taint: true } }

// utils/user.ts
import { experimental_taintObjectReference, experimental_taintUniqueValue } from 'react'

export async function getUser(id: string) {
  const user = await db.users.findUnique({ where: { id } })
  experimental_taintObjectReference('Do not pass full user to client', user)
  experimental_taintUniqueValue('Do not pass token to client', user, user.apiToken)
  return user
}
```

## Accessibility

- Use semantic HTML (`<button>`, `<nav>`, `<main>`, `<article>`) over `<div>` with roles.
- Add `aria-label` / `aria-describedby` on interactive elements that lack visible text.
- Ensure keyboard navigability: focusable elements in logical DOM order.
- Provide `alt` text on all `<Image>` components (set `alt=""` for decorative images).
- Test with `axe-core` or browser extensions during development.

## File and Project Organization

```
app/
  (marketing)/         # route group — no URL segment
    page.tsx
  dashboard/
    layout.tsx
    page.tsx
    _components/       # co-located, not a route
      Sidebar.tsx
components/            # shared UI
  ui/
    Button.tsx
lib/                   # utilities, data-fetching helpers
  db.ts
  auth.ts
```

- Co-locate components with the routes that use them under `_components/`.
- Share truly reusable components in `components/`.
- Keep data-fetching helpers in `lib/` and mark with `server-only` where appropriate.

## Quick Reference

| Rule | Impact |
|---|---|
| Parallelize independent `await` calls | CRITICAL |
| Default to Server Components | HIGH |
| Keep `'use client'` at leaf nodes | HIGH |
| Dynamic-import non-critical modules | HIGH |
| Stream slow widgets with `<Suspense>` | HIGH |
| Deduplicate fetches with `React.cache` | MEDIUM |
| Lazy-initialize `useState` with callback | MEDIUM |
| Combine loop iterations | MEDIUM |
| Memoize expensive calculations | LOW |

## Additional Resources

- **`references/data-fetching.md`** — Complete data fetching patterns: caching, revalidation, tags, Server Actions, and taint APIs
- **`references/performance.md`** — Performance optimization: bundle analysis, image optimization, font loading, Core Web Vitals
- **`references/state-management.md`** — State management decision guide: hook patterns, Zustand, Jotai, TanStack Query integration
