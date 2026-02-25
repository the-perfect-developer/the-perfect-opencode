# Test Patterns: Structure, Naming, and Organization

## Table of Contents

- [The AAA Pattern](#the-aaa-pattern)
- [The BDD Style: Given/When/Then](#the-bdd-style-givenwhenthen)
- [Naming Conventions](#naming-conventions)
- [Parameterized Tests](#parameterized-tests)
- [Test Organization and Grouping](#test-organization-and-grouping)
- [Setup and Teardown Patterns](#setup-and-teardown-patterns)
- [Coverage Strategy](#coverage-strategy)

---

## The AAA Pattern

The Arrange-Act-Assert pattern is the most widely adopted structure for unit tests. It imposes a strict three-phase layout that makes every test scannable at a glance.

### The Three Phases

**Arrange**  
Configure everything the test needs before the action takes place:
- Instantiate the unit under test
- Create test doubles and configure their behavior
- Define input values and expected output values
- Set up any preconditions (state, environment)

**Act**  
Execute the single behavior being tested:
- Call the method or function under test
- Capture the actual result
- Keep this section to a single call; multiple calls indicate multiple concerns

**Assert**  
Verify the outcome matches expectations:
- Compare actual result against expected result
- One logical assertion per test (multiple assertions on the same logical outcome are acceptable)
- Assertions on multiple unrelated outcomes belong in separate tests

### Separating the Phases

Use blank lines between phases to create visual separation. Optionally use comments (`// Arrange`, `// Act`, `// Assert`) if the team benefits from explicit labels.

Resist merging Act and Assert into a single line. Splitting them makes it unambiguous which part of the test caused a failure.

### What Belongs in Each Phase

| Phase | Do | Avoid |
|---|---|---|
| Arrange | Set up state, configure doubles, define values | Calling the method under test |
| Act | One call to the unit under test | Assertions, additional setup |
| Assert | Verify outcomes | Logic, conditionals, loops |

---

## The BDD Style: Given/When/Then

Behavior-Driven Development (BDD) uses the Given/When/Then vocabulary. It maps directly onto AAA but uses language oriented toward describing behavior rather than test mechanics.

| AAA | BDD | Meaning |
|---|---|---|
| Arrange | Given | The preconditions and context |
| Act | When | The action or event |
| Assert | Then | The expected outcome |

BDD-style names make tests readable to non-technical stakeholders and frame tests as specifications of desired behavior:

- `given_a_new_user_when_registering_with_an_existing_email_then_returns_conflict`
- `given_an_empty_cart_when_adding_the_first_item_then_total_equals_item_price`

BDD-style is particularly valuable when tests serve as living documentation shared across engineering and product teams.

---

## Naming Conventions

### The Method-State-Expected Pattern

The most common naming pattern encodes three pieces of information:

```
MethodName_StateUnderTest_ExpectedBehavior
```

**MethodName**: The method or function being tested  
**StateUnderTest**: The condition or input scenario  
**ExpectedBehavior**: The expected result or behavior

Examples:
- `Calculate_NegativeInput_ThrowsArgumentException`
- `GetById_RecordDoesNotExist_ReturnsNull`
- `Transfer_InsufficientFunds_ReturnsFalse`
- `Parse_EmptyString_ReturnsZero`

### Principles for Good Test Names

**Be specific, not generic**  
`Add_TwoIntegers_ReturnsCorrectSum` beats `TestAdd` and `AddTest`.

**Use the language of the domain**  
`CreateOrder_CustomerHasExpiredMembership_AppliesNoDiscount` communicates business rules.
`TestOrderMethod_3` communicates nothing.

**Encode the scenario, not just the method**  
The same method can have many scenarios. The name differentiates them:
- `Login_CorrectCredentials_ReturnsAuthToken`
- `Login_WrongPassword_ReturnsUnauthorized`
- `Login_AccountLocked_ReturnsForbidden`

**Avoid conjunctions in test names**  
A name containing "and" usually indicates two concerns in one test:
- `Login_CorrectCredentials_ReturnsTokenAndSetsLastLoginDate` → split into two tests

### Consistency Is More Important Than Convention

Any naming convention is acceptable as long as it is applied consistently across the entire test suite. Mixed conventions create cognitive overhead when reading or searching tests.

---

## Parameterized Tests

Parameterized tests run the same test logic against multiple input/output combinations without duplicating test methods. They are the correct solution when the same concern must be verified across different data points.

### When to Use Parameterized Tests

Use parameterized tests when:
- Multiple input values share the same expected behavior pattern
- Boundary values and typical values should all be covered
- Removing duplication would otherwise require copy-pasting test methods

### When Not to Use Parameterized Tests

Do not use parameterized tests to:
- Replace a loop inside a single test method (same problem, different syntax)
- Combine scenarios with fundamentally different expected behaviors in one test
- Avoid writing separate tests for conceptually distinct scenarios

### The Inline Data Pattern

Each set of parameters represents a complete, independent test case. Each parameter set should:
- Include a name or identifier describing that specific case
- Cover one specific boundary or scenario
- Not require any conditional logic inside the test body to handle

---

## Test Organization and Grouping

### Mirror the Production Structure

Test files map to production files in a predictable location. Common patterns:

- `src/services/UserService.ts` → `tests/services/UserService.test.ts`
- `com.example.services.UserService` → `com.example.services.UserServiceTest`

Consistent mirroring makes it easy to find tests for any production file without searching.

### Group Tests by Unit Under Test

Group all tests for a single class or function together. Within that group, organize by method, then by scenario.

```
UserService
  ├── register()
  │     ├── when email is already taken → returns conflict error
  │     ├── when input is valid → creates user and returns id
  │     └── when email format is invalid → throws validation error
  └── findById()
        ├── when user exists → returns user object
        └── when user does not exist → returns null
```

### Test File Size

A test file that grows too large is a signal that the production unit it tests is too large. Consider:
- Splitting large test files as a refactoring signal for the production code
- Grouping using nested describe blocks (or equivalent) to maintain readability without splitting files

---

## Setup and Teardown Patterns

### Per-Test Setup (Preferred)

Initialize objects fresh in each test's Arrange phase. This makes each test self-contained and prevents state leakage.

Advantages:
- No hidden dependencies between tests
- Test execution order does not matter
- Each test is readable in isolation

### Shared Setup via Helper Methods

When many tests share the same initialization logic, extract factory methods:
- `createValidUser()` → returns a user in a standard valid state
- `createUserWithExpiredMembership()` → returns a user in a specific state

Helper methods should be pure—they return new instances each time, never sharing state.

### Test-Level Setup (Before Each)

Most frameworks support a `beforeEach` hook that runs before each test. Use it for:
- Resetting shared test doubles
- Instantiating the unit under test
- Applying configurations consistent across all tests in the file

Avoid putting assertions or Act-phase calls in `beforeEach`.

### Teardown (After Each)

Run cleanup after each test to restore the environment. Critical teardown actions:
- Delete temporary files
- Release database connections
- Reset global or module-level state
- Unsubscribe from events or timers

Teardown ensures tests remain independent of execution order. A test that passes in isolation but fails in a suite is a teardown problem.

### Test Suite Setup (Before All)

Reserve `beforeAll` / `afterAll` for expensive, truly shared setup that cannot be replicated per test:
- Starting an embedded test server (integration tests)
- Loading a large static fixture file once

Never use `beforeAll` to initialize objects that are mutated by tests, as mutations in one test bleed into others.

---

## Coverage Strategy

### What Coverage Measures—and What It Doesn't

Code coverage reports the percentage of production lines executed by the test suite. It measures which lines ran, not whether those lines behave correctly. A line can be covered by a test that never asserts anything meaningful.

Coverage is a floor, not a ceiling. It identifies which code is definitely not tested. It does not identify whether tested code is thoroughly verified.

### Target Range

A practical target is **70–80% code coverage** for most projects:
- Below 70%: Meaningful gaps in the safety net
- 70–80%: Practical balance between coverage and test maintenance cost
- Above 90%: May indicate diminishing returns from testing trivial code (getters, setters, simple delegations)
- 100%: Only appropriate for critical-path or safety-critical systems

### What to Prioritize

Not all code warrants equal test investment. Prioritize:

1. **Complex business logic**: High cyclomatic complexity, many branches, critical calculations
2. **Error handling paths**: Exception cases, boundary conditions, invalid input handling
3. **High-change areas**: Code that changes frequently is likely to regress
4. **Public API surface**: The contracts that external code depends on
5. **Core domain logic**: The decisions that define the application's value

Deprioritize:
- Simple property accessors (getters/setters)
- Pure delegation methods
- Auto-generated code
- Framework integration glue code

### Branch Coverage vs Line Coverage

Line coverage is the most common metric. Branch coverage is more stringent—it requires that both the true and false paths of each conditional are exercised. For logic-heavy code, targeting branch coverage over line coverage catches more edge case gaps.

### Mutation Testing

Mutation testing is an advanced technique that automatically introduces small defects into the production code (mutations) and checks whether the test suite catches each one. High mutation test scores indicate that tests are actually verifying behavior, not just executing lines. This complements coverage metrics by testing the quality of tests themselves.
