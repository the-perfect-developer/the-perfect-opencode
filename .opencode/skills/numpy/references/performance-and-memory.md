# NumPy Performance and Memory Guide

## Table of Contents

1. [Memory Layout: C vs Fortran Order](#memory-layout)
2. [Contiguous Arrays and Strides](#contiguous-arrays)
3. [dtype Selection for Performance](#dtype-selection)
4. [Vectorization Patterns](#vectorization-patterns)
5. [In-Place Operations](#in-place-operations)
6. [Avoiding Common Performance Traps](#performance-traps)
7. [Profiling NumPy Code](#profiling)
8. [Memory-Efficient Workflows](#memory-efficient-workflows)

---

## Memory Layout: C vs Fortran Order {#memory-layout}

NumPy stores array data as a flat buffer in memory. The **order** determines how multi-dimensional indices map to that buffer.

- **C order** (row-major, default): last index varies fastest. Row `i` is stored contiguously.
- **Fortran order** (column-major): first index varies fastest. Column `j` is stored contiguously.

```python
a = np.arange(12).reshape(3, 4)           # C order (default)
a_f = np.asfortranarray(a)                # Fortran order copy

a.flags['C_CONTIGUOUS']                   # True
a_f.flags['F_CONTIGUOUS']                 # True
```

**Rule:** Iterate / slice along the **last** axis for C-order arrays (rows), and along the **first** axis for Fortran-order arrays (columns). Misaligned access causes cache misses and significantly degrades performance.

```python
# Efficient — iterate along last axis (C order)
row_sums = a.sum(axis=1)    # sums along axis 1 (columns per row)

# Cache-friendly element access pattern
for row in a:               # iterates rows — each row is contiguous
    process(row)
```

When interfacing with Fortran libraries (e.g., LAPACK via `scipy.linalg`), use Fortran order:

```python
A_fortran = np.asfortranarray(A)
```

---

## Contiguous Arrays and Strides {#contiguous-arrays}

An array is **contiguous** when its elements are stored without gaps in memory. Many high-performance operations require contiguous input.

```python
x = np.arange(20).reshape(4, 5)
y = x[::2, ::2]               # non-contiguous view (stride skips elements)
y.flags['C_CONTIGUOUS']        # False

# Force contiguous copy when needed
y_contig = np.ascontiguousarray(y)
```

Use `np.ascontiguousarray` only when interoperability with C extensions or certain BLAS routines requires it. For pure NumPy operations, non-contiguous arrays work correctly but may be slower.

**Strides** describe the byte step between elements along each axis:

```python
a = np.ones((3, 4), dtype=np.float64)
a.strides    # (32, 8) — 32 bytes per row, 8 bytes per column element
```

Transposing an array swaps strides without copying data:

```python
a.T.strides  # (8, 32) — now column-major
```

---

## dtype Selection for Performance {#dtype-selection}

Choosing the smallest correct dtype reduces memory bandwidth and fits more data in CPU cache.

| Data | Preferred dtype | Notes |
|---|---|---|
| ML model weights / activations | `float32` | Standard; halves memory vs `float64` |
| High-precision scientific | `float64` | NumPy default |
| Integer indices, small range | `int32` | Use `int64` only if values exceed ~2 billion |
| Boolean masks | `bool_` | 1 byte per element |
| Pixel values 0–255 | `uint8` | Standard image dtype |
| Complex signal processing | `complex64` | Two `float32` components |

```python
# Downcast after loading, before heavy computation
data = np.load("large_array.npy").astype(np.float32, copy=False)
```

`copy=False` avoids an extra allocation when the source is already `float32`. When the dtype differs, a copy is made regardless of `copy=False`.

**Avoid mixed-dtype arithmetic** — NumPy will upcast to the wider type, allocating a new array:

```python
a = np.ones(1_000_000, dtype=np.float32)
b = np.ones(1_000_000, dtype=np.float64)
c = a + b    # upcasts a to float64 → 8 MB temporary
```

---

## Vectorization Patterns {#vectorization-patterns}

### Replace explicit loops

```python
# Slow — Python loop with repeated Python overhead
def mse_loop(predictions, labels):
    n = len(predictions)
    total = 0.0
    for p, l in zip(predictions, labels):
        total += (p - l) ** 2
    return total / n

# Fast — fully vectorized
def mse_vectorized(predictions, labels):
    return np.mean((predictions - labels) ** 2)
```

### Conditional assignment without loops

```python
arr = np.array([-3, 1, -2, 4, -1, 5])

# Clamp negatives to zero — no loop
arr[arr < 0] = 0

# Or with np.where for a new array
clipped = np.where(arr > 0, arr, 0)
```

### Reduction across axes

```python
matrix = rng.random((1000, 256))

# Per-row L2 norm — fast axis-aware operation
norms = np.sqrt((matrix ** 2).sum(axis=1))   # shape (1000,)

# Normalize each row by its norm (broadcasting)
normalized = matrix / norms[:, np.newaxis]    # shape (1000, 256)
```

### Batch operations using axis

Prefer passing the `axis` parameter over calling `.T` and then operating:

```python
# Standardize columns (zero mean, unit variance)
mean = matrix.mean(axis=0)      # shape (256,)
std  = matrix.std(axis=0)       # shape (256,)
standardized = (matrix - mean) / std   # broadcasting handles (1000,256) - (256,)
```

### `np.einsum` for complex contractions

Use `np.einsum` for multi-dimensional contractions that would require many intermediate arrays with `@` or `np.dot`:

```python
# Batch matrix-vector multiply: (B, M, N) @ (B, N) → (B, M)
result = np.einsum('bmn,bn->bm', matrices, vectors)

# Trace of a matrix
trace = np.einsum('ii->', A)
```

---

## In-Place Operations {#in-place-operations}

In-place operations (`+=`, `*=`, `np.add(a, b, out=a)`) modify the array without allocating a new one, saving memory.

```python
# Allocates new array each iteration — memory pressure in hot loops
for _ in range(n):
    arr = arr * scale + offset

# In-place — no extra allocations
for _ in range(n):
    arr *= scale
    arr += offset
```

Use the `out` parameter of ufuncs to direct output to a pre-allocated buffer:

```python
result = np.empty_like(a)
np.multiply(a, b, out=result)   # no temporary allocation
np.add(result, c, out=result)   # accumulate in-place
```

**Warning:** In-place operations on views modify the underlying data. This is intended behavior but must be done deliberately.

```python
x = np.arange(6).reshape(2, 3)
row = x[0]         # view
row += 100         # modifies x[0] in-place — x is also changed
```

---

## Avoiding Common Performance Traps {#performance-traps}

### Trap 1: Calling `np.array()` in a loop

```python
# Slow — repeated allocation and copy
result = np.array([])
for val in data:
    result = np.append(result, val)   # O(n²) — creates new array each time

# Correct — pre-allocate or use a list then convert once
result = np.empty(len(data))
for i, val in enumerate(data):
    result[i] = val

# Or collect in a Python list first, convert once
parts = [compute(x) for x in data]
result = np.array(parts)
```

### Trap 2: Unnecessary `.copy()` on slices

Slices are views — copying them wastes memory unless isolation is required:

```python
# Unnecessary copy in read-only context
sub = arr[10:20].copy()    # only needed if sub will be mutated independently

# Fine for read-only use
sub = arr[10:20]
```

### Trap 3: Large broadcasting intermediates

```python
# Creates a (10000, 10000) intermediate
a = np.ones((10000, 1))
b = np.ones((1, 10000))
c = a + b    # 800 MB intermediate for float64

# Better: use scipy.spatial.distance or an explicit loop for VQ problems
```

### Trap 4: Using `np.matrix`

`np.matrix` is deprecated. Use 2-D `ndarray` with `@`:

```python
# Deprecated
m = np.matrix([[1, 2], [3, 4]])

# Correct
m = np.array([[1, 2], [3, 4]])
result = m @ m     # matrix multiplication
```

### Trap 5: Forgetting axis in aggregations

```python
matrix = np.arange(12).reshape(3, 4)

matrix.sum()           # scalar — entire array sum
matrix.sum(axis=0)     # shape (4,) — column sums
matrix.sum(axis=1)     # shape (3,) — row sums

# Keepdims for broadcasting-compatible shape
col_means = matrix.mean(axis=0, keepdims=True)   # shape (1, 4)
centered = matrix - col_means                     # broadcasts correctly
```

---

## Profiling NumPy Code {#profiling}

Use `%timeit` in Jupyter or `timeit` in scripts to measure NumPy performance:

```python
import timeit

# Time a vectorized operation vs loop
setup = "import numpy as np; arr = np.random.rand(100_000)"
loop_time = timeit.timeit("sum([x**2 for x in arr])", setup=setup, number=100)
vec_time  = timeit.timeit("(arr**2).sum()", setup=setup, number=100)
print(f"Loop: {loop_time:.3f}s  Vectorized: {vec_time:.3f}s")
```

Use `np.testing.assert_allclose` to verify correctness when optimizing:

```python
np.testing.assert_allclose(vectorized_result, reference_result, rtol=1e-5)
```

Check memory usage with `arr.nbytes`:

```python
a = np.ones((1000, 1000), dtype=np.float64)
print(f"Array size: {a.nbytes / 1e6:.1f} MB")   # 8.0 MB
```

---

## Memory-Efficient Workflows {#memory-efficient-workflows}

### Process data in chunks

```python
chunk_size = 10_000
n = len(data)

results = np.empty(n)
for start in range(0, n, chunk_size):
    end = min(start + chunk_size, n)
    results[start:end] = expensive_operation(data[start:end])
```

### Use `np.memmap` for out-of-core arrays

```python
# Write a large array to disk without loading it all into RAM
fp = np.memmap("large.dat", dtype=np.float32, mode="w+", shape=(1_000_000, 128))
fp[:] = rng.random((1_000_000, 128), dtype=np.float32)
del fp   # flush and close

# Read back a slice without loading the full file
fp = np.memmap("large.dat", dtype=np.float32, mode="r", shape=(1_000_000, 128))
batch = fp[0:1000]   # only this slice is read into RAM
```

### Reuse pre-allocated buffers

```python
# Allocate once outside the loop
output = np.empty(n)
temp   = np.empty(n)

for i in range(iterations):
    np.multiply(data, weights, out=temp)   # write to pre-allocated buffer
    np.add(temp, bias, out=output)
    process(output)
```
