<!-- TEMPLATE_PLACEHOLDER: Replace with actual project roadmap -->

# Project Roadmap

> **Purpose**: Phase-by-phase plan with clear acceptance criteria. Agents use this to understand project trajectory and prioritize work.

## Roadmap Principles

1. **Begin with the end in mind**: Start with mockups, architecture, and user experience before implementation
2. **Phases are sequential**: Complete current phase before starting next
3. **Acceptance criteria are non-negotiable**: Each phase must meet all criteria before advancing

---

## Phase 0: Vision & Architecture (Pre-Development)

**Status**: [ ] Not Started / [ ] In Progress / [ ] Complete

**Objective**: Define what we're building before writing code.

### Deliverables
- [ ] High-level architecture diagram
- [ ] UI/UX mockups (can be AI-generated)
- [ ] Tech stack decision with rationale
- [ ] Initial domain rules documented in `rules/`

### Acceptance Criteria
- [ ] Team/stakeholders approve mockups
- [ ] Architecture supports all known requirements
- [ ] No major "unknown unknowns" remain

---

## Phase 1: Foundation

**Status**: [ ] Not Started / [ ] In Progress / [ ] Complete

**Objective**: Set up project infrastructure and CI/CD.

### Deliverables
- [ ] Repository initialized with template
- [ ] CI/CD pipeline running (lint, test, build)
- [ ] Development environment documented
- [ ] Core dependencies installed

### Acceptance Criteria
- [ ] `./test.sh` passes
- [ ] CI pipeline green on main branch
- [ ] README has working setup instructions

---

## Phase 2: Core Features

**Status**: [ ] Not Started / [ ] In Progress / [ ] Complete

**Objective**: Implement minimum viable functionality.

### Deliverables
- [ ] [Feature 1 description]
- [ ] [Feature 2 description]
- [ ] Unit test coverage > X%

### Acceptance Criteria
- [ ] All core user stories complete
- [ ] Tests pass locally and in CI
- [ ] No critical bugs open

---

## Phase 3: Polish & Launch

**Status**: [ ] Not Started / [ ] In Progress / [ ] Complete

**Objective**: Production-ready release.

### Deliverables
- [ ] Error handling complete
- [ ] Performance optimized
- [ ] Documentation complete
- [ ] Deployment pipeline working

### Acceptance Criteria
- [ ] All automated tests pass
- [ ] Manual QA complete
- [ ] Production deployment successful

---

## How to Update This Roadmap

1. Mark items complete as work progresses
2. Add new phases if scope expands
3. Update the latest `agent-state:v1` issue/PR comment to reflect live work
4. Log significant decisions in `00_INDEX.md`
