# Evaluation Criteria Reference

Per-dimension checklists and scoring rubrics for each evaluator agent in the
`perfectcode-zen-evaluation` workflow. Inject the relevant section into each
evaluator's prompt alongside the plan and implementation survey.

---

## Table of Contents

1. [Plan Fidelity — @code-analyst](#plan-fidelity)
2. [Test Coverage — @test-engineer](#test-coverage)
3. [Security — @security-expert](#security)
4. [Performance — @performance-engineer](#performance)
5. [Architecture — @principal-architect + @solution-architect](#architecture)
6. [Database — @database-architect](#database)
7. [Scoring Rubric](#scoring-rubric)

---

## Plan Fidelity — @code-analyst

Evaluate whether the implementation matches the written plan in scope, structure,
and approach. This is the foundational dimension — all other dimensions build on it.

### Checklist

**Scope**
- [ ] Every item in the plan's "What to do" list is present in the code
- [ ] Every prohibition in "What NOT to do" is respected — no forbidden pattern is present
- [ ] Nothing was built that is explicitly out of scope
- [ ] No gold-plating — extra features, abstractions, or complexity not called for by the plan

**Architecture**
- [ ] Component structure matches the plan's architecture section
- [ ] Data flow follows the described design
- [ ] Integration points are implemented at the correct layer
- [ ] Interfaces between components match the described design

**Patterns and Conventions**
- [ ] Language and framework conventions from the plan are followed
- [ ] Naming conventions are consistent with the plan and existing codebase
- [ ] No anti-patterns the plan explicitly warned against appear in the code
- [ ] Code style matches the loaded language skill (TypeScript, Python, Go, etc.)

**Documentation**
- [ ] Public APIs have docstrings or JSDoc
- [ ] Non-obvious logic has inline comments
- [ ] README updated if plan required it
- [ ] `.env.example` updated for new environment variables

**Cleanliness**
- [ ] No debug artefacts (`console.log`, commented-out code, temporary files)
- [ ] No dead code introduced
- [ ] No TODO comments left without a linked issue

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | Every plan item implemented; zero scope violations; conventions clean |
| 4 | All critical items present; one or two minor gaps; no forbidden patterns |
| 3 | Core scope delivered; some non-trivial gaps; minor convention drift |
| 2 | Multiple items missing or a forbidden pattern present |
| 1 | Core requirement absent or critical prohibition violated |

---

## Test Coverage — @test-engineer

Evaluate whether the testing strategy from the plan is fully realised and whether
the tests provide genuine confidence in the implementation.

### Checklist

**Coverage Presence**
- [ ] Unit tests exist for all new modules, functions, and classes
- [ ] Integration tests cover component interactions described in the plan
- [ ] E2E tests present if the plan's testing strategy required them
- [ ] Tests exist for all acceptance criteria listed in the plan

**Coverage Quality**
- [ ] Happy path is tested for every new feature
- [ ] Error paths and failure modes are tested (not just success cases)
- [ ] Boundary conditions and edge cases from the plan are covered
- [ ] Tests have meaningful assertions — not just "it runs without throwing"
- [ ] Tests are deterministic — no flaky timing dependencies or random data

**Test Design**
- [ ] Tests are isolated — each test sets up its own state
- [ ] Mocks and stubs are used appropriately — not mocking what should be real
- [ ] Test names clearly describe what they verify
- [ ] Tests are maintainable — changes to implementation do not cascade failures unnecessarily

**Gaps**
- [ ] No critical path is left untested
- [ ] Security-relevant code (auth, input validation) has dedicated tests
- [ ] Migration code is tested if the plan included migrations

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | All acceptance criteria tested; edge cases covered; high-quality assertions |
| 4 | Core paths tested; minor coverage gaps; assertions are meaningful |
| 3 | Happy path covered; error paths thin; some acceptance criteria untested |
| 2 | Multiple acceptance criteria untested; critical paths have no coverage |
| 1 | No tests, or tests exist but are non-functional / purely smoke tests |

---

## Security — @security-expert

Evaluate whether all security requirements from the plan are correctly implemented
and whether any new vulnerabilities were introduced.

### Checklist

**Threat Mitigations**
- [ ] Every threat identified in the plan's security section has a corresponding control
- [ ] Authentication is implemented correctly per the plan (provider, session management)
- [ ] Authorisation checks are present at every access-controlled endpoint or operation
- [ ] Input validation is applied at all trust boundaries
- [ ] Output encoding is applied where user-controlled data is rendered

**Forbidden Patterns**
- [ ] No hardcoded secrets, credentials, or API keys in source code
- [ ] No unsafe desialisation
- [ ] No SQL built by string concatenation (parameterised queries only)
- [ ] No unvalidated redirects
- [ ] No credentials logged or exposed in error messages

**Data Handling**
- [ ] Sensitive data is not stored longer than necessary
- [ ] Data at rest is encrypted where the plan required
- [ ] Data in transit uses TLS; no plaintext transmission of sensitive data
- [ ] PII and secrets are excluded from logs, metrics, and tracing

**Dependencies**
- [ ] No new dependencies with known critical CVEs introduced
- [ ] External inputs from dependencies are validated before use

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | All mitigations in place; no new vulnerabilities; forbidden patterns absent |
| 4 | Core controls correct; one minor gap that does not create exploitable risk |
| 3 | Most controls present; a non-trivial gap that should be fixed |
| 2 | A significant control missing or a forbidden pattern (e.g., SQL injection risk) |
| 1 | Critical vulnerability introduced or a major security requirement ignored |

---

## Performance — @performance-engineer

Evaluate whether the performance requirements and optimisations in the plan are
correctly applied and whether any obvious regressions were introduced.

### Checklist

**Plan Requirements**
- [ ] Optimisations explicitly specified in the plan are present in the code
- [ ] Approaches ruled out in the plan are not present
- [ ] Latency budget or throughput targets are plausibly achievable from the code

**Common Regressions**
- [ ] No N+1 query patterns in loops that hit a database or external API
- [ ] No unbounded collection loads (pagination or streaming used where data may grow)
- [ ] No synchronous blocking calls on hot paths that should be async
- [ ] No large serialisation/deserialisation on every request where caching would apply
- [ ] No redundant computation that could be memoised or pre-computed

**Resource Efficiency**
- [ ] Memory allocations in hot paths are minimal and appropriate
- [ ] Connection pools and clients are reused (not created per request)
- [ ] Expensive initialisation happens once at startup, not per call
- [ ] Timeouts are set on all external calls; no calls that can block indefinitely

**Observability for Performance**
- [ ] Metrics or structured logs allow latency and throughput to be measured
- [ ] Slow operations are instrumented (database queries, external calls)

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | All optimisations applied; no regressions; observable and within budget |
| 4 | Core optimisations present; one minor inefficiency; no serious regression |
| 3 | Most requirements met; a non-trivial inefficiency present |
| 2 | N+1 or unbounded load present; or a required optimisation absent |
| 1 | Severe regression introduced or a critical performance requirement ignored |

---

## Architecture — @principal-architect + @solution-architect

Evaluate whether the system design and service structure match the agreed
architecture from the plan.

### Principal Architect Checklist

**System Design**
- [ ] High-level component structure matches the plan's architecture section
- [ ] Cross-service data flow follows the described design
- [ ] No new tight coupling between components that should be loosely coupled
- [ ] Technical governance decisions from the plan are respected
- [ ] No architectural shortcuts that create long-horizon design debt

**Cross-Cutting Concerns**
- [ ] Logging is consistent and structured across all new code
- [ ] Error handling follows a consistent strategy; errors are not swallowed silently
- [ ] Observability hooks (metrics, traces) are placed at the correct boundaries
- [ ] Feature flags or configuration switches are used where the plan required them

### Solution Architect Checklist

**Service Boundaries**
- [ ] Each service or module has a clear, single responsibility
- [ ] Interfaces between services match the described API or contract
- [ ] No implementation detail leaks across service boundaries
- [ ] Backward compatibility is maintained for existing consumers (if required by plan)

**Component Design**
- [ ] Dependencies flow in the correct direction (no circular dependencies)
- [ ] Abstractions are at the right level — not too thin, not too deep
- [ ] Configuration is externalised; no environment-specific values hardcoded
- [ ] Dependency injection is used where the plan or codebase conventions require it

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | Implementation is a precise realisation of the agreed design |
| 4 | Design is sound; one minor deviation with acceptable rationale |
| 3 | Core structure correct; a non-trivial design gap or unnecessary coupling |
| 2 | Service boundary violated or a key architectural decision ignored |
| 1 | Fundamentally different architecture from the plan with no justification |

---

## Database — @database-architect

Evaluate whether data models, schema changes, queries, and migrations are sound
and match the plan's database section.

### Checklist

**Schema and Migrations**
- [ ] Schema matches the data model in the plan
- [ ] Migrations are present for every schema change
- [ ] Migrations are reversible (down migration or equivalent rollback strategy)
- [ ] Migrations are idempotent — safe to run multiple times
- [ ] Migration ordering is correct; no dependency conflicts

**Query Quality**
- [ ] Queries use parameterised inputs — no string concatenation with user data
- [ ] Indexes are defined for columns used in WHERE, JOIN, and ORDER BY clauses
- [ ] No full-table scans on large tables where an index would apply
- [ ] Transactions wrap operations that must be atomic

**Data Integrity**
- [ ] Foreign key constraints are present where relationships exist
- [ ] NOT NULL constraints are applied to required fields
- [ ] Unique constraints are present where uniqueness is required by the domain
- [ ] Soft-delete or hard-delete strategy matches the plan's decision

**ORM and Query Builder Usage**
- [ ] ORM models accurately reflect schema (field types, nullable, defaults)
- [ ] Eager loading is used where N+1 would otherwise occur
- [ ] Raw queries are used only where ORM cannot express the operation cleanly

### Score Guidance

| Score | Criteria |
|---|---|
| 5 | Schema matches plan; migrations sound; queries efficient and safe |
| 4 | Core schema correct; one minor index gap or non-critical query inefficiency |
| 3 | Schema mostly correct; a migration concern or moderate query issue |
| 2 | Missing migration, injection risk, or significant schema deviation |
| 1 | No migration for schema changes, SQL injection present, or data loss risk |

---

## Scoring Rubric

### Scale

| Score | Verdict | Meaning |
|---|---|---|
| 5 | Excellent | Fully implemented; matches or exceeds plan requirements |
| 4 | Good | Implemented correctly with minor, non-functional gaps |
| 3 | Acceptable | Core delivered; non-trivial gaps; improvement recommended |
| 2 | Needs Work | Significant gaps or deviations; risk to correctness or safety |
| 1 | Failing | Critical requirement missing or dangerous anti-pattern present |

### Overall Verdict Logic

| Condition | Overall Verdict |
|---|---|
| All dimensions score 4–5 | **Pass** |
| All dimensions score 3–5, no dimension is 1 | **Conditional Pass** — address minors before next cycle |
| Any dimension scores 2 | **Conditional Pass** — address majors before merge |
| Any dimension scores 1 | **Fail** — critical issues must be resolved |

### Finding Severity Mapping

| Score | Finding Severity | Action |
|---|---|---|
| 1 | Critical | Must fix before merge; blocks pass |
| 2 | Major | Strong recommendation to fix; conditional pass at best |
| 3 | Minor | Non-blocking; address in next iteration or as tech debt |
| 4 | Note | Observation only; no action required |

### Improvement Suggestions vs. Findings

A **finding** is a gap against the plan — something the plan required that is
absent, wrong, or violating a stated constraint.

A **suggestion** is an improvement beyond the plan — something not required by
the plan but that would meaningfully improve quality, maintainability, security,
or performance.

Suggestions must be:
- Concrete and actionable (not "improve error handling" — say where and how)
- Ranked by impact (highest impact first)
- Scoped to what is realistic given the feature's context
- Clearly separated from findings so they are not mistaken for blocking issues
