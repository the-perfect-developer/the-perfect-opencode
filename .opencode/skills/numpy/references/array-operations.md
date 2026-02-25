# NumPy Array Operations Reference

## Table of Contents

1. [Advanced Indexing](#advanced-indexing)
2. [Broadcasting In Depth](#broadcasting-in-depth)
3. [Universal Functions (ufuncs)](#ufuncs)
4. [Sorting and Searching](#sorting-and-searching)
5. [Set Operations](#set-operations)
6. [Structured Arrays](#structured-arrays)
7. [String and Bytes Arrays](#string-arrays)
8. [I/O Patterns](#io-patterns)

---

## Advanced Indexing {#advanced-indexing}

Advanced indexing always returns a **copy** (never a view). It triggers when the index object is a non-tuple sequence, an `ndarray`, or contains `slice`/`Ellipsis` mixed with arrays.

### Integer array indexing

Select arbitrary elements by index:

```python
x = np.array([10, 20, 30, 40, 50])
idx = np.array([0, 2, 4])
x[idx]          # array([10, 30, 50])

# Reorder rows of a matrix
matrix = np.arange(12).reshape(3, 4)
order = np.array([2, 0, 1])
matrix[order]   # rows reordered: [2, 0, 1]
```

Multi-dimensional integer indexing:

```python
# Select specific (row, col) pairs
rows = np.array([0, 1, 2])
cols = np.array([0, 2, 1])
matrix[rows, cols]   # diagonal-like selection: [m[0,0], m[1,2], m[2,1]]
```

### Boolean (mask) indexing

```python
arr = np.array([[1, -2, 3], [-4, 5, -6]])

# Flat selection of all elements satisfying condition
positives = arr[arr > 0]        # 1-D copy: [1, 3, 5]

# In-place zeroing of negatives
arr[arr < 0] = 0

# Row selection using per-row condition
row_mask = arr.any(axis=1)     # True for rows with any non-zero
arr[row_mask]                   # selected rows
```

### Ellipsis and `np.newaxis`

`...` (Ellipsis) selects all remaining dimensions:

```python
tensor = np.ones((2, 3, 4, 5))
tensor[0, ..., 2]    # shape (3, 4) — first dim=0, last dim=2, rest = :
```

`np.newaxis` inserts a length-1 axis for broadcasting:

```python
a = np.array([1, 2, 3])    # shape (3,)
a[np.newaxis, :]           # shape (1, 3) — row vector
a[:, np.newaxis]           # shape (3, 1) — column vector
```

### `np.ix_` for open meshes

`np.ix_` creates an open mesh from multiple 1-D index arrays — useful for selecting submatrices without `np.meshgrid`:

```python
matrix = np.arange(20).reshape(4, 5)
row_idx = np.array([0, 2])
col_idx = np.array([1, 3, 4])
matrix[np.ix_(row_idx, col_idx)]   # shape (2, 3) submatrix
```

---

## Broadcasting In Depth {#broadcasting-in-depth}

### Shape alignment rules

Broadcasting aligns shapes from the **right** (trailing dimensions first). Missing leading dimensions are treated as size 1.

```
A: (8, 1, 6, 1)
B:    (7, 1, 5)
→    (8, 7, 6, 5)
```

### Common broadcasting patterns

**Scale each feature column independently:**

```python
X = rng.random((1000, 10))     # 1000 samples, 10 features
scale = np.array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])  # shape (10,)
X_scaled = X * scale           # scale broadcasts over rows
```

**Pairwise distance matrix (outer difference):**

```python
points = rng.random((50, 3))   # 50 points in 3D
diff = points[:, np.newaxis, :] - points[np.newaxis, :, :]  # (50, 50, 3)
dist = np.sqrt((diff ** 2).sum(axis=-1))   # (50, 50)
```

**Normalize rows to unit L2 norm:**

```python
norms = np.linalg.norm(X, axis=1, keepdims=True)   # shape (1000, 1)
X_unit = X / norms             # norms broadcasts over columns
```

### Broadcasting anti-patterns

Avoid broadcasting that creates large temporaries:

```python
# (10000, 1) vs (1, 10000) → 800 MB intermediate (float64)
# Use scipy.spatial.distance.cdist instead for pairwise distances on large sets
```

---

## Universal Functions (ufuncs) {#ufuncs}

Ufuncs are element-wise functions implemented in C that operate on `ndarray`s with optional `out`, `where`, and `axis` parameters.

### Core ufuncs

| Category | Functions |
|---|---|
| Arithmetic | `np.add`, `np.subtract`, `np.multiply`, `np.divide`, `np.power` |
| Trigonometry | `np.sin`, `np.cos`, `np.tan`, `np.arctan2` |
| Exponential / log | `np.exp`, `np.exp2`, `np.log`, `np.log2`, `np.log10` |
| Comparison | `np.greater`, `np.less`, `np.equal`, `np.maximum`, `np.minimum` |
| Bitwise | `np.bitwise_and`, `np.bitwise_or`, `np.left_shift` |
| Floating point | `np.floor`, `np.ceil`, `np.round_`, `np.abs`, `np.sign` |

### `out` parameter — zero-copy writes

```python
result = np.empty_like(a)
np.sqrt(a, out=result)         # write directly to pre-allocated buffer
np.multiply(result, b, out=result)
```

### `where` parameter — conditional application

```python
# Only compute sqrt where values are non-negative
safe_sqrt = np.sqrt(arr, where=arr >= 0, out=np.zeros_like(arr, dtype=float))
```

### Generalized ufunc (`gufunc`) — `np.apply_along_axis` alternative

Prefer `np.einsum` or explicit axis operations over `np.apply_along_axis` — the latter calls Python per slice.

```python
# Slow — calls Python for each row
result = np.apply_along_axis(np.linalg.norm, axis=1, arr=matrix)

# Fast — vectorized
result = np.linalg.norm(matrix, axis=1)
```

### `np.frompyfunc` for custom ufuncs

Creates a ufunc from a Python function — returns object dtype (slower than C ufuncs but supports arbitrary types):

```python
logit = np.frompyfunc(lambda x: np.log(x / (1 - x)), 1, 1)
result = logit(np.linspace(0.01, 0.99, 10)).astype(float)
```

For performance-critical custom element-wise operations, use Numba's `@numba.vectorize` instead.

---

## Sorting and Searching {#sorting-and-searching}

### Sorting

```python
arr = np.array([3, 1, 4, 1, 5, 9, 2, 6])

# Returns a sorted copy
np.sort(arr)             # array([1, 1, 2, 3, 4, 5, 6, 9])

# Sort in-place
arr.sort()

# Indirect sort — returns indices that would sort the array
np.argsort(arr)          # useful for reordering other arrays by this one

# Stable sort (preserves order of equal elements)
np.sort(arr, kind='stable')

# Sort along axis
matrix = rng.integers(0, 10, size=(4, 5))
matrix.sort(axis=0)     # sort each column
matrix.sort(axis=1)     # sort each row
```

### Partial sort — `np.partition`

`np.partition` is O(n) vs O(n log n) for full sort — use it when only the k smallest/largest values are needed:

```python
arr = rng.integers(0, 100, size=1_000_000)

# Get the 5 smallest values (not necessarily sorted among themselves)
k = 5
partitioned = np.partition(arr, k)
smallest_5 = partitioned[:k]

# Sorted top-k
top_k_idx = np.argpartition(arr, -k)[-k:]
top_k = arr[top_k_idx]
```

### Searching

```python
arr = np.array([10, 20, 30, 40, 50])

np.searchsorted(arr, 25)        # 2 — insertion point (binary search)
np.searchsorted(arr, 25, side='right')   # 2

np.nonzero(arr > 25)            # (array([2, 3, 4]),) — indices where True
np.argmax(arr)                  # 4 — index of maximum
np.argmin(arr)                  # 0 — index of minimum
np.argmax(matrix, axis=1)       # index of max per row
```

---

## Set Operations {#set-operations}

NumPy provides 1-D set operations on sorted unique arrays:

```python
a = np.array([1, 2, 3, 4, 5])
b = np.array([3, 4, 5, 6, 7])

np.intersect1d(a, b)            # [3, 4, 5]
np.union1d(a, b)                # [1, 2, 3, 4, 5, 6, 7]
np.setdiff1d(a, b)              # [1, 2]  — elements in a not in b
np.in1d(a, b)                   # [F, F, T, T, T] — membership test
np.isin(a, b)                   # same as in1d but supports ND arrays

np.unique(a)                    # unique values, sorted
vals, counts = np.unique(a, return_counts=True)   # with occurrence counts
```

---

## Structured Arrays {#structured-arrays}

Structured arrays store heterogeneous records (similar to a table) in a NumPy array:

```python
# Define a dtype for a record type
dtype = np.dtype([
    ('name',     'U20'),       # Unicode string, max 20 chars
    ('age',      np.int32),
    ('score',    np.float64),
])

records = np.array([
    ('Alice', 30, 95.5),
    ('Bob',   25, 87.3),
    ('Carol', 35, 91.0),
], dtype=dtype)

# Field access by name
records['name']           # array(['Alice', 'Bob', 'Carol'])
records['score'].mean()   # 91.26...

# Sort by field
records.sort(order='score')

# Filter using boolean mask on a field
records[records['age'] > 28]
```

Prefer `pandas.DataFrame` for interactive data analysis — structured arrays are most valuable for low-level binary I/O and C extension interoperability.

---

## String and Bytes Arrays {#string-arrays}

NumPy supports two string dtypes:

| dtype | Usage |
|---|---|
| `np.str_` / `'U<n>'` | Fixed-width Unicode strings |
| `np.bytes_` / `'S<n>'` | Fixed-width byte strings |

```python
# Fixed-width Unicode — 'U10' means up to 10 Unicode chars
names = np.array(['Alice', 'Bob', 'Carol'], dtype='U10')
names.dtype    # dtype('<U5') — inferred to max length

# String operations via np.char
np.char.upper(names)           # ['ALICE', 'BOB', 'CAROL']
np.char.startswith(names, 'A') # [True, False, False]
np.char.join('-', names)        # element-wise join
```

For variable-length strings or complex string processing, use Python lists or pandas Series — NumPy fixed-width strings are memory-efficient for uniform-length data.

---

## I/O Patterns {#io-patterns}

### Binary formats — `.npy` and `.npz`

```python
# Single array — preserves dtype, shape, and order
np.save("array.npy", arr)
arr = np.load("array.npy")

# Multiple arrays in one file
np.savez("dataset.npz", X=X_train, y=y_train)
data = np.load("dataset.npz")
X_train = data["X"]
y_train = data["y"]

# Compressed archive (slower write/read, smaller file)
np.savez_compressed("dataset_compressed.npz", X=X_train, y=y_train)
```

### Text formats — CSV and TSV

```python
# Write — delimiter, header, format
np.savetxt("output.csv", matrix, delimiter=",", header="a,b,c", fmt="%.4f")

# Read — skip header row
matrix = np.loadtxt("output.csv", delimiter=",", skiprows=1)
```

`np.loadtxt` loads the entire file into memory. For large CSV files, use `pandas.read_csv` and convert with `.to_numpy()`.

### Memory-mapped files — `np.memmap`

Access large on-disk arrays as NumPy arrays without loading them fully into RAM:

```python
# Write a large array
fp = np.memmap("large.dat", dtype="float32", mode="w+", shape=(1_000_000, 128))
fp[:] = rng.random((1_000_000, 128))
del fp    # flush to disk

# Read a slice (loads only the requested pages)
fp = np.memmap("large.dat", dtype="float32", mode="r", shape=(1_000_000, 128))
batch = fp[0:256].copy()   # .copy() to get a RAM-resident array from the slice
```

### Interoperability with other libraries

```python
# pandas → numpy
df_array = df.to_numpy()             # or df.values (no copy guarantee)

# numpy → pandas
import pandas as pd
df = pd.DataFrame(matrix, columns=["a", "b", "c"])

# PyTorch → numpy
tensor_np = tensor.detach().cpu().numpy()

# numpy → PyTorch
import torch
tensor = torch.from_numpy(arr)       # shares memory when dtype is compatible
```

`torch.from_numpy` shares the underlying buffer — mutating the array mutates the tensor. Use `.clone()` on the tensor or `.copy()` on the array to isolate them.
