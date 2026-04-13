# Domain: Code Quality

> **Purpose**: Language-neutral code quality principles for AI agents. Adapted from SOLID, clean code, and TDD practices. Apply these when writing, reviewing, or refactoring code in any language.

## Hard Rules (Never Violate)

1. **No untested behavioral changes.** Every change to observable behavior must include a corresponding test. "It works when I run it" is not a substitute for an automated test.

2. **No secrets in code.** Passwords, API keys, tokens, and connection strings must come from environment variables or a secret manager. Never hardcode, never commit, never log.

3. **Handle errors explicitly.** Never silently swallow exceptions or ignore error return values. Every error path must either be handled, propagated with context, or logged with enough detail to diagnose.

4. **Functions do one thing.** A function should have a single, clear responsibility. If you need the word "and" to describe what it does, split it.

## Soft Rules (Prefer Unless Justified)

### SOLID Principles (Object-Oriented Contexts)

1. **Single Responsibility.** Each class/module should have one reason to change. When a module handles both business logic and data formatting, separate them.

2. **Open/Closed.** Prefer extending behavior through composition, strategy patterns, or configuration over modifying existing working code. New features should not require rewriting stable code.

3. **Liskov Substitution.** Subtypes must be usable wherever their parent type is expected without surprising behavior. If a subclass overrides a method in a way that breaks callers, the inheritance is wrong.

4. **Interface Segregation.** Don't force consumers to depend on methods they don't use. Prefer small, focused interfaces over large, general-purpose ones.

5. **Dependency Inversion.** High-level modules should depend on abstractions, not concrete implementations. Inject dependencies rather than instantiating them internally.

### Clean Code Practices

6. **Descriptive naming.** Variables, functions, and classes should reveal their intent. `getUsersByStatus(status)` over `get(s)`. Longer descriptive names are better than short cryptic ones.

7. **Keep functions short.** Functions should typically fit on one screen. When a function grows beyond ~30 lines, look for extraction opportunities. This is a guideline, not a hard limit — clarity matters more than line counts.

8. **Minimize nesting.** Prefer early returns and guard clauses over deeply nested conditionals. If code is indented more than 3 levels, refactor.

9. **Don't Repeat Yourself (with judgment).** Extract genuinely duplicated logic into shared functions. But don't over-abstract — two pieces of code that look similar but change for different reasons should remain separate.

10. **Comments explain why, not what.** Code should be self-documenting for *what* it does. Comments should explain *why* a non-obvious decision was made, not narrate the code.

### Testing Practices

11. **Test pyramid.** Many fast unit tests, fewer integration tests, minimal end-to-end tests. Unit tests should run in milliseconds.

12. **Test behavior, not implementation.** Tests should verify what code does (outputs, side effects), not how it does it internally. This makes tests resilient to refactoring.

13. **Arrange-Act-Assert.** Structure tests with clear setup, execution, and verification phases. One logical assertion per test.

14. **Test edge cases.** Empty inputs, null/undefined values, boundary conditions, error paths, and concurrent access should all have test coverage.

### Architecture

15. **Separate concerns by layer.** Keep presentation, business logic, and data access in distinct layers. A UI component should not contain SQL queries. An API handler should not contain business rules.

16. **Favor composition over inheritance.** Inheritance creates tight coupling. Prefer composing behavior from small, focused pieces.

17. **Design for deletion.** Code should be easy to remove. If deleting a feature requires touching 20 files across the codebase, the boundaries are wrong.

## When to Apply

- **Always apply** Hard Rules — no exceptions without documented justification
- **Apply Soft Rules** when writing new code or refactoring existing code
- **Don't retroactively refactor** stable, working code just to satisfy soft rules — only refactor code you're already changing for other reasons
- **Language-specific conventions** (e.g., Python's PEP 8, Go's `gofmt`) take precedence over these general guidelines when they conflict

## Rationale

- These principles reduce defect rates, improve maintainability, and make code easier for both humans and AI agents to understand
- AI agents produce better output when given explicit quality constraints rather than relying on training defaults
- The hard/soft split allows pragmatic trade-offs without abandoning standards entirely

## References

- Robert C. Martin, *Clean Code* (principles adapted, not line-count rules)
- Martin Fowler, *Refactoring*
- SOLID principles (Robert C. Martin)
- Kent Beck, *Test-Driven Development*
