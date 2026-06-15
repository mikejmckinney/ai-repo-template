# Design contract

> **Purpose**: Root design contract for agent-assisted product design and UI implementation.
>
> **For design tools** (OpenDesign, Claude Design, Figma AI exports, etc.): load this file as the primary context before generating mockups or interactive prototypes. It defines product feel, tokens, accessibility floor, layout patterns, and where artifacts land in the repo.
>
> **Template repo note (`ai-repo-template`):** This repo has no product UI. The sections below are a **generic contract template** shipped so derived projects and agents know the expected shape. During Mode B onboarding, reset from the canonical stub in [`.github/prompts/repo-onboarding-stubs.md`](.github/prompts/repo-onboarding-stubs.md) (procedure: [`.github/prompts/repo-onboarding.md`](.github/prompts/repo-onboarding.md) Track B) and replace `[TBD]` / example values with product-specific direction **before frontend implementation starts**.

## Status

- **Project**: [TBD — ai-repo-template: process/template repo, no product UI]
- **Design owner**: [TBD]
- **Current design phase**: [Discovery / Prototype / Approved / Implementing / Maintenance]
- **Last reviewed**: [YYYY-MM-DD]
- **Primary implementation stack**: [TBD]

## How agents and design tools should use this file

1. Read this file **before** invoking OpenDesign, Claude Design, or any UI generator.
2. Pass relevant sections (product identity, tokens, UX principles, accessibility floor, layout patterns) as context to the design tool — do not rely on the tool's defaults alone.
3. Treat this file as the **root design contract**; generated output must conform to tokens and accessibility rules here unless an explicit decision record says otherwise.
4. Store generated design artifacts under `.context/vision/mockups/<tool>/<YYYY-MM-DD>/` (e.g. `mockups/opendesign/`, `mockups/claude-design/`).
5. Record approved UI decisions in `docs/design/ui-decision.md` or a project-specific equivalent.
6. Do **not** treat generated prototype HTML/React as production source unless the project explicitly chooses that architecture.
7. Keep accessibility requirements visible in every design and implementation handoff.

## Product identity

Describe the product's intended feel in plain language.

- **Personality**: [e.g., calm, trustworthy, fast, playful, clinical, premium]
- **Primary audience**: [TBD]
- **Main user jobs**:
  - [Job 1]
  - [Job 2]
  - [Job 3]
- **Non-goals**:
  - [Non-goal 1]
  - [Non-goal 2]

## UX principles

Replace these with project-specific principles.

1. **Clarity before novelty**: Prefer obvious flows and readable content over decorative complexity.
2. **Fast first success**: The first useful action should be discoverable within one screen.
3. **Progressive disclosure**: Keep advanced settings available but not dominant.
4. **Accessible by default**: Keyboard, screen-reader, contrast, and touch-target requirements are not optional.
5. **Design for interruption**: Important flows should survive pauses, navigation, and resume states.

## Accessibility floor

Every UI direction and implementation should satisfy:

- semantic headings and landmarks
- visible focus states
- keyboard access to all interactive controls
- sufficient color contrast
- non-color-only status indicators
- labels for form controls and icon-only buttons
- readable mobile layouts
- touch targets appropriate for phones and tablets
- reduced-motion compatibility for animated elements
- status updates that can be understood by screen readers

## Design tokens

Use semantic token names. Do not hard-code final values here unless the project has approved a design system. Design tools should read these names and map them to concrete values in generated mockups.

### Color tokens

| Token | Purpose | Notes |
|---|---|---|
| `color-bg` | Main app background | [TBD] |
| `color-surface` | Cards, panels, dialogs | [TBD] |
| `color-surface-muted` | Secondary panels | [TBD] |
| `color-text` | Primary text | [TBD] |
| `color-text-muted` | Secondary text | [TBD] |
| `color-border` | Dividers and outlines | [TBD] |
| `color-accent` | Primary action and highlights | [TBD] |
| `color-success` | Positive state | Must not rely on color alone |
| `color-warning` | Caution state | Must not rely on color alone |
| `color-danger` | Destructive or error state | Must not rely on color alone |
| `color-focus-ring` | Keyboard focus | Must be highly visible |

### Typography tokens

| Token | Purpose | Notes |
|---|---|---|
| `font-sans` | Primary UI typeface | [TBD] |
| `font-mono` | Code or technical values | Optional |
| `text-xs` | Metadata | [TBD] |
| `text-sm` | Secondary UI text | [TBD] |
| `text-base` | Body text | [TBD] |
| `text-lg` | Section headings | [TBD] |
| `text-xl` | Page headings | [TBD] |

### Spacing tokens

| Token | Purpose |
|---|---|
| `space-1` | Tight inline gaps |
| `space-2` | Compact control gaps |
| `space-3` | Card internal spacing |
| `space-4` | Section spacing |
| `space-6` | Page spacing |
| `space-8` | Major layout separation |

## Layout patterns

Define the project's major layout patterns.

- **App shell**: [TBD]
- **Navigation model**: [TBD]
- **Dashboard layout**: [TBD]
- **Primary task layout**: [TBD]
- **Detail/review layout**: [TBD]
- **Modal/dialog usage**: [TBD]
- **Empty states**: [TBD]
- **Loading states**: [TBD]
- **Error states**: [TBD]

## Responsive behavior

Define how the UI adapts across common breakpoints.

| Viewport | Design intent | Notes |
|---|---|---|
| Phone | [TBD] | Prioritize core action and readable content |
| Tablet | [TBD] | Consider split view or secondary panels |
| Laptop/Desktop | [TBD] | Use additional width for navigation, context, and analytics |

## Component inventory

List expected reusable components. Design tools should align generated UI to these names where possible.

| Component | Purpose | Status |
|---|---|---|
| `AppShell` | Global layout/navigation | [TBD] |
| `PrimaryButton` | Main actions | [TBD] |
| `SecondaryButton` | Non-primary actions | [TBD] |
| `Card` | Surface container | [TBD] |
| `Dialog` | Confirmation or focused task | [TBD] |
| `FormField` | Accessible form control wrapper | [TBD] |
| `StatusBadge` | State indicator | [TBD] |
| `DataSummary` | Compact metric display | [TBD] |

## Design-tool workflow (OpenDesign, Claude Design, etc.)

Use this workflow when generating UI with external design tools:

1. **Load context**: Provide this `DESIGN.md` (or the relevant sections) to the design tool as system/context input.
2. **Brief**: Start from product requirements and user outcomes — not from implementation files.
3. **Generate directions**: Produce 2–3 distinct prototype directions that honor tokens, UX principles, and the accessibility floor.
4. **Save artifacts**: Export mockups, HTML, or tool-native files under `.context/vision/mockups/<tool>/<YYYY-MM-DD>/` with a short `README.md` describing each file.
5. **Critique**: Review against user outcomes, accessibility, implementation simplicity, and maintainability.
6. **Decide**: Record the selected direction in `docs/design/ui-decision.md`.
7. **Implement**: Frontend agents translate the approved direction into production components in the app's source tree — referencing mockups as **design input**, not copy-paste source, unless explicitly approved.

## Design artifact locations

| Path | Purpose |
|---|---|
| `DESIGN.md` | Root design contract (this file) |
| `.context/vision/README.md` | Vision and design-artifact index |
| `.context/vision/mockups/` | Generated or hand-authored mockups/prototypes |
| `.context/vision/mockups/opendesign/` | OpenDesign exports (convention) |
| `.context/vision/mockups/claude-design/` | Claude Design exports (convention) |
| `.context/vision/architecture/` | Architecture diagrams and user-flow diagrams |
| `docs/design/` | Human-readable design decisions, critiques, and handoffs |
| `src/**` | Production implementation, if the derived project has runtime code |

## Implementation handoff checklist

Before frontend implementation starts:

- [ ] `DESIGN.md` has been customized for the project.
- [ ] Mockups or prototypes exist under `.context/vision/mockups/`.
- [ ] A design decision has been recorded under `docs/design/`.
- [ ] Accessibility requirements are explicit.
- [ ] The component inventory is known.
- [ ] The implementation agent knows which prototype artifacts are references only.
- [ ] The production stack and test strategy are documented.

## Decision log

| Date | Decision | Rationale | Link |
|---|---|---|---|
| YYYY-MM-DD | [TBD] | [TBD] | [TBD] |

## Open questions

- [ ] What visual tone best fits this product?
- [ ] Which user flow should be prototyped first?
- [ ] What accessibility constraints are most important for the audience?
- [ ] What existing brand or design system, if any, should be used?
- [ ] Which design tools (OpenDesign, Claude Design, Figma, etc.) are approved for this project?
- [ ] Which generated artifacts are allowed to influence production implementation?

## Related references

- [`.github/prompts/repo-onboarding-stubs.md`](.github/prompts/repo-onboarding-stubs.md) — Mode B canonical stub source (procedure: [`repo-onboarding.md`](.github/prompts/repo-onboarding.md))
- [`.context/roadmap.md`](.context/roadmap.md) — Phase 0 deliverables (mockups, stack, domain rules)
- [`.context/vision/README.md`](.context/vision/README.md) — mockup and diagram index
