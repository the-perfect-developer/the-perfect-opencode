# Test Doubles: Types, Differences, and When to Use Each

## Table of Contents

- [The Problem Test Doubles Solve](#the-problem-test-doubles-solve)
- [The Five Types of Test Doubles](#the-five-types-of-test-doubles)
- [Decision Guide: Which Double to Use](#decision-guide-which-double-to-use)
- [Common Mistakes With Test Doubles](#common-mistakes-with-test-doubles)
- [Isolation Depth Considerations](#isolation-depth-considerations)

---

## The Problem Test Doubles Solve

Unit tests must run in isolation. But real code rarely lives in isolation—it interacts with databases, external APIs, file systems, message queues, clocks, and other units. Calling the real dependencies during unit tests breaks isolation and introduces:

- **Slowness**: Network calls, disk I/O, and database queries are orders of magnitude slower than in-memory operations
- **Non-determinism**: External services fail, return different data, or have rate limits
- **Side effects**: Tests that write to real databases or send real emails are destructive
- **Environmental coupling**: Tests that only pass when specific infrastructure is running are fragile

Test doubles are objects that stand in for real dependencies during tests. They preserve isolation while allowing tests to verify how the unit interacts with—or responds to—its dependencies.

---

## The Five Types of Test Doubles

### 1. Dummy

**What it is**: An object passed to satisfy a method signature but never actually used during the test.

**When to use**: When a method requires a parameter but that parameter's behavior is irrelevant to the specific scenario being tested.

**Characteristics**:
- Has no real implementation
- Will cause test failures if it gets called unexpectedly (surfacing a design problem)
- Used only to fulfill compiler or type requirements

**Conceptual example**: Testing that a `UserService.register()` method rejects duplicate usernames. The `EmailNotificationService` parameter is required but irrelevant—a dummy satisfies the signature without behavior.

---

### 2. Stub

**What it is**: A test double that returns predefined, controlled responses to calls from the unit under test.

**When to use**: When the unit's behavior depends on data or results from a dependency, and the test needs to control what that dependency returns.

**Characteristics**:
- Provides canned answers to queries
- Does not verify how it was called
- Focused on controlling the test environment (the "Arrange" phase)
- Use when testing return values or state changes

**Typical use cases**:
- Making a repository return a specific user object
- Making a configuration service return a specific flag value
- Making a clock return a fixed timestamp
- Simulating an API returning an error response

**Key distinction from mocks**: Stubs provide data; they don't assert. Stubs care about what the unit under test does with the data, not about how the stub itself was called.

---

### 3. Spy

**What it is**: A test double that wraps the real object and records how it was called, allowing post-test verification of interactions.

**When to use**: When partial real behavior is needed, or when the test needs to verify that a side-effecting call happened without replacing the entire dependency.

**Characteristics**:
- Delegates to real implementation unless overridden
- Records call history (arguments, call count, call order)
- Supports hybrid tests that need both real behavior and interaction verification
- Less strict than a mock—typically does not define expectations upfront

**Typical use cases**:
- Verifying that a logging call was made without replacing the real logger
- Confirming an event was published while preserving the real event bus behavior
- Observing method calls during integration-style unit tests

**Key distinction from mocks**: Spies record and report; mocks also prescribe expectations upfront and fail fast if those expectations aren't met.

---

### 4. Mock

**What it is**: A test double that is pre-programmed with expectations about which calls it will receive, in what order, and with what arguments. Fails the test immediately if unexpected calls occur.

**When to use**: When the test is specifically verifying that the unit under test interacts with a dependency in a specific way (behavioral verification).

**Characteristics**:
- Expectations are declared before the act
- Failures are immediate when an unexpected call is made
- Verifies behavior (how the code interacts with the dependency), not just state (what the result was)
- More brittle than stubs—changes to internal call patterns break mocked tests even if behavior is preserved

**Typical use cases**:
- Verifying that a payment gateway is called exactly once with the correct amount
- Confirming that a cache invalidation call is made after an update
- Asserting that an audit log is written with specific parameters

**Over-mocking warning**: Mocking every dependency creates tests so tightly coupled to implementation that any refactoring breaks the suite. Reserve mocks for interactions that represent meaningful contract boundaries, not internal implementation details.

---

### 5. Fake

**What it is**: A working, simplified implementation of a dependency that is functionally equivalent but unsuitable for production (typically due to performance or simplicity tradeoffs).

**When to use**: When the behavior of a dependency is complex enough that a stub would be too rigid or a mock too verbose, but the real implementation is too heavy for unit tests.

**Characteristics**:
- Has real, working logic (not just canned responses)
- Much simpler and lighter than the real implementation
- Often in-memory (e.g., an in-memory repository, an in-memory message bus)
- More expressive than stubs for complex interaction scenarios
- Requires maintenance if the interface changes

**Typical use cases**:
- An in-memory repository implementing the same interface as a database-backed repository
- A fake message queue that stores messages in a list
- A fake email service that captures sent emails for assertion

**Key distinction from stubs**: Fakes compute responses based on inputs using real logic. Stubs return hardcoded responses regardless of inputs.

---

## Decision Guide: Which Double to Use

```
Is the parameter needed but irrelevant to this test?
  └── YES → Dummy

Does the test need to control what the dependency returns?
  └── YES → Stub (simple cases) or Fake (complex behavior needed)

Does the test need to verify that an interaction occurred?
  └── YES → Does the test also need partial real behavior?
        ├── NO  → Mock (strict expectation upfront)
        └── YES → Spy (observe without full replacement)
```

**General guidance**:

- Default to **stubs** when setting up conditions for a test
- Use **fakes** when stub responses are too inflexible for complex dependency behavior
- Use **mocks** sparingly—only when verifying the interaction itself is the core of the test
- Use **spies** when you need interaction verification but cannot fully replace a dependency
- Use **dummies** to satisfy signatures and nothing more

---

## Common Mistakes With Test Doubles

### Over-mocking

Mocking every dependency, including simple value objects or internal helpers, produces tests that are coupled to implementation rather than behavior. When the implementation is refactored without changing behavior, the tests break—undermining the purpose of having tests.

**Signal**: A test breaks after an internal refactoring that preserves external behavior.  
**Remedy**: Only mock dependencies that represent meaningful external contracts (repositories, external APIs, notification services). Do not mock pure utility functions or value objects.

### Verifying Too Many Interactions

Asserting on every call to every dependency in a single test turns each test into a full specification of the implementation. Small internal changes cascade into many test failures.

**Remedy**: Each test verifies one primary concern. One interaction assertion per test unless multiple are genuinely inseparable.

### Leaking Test Doubles Across Tests

Shared mutable test doubles that retain state between tests create ordering dependencies and unpredictable failures.

**Remedy**: Initialize fresh test doubles in each test's Arrange phase, or reset shared doubles during teardown.

### Using Mocks When Stubs Suffice

Stubs are simpler and produce less brittle tests. Mocks add strict interaction expectations that fail the test if any unexpected call occurs.

**Remedy**: Start with a stub. Upgrade to a mock only when verifying the specific interaction is the purpose of the test.

---

## Isolation Depth Considerations

Not all tests require the same depth of isolation. Consider two schools of thought:

**Classical (Detroit) school**: Minimize the use of test doubles; use real objects wherever feasible. Only replace dependencies that are genuinely problematic (slow, non-deterministic, destructive). Tests exercise more real code and are less fragile.

**Mockist (London) school**: Replace all dependencies with doubles to achieve maximum isolation. Focuses on testing one class at a time, with strict interaction verification.

In practice, most teams adopt a pragmatic middle ground:
- Always replace: external network calls, database connections, file I/O, clocks, random number generators
- Prefer real objects: pure utilities, value objects, simple calculations
- Use judgment for: other in-process dependencies based on complexity and coupling

The key criterion: if a dependency makes the test slow, non-deterministic, or destructive, replace it. If it's a simple, fast, side-effect-free object, using the real implementation often makes the test more meaningful.
