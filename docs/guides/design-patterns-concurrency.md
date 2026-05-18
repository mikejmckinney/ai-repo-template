# Design Patterns — Concurrency Catalog

> **Purpose**: concurrency control and scheduling patterns for downstream-project reviews. Cite these entries by stable ID (`CCP1`–`CCP8`) when a review concern is about work handoff, bounded parallelism, phase coordination, or shared-state access under concurrency.
>
> **Read first**: [`design-patterns.md`](design-patterns.md#read-this-first--descriptive-vocabulary-not-prescription) — lead file with framing, descriptive-not-prescriptive caveats, and citation conventions. **Don't cite from this file without reading the lead file's "Read this first" section.** Patterns are vocabulary, not rules.
>
> **Status**: advisory. A `CCP` citation is a review handle; it does not create a Judge block condition.

Examples stay compact on purpose. Concurrency shapes are easy to overfit to one runtime or library; the point here is to name the coordination idea, not to bless one framework's API.

---

## Catalog

### CCP1 — Producer-Consumer

**Intent**: decouple the rate of work creation from the rate of work execution by handing work through a queue or buffer.

**When to use**: bursty ingest, background jobs, log/event pipelines, or any workflow where producers should stay responsive while consumers drain at their own pace.

**When NOT to use**: request paths where the producer immediately needs the result; tiny in-process call chains where a queue only hides latency; systems with no explicit backpressure or queue bound.

**Signals / example**: look for enqueue/dequeue boundaries, often with a bounded queue and explicit shutdown policy.

```python
jobs.put(task)
# elsewhere
task = jobs.get()
handle(task)
```

### CCP2 — Worker Pool / Thread Pool

**Intent**: reuse a bounded set of workers to execute many similar tasks instead of spawning unbounded concurrency.

**When to use**: batch jobs, request fan-out, or task queues where throughput matters but resource ceilings (threads, CPU, DB connections) must stay bounded.

**When NOT to use**: one-off tasks with distinct lifecycles; long-lived stateful actors that need sticky ownership; async runtimes where a pool would add a second scheduler without a clear win.

**Signals / example**: a central executor owns `max_workers` or an equivalent cap; callers submit tasks and collect results later.

```python
with ThreadPoolExecutor(max_workers=8) as pool:
    futures = [pool.submit(render, doc) for doc in docs]
```

### CCP3 — Future / Promise

**Intent**: represent a result that will exist later, with an explicit handle for awaiting, composing, or joining it.

**When to use**: fan-out/fan-in workflows, deferred joins, callback replacement, or APIs that must hand back "work in progress" before the value exists.

**When NOT to use**: straight-line code that blocks immediately after creating the future; simple sync APIs where the placeholder adds state transitions without real overlap.

**Signals / example**: reviewers should see a placeholder value that is completed elsewhere and consumed at a later boundary.

```python
future = pool.submit(fetch_profile, user_id)
# do other work here
profile = future.result()
```

### CCP4 — Async / Await

**Intent**: express cooperative concurrency with suspendable functions rather than nested callbacks or thread-per-task spawning.

**When to use**: I/O-bound workloads with many waits in flight at once, such as network clients, brokers, or multiplexed request handlers.

**When NOT to use**: CPU-bound hot paths, blocking libraries that cannot yield, or codebases where `async` would leak through every boundary for only one or two awaited calls.

**Signals / example**: explicit suspension points (`await`) mark where control may switch to other tasks; good review questions are "what blocks here?" and "what cancellation policy applies?"

```python
async def fetch_all(ids):
    return await asyncio.gather(*(fetch_one(i) for i in ids))
```

### CCP5 — Semaphore

**Intent**: allow up to N concurrent holders for a finite resource or rate-limited operation.

**When to use**: outbound API caps, file descriptor limits, shared GPU slots, or any path where some concurrency is good but too much becomes failure.

**When NOT to use**: complex critical sections that need ownership semantics, fairness guarantees, or separate read/write behavior; single-resource mutation where a mutex or queue is clearer.

**Signals / example**: a permit count is acquired before work starts and released after it ends; leaks and missing timeout policy are the usual review concerns.

```python
async with semaphore:
    await call_provider(payload)
```

### CCP6 — Barrier

**Intent**: hold participating tasks at a phase boundary until all required peers arrive, then release them together.

**When to use**: phased simulations, parallel test harness startup, staged batch work, or deterministic "everyone is ready before phase 2" coordination.

**When NOT to use**: open-ended worker sets, failure-prone distributed flows, or user-facing paths where one slow participant would stall everyone else.

**Signals / example**: `N` participants are known in advance and each calls a shared wait point before proceeding.

```python
barrier.wait()  # all workers finish setup before processing begins
```

### CCP7 — Fork-Join

**Intent**: split work into independent sub-tasks, run them in parallel, then join their results at one merge point.

**When to use**: tree walks, batch transforms, independent subqueries, or recursive divide-and-conquer where the merge step is explicit.

**When NOT to use**: tasks with heavy shared mutable state, tiny units where split/join overhead dominates, recursive divide-and-conquer on a fixed-size pool (risk of exhaustion deadlock), or streaming pipelines where results should flow incrementally instead of waiting for the whole batch.

**Signals / example**: code has a visible split phase, a join phase, and a merge rule for partial results.

```python
left = pool.submit(sum_range, lo, mid)
right = pool.submit(sum_range, mid, hi)
total = left.result() + right.result()
```

### CCP8 — Read-Write Lock

**Intent**: allow multiple concurrent readers while still requiring exclusive access for writers.

**When to use**: read-heavy shared in-memory state with short critical sections and a meaningful difference between read contention and write contention.

**When NOT to use**: write-heavy paths, long critical sections, upgrade/downgrade-heavy code, or cases where immutable snapshots, copy-on-write, or message passing would remove the shared mutable state entirely.

**Signals / example**: separate read and write acquisition APIs guard the same structure; reviewers should ask whether writer starvation or lock upgrade paths are handled.

```python
with rwlock.read_lock():
    value = cache.get(key)
with rwlock.write_lock():
    cache.put(key, next_value)
```

---

## External pointers (no internal IDs)

- **Actor**: useful when ownership of mutable state matters more than shared-memory locking. Keep this as an external pointer because concrete actor semantics vary sharply by runtime (Erlang, Akka, Orleans, Actix, etc.).
- **Reactor**: useful when one event loop demultiplexes readiness notifications across many I/O sources. Keep this as an external pointer because the pattern is tightly coupled to event-loop/framework design.
- **Structured concurrency**: useful when task lifetimes must nest cleanly under a parent scope with shared cancellation and error propagation. Keep this as an external pointer because current language support and terminology are still runtime-specific.

If a review needs one of those terms, cite an external authority directly rather than inventing a local `CCP9+` handle.
