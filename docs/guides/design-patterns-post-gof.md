# Design Patterns — Post-GoF Catalog

> **Purpose**: patterns that emerged or were named after the 1994 Gang of Four book and have entered the canon. Tailored to downstream-project domains: data access, distributed systems, microservices, regulated/audit-heavy workloads, infrastructure-as-code.
>
> **Read first**: [`design-patterns.md`](design-patterns.md) — lead file with framing, descriptive-not-prescriptive caveats, and citation conventions. **Don't cite from this file without reading the lead file's "Read this first" section.** Patterns are vocabulary, not rules. Several entries below (CQRS, Event Sourcing) carry significant operational weight and are easy to over-apply.
>
> **Boundary note**: data / persistence mechanics that previously looked like possible `CP35`+ additions live in [`design-patterns-data.md`](design-patterns-data.md) instead: Object Pool / Connection Pool is `CDP12`, Idempotency Key is `CDP13`, and Transactional Outbox is `CDP14`. Integration / messaging topology and payload-shaping patterns now live in [`design-patterns-integration.md`](design-patterns-integration.md) instead: message channels, routers, translators, splitters, aggregators, claim checks, dead-letter queues, receiver dedupe, correlation IDs, and envelope wrappers belong to `CIP`, not `CP`. Concurrency control and scheduling shapes now live in [`design-patterns-concurrency.md`](design-patterns-concurrency.md) instead: Producer-Consumer, Worker Pool / Thread Pool, Future / Promise, Async / Await, Semaphore, Barrier, Fork-Join, and Read-Write Lock belong to `CCP`, not `CP`. Do not extend the `CP` range for those entries.

Examples are kept to interface sketches and one-paragraph remarks rather than full Python; the post-GoF entries describe shapes that span multiple files and processes, where a single Python snippet would mislead more than it would clarify.

---

## Catalog

### CP25 — Repository

**Intent**: collection-like interface mediating between domain logic and data storage.

**When to use**: decouple business logic from persistence. Standard in Domain-Driven Design. Useful when the same domain object can come from a SQL store, an external API, or a cache, and the business logic shouldn't care which.

**When NOT to use**: small CRUD apps where the ORM already *is* the repository. Adding a wrapper around `db.session.query(User).get(id)` that just calls it for you is pure overhead. Repository earns its keep when there's behavior to add (caching, multi-source merging, audit logging) or when the persistence might genuinely change.

```python
class UserRepository:
    def get(self, user_id): ...
    def save(self, user): ...
    def find_by_email(self, email): ...
# Implementations: SqlUserRepository, InMemoryUserRepository (for tests),
#                  CompositeUserRepository (cache + SQL fallback)
```

### CP26 — Unit of Work

**Intent**: track changes during a business transaction and flush them together.

**When to use**: multi-entity transactions in ORMs (SQLAlchemy session, EF Core `DbContext`, Hibernate session). Lets a service mutate several aggregates and commit atomically without writing transaction boilerplate per call site.

**When NOT to use**: single-entity writes where the database transaction is the unit of work. Rolling your own UoW on top of an ORM that already provides one is duplication.

```python
class UnitOfWork:
    def __enter__(self): self.session = Session(); return self
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None: self.session.commit()
        else: self.session.rollback()

with UnitOfWork() as uow:
    user.email = "new@example.com"
    profile.bio = "..."
    # both saved atomically on exit
```

### CP27 — Dependency Injection (DI)

**Intent**: pass dependencies in from outside instead of constructing them internally.

**When to use**: almost always — for testability, configuration, swapping implementations. Often the right answer when you're tempted to use [`CP2` Singleton](design-patterns-gof.md#cp2--singleton).

**When NOT to use**: pure functions don't need DI; they take inputs and return outputs. Trivial helpers don't need DI either — passing a `print` function into a logging helper to make it "testable" is over-engineering.

DI does NOT require a framework. In Python, DI is "pass it as a parameter." DI containers (Spring, Dagger, .NET DI) are useful when the wiring graph is large; for small graphs, manual wiring at the composition root is cleaner and more debuggable.

```python
# Manual DI — no framework needed
class OrderService:
    def __init__(self, repo, payment_gateway, notifier):
        self.repo = repo
        self.payment_gateway = payment_gateway
        self.notifier = notifier

# At composition root:
service = OrderService(SqlOrderRepository(), StripeGateway(), EmailNotifier())
```

### CP28 — MVC / MVP / MVVM

**Intent**: separate UI rendering, application state, and business logic.

**When to use**: any non-trivial UI app. The three variants differ in who owns view-state and how view ↔ logic communication flows:

- **MVC** (Model-View-Controller): controller mediates; classic web frameworks (Rails, Django).
- **MVP** (Model-View-Presenter): presenter holds view-state; common in older desktop apps.
- **MVVM** (Model-View-ViewModel): two-way binding between view and view-model; dominates modern web/mobile (Vue, SwiftUI, WPF, Jetpack Compose). React with hooks is sometimes lumped here but is more accurately a one-way data-flow / unidirectional architecture (Flux/Redux family) — closer to MVC's controller-mediated flow than to MVVM's two-way binding.

**When NOT to use**: scripts, CLIs, services with no UI. Choosing MVC for an API server is a category error — there's no "view" in the UI sense.

The boundary lines blur in practice; modern frameworks blend the variants. Don't argue MVC-vs-MVVM in code review; argue "is the model leaking into the view" or "is logic in the wrong layer."

### CP29 — CQRS (Command Query Responsibility Segregation)

**Intent**: separate write models (commands) from read models (queries). Commands change state and return nothing meaningful; queries return state and change nothing.

**When to use**: read-heavy systems with complex reporting needs; systems where read and write scaling profiles differ; domains where the natural write model and the natural read model genuinely differ in shape (writes optimize for invariants, reads optimize for projections).

**When NOT to use**: CRUD apps. CQRS adds significant complexity (two models to maintain, eventual consistency between them, more deployment surface) and is overkill for systems where the write model and read model can be the same shape. Premature CQRS is a top contender for accidental complexity.

Often paired with [`CP30`](#cp30--event-sourcing) but neither requires the other.

### CP30 — Event Sourcing

**Intent**: persist state as an append-only log of events; current state is a fold over events.

**When to use**: audit-critical domains (finance, healthcare, regulated systems where "show me the history" is a hard requirement); domains where temporal queries matter ("what was the balance on 2024-03-15?"); systems where the event log is itself a product (analytics pipelines, change-data-capture consumers).

**When NOT to use**: anything where the audit history isn't load-bearing. Event sourcing is operationally heavy: you need event versioning (events are forever; their schema changes are migrations), snapshots (replaying years of events at every read is too slow), replay tooling, projections, and idempotency guarantees on every consumer. The cost is real and ongoing.

Don't introduce event sourcing for a single audit requirement that an audit-log table would solve.

### CP31 — Saga

**Intent**: coordinate distributed transactions across services using compensating actions instead of locks.

**When to use**: microservices where two-phase commit isn't viable (different databases, different teams, different failure modes). The classic example is order fulfillment across inventory, payment, and shipping services — each step succeeds independently and prior steps are explicitly undone if a later step fails.

**When NOT to use**: single-service transactions where the database transaction handles atomicity. Sagas have failure modes of their own — partial completions visible to other consumers, compensating actions that themselves fail, ordering ambiguity — and are not a free win.

Two saga shapes exist: **orchestration** (a central coordinator drives the steps) and **choreography** (services react to events from each other). Orchestration is easier to debug; choreography scales loosely-coupled teams better. Pick one per saga; mixing within one saga is confusing.

### CP32 — Circuit Breaker

**Intent**: stop calling a failing dependency to let it recover; trip after a threshold, half-open to test recovery, close when calls succeed again.

**When to use**: distributed systems with unreliable downstream services. Standard in resilience libraries (Hystrix, Polly, resilience4j, gobreaker).

**When NOT to use**: in-process calls to local code (the dependency isn't external; failures are bugs, not transient outages). Don't wrap a function call to a module in your own process in a circuit breaker.

The failure modes of circuit breakers themselves matter: a breaker that trips on benign timeouts can amplify an outage by cascading "circuit open" responses to upstream services that would have been fine waiting. Tune thresholds against real production traffic; defaults are starting points.

### CP33 — Bulkhead

**Intent**: isolate resource pools so failure in one doesn't drown the others.

**When to use**: multi-tenant or multi-dependency services where one slow dependency would otherwise exhaust shared thread pools, connection pools, or memory budgets. Named after ship hull compartments — one flooded compartment doesn't sink the ship.

**When NOT to use**: single-tenant single-dependency services with no tail-latency concern. Don't partition pools speculatively; the partitioning itself reduces total capacity (each pool is smaller than the unified pool would be) and the win only materializes when one of the partitions saturates.

Often paired with [`CP32` Circuit Breaker](#cp32--circuit-breaker): bulkheads contain the blast radius of a failing dependency, breakers stop calling it.

### CP34 — Sidecar

**Intent**: deploy supporting functionality (proxy, logging, config, secrets fetcher) as a separate process alongside the main app, sharing its lifecycle.

**When to use**: service meshes (Envoy/Istio), where you want cross-cutting infra concerns out of application code; secrets injection (Vault Agent); per-pod observability (log forwarders, metrics exporters). Common in Kubernetes (one pod, multiple containers).

**When NOT to use**: when the cross-cutting concern is naturally a library and the language/framework already integrates it cleanly. Sidecars add deployment complexity (more containers per pod, more upgrade coordination, more failure modes); use them when the language-agnostic separation is genuinely useful, not just because the cloud-native pattern catalog says to.

The sidecar model also breaks down when the main app and sidecar disagree about lifecycle ordering — a sidecar that needs to start before the main app can drain traffic, or finish flushing after the main app has terminated, often needs explicit coordination the platform doesn't provide.

---

## Cross-references

- [`design-patterns.md`](design-patterns.md) — lead file, framing and `CAP1` / `CAP2` / `CP1`.
- [`design-patterns-gof.md`](design-patterns-gof.md) — sibling file, `CP2`–`CP24` (Gang of Four).
- [`design-patterns-concurrency.md`](design-patterns-concurrency.md) — sibling file, `CCP1`–`CCP8` (concurrency control and scheduling).
- [`design-patterns-data.md`](design-patterns-data.md) — sibling file, `CDP1`–`CDP14` (data / persistence).
- [`design-patterns-integration.md`](design-patterns-integration.md) — sibling file, `CIP1`–`CIP11` (integration / messaging); `CIP9` receiver-side message dedupe remains separate from [`CDP13`](design-patterns-data.md#cdp13--idempotency-key) request-key durability.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) — orchestration-layer patterns for *this* template.
