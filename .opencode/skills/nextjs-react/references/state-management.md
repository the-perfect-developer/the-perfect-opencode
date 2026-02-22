# State Management — React & Next.js

## Table of Contents

1. [Decision Guide](#decision-guide)
2. [Built-in React Hooks](#built-in-react-hooks)
3. [Context for Shared UI State](#context-for-shared-ui-state)
4. [Zustand for Client State](#zustand-for-client-state)
5. [Jotai for Atomic State](#jotai-for-atomic-state)
6. [TanStack Query for Server State](#tanstack-query-for-server-state)
7. [React Hook Form for Forms](#react-hook-form-for-forms)
8. [Anti-Patterns](#anti-patterns)

---

## Decision Guide

Choose the right tool for the scope of the state. Importing a global library for local state adds unnecessary bundle weight.

```
Is the state used only in one component?
  → useState / useReducer

Does the state need to be shared across a component subtree?
  → useContext + useReducer

Is the state complex, frequently updated, and shared across many components?
  → Zustand (if no server integration needed)
  → Jotai (if many independent atoms)

Is the state primarily derived from server data and needs caching?
  → TanStack Query

Is the state a form?
  → React Hook Form + Zod
```

| Scenario | Tool | Bundle cost |
|---|---|---|
| Local toggle, counter, input | `useState` | 0 |
| Multi-step form state | `useReducer` | 0 |
| Theme, locale, auth context | `useContext` + `useReducer` | 0 |
| Global client-side state | Zustand | ~2 KB |
| Independent atomic state slices | Jotai | ~3 KB |
| Server data with caching | TanStack Query | ~13 KB |
| Complex forms with validation | React Hook Form + Zod | ~25 KB |

---

## Built-in React Hooks

### `useState`

Use for local, simple state. Lazy-initialize when the initial value is expensive:

```tsx
// Bad: runs JSON.parse on every render
const [config, setConfig] = useState(JSON.parse(localStorage.getItem('cfg') ?? '{}'))

// Good: initializer function runs once at mount
const [config, setConfig] = useState(
  () => JSON.parse(localStorage.getItem('cfg') ?? '{}')
)
```

Prefer functional updates when new state depends on previous state:

```tsx
// Bad: stale closure risk in async contexts
setCount(count + 1)

// Good: always uses latest state
setCount(prev => prev + 1)
```

### `useReducer`

Use when:
- Multiple related state fields update together
- Next state depends on complex logic
- Actions need to be testable independently

```tsx
type State = {
  items: CartItem[]
  status: 'idle' | 'loading' | 'error'
  error: string | null
}

type Action =
  | { type: 'ADD_ITEM'; item: CartItem }
  | { type: 'REMOVE_ITEM'; id: string }
  | { type: 'SET_STATUS'; status: State['status'] }
  | { type: 'SET_ERROR'; error: string }

function cartReducer(state: State, action: Action): State {
  switch (action.type) {
    case 'ADD_ITEM':
      return { ...state, items: [...state.items, action.item] }
    case 'REMOVE_ITEM':
      return { ...state, items: state.items.filter(i => i.id !== action.id) }
    case 'SET_STATUS':
      return { ...state, status: action.status }
    case 'SET_ERROR':
      return { ...state, error: action.error, status: 'error' }
    default:
      return state
  }
}

function CartProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(cartReducer, {
    items: [],
    status: 'idle',
    error: null,
  })

  return <CartContext.Provider value={{ state, dispatch }}>{children}</CartContext.Provider>
}
```

---

## Context for Shared UI State

Context is appropriate for low-frequency updates shared across a subtree: theme, locale, authenticated user, open/closed modal state.

**Do not use Context for high-frequency updates** (e.g., mouse position, real-time data). Consumers re-render on every context value change.

```tsx
// lib/theme-context.tsx
'use client'
import { createContext, useContext, useReducer } from 'react'

type Theme = 'light' | 'dark' | 'system'
type ThemeAction = { type: 'SET_THEME'; theme: Theme }

const ThemeContext = createContext<{
  theme: Theme
  setTheme: (theme: Theme) => void
} | null>(null)

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, dispatch] = useReducer(
    (_: Theme, action: ThemeAction) => action.theme,
    'system'
  )

  return (
    <ThemeContext.Provider value={{ theme, setTheme: theme => dispatch({ type: 'SET_THEME', theme }) }}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme() {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider')
  return ctx
}
```

Split contexts to prevent unnecessary re-renders when only part of the state changes:

```tsx
// Separate state from dispatch — components reading only dispatch won't re-render on state changes
const CartStateContext = createContext<CartState | null>(null)
const CartDispatchContext = createContext<Dispatch<CartAction> | null>(null)
```

---

## Zustand for Client State

Zustand is minimal (~2 KB) and works well for global client state without boilerplate.

```bash
npm install zustand
```

```ts
// store/cart.ts
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

type CartItem = { id: string; name: string; price: number; quantity: number }

type CartStore = {
  items: CartItem[]
  addItem: (item: Omit<CartItem, 'quantity'>) => void
  removeItem: (id: string) => void
  clearCart: () => void
  total: () => number
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],

      addItem: (item) =>
        set(state => {
          const existing = state.items.find(i => i.id === item.id)
          if (existing) {
            return {
              items: state.items.map(i =>
                i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
              ),
            }
          }
          return { items: [...state.items, { ...item, quantity: 1 }] }
        }),

      removeItem: (id) =>
        set(state => ({ items: state.items.filter(i => i.id !== id) })),

      clearCart: () => set({ items: [] }),

      total: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
    }
  )
)
```

```tsx
// components/CartButton.tsx
'use client'
import { useCartStore } from '@/store/cart'

export function CartButton() {
  const itemCount = useCartStore(state => state.items.length)   // subscribed to count only
  return <button>Cart ({itemCount})</button>
}
```

Subscribe to slices of the store to avoid re-renders from unrelated state changes.

---

## Jotai for Atomic State

Jotai excels when state is composed of many independent atoms, particularly useful for derived/computed values.

```bash
npm install jotai
```

```ts
// atoms/filters.ts
import { atom } from 'jotai'

export const searchQueryAtom = atom('')
export const categoryAtom = atom<string | null>(null)
export const priceRangeAtom = atom<[number, number]>([0, 1000])

// Derived atom — recomputes when dependencies change
export const activeFiltersCountAtom = atom(get => {
  let count = 0
  if (get(searchQueryAtom)) count++
  if (get(categoryAtom)) count++
  const [min, max] = get(priceRangeAtom)
  if (min > 0 || max < 1000) count++
  return count
})
```

```tsx
'use client'
import { useAtom, useAtomValue, useSetAtom } from 'jotai'
import { searchQueryAtom, activeFiltersCountAtom } from '@/atoms/filters'

export function SearchBar() {
  const [query, setQuery] = useAtom(searchQueryAtom)
  return <input value={query} onChange={e => setQuery(e.target.value)} />
}

export function FilterBadge() {
  const count = useAtomValue(activeFiltersCountAtom)  // read-only subscription
  return count > 0 ? <span>{count} filters active</span> : null
}
```

---

## TanStack Query for Server State

TanStack Query manages asynchronous server state: fetching, caching, background updates, and deduplication.

```bash
npm install @tanstack/react-query
```

```tsx
// app/providers.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,   // 1 minute
        retry: 1,
      },
    },
  }))

  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
}
```

```tsx
// hooks/usePosts.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

export function usePosts() {
  return useQuery({
    queryKey: ['posts'],
    queryFn: () => fetch('/api/posts').then(r => r.json()),
  })
}

export function useCreatePost() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: CreatePostData) =>
      fetch('/api/posts', { method: 'POST', body: JSON.stringify(data) }).then(r => r.json()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['posts'] })
    },
  })
}
```

```tsx
// With optimistic updates
export function useLikePost() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (postId: string) =>
      fetch(`/api/posts/${postId}/like`, { method: 'POST' }).then(r => r.json()),

    onMutate: async (postId) => {
      await queryClient.cancelQueries({ queryKey: ['posts'] })
      const previous = queryClient.getQueryData(['posts'])

      queryClient.setQueryData(['posts'], (old: Post[]) =>
        old.map(p => p.id === postId ? { ...p, likes: p.likes + 1 } : p)
      )

      return { previous }
    },

    onError: (_, __, context) => {
      queryClient.setQueryData(['posts'], context?.previous)
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['posts'] })
    },
  })
}
```

---

## React Hook Form for Forms

React Hook Form avoids controlled component overhead by using uncontrolled inputs.

```bash
npm install react-hook-form zod @hookform/resolvers
```

```tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const SignUpSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  confirmPassword: z.string(),
}).refine(data => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
})

type SignUpValues = z.infer<typeof SignUpSchema>

export function SignUpForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<SignUpValues>({
    resolver: zodResolver(SignUpSchema),
  })

  async function onSubmit(values: SignUpValues) {
    await createAccount(values)
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('email')} type="email" placeholder="Email" />
      {errors.email && <p className="text-red-500">{errors.email.message}</p>}

      <input {...register('password')} type="password" placeholder="Password" />
      {errors.password && <p className="text-red-500">{errors.password.message}</p>}

      <input {...register('confirmPassword')} type="password" placeholder="Confirm password" />
      {errors.confirmPassword && <p className="text-red-500">{errors.confirmPassword.message}</p>}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Creating account…' : 'Sign up'}
      </button>
    </form>
  )
}
```

---

## Anti-Patterns

### Global state for local concerns

```tsx
// Bad: global store for data only one component uses
const useModalStore = create(set => ({
  isOpen: false,
  open: () => set({ isOpen: true }),
  close: () => set({ isOpen: false }),
}))

// Good: local useState
function ProductModal() {
  const [isOpen, setIsOpen] = useState(false)
  // ...
}
```

### Storing derived data in state

```tsx
// Bad: syncing computed value into state
const [filteredItems, setFilteredItems] = useState(items)
useEffect(() => {
  setFilteredItems(items.filter(i => i.active))
}, [items])

// Good: compute during render (or useMemo if expensive)
const filteredItems = useMemo(
  () => items.filter(i => i.active),
  [items]
)
```

### Context for high-frequency updates

```tsx
// Bad: all consumers re-render on every mouse move
const MouseContext = createContext({ x: 0, y: 0 })

// Good: use a Zustand store or a ref for high-frequency values
const useMouseStore = create(set => ({
  x: 0,
  y: 0,
  setPosition: (x: number, y: number) => set({ x, y }),
}))
```

### Redundant `useEffect` for state initialization

```tsx
// Bad: two renders — initial empty state + populated state
const [user, setUser] = useState(null)
useEffect(() => {
  setUser(getCurrentUser())
}, [])

// Good in Server Components: fetch directly
// Good for sync client data: initialize with function
const [user, setUser] = useState(() => getCurrentUser())
```
