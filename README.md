# GapHunter

A Claude Code skill that researches negative user reviews of a competing product, identifies missing or unimplemented features, and produces a single self-contained HTML intelligence report with a prioritized implementation plan.

## Usage

```
/gaphunter <ProductName>
```

Example:

```
/gaphunter DBeaver
/gaphunter Notion
/gaphunter Figma
```

The skill searches G2, Capterra, TrustRadius, Reddit, and GitHub Issues in parallel, cross-references findings against the current project, and writes `docs/<product>-gap-report.html`.

## Install

```bash
bash install.sh
```

This symlinks `SKILL.md` into `~/.claude/skills/gaphunter/` so Claude Code picks it up globally. Restart Claude Code after installing.

## Uninstall

```bash
bash uninstall.sh
```

## Project structure

```
gaphunter-skill/
├── SKILL.md              # Canonical skill definition
├── install.sh            # Symlinks SKILL.md into ~/.claude/skills/gaphunter/
├── uninstall.sh          # Removes the installed skill
└── examples/
    └── dbeaver-gap-report.html   # Sample output — DBeaver vs Tabularis
```

## Output format

The HTML report contains:

1. **Executive Summary** — top 3–5 critical gaps
2. **Negative Review Analysis** — findings grouped by theme, with direct user quotes and source badges
3. **Gap Matrix** — table comparing each feature across the competitor and the current project
4. **Implementation Plan** — feature cards with effort estimate, implementation steps, and files to touch
5. **Sources** — all URLs consulted with access status

The HTML is fully self-contained (no external dependencies) and renders correctly when opened directly in a browser.
