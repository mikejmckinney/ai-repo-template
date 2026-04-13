# Domain: Code Quality

> **Purpose**: Universal code quality principles that all agents should follow regardless of language, framework, or tool. Derived from SOLID principles, TDD practices, and clean code standards.

## Hard Rules (Never Violate)

### 1. SOLID Principles

1. **Single Responsibility (SRP)**: Each class, module, or function should have one reason to change. If you cannot describe a function's purpose in one sentence without "and," split it.

2. **Open/Closed (OCP)**: Code should be open for extension but closed for modification. Prefer composition, strategy patterns, and dependency injection over modifying existing code.

3. **Liskov Substitution (LSP)**: Subtypes must be substitutable for their base types without altering program correctness. Avoid "instanceof" checks in consuming code.

4. **Interface Segregation (ISP)**: No client should be forced to depend on methods it does not use. Prefer multiple small, focused interfaces over one large interface.

5. **Dependency Inversion (DIP)**: High-level modules should not depend on low-level modules; both should depend on abstractions. Inject dependencies rather than importing concrete implementations directly.

### 2. Test-Driven Development (TDD)

Follow the Red-Green-Refactor cycle when implementing new features:

1. **Red**: Write a failing test that defines the desired behavior
2. **Green**: Write the minimum code to make the test pass
3. **Refactor**: Clean up the code while keeping tests green

When TDD is not practical (e.g., exploratory prototyping), write tests alongside or immediately after implementation — never skip tests entirely.

### 3. Clean Code Fundamentals

1. **Meaningful names**: Variables, functions, and classes should reveal intent. Avoid abbreviations, single-letter names (except loop counters), and misleading names.

2. **Small functions**: Functions should do one thing. Target ≤ 20 lines; if a function exceeds 30 lines, consider splitting it.

3. **No magic values**: Replace magic numbers and strings with named constants or enums.

4. **Fail fast**: Validate inputs at function boundaries. Return early on invalid state rather than nesting deeply.

5. **Don't Repeat Yourself (DRY)**: If logic is duplicated in 3+ places, extract it. Two occurrences may be acceptable if the contexts differ.

## Soft Rules (Prefer Unless Justified)

### Design Patterns

- Use design patterns (Factory, Strategy, Observer, etc.) when they simplify the code — not just because they exist
- Prefer composition over inheritance
- Use value objects for domain primitives (IDs, emails, money amounts) when the language supports them

### Code Smells to Watch For

| Smell | Symptom | Fix |
|-------|---------|-----|
| Long Method | Function > 30 lines | Extract methods |
| God Class | Class with 10+ methods or 200+ lines | Split responsibilities |
| Feature Envy | Method uses another class's data more than its own | Move method to the other class |
| Primitive Obsession | Using raw strings/numbers for domain concepts | Introduce value objects or types |
| Shotgun Surgery | One change requires editing many files | Consolidate related logic |
| Dead Code | Unused functions, variables, imports | Delete them |

### Architecture

- **Vertical slicing**: Organize by feature, not by technical layer, when possible
- **Clean architecture**: Dependencies should point inward (UI → Application → Domain → Infrastructure)
- **Explicit boundaries**: Define clear interfaces between modules/services

## Rationale

These principles produce code that is easier to test, maintain, and extend. They reduce bugs, speed up onboarding, and make agent-generated code closer to senior-engineer quality.

Adapted from universal software engineering practices. For Claude Code users, the [solid-skills](https://github.com/ramziddin/solid-skills) plugin provides automated enforcement of these principles in TypeScript/NestJS projects.

## Exceptions Process

If a principle must be violated (e.g., performance-critical code that requires a large function):
1. Add a comment explaining why the principle is intentionally violated
2. Document in the PR description
3. Ensure tests cover the exceptional code thoroughly
