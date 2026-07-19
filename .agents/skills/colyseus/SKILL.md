---
name: colyseus
description: |
  Design, implement, test, deploy, and scale authoritative multiplayer servers
  with Colyseus. Use for rooms, state synchronization, matchmaking,
  reconnection, unit testing, load testing, deployment, scalability, Colyseus
  Cloud, and Phaser-to-Colyseus integration. Verify version-specific APIs in
  official Colyseus documentation before editing code.
---

# Colyseus

Treat the server as authoritative. Clients send intent; the room validates and
applies it; synchronized state communicates accepted outcomes. Never trust a
client-provided identity, position, score, inventory, cooldown, or permission.

## Verify the installed version

Read the server and client package manifests, lockfile, and generated project
structure first. Colyseus APIs and package names evolve. Use the installed types
and current official documentation as the source of truth instead of recalling
method signatures from memory. Keep server and client protocol expectations
compatible.

## Design rooms and state

1. Define a room around one authoritative session or simulation boundary.
2. Keep lifecycle, admission, authentication, reconnection, and disposal rules
   explicit. Bound player counts and validate matchmaking options.
3. Put shared observable game data in the synchronized schema. Keep secrets,
   server-only calculations, transient infrastructure data, and high-frequency
   values that clients do not need outside synchronized state.
4. Validate every incoming message before mutation. Rate-limit abuse-prone
   actions and make invalid transitions observable without leaking secrets.
5. Drive simulation from server time. Separate deterministic game rules from
   room transport so rules can be unit tested without network timing.
6. Make disconnect and reconnection behavior explicit, including reservation
   expiry, forfeits, cleanup, and duplicate-session handling.

For Phaser clients, keep rendering and prediction client-side while reconciling
to authoritative snapshots or patches. Do not couple Phaser scene lifecycle to
the lifetime of a network subscription without cleanup.

## Matchmaking

Define the room name, join/create policy, public filter fields, capacity, and
admission checks. Keep private or security-sensitive values out of public room
metadata. Test concurrent joins, full rooms, invalid options, retries,
reconnection, and no-match behavior. For custom matchmaking, state the fairness,
latency, party, region, and skill constraints before selecting an algorithm.

## Test before deployment

- Use Colyseus unit testing utilities to exercise room creation, joins, messages,
  synchronized state, leaves, reconnection, and disposal.
- Test game rules separately with deterministic clocks and seeded randomness.
- Add integration tests with real server/client serialization for protocol
  boundaries; mocks alone do not prove compatibility.
- Use `@colyseus/loadtest` with representative bot behavior, connection churn,
  message rates, and room distributions. Increase load gradually and record CPU,
  memory, event-loop delay, network, room count, and error rates.
- Test malformed and unauthorized messages, slow clients, abrupt disconnects,
  deploy shutdown, and dependency outages.

Do not claim a concurrency target from a synthetic connection count alone.
Capacity depends on simulation cost, patch size, message rate, room shape,
runtime resources, and external dependencies.

## Deploy and operate

1. Build the production artifact and run its test suite locally.
2. Configure the public WebSocket endpoint, TLS, allowed origins, environment
   variables, health checks, logging, and graceful shutdown.
3. Keep secrets outside source control. Use the hosting platform's secret store
   and a least-privilege runtime identity.
4. Verify that the load balancer supports long-lived WebSocket connections and
   that draining allows rooms to finish or reconnect safely during deploys.
5. Monitor room creation/disposal, concurrent clients, message failures,
   reconnects, event-loop delay, memory, process restarts, and dependency health.

For horizontal scalability, use shared presence and a shared driver supported by
the installed Colyseus version so processes can coordinate and discover rooms.
Confirm routing, process selection, failure handling, and rolling-deploy behavior
under load. Do not add Redis, a database, or orchestration before multi-process
requirements justify it.

Compare self-hosting with **Colyseus Cloud** using operational ownership, region,
autoscaling, observability, deployment, data, and cost requirements. Cloud is a
hosting option, not proof that application-level capacity and recovery work.

## Official sources

- [Colyseus documentation](https://docs.colyseus.io/)
- [Rooms](https://docs.colyseus.io/room)
- [State synchronization](https://docs.colyseus.io/state)
- [Matchmaking](https://docs.colyseus.io/matchmaker)
- [Unit testing](https://docs.colyseus.io/tools/unit-testing)
- [Load testing](https://docs.colyseus.io/tools/loadtest)
- [Deployment](https://docs.colyseus.io/deployment)
- [Scalability](https://docs.colyseus.io/scalability)
- [Colyseus Cloud](https://docs.colyseus.io/cloud)

## Ownership and freshness

This is a repository-owned skill and has no Colyseus MCP dependency. It is
excluded from external refresh automation. Revalidate package names, lifecycle
APIs, testing utilities, deployment guidance, and scaling adapters against the
linked official documentation whenever the installed version changes or this
skill is materially edited.
