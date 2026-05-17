# Design Patterns — Integration / Messaging Catalog

> **Purpose**: integration and messaging patterns for downstream-project
> reviews. Cite these entries by stable ID (`CIP1`–`CIP11`) when a review
> concern is about channel shape, routing, payload boundaries, asynchronous
> coordination, or delivery semantics between services.
>
> **Read first**: [`design-patterns.md`](design-patterns.md#read-this-first--descriptive-vocabulary-not-prescription) — lead file with
> framing, descriptive-not-prescriptive caveats, and citation conventions.
> **Don't cite from this file without reading the lead file's "Read this first"
> section.** Patterns are vocabulary, not rules.
>
> **Status**: advisory. A `CIP` citation is a review handle; it does not create a
> Judge block condition.

Examples are intentionally compact. Most integration patterns span queues,
workers, schema contracts, retries, and operational monitoring; a short sketch
is safer than a pseudo-implementation that hides the real trade-offs.

---

## Catalog

### CIP1 — Message Channel

**Intent**: define an explicit path that messages travel through between sender
and receiver.

**When to use**: asynchronous work, decoupled service boundaries, or workflows
where senders should hand off to a broker, queue, or topic instead of calling
receivers directly.

**When NOT to use**: in-process collaboration between two functions or modules
that already share a runtime and failure domain. A queue between local helpers
is latency and operational drag without meaningful decoupling.

**Signals / example**: look for named queues, topics, streams, or webhook
endpoints as first-class integration surfaces. If producers construct the
broker path ad hoc in multiple places, the channel exists but the contract is
drifting.

```text
payments.authorized -> topic: billing-events -> subscriber: invoice-worker
```

### CIP2 — Message Router

**Intent**: examine a message and direct it to one of several destinations.

**When to use**: a single intake stream feeds multiple handlers, but the
decision can be made from explicit route metadata such as event type, source,
or tenant.

**When NOT to use**: when every consumer should see every message. Introducing a
router in a fan-out case hides the simpler publish/subscribe shape.

**Signals / example**: one component receives a message and forwards it to one
of N channels. Reviewers should ask whether the routing table is centralized
and testable, not spread across conditionals in multiple workers.

```python
route = {
    "invoice.created": "billing-queue",
    "account.suspended": "compliance-queue",
}
broker.publish(route[event.type], event)
```

### CIP3 — Content-Based Router

**Intent**: route a message based on its payload content rather than only on a
header or channel name.

**When to use**: the destination depends on fields inside the message body, such
as country, risk score, or requested operation.

**When NOT to use**: when a simple type or topic name already distinguishes the
paths. Overusing content-based routing turns one router into an opaque policy
engine.

**Signals / example**: routing logic reads business fields from the payload
before choosing a destination. Reviewers should flag duplicated routing rules
across services or payload parsing that is too schema-fragile for the
throughput involved.

```python
if event["risk_score"] >= 80:
    broker.publish("manual-review", event)
else:
    broker.publish("auto-approve", event)
```

### CIP4 — Message Translator

**Intent**: convert one message shape into another without forcing sender and
receiver to share the same schema.

**When to use**: integrating legacy systems, external providers, or internal
bounded contexts that use different field names, value enums, or nesting.

**When NOT to use**: when two services are owned together and can safely share a
single contract. Translators become debt if they only hide avoidable schema
divergence.

**Signals / example**: a dedicated adapter maps one payload shape to another
before publish or consume. Reviewers should ask whether translation rules are
versioned and whether unmapped fields fail loudly enough.

```python
provider_payload = {
    "customerId": event["tenant_id"],
    "occurredAt": event["timestamp"],
    "kind": event["event_type"],
}
```

### CIP5 — Splitter

**Intent**: divide one composite message into multiple smaller messages that
downstream handlers can process independently.

**When to use**: a batch, archive, or compound command arrives as one payload,
but downstream work scales better item-by-item.

**When NOT to use**: when downstream correctness depends on whole-batch context
that would be lost after splitting. Splitting too early can make later
reconciliation harder than the original batch handling.

**Signals / example**: one input message emits N derived messages. Reviewers
should check whether correlation metadata survives the split so the original
batch can still be reconstructed.

```python
for line_item in order["items"]:
    broker.publish("reserve-item", {"order_id": order["id"], "item": line_item})
```

### CIP6 — Aggregator

**Intent**: collect related messages and emit one combined result when a
completeness rule is satisfied.

**When to use**: fan-out / fan-in workflows, partial results, or multi-source
enrichment where downstream consumers need one assembled view.

**When NOT to use**: when lateness, duplication, or missing fragments cannot be
bounded. Aggregators without timeouts and partial-failure policy become silent
message sinks.

**Signals / example**: state is stored by correlation key until all expected
parts arrive or a timer expires. Reviewers should ask what happens to late
arrivals and whether the completeness rule is explicit.

```text
wait for: inventory_checked + payment_authorized + fraud_screened
keyed by: order_id
emit: order.ready_for_fulfillment
```

### CIP7 — Claim Check

**Intent**: move large payloads out of the message body and replace them with a
reference that consumers can redeem later.

**When to use**: message-size limits, large attachments, or binary artifacts
would otherwise bloat the broker path.

**When NOT to use**: when consumers always need the full payload immediately and
the broker can carry it safely. Claim check adds another storage dependency and
another failure mode.

**Signals / example**: a message contains a blob key, object-store URL, or
document ID instead of the full asset. Reviewers should check expiry,
authorization, and cleanup for the referenced payload.

```json
{
  "report_id": "rpt_123",
  "payload_ref": "s3://audit-artifacts/rpt_123.json"
}
```

### CIP8 — Dead Letter Queue

**Intent**: isolate messages that repeatedly fail normal processing so they can
be inspected or replayed separately.

**When to use**: consumers can hit poison messages, malformed payloads, or
persistent downstream errors that should not block the main queue forever.

**When NOT to use**: as a substitute for observability. A dead letter queue that
no one monitors is just deferred data loss.

**Signals / example**: retry count or failure reason determines when a message
is moved to a DLQ. Reviewers should ask who owns triage and replay, and whether
idempotent reprocessing is possible.

```text
main queue -> retry x5 -> dead-letter queue with error_code and failed_at
```

### CIP9 — Idempotent Receiver

**Intent**: make a consumer safe to run more than once against the same message.

**When to use**: at-least-once delivery, replay tools, retried webhooks, or any
broker path where duplicate delivery is expected behavior rather than an edge
case.

**When NOT to use**: when the operation is already naturally idempotent and no
durable side effect would repeat. Also do not confuse this with request-side
idempotency keys: receiver-side message dedupe belongs here, while durable API
request keys remain `CDP13` in the data catalog.

**Signals / example**: a consumer stores processed message IDs, sequence
numbers, or deterministic dedupe keys before applying side effects. Reviewers
should flag dedupe records kept only in memory, keys derived from process-local
values such as Python's built-in `hash()` (which is non-deterministic across
restarts), or scopes too broad to survive restarts. For durable keys, prefer
stable digest functions such as `hashlib.sha256(event.id.encode()).hexdigest()`.

```python
if not processed_messages.record_if_new(event.id):
    return
apply_side_effect(event)
```

### CIP10 — Correlation ID

**Intent**: carry one stable identifier across related messages so logs, traces,
and aggregators can tie them back to the same workflow.

**When to use**: multi-hop messaging, fan-out / fan-in flows, or incident
response where operators need to reconstruct one business transaction across
services.

**When NOT to use**: as a replacement for domain identifiers that already exist.
Correlation IDs complement order IDs, request IDs, and tenant IDs; they should
not erase them.

**Signals / example**: messages include `correlation_id`, `request_id`, or a
trace token that is forwarded unchanged. Reviewers should ask whether retries
preserve the same ID and whether logs emit it consistently.

```json
{
  "correlation_id": "ord_4827",
  "event_type": "payment.authorized"
}
```

### CIP11 — Envelope Wrapper

**Intent**: wrap a payload in a standard outer structure that carries metadata
such as schema version, sender, content type, and tracing context.

**When to use**: a shared messaging platform needs consistent metadata across
many event types, or receivers need versioning and tracing info before parsing
the payload.

**When NOT to use**: when the envelope grows into a second schema that every
consumer must special-case. Keep the wrapper generic and the business payload
inside it.

**Signals / example**: messages have a common outer object plus a domain
payload. Reviewers should flag wrappers that duplicate the same field in both
places or hide version changes in untyped metadata.

```json
{
  "schema_version": 3,
  "content_type": "application/json",
  "correlation_id": "ord_4827",
  "payload": {"event_type": "payment.authorized", "amount": 1250}
}
```

---

## Cross-references

- [`design-patterns.md`](design-patterns.md) — lead file, framing and ID routing.
- [`design-patterns-gof.md`](design-patterns-gof.md) — sibling file, `CP2`–`CP24` (Gang of Four).
- [`design-patterns-post-gof.md`](design-patterns-post-gof.md) — sibling file, `CP25`–`CP34`; distributed-system patterns such as CQRS, Event Sourcing, Saga, Circuit Breaker, Bulkhead, and Sidecar remain there.
- [`design-patterns-data.md`](design-patterns-data.md) — sibling file, `CDP1`–`CDP14`; data and persistence mechanics such as `CDP13` Idempotency Key remain separate from receiver-side dedupe in [`CIP9`](#cip9--idempotent-receiver).
- [`design-patterns-post-gof.md#cp31--saga`](design-patterns-post-gof.md#cp31--saga) — often composes [`CIP6`](#cip6--aggregator), [`CIP8`](#cip8--dead-letter-queue), and [`CIP10`](#cip10--correlation-id) in the surrounding messaging workflow.
