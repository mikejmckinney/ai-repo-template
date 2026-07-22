# README Visual Assets

The root README uses two hand-authored, self-contained SVG files:

- `repository-lifecycle.svg` is the lifecycle hero.
- `feature-tour.svg` is the six-journey overview.

SVG is both the deterministic source and the rendered asset. There is no second
Mermaid, design-tool export, font download, script, or generated copy to keep in
sync. Use system font stacks and retain each asset's `<title>` and `<desc>`.

Every visual claim must also appear as prose in the root README. Images are
supplementary; changing a card requires changing its equivalent prose in the
same pull request. The root README is the freshness owner for these assets.

Video is deferred. Add motion only after a recorded first-time-evaluator test
identifies a temporal misunderstanding that the static assets and equivalent
prose cannot resolve. If that gate is met, document the storyboard, accessible
controls, external hosting, privacy boundary, and freshness owner before
capturing authenticated interfaces.
