# Design Patterns — Data / Persistence Catalog

> **Purpose**: data and persistence patterns for downstream-project reviews. Cite
> these entries by stable ID (`CDP1`–`CDP14`) when a review concern is about
> cache ownership, read-model shape, write consistency, auditability, or
> persistence-side concurrency.
>
> **Read first**: [`design-patterns.md`](design-patterns.md#read-this-first--descriptive-vocabulary-not-prescription) — lead file with
> framing, descriptive-not-prescriptive caveats, and citation conventions.
> **Don't cite from this file without reading the lead file's "Read this first"
> section.** Patterns are vocabulary, not rules.
>
> **Status**: advisory. A `CDP` citation is a review handle; it does not create a
> Judge block condition.

Examples are intentionally small. Most entries describe a shape that spans
application code, storage, and operational runbooks; a short sketch is safer
than a full implementation that hides the trade-offs.

---

## Catalog

### CDP1 — Cache-Aside

**Intent**: the application owns cache lookup and population. Read cache first;
on miss, read the source of truth, then write the cache.

**When to use**: read-heavy paths where stale data is acceptable for a bounded
time and the application can cheaply repopulate missing entries. Useful when a
cache outage should degrade to the backing store rather than fail the request.

**When NOT to use**: write-heavy or strongly-consistent paths where stale reads
would violate a user promise. Avoid it when cache invalidation rules are more
complex than the read itself.

**Signals / example**: look for `get cache -> if missing fetch DB -> set cache`
near the read path. If multiple call sites each invent their own TTL and key
format, the pattern is present but drifting; centralize the policy.

```python
user = cache.get(f"user:{user_id}")
if user is None:
    user = users.get(user_id)
    cache.set(f"user:{user_id}", user, ttl=300)
```

### CDP2 — Read-Through Cache

**Intent**: hide cache misses behind the cache abstraction. Callers ask the
cache for data; the cache loads from the backing store on miss.

**When to use**: many read paths need the same cache-fill policy and should not
duplicate fallback logic. Common with cache libraries that support loaders.

**When NOT to use**: when different callers need different consistency,
authorization, or projection rules. A read-through cache that bypasses
request-specific authorization is a security bug wearing a performance hat.

**Signals / example**: reviewers should see a loader registered once, not
ad-hoc database calls after every cache miss. If a cache class imports the whole
domain layer to load one entity, the abstraction boundary may be too wide.

```python
# Registration (e.g. at startup)
user_cache = ReadThroughCache(loader=lambda key: users.get(key))

# Usage in many read paths
user = user_cache.get(user_id)
```

### CDP3 — Write-Through Cache

**Intent**: writes update the cache and the source of truth synchronously before
returning success.

**When to use**: read-after-write matters and the cache is part of the serving
path. The caller should not observe an old cached value immediately after a
successful write.

**When NOT to use**: high-latency stores or low-value caches where making the
write path wait on both systems is unnecessary. If the cache write can fail
after the database write, define whether the whole operation rolls back or the
cache is repaired asynchronously.

**Signals / example**: write paths contain both persistent write and cache
update in one unit. A missing failure policy is the usual review concern.

```python
# Registration
user_cache = WriteThroughCache(writer=lambda user: users.save(user))

# Usage
user_cache.save(user)
```

### CDP4 — Write-Behind Cache

**Intent**: accept writes into a cache or buffer, then flush to the durable store
asynchronously.

**When to use**: high-write-volume paths where batching or coalescing writes is
worth the consistency delay, and the system can replay buffered writes after a
crash.

**When NOT to use**: money movement, access control, audit records, or any path
where acknowledging a write before durability would break the contract. Do not
use without explicit flush, retry, and data-loss semantics.

**Signals / example**: a queue, buffer, or cache accepts a write before the
database does. Reviewers should ask where the buffer is durably stored and how
failed flushes are observed.

```text
request -> write buffer -> 202 Accepted
worker  -> batch flush buffer to database
```

### CDP5 — Materialized View

**Intent**: precompute and store a read model derived from base data.

**When to use**: expensive joins, aggregates, compliance dashboards, or search
pages where query-time recomputation is too slow. Especially useful when the
read shape is stable and can lag behind writes by a known amount.

**When NOT to use**: simple queries that the database can already optimize, or
domains where every read must reflect the latest committed write. A materialized
view adds refresh scheduling, invalidation, and drift monitoring.

**Signals / example**: a table or database view has no direct user write path
and is refreshed from canonical tables/events. The review question is the
freshness promise: "How stale can this be, and how do we know?"

```sql
CREATE MATERIALIZED VIEW account_daily_totals AS
SELECT account_id, day, SUM(amount) AS total
FROM ledger_entries
GROUP BY account_id, day;
```

### CDP6 — Index Table

**Intent**: maintain a separate table keyed for a query the primary table cannot
serve efficiently.

**When to use**: stores with limited secondary-index support, high-cardinality
lookup paths, or denormalized access patterns such as "all documents by tenant
and status." Common in DynamoDB/Cassandra-style modeling.

**When NOT to use**: relational databases where a native index solves the
problem. Avoid duplicating data unless the query shape is important enough to
own consistency and backfill logic.

**Signals / example**: the same entity ID appears in a primary table and a
query-specific index table. Reviewers should look for atomic update or repair
logic whenever the indexed fields change.

```text
documents(id, tenant_id, status, ...)
documents_by_tenant_status(tenant_id, status, document_id)
```

### CDP7 — Optimistic Locking

**Intent**: let concurrent writers proceed, then reject a write if the record
changed since it was read.

**When to use**: conflicts are rare, transactions are short, and users can
retry or resolve a conflict. Standard for versioned rows, ETags, and update
forms.

**When NOT to use**: hot rows with frequent conflicting writes. If most writes
fail and retry, use a different model, partition the state, or consider
[`CDP8`](#cdp8--pessimistic-locking).

**Signals / example**: update statements include `WHERE version = ?` or HTTP
requests use `If-Match`. Reviewers should ask what happens after the conflict:
silent overwrite is not optimistic locking.

```sql
UPDATE profiles
SET display_name = ?, version = version + 1
WHERE id = ? AND version = ?;
```

### CDP8 — Pessimistic Locking

**Intent**: acquire a lock before reading or writing so competing writers wait
instead of racing.

**When to use**: conflicts are likely and the critical section must be
serialized: inventory holds, account-balance mutation, or migration control
rows.

**When NOT to use**: user think-time workflows, remote API calls, or long
transactions. Holding locks while waiting on people or networks is how latency
turns into outages.

**Signals / example**: `SELECT ... FOR UPDATE`, advisory locks, or mutexes guard
the record before mutation. Reviewers should check lock ordering, timeout
behavior, and deadlock handling.

```sql
BEGIN;
SELECT * FROM inventory WHERE sku = ? FOR UPDATE;
UPDATE inventory SET available = available - 1 WHERE sku = ?;
COMMIT;
```

### CDP9 — Soft Delete

**Intent**: mark records as deleted instead of physically removing them.

**When to use**: restore workflows, audit-heavy domains, delayed purge
requirements, or references that must remain valid after user-visible deletion.

**When NOT to use**: privacy or retention rules that require hard deletion.
Soft delete is not erasure. It also adds query complexity: every normal read
must know whether deleted rows are visible.

**Signals / example**: `deleted_at`, `deleted_by`, or `is_deleted` appears on a
table. Reviewers should look for default query filters, uniqueness constraints
that handle deleted rows, and a purge path when retention expires.

```sql
UPDATE documents
SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ?
WHERE id = ?;
```

### CDP10 — Audit Log

**Intent**: append immutable records describing who did what, when, and to which
resource.

**When to use**: regulated workflows, administrative actions, security-relevant
changes, or any feature where future readers must reconstruct actor intent and
sequence.

**When NOT to use**: as a substitute for domain state. An audit log answers
"what happened"; it should not be the only place the application stores the
current value unless the design is intentionally event-sourced.

**Signals / example**: append-only audit tables include actor, action, target,
timestamp, request/correlation ID, and before/after metadata. Reviewers should
flag audit records that can be edited through ordinary admin screens.

```text
audit_log(actor_id, action, target_type, target_id, occurred_at, request_id, before_state, after_state, metadata)
```

### CDP11 — Snapshot

**Intent**: persist a point-in-time copy of derived or mutable state so later
reads do not need to replay the full history.

**When to use**: event-sourced aggregates, long-running approvals, reporting
cutoffs, or workflows where "what did this look like then?" matters.

**When NOT to use**: when recomputing from source data is cheap and less risky.
Snapshots add versioning: readers must know which schema produced the snapshot
and whether it can be trusted after upstream changes.

**Signals / example**: `snapshot_version`, `as_of`, or serialized aggregate
state is stored alongside events or source records. Reviewers should ask how
old snapshots are rebuilt when the snapshot format changes.

```text
account_snapshot(account_id, version, as_of_event_id, balance, serialized_state)
```

### CDP12 — Object Pool / Connection Pool

**Intent**: reuse expensive objects, most commonly network or database
connections, behind a bounded pool.

**When to use**: creating the object is expensive and reuse is safe after reset.
Connection pools are standard for databases, HTTP clients, and message brokers.

**When NOT to use**: cheap, immutable, or request-scoped objects. Pooling the
wrong thing creates stale state, leaks, and artificial capacity limits. Do not
write a custom pool when the driver already provides one.

**Signals / example**: a bounded pool has acquire, release, timeout, and health
checks. Reviewers should verify leaked acquisitions are returned on exception
paths and that pool size matches downstream capacity.

```python
with db_pool.connection(timeout=1.0) as conn:
    conn.execute(query)
```

### CDP13 — Idempotency Key

**Intent**: make a retried operation safe by binding one client-supplied key to
one durable result.

**When to use**: payment, order creation, provisioning, email-send, webhook, and
job-start endpoints where clients or networks may retry after an ambiguous
timeout.

**When NOT to use**: naturally idempotent reads or updates where repeating the
same request already has the same effect. Also avoid keys that are not scoped to
the caller; two tenants must not collide on the same key.

**Signals / example**: requests carry `Idempotency-Key`; the server stores key,
request fingerprint, status, and response. Reviewers should flag implementations
that check the key only in memory or after the side effect has already happened.

```text
idempotency_keys(tenant_id, key, request_hash, status, response_body, expires_at)
```

```python
import hashlib

# Check before side effect
body_bytes = request.body if isinstance(request.body, bytes) else request.body.encode()
request_hash = hashlib.sha256(body_bytes).hexdigest()
existing = idempotency_keys.get(tenant_id, key)
if existing and existing.request_hash == request_hash:
    return existing.response_body
result = perform_operation(request)
idempotency_keys.put(tenant_id, key, request_hash, "COMPLETED", result, expires_at)
return result
```

### CDP14 — Transactional Outbox

**Intent**: write state changes and messages to an outbox table in the same
database transaction, then publish messages asynchronously from that table.

**When to use**: a service must update its database and publish an event without
losing either side. Standard for event-driven systems where distributed
transactions are not available.

**When NOT to use**: single-process callbacks or non-critical notifications
where best-effort delivery is enough. The outbox adds a worker, retry policy,
dedupe story, and operational monitoring.

**Signals / example**: domain tables and `outbox_messages` are written in one
transaction; a relay publishes pending rows and marks them sent. Reviewers
should ask how consumers handle duplicate messages, because publish can succeed
and the "mark sent" update can still fail.

```sql
BEGIN;
UPDATE orders SET status = 'paid' WHERE id = ?;
INSERT INTO outbox_messages(id, topic, payload) VALUES (?, 'order.paid', ?);
COMMIT;
```

---

## Cross-references

- [`design-patterns.md`](design-patterns.md) — lead file, framing and ID routing.
- [`design-patterns-gof.md`](design-patterns-gof.md) — sibling file, `CP2`–`CP24` (Gang of Four).
- [`design-patterns-post-gof.md`](design-patterns-post-gof.md) — sibling file, `CP25`–`CP34`; data-adjacent distributed patterns such as CQRS, Event Sourcing, Saga, Circuit Breaker, Bulkhead, and Sidecar remain there.
- [`design-patterns-post-gof.md#cp30--event-sourcing`](design-patterns-post-gof.md#cp30--event-sourcing) — often uses [`CDP11`](#cdp11--snapshot) for replay performance and [`CDP14`](#cdp14--transactional-outbox) for publication.
