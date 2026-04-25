# GapHunter

A Claude Code skill that researches negative user reviews of a competing product, identifies missing or unimplemented features, and produces a single self-contained HTML intelligence report with filters, PDF export, and a rigid reusable template.

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

The skill searches G2, Capterra, TrustRadius, Reddit, and GitHub Issues in parallel, cross-references findings against the current project, fills `templates/gaphunter-report-template.html`, and writes `docs/<product>-gap-report.html`.

## Install

```bash
bash install.sh
```

This symlinks `SKILL.md` and `templates/` into `~/.claude/skills/gaphunter/` so Claude Code picks them up globally. Restart Claude Code after installing.

## Uninstall

```bash
bash uninstall.sh
```

## Project structure

```
gaphunter-skill/
├── SKILL.md              # Canonical skill definition
├── templates/
│   └── gaphunter-report-template.html  # Locked HTML report template
├── install.sh            # Symlinks SKILL.md and templates/ into ~/.claude/skills/gaphunter/
├── uninstall.sh          # Removes the installed skill
└── examples/
    └── dbeaver-gap-report.html   # Sample output — DBeaver vs Tabularis
```

## Template contract

Generated reports must be created by copying `templates/gaphunter-report-template.html` and replacing only the `__REPORT_DATA_JSON__` placeholder. The layout, filters, CSS, JavaScript renderer, section order, and print/PDF styling are owned by the template file so every report has the same structure.

## Output format

The HTML report contains:

1. **Executive Summary** — top 3–5 critical gaps
2. **Negative Review Analysis** — findings grouped by theme, with direct user quotes and source badges
3. **Gap Matrix** — table comparing each feature across the competitor and the current project
4. **Implementation Plan** — feature cards with effort estimate, implementation steps, and files to touch
5. **Sources** — all URLs consulted with access status

The HTML is fully self-contained, has no external dependencies, includes client-side filters, and exports to PDF through the browser print dialog.
