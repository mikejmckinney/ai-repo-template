<!-- TEMPLATE_PLACEHOLDER: Add domain rules here -->

# Domain Rules

> **Purpose**: This directory contains **immutable constraints** that must never be violated. Agents should check these rules before making changes.

## What Belongs Here

- Security requirements (e.g., "never log PII")
- Architectural constraints (e.g., "all API calls go through the gateway")
- Business rules (e.g., "users must verify email before posting")
- Coding standards that are project-specific

## Naming Convention

Files should be named `domain_<area>.md`:
- `domain_auth.md` - Authentication/authorization rules
- `domain_data.md` - Data handling constraints
- `domain_api.md` - API design rules
- `domain_testing.md` - Testing requirements

## Example Rule File Structure

```markdown
# Domain: Authentication

## Hard Rules (Never Violate)
1. Passwords must be hashed with bcrypt (cost factor >= 12)
2. JWTs expire after 15 minutes
3. Refresh tokens stored in httpOnly cookies only

## Soft Rules (Prefer Unless Justified)
1. Prefer OAuth2 over custom auth
2. Use established libraries over custom implementations

## Rationale
- [Why these rules exist]

## Exceptions Process
- If a rule must be violated, document in PR with security review
```

## Current Rules

<!-- Add links to domain rule files as they're created -->

- [`domain_code_quality.md`](./domain_code_quality.md) — built-in, language-neutral SOLID / TDD / clean-code floor. Architect-owned. Read before any non-trivial refactor; Judge blocks diff-gate on unjustified Hard-rule violations.

Add further rules as `domain_<area>.md` (for example `domain_auth.md`, `domain_api.md`) following the naming convention above.
