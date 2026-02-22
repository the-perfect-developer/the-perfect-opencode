# Data Fetching Patterns — Next.js App Router

## Table of Contents

1. [Caching Fundamentals](#caching-fundamentals)
2. [Revalidation Strategies](#revalidation-strategies)
3. [Parallel vs Sequential Fetching](#parallel-vs-sequential-fetching)
4. [Preload Pattern](#preload-pattern)
5. [Server Actions and Mutations](#server-actions-and-mutations)
6. [Taint APIs: Preventing Sensitive Data Leaks](#taint-apis)
7. [Common Anti-Patterns](#common-anti-patterns)

---

## Caching Fundamentals

Next.js 14 App Router caches `fetch` responses by default. Control caching per request:

```ts
// Cache indefinitely (default for static builds)
fetch('https://api.example.com/data')

// Disable caching (always fresh)
fetch('https://api.example.com/data', { cache: 'no-store' })

// Revalidate every 60 seconds
fetch('https://api.example.com/data', { next: { revalidate: 60 } })

// Tag for on-demand invalidation
fetch('https://api.example.com/posts', { next: { tags: ['posts'] } })
```

For non-`fetch` data sources (ORMs, SDKs), use `React.cache` for request-level deduplication:

```ts
import { cache } from 'react'
import 'server-only'

export const getUser = cache(async (id: string) => {
  return prisma.user.findUnique({ where: { id } })
})

export const preloadUser = (id: string) => {
  void getUser(id)   // kick off without blocking
}
```

### Cache Layers in Next.js

| Layer | Scope | Invalidation |
|---|---|---|
| Request Memoization | Single request lifecycle | Automatic per request |
| Data Cache | Persistent (filesystem) | `revalidatePath`, `revalidateTag`, time-based |
| Full Route Cache | Rendered HTML on disk | Deploy, on-demand revalidation |
| Router Cache | Client-side in-memory | Navigation, `router.refresh()` |

---

## Revalidation Strategies

### Time-Based Revalidation (ISR)

```ts
// Revalidate page every 3600 seconds
export const revalidate = 3600

// Or per fetch
const data = await fetch('/api/products', { next: { revalidate: 3600 } })
```

### On-Demand Revalidation

Trigger from Server Actions or Route Handlers:

```ts
'use server'
import { revalidatePath, revalidateTag } from 'next/cache'

// Invalidate a specific path
export async function updatePost(id: string, data: PostData) {
  await db.posts.update({ where: { id }, data })
  revalidatePath(`/posts/${id}`)
}

// Invalidate by tag (more precise)
export async function publishPost(id: string) {
  await db.posts.update({ where: { id }, data: { published: true } })
  revalidateTag('posts')
  revalidateTag(`post-${id}`)
}
```

Tag fetches at the point of data access:

```ts
async function getPost(id: string) {
  return fetch(`/api/posts/${id}`, {
    next: { tags: ['posts', `post-${id}`] }
  }).then(r => r.json())
}
```

### Opt Out of Caching

Dynamic routes that always need fresh data:

```ts
// Force dynamic rendering for the entire route
export const dynamic = 'force-dynamic'

// Or per segment config
export const fetchCache = 'force-no-store'
```

---

## Parallel vs Sequential Fetching

### Sequential (use when data depends on prior result)

```tsx
async function ArtistPage({ params }: { params: { username: string } }) {
  const artist = await getArtist(params.username)    // must complete first

  return (
    <>
      <h1>{artist.name}</h1>
      <Suspense fallback={<Skeleton />}>
        {/* Playlists needs artistId — sequential is correct here */}
        <Playlists artistId={artist.id} />
      </Suspense>
    </>
  )
}
```

Wrap dependent subtrees in `<Suspense>` so the parent route is not fully blocked.

### Parallel (use when fetches are independent)

```tsx
// Initiate both before any await
export default async function Page({ params }: { params: { username: string } }) {
  const artistPromise = getArtist(params.username)
  const albumsPromise = getArtistAlbums(params.username)

  const [artist, albums] = await Promise.all([artistPromise, albumsPromise])

  return (
    <>
      <h1>{artist.name}</h1>
      <AlbumList albums={albums} />
    </>
  )
}
```

### Fan-Out with Independent Suspense Boundaries

When data for different sections is independent, fan out and stream each separately:

```tsx
export default function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <Suspense fallback={<RevenueCardSkeleton />}>
        <RevenueCard />       {/* fetches independently */}
      </Suspense>
      <Suspense fallback={<ActivityFeedSkeleton />}>
        <ActivityFeed />      {/* fetches independently */}
      </Suspense>
      <Suspense fallback={<OrderTableSkeleton />}>
        <OrderTable />        {/* fetches independently */}
      </Suspense>
    </div>
  )
}
```

Each widget streams to the client as soon as its data resolves — the slowest widget does not block the rest.

---

## Preload Pattern

Start a fetch before an unrelated async operation completes:

```tsx
// components/Item.tsx
import { cache } from 'react'
import 'server-only'

export const preload = (id: string) => {
  void getItem(id)
}

export const getItem = cache(async (id: string) => {
  return db.items.findUnique({ where: { id } })
})

export default async function Item({ id }: { id: string }) {
  const item = await getItem(id)
  return <div>{item.name}</div>
}
```

```tsx
// app/item/[id]/page.tsx
import Item, { preload } from '@/components/Item'
import { checkIsAvailable } from '@/lib/inventory'

export default async function Page({ params }: { params: { id: string } }) {
  preload(params.id)                      // starts fetching immediately
  const isAvailable = await checkIsAvailable()   // runs in parallel

  return isAvailable ? <Item id={params.id} /> : <OutOfStock />
}
```

---

## Server Actions and Mutations

Server Actions are async functions that run on the server. Define with `'use server'` and invoke from forms or event handlers.

### Form-Based Actions

```tsx
// app/posts/actions.ts
'use server'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'

const CreatePostSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
})

export async function createPost(formData: FormData) {
  const parsed = CreatePostSchema.safeParse({
    title: formData.get('title'),
    content: formData.get('content'),
  })

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors }
  }

  await db.posts.create({ data: parsed.data })
  revalidatePath('/posts')
  redirect('/posts')
}
```

```tsx
// app/posts/new/page.tsx
import { createPost } from '../actions'

export default function NewPostPage() {
  return (
    <form action={createPost}>
      <input name="title" placeholder="Title" required />
      <textarea name="content" placeholder="Content" required />
      <button type="submit">Publish</button>
    </form>
  )
}
```

### Programmatic Invocation with `useActionState`

```tsx
'use client'
import { useActionState } from 'react'
import { createPost } from '../actions'

export function CreatePostForm() {
  const [state, action, isPending] = useActionState(createPost, null)

  return (
    <form action={action}>
      <input name="title" />
      {state?.errors?.title && <p className="error">{state.errors.title}</p>}
      <button disabled={isPending}>
        {isPending ? 'Publishing…' : 'Publish'}
      </button>
    </form>
  )
}
```

### Optimistic Updates with `useOptimistic`

```tsx
'use client'
import { useOptimistic } from 'react'
import { toggleLike } from './actions'

export function LikeButton({ postId, initialLiked }: Props) {
  const [optimisticLiked, setOptimisticLiked] = useOptimistic(initialLiked)

  async function handleClick() {
    setOptimisticLiked(!optimisticLiked)    // instant UI update
    await toggleLike(postId)                // actual mutation
  }

  return (
    <button onClick={handleClick}>
      {optimisticLiked ? 'Unlike' : 'Like'}
    </button>
  )
}
```

---

## Taint APIs: Preventing Sensitive Data Leaks

Enable in `next.config.js`:

```js
module.exports = {
  experimental: { taint: true },
}
```

Apply taints to objects and values that must never reach the client:

```ts
// lib/user.ts
import {
  experimental_taintObjectReference,
  experimental_taintUniqueValue,
} from 'react'

export async function getUserData(id: string) {
  const user = await db.users.findUnique({ where: { id } })

  // Prevent passing the entire object to a Client Component
  experimental_taintObjectReference(
    'Do not pass the full user object to the client',
    user
  )

  // Prevent passing specific sensitive values
  experimental_taintUniqueValue(
    "Do not pass the user's API token to the client",
    user,
    user.apiToken
  )

  return user
}
```

Passing a tainted reference to a Client Component throws an error at development time, catching leaks before production.

---

## Common Anti-Patterns

### Fetching in `useEffect` when Server Components can fetch

```tsx
// Old pattern — avoid in App Router
'use client'
function ProductList() {
  const [products, setProducts] = useState([])
  useEffect(() => {
    fetch('/api/products').then(r => r.json()).then(setProducts)
  }, [])
  return <ul>{products.map(...)}</ul>
}

// Preferred: Server Component
async function ProductList() {
  const products = await db.products.findMany()
  return <ul>{products.map(...)}</ul>
}
```

### Sequential awaits for independent data

See the Parallel Fetching section above.

### Blocking an entire route on a slow fetch

Wrap slow fetches in `<Suspense>` rather than awaiting at the page level without boundaries.

### Re-exposing server data through Client Component props

Pass only the minimum serializable data that the Client Component needs—never full database rows, tokens, or sensitive config objects.
