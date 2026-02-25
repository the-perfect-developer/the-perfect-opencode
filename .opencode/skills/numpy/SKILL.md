---
name: numpy
description: This skill should be used when the user asks to "use NumPy", "write NumPy code", "optimize NumPy arrays", "vectorize with NumPy", or needs guidance on NumPy best practices, array operations, broadcasting, memory management, or scientific computing with Python.
---

# NumPy Best Practices

NumPy is the fundamental package for scientific computing with Python. It provides N-dimensional array objects, vectorized math operations, broadcasting, linear algebra, Fourier transforms, and random number generation. This skill covers best practices for writing correct, efficient, and maintainable NumPy code.

## Import Convention

Always import NumPy with the standard alias:

```python
import numpy as np
```

Never use `from numpy import *` — it pollutes the namespace and makes code harder to read.

## Array Creation

### Choose the right creation function

| Use case | Function |
|---|---|
| Known values | `np.array([1, 2, 3])` |
| Zeros | `np.zeros(shape)` |
| Ones | `np.ones(shape)` |
| Uninitialized (fill later) | `np.empty(shape)` |
| Integer range | `np.arange(start, stop, step)` |
| Evenly spaced floats | `np.linspace(start, stop, num)` |
| Identity matrix | `np.eye(n)` |
| Like existing array | `np.zeros_like(arr)`, `np.ones_like(arr)` |

### Specify dtype explicitly

Always specify `dtype` when the intended type differs from NumPy's default (`float64` for floats, `int64` for integers):

```python
# Explicit dtype avoids silent precision issues
weights = np.ones(1000, dtype=np.float32)   # saves memory for ML models
indices = np.arange(100, dtype=np.int32)    # sufficient range, half memory
flags = np.zeros(50, dtype=np.bool_)        # boolean array
```

Do not rely on implicit upcasting — declare the dtype the data actually needs.

### Use `np.random.default_rng()` for random numbers

The legacy `np.random.*` functions (e.g., `np.random.rand`) are deprecated in favour of the Generator API:

```python
# Correct — reproducible, modern API
rng = np.random.default_rng(seed=42)
samples = rng.normal(loc=0.0, scale=1.0, size=(100, 3))
integers = rng.integers(0, 10, size=50)

# Avoid — legacy API, global state
np.random.seed(42)
samples = np.random.randn(100, 3)
```

Pass `seed` to `default_rng` for reproducibility in tests and experiments.

## Vectorization Over Loops

Replace Python loops with vectorized NumPy operations wherever possible. NumPy operations execute in optimized C code, making them orders of magnitude faster.

```python
# Avoid — Python loop
result = []
for x in data:
    result.append(x ** 2 + 2 * x + 1)
result = np.array(result)

# Correct — fully vectorized
result = data ** 2 + 2 * data + 1
```

Use `np.vectorize` only as a convenience wrapper for scalar functions — it does **not** improve performance since it still calls Python per element.

## Broadcasting Rules

Broadcasting allows operations on arrays of different shapes without copying data. Apply broadcasting instead of explicit `tile` or `repeat` calls.

**Broadcasting rules** (trailing dimensions are compared):
1. Dimensions are equal — compatible.
2. One dimension is 1 — that dimension is stretched.
3. Otherwise — `ValueError`.

```python
# Add a bias vector to each row of a matrix — broadcasting handles shape (3,) vs (4, 3)
matrix = np.zeros((4, 3))
bias = np.array([1.0, 2.0, 3.0])
result = matrix + bias   # shape (4, 3); no copy made

# Outer product via newaxis
a = np.array([0.0, 10.0, 20.0])    # shape (3,)
b = np.array([1.0, 2.0, 3.0])      # shape (3,)
outer = a[:, np.newaxis] + b        # shape (3, 3)
```

Avoid broadcasting that produces very large intermediate arrays — use an explicit loop for memory-constrained cases.

## Views vs Copies

**Basic indexing** (slices) returns a **view** — modifying it modifies the original:

```python
x = np.arange(10)
y = x[2:5]     # view — shares memory
y[0] = 99      # also changes x[2]
```

**Advanced indexing** (integer arrays, boolean masks) returns a **copy**:

```python
x = np.arange(10)
idx = [1, 3, 5]
y = x[idx]     # copy — independent of x
```

Check ownership with `arr.base`:

```python
y.base is None    # True → copy
y.base is x       # True → view of x
```

### When to force a copy

Call `.copy()` explicitly when an independent array is needed:

```python
backup = original.copy()
```

Use `.ravel()` (view when possible) over `.flatten()` (always copies) when write access to the parent is acceptable. Use `reshape(-1)` as the most reliable way to get a flat view.

## Indexing and Selection

### Boolean indexing for filtering

```python
arr = np.array([1, -2, 3, -4, 5])
positive = arr[arr > 0]           # copy: [1, 3, 5]
arr[arr < 0] = 0                  # in-place modification via boolean mask
```

### `np.where` for conditional selection

```python
# Replace negatives with zero, keep positives
cleaned = np.where(arr > 0, arr, 0)
```

### Avoid loops for aggregations

Use axis-aware aggregation functions instead of looping over rows or columns:

```python
matrix = np.arange(12).reshape(3, 4)
row_sums = matrix.sum(axis=1)    # sum each row → shape (3,)
col_max  = matrix.max(axis=0)    # max each column → shape (4,)
```

## Data Types and Precision

### Choose the smallest sufficient dtype

| Scenario | Recommended dtype |
|---|---|
| ML model weights | `np.float32` |
| High-precision scientific | `np.float64` |
| Small integer counts (<32 k) | `np.int16` |
| Large integer counts | `np.int32` or `np.int64` |
| Boolean flags | `np.bool_` |
| Complex numbers | `np.complex64` or `np.complex128` |

Use `arr.astype(np.float32, copy=False)` to cast in-place when the data is already the right type — `copy=False` avoids an unnecessary allocation.

### Watch for integer overflow

NumPy integer arithmetic wraps silently:

```python
x = np.array([200], dtype=np.int8)   # max 127
x + 100    # array([ 44], dtype=int8) — silent overflow!
```

Cast to a wider type before operations that risk overflow.

## Saving and Loading Arrays

| Format | Function | Use case |
|---|---|---|
| Single array (binary) | `np.save` / `np.load` | Fast, preserves dtype and shape |
| Multiple arrays | `np.savez` / `np.savez_compressed` | Archive multiple arrays |
| Text (CSV etc.) | `np.savetxt` / `np.loadtxt` | Human-readable interchange |

```python
# Save and reload with full metadata preserved
np.save("data.npy", arr)
arr_loaded = np.load("data.npy")

# Save several arrays
np.savez("dataset.npz", X=X_train, y=y_train)
npz = np.load("dataset.npz")
X_train = npz["X"]
```

Prefer `.npy`/`.npz` over text formats for large arrays — binary I/O is faster and lossless.

## Reshaping and Shape Manipulation

Use `-1` as a wildcard dimension — NumPy infers the correct size:

```python
flat = arr.reshape(-1)        # flatten to 1-D (view when possible)
col  = arr.reshape(-1, 1)     # column vector
row  = arr.reshape(1, -1)     # row vector
```

Use `np.newaxis` (equivalent to `None`) to insert a dimension for broadcasting:

```python
a = np.array([1, 2, 3])       # shape (3,)
a_col = a[:, np.newaxis]      # shape (3, 1)
a_row = a[np.newaxis, :]      # shape (1, 3)
```

## Linear Algebra

Use `np.linalg` for matrix operations:

```python
A = np.array([[1, 2], [3, 4]], dtype=np.float64)

# Matrix multiplication — use @ operator (Python 3.5+)
C = A @ B             # preferred over np.dot(A, B) for 2-D

# Common operations
vals, vecs = np.linalg.eig(A)
inv_A      = np.linalg.inv(A)
rank       = np.linalg.matrix_rank(A)
det        = np.linalg.det(A)

# Solve Ax = b without computing inverse (faster, more stable)
x = np.linalg.solve(A, b)     # preferred over inv(A) @ b
```

Never use `np.matrix` — it is deprecated. Use 2-D `ndarray` with `@` instead.

## Quick Reference

| Task | Idiomatic code |
|---|---|
| Import | `import numpy as np` |
| Array from list | `np.array([1, 2, 3])` |
| Shape / ndim / size | `arr.shape`, `arr.ndim`, `arr.size` |
| Reshape | `arr.reshape(rows, -1)` |
| Flatten (view) | `arr.reshape(-1)` or `arr.ravel()` |
| Flatten (copy) | `arr.flatten()` |
| Transpose | `arr.T` or `arr.transpose()` |
| Boolean mask | `arr[arr > 0]` |
| Axis aggregation | `arr.sum(axis=0)` |
| Matrix multiply | `A @ B` |
| Copy | `arr.copy()` |
| Check view | `arr.base is not None` |
| Cast dtype | `arr.astype(np.float32, copy=False)` |
| Random (modern) | `np.random.default_rng(seed)` |
| Save / load | `np.save` / `np.load` |

## Additional Resources

### Reference Files

For deeper guidance, consult:

- **`references/performance-and-memory.md`** — Vectorization patterns, memory layout, dtype selection, profiling, and avoiding common performance traps
- **`references/array-operations.md`** — Broadcasting in depth, advanced indexing, ufuncs, structured arrays, and I/O patterns
