---
name: unit-testing
description: This skill should be used when the user asks to "write unit tests", "follow unit testing best practices", "improve test quality", "structure test cases", or needs guidance on unit testing concepts, patterns, and principles.
---

# Unit Testing Best Practices

Comprehensive guidance on writing reliable, maintainable, and effective unit tests. Covers core principles, structural patterns, isolation strategies, and common pitfalls.

## What Is a Unit Test

A unit test exercises the smallest individual component of code—a function, method, or class—in complete isolation, verifying that its actual behavior matches its expected behavior.

Key properties of a good unit test: **readable**, **isolated**, **reliable**, **simple**, **fast**, and **timely**.

Unit tests serve a dual purpose: they validate behavior and act as executable documentation that never goes out of sync with the code.

## Core Principles

### Isolation Is Non-Negotiable

Unit tests must run without connecting to external systems: databases, file systems, network APIs, or third-party services. Isolation ensures:

- Tests run fast (milliseconds, not seconds)
- Test failures point directly to the unit under test, not to infrastructure
- Tests remain deterministic across environments and runs

Replace external dependencies with test doubles (stubs, mocks, spies) to maintain isolation.

### Determinism: Tests Must Be Predictable

A test is deterministic when it always produces the same result given unchanged production code. Non-deterministic tests—those that sometimes pass and sometimes fail without code changes—destroy developer trust.

Sources of non-determinism to eliminate:
- Dependency on current time, date, or locale
- Reliance on shared mutable state between tests
- Calls to real external services
- Dependence on test execution order

### One Concern Per Test

Each test verifies a single end result from a single unit of work. End results are:
- A return value
- A change to system state
- A call to a third-party dependency

When a test asserts on multiple unrelated outcomes, it becomes harder to diagnose failures and indicates the test is covering more than one concern.

### Tests Are First-Class Code

Test code has the same quality requirements as production code: readability, maintainability, and correctness. A buggy test suite is worse than no tests at all—it provides false confidence.

## Structural Patterns

### The AAA Pattern (Arrange-Act-Assert)

Every test method follows three distinct phases:

- **Arrange**: Create and configure all objects and preconditions needed for the test
- **Act**: Call the method or trigger the behavior under test; capture the actual result
- **Assert**: Compare the actual result against the expected result

Clearly delimit these three phases (via whitespace or comments) to improve readability at a glance.

### One Act Per Test Method

Avoid multiple Act steps in a single test. When a test exercises two different behaviors, it becomes impossible to tell at a glance which behavior caused a failure. Create a separate test method for each behavior being verified.

### Naming Convention: Method-State-Expected

Use a three-part naming pattern that makes the test self-documenting:

```
MethodName_StateUnderTest_ExpectedBehavior
```

Examples:
- `Add_TwoPositiveNumbers_ReturnsCorrectSum`
- `ParseDate_InvalidFormat_ThrowsFormatException`
- `GetUser_UserDoesNotExist_ReturnsNull`

A good name communicates three things without reading the test body: what is being tested, under what conditions, and what result is expected. When a test fails, its name alone should indicate which scenario broke.

### Avoid Magic Values

Hardcoded literal strings and numbers in tests obscure intent and make tests brittle. Use named constants or variables that communicate meaning:

- Instead of `"123456789"` → `const INVALID_IDENTITY_NUMBER = "123456789"`
- Instead of `42` → `const MAX_RETRY_ATTEMPTS = 42`

Named values also serve as documentation—they explain why that specific value is being used.

### Use Helper Methods for Shared Setup

When multiple tests require the same object configuration, extract a factory or setup helper method rather than duplicating the construction logic inline. Benefits:

- Changes to the object's constructor require updates in one place only
- Test bodies remain focused on behavior, not setup
- Reduces cognitive overhead when reading tests

## Isolation Strategies

### Test Doubles: The Right Tool for Each Job

The term "mock" is often used loosely, but test doubles come in distinct types with different purposes. Choosing the right type prevents over-specification and brittle tests.

| Double Type | Purpose |
|---|---|
| **Stub** | Returns predefined data for a dependency; used to control the test environment |
| **Mock** | Records calls and verifies that expected interactions occurred; used for behavioral verification |
| **Spy** | Like a mock but wraps the real object; allows partial verification without full replacement |
| **Fake** | A lightweight working implementation (e.g., an in-memory repository) used when stubs are too simple |
| **Dummy** | A placeholder passed to satisfy a parameter; never actually used in the test |

Use stubs and fakes when verifying return values or state changes. Use mocks and spies when verifying that a specific interaction with a dependency occurred.

For a detailed comparison of test double types and when to use each, see `references/test-doubles.md`.

### Avoid Testing Through Implementation Details

Tests that couple to internal implementation details—private methods, specific internal state, the exact sequence of internal calls—become brittle. When the implementation changes but the behavior stays the same, those tests break unnecessarily.

Test through the public interface. Verify observable outcomes: return values, state changes visible through public accessors, and calls to external dependencies.

## Test Quality Properties

### Speed

- Fast tests get run frequently; slow tests get run infrequently or skipped
- A common threshold: any test exceeding 75–100ms is considered slow
- Ensure speed by: keeping tests simple, mocking external dependencies, and avoiding interdependencies between tests

### Simplicity and Low Cyclomatic Complexity

Keep test logic free of conditional branches (`if`, `for`, `while`, `switch`). Test methods that contain branching logic are themselves complex enough to contain bugs. If multiple input scenarios need verification, use parameterized tests instead of loops within a single test.

### No Duplication of Implementation Logic

Tests that replicate the production algorithm inside the test body provide no real safety net. If the algorithm is wrong, the mirrored test logic will be wrong in the same way, and the test will still pass. Tests must encode the expected outcome as a fixed, independently derived value—not compute it using the same logic.

### Comprehensive Coverage

Cover both positive and negative paths:

- **Positive cases**: Valid inputs producing expected results
- **Negative cases**: Invalid, unexpected, or boundary inputs
- **Edge cases**: Empty values, nulls, maximum/minimum values, boundary conditions

Target 70–80% code coverage as a practical baseline. Coverage is a useful indicator but not a goal in itself—100% coverage with low-quality tests is worse than 75% coverage with high-quality tests.

### Environment Restoration (Teardown)

After each test, restore the environment to a clean state. Leftover state from one test can cause unpredictable failures in subsequent tests. Common teardown actions:

- Delete temporary files
- Reset global or shared state
- Close database connections or file handles
- Release resources acquired during the test

## Integration With the Development Process

### Run Tests as Part of CI/CD

Unit tests run automatically on every code change through a CI/CD pipeline. A failing test marks the build as broken and prevents broken code from reaching downstream environments. Running tests locally is necessary but not sufficient—the pipeline provides the authoritative safety net.

### Test-Driven Development (TDD)

TDD inverts the usual workflow: write a failing test first, then write the minimal production code to make it pass, then refactor. Benefits:

- Forces the developer to define expected behavior before implementation
- Naturally produces testable code (if code is hard to test, TDD surfaces that immediately)
- Results in a test suite that documents intent, not just behavior

### Testable Code Architecture

If adding unit tests to a piece of code is difficult, that difficulty signals a design problem. Common architectural enablers of testability:

- **Dependency injection**: Dependencies are provided externally rather than constructed internally, making them replaceable with test doubles
- **Single responsibility**: Small, focused units are easier to test in isolation than large units with many concerns
- **Pure functions**: Functions with no side effects and no external dependencies are trivially testable
- **Avoiding global state**: Global mutable state creates hidden dependencies between tests

Difficulty writing unit tests is a signal to refactor the production code, not to skip testing.

## Common Pitfalls

| Pitfall | Why It Hurts | Remedy |
|---|---|---|
| Complex logic in tests | Tests become buggy and untrustworthy | Keep cyclomatic complexity near 1 |
| Multiple acts in one test | Failures are ambiguous | One act per test method |
| Testing implementation details | Tests break on refactoring | Test through the public interface |
| Non-deterministic tests | Developers lose trust in the suite | Eliminate time, randomness, and shared state dependencies |
| Magic literals | Intent is obscured | Use named constants |
| Mirroring implementation logic | Tests can't catch bugs in the logic | Use independent, fixed expected values |
| Slow tests | Tests are run infrequently | Mock external dependencies; keep tests simple |
| Missing teardown | Tests pollute each other's environments | Always restore state after each test |

## Quick Reference

**Core rules:**
- One concern, one test
- One act per test method
- Arrange → Act → Assert
- No external dependencies—use test doubles
- Name tests: `Method_State_Expected`
- No logic in tests (no `if`/`for`/`while`)
- Use named constants, not magic values
- Restore state after each test

**Test coverage targets:** 70–80% is a practical baseline

**Test speed threshold:** Tests taking >75–100ms warrant review

## Additional Resources

For deeper detail on specific topics:

- **`references/test-doubles.md`** - Detailed breakdown of stub, mock, spy, fake, and dummy differences with decision guidance
- **`references/test-patterns.md`** - AAA pattern, BDD Given/When/Then style, naming conventions, and parameterized testing strategies
