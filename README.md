# GapHunter

A Claude Code skill that researches negative user reviews of competing products, identifies missing or poorly implemented features, cross-references them against the current project, and produces a single self-contained HTML intelligence report with filters, PDF export, a Priority/Effort quadrant, and a rigid reusable template.

## Usage

```
/gaphunter <ProductName>
/gaphunter <Product1> <Product2> ...
/gaphunter <ProductName> --sources-only
```

**Single product:**

```
/gaphunter DBeaver
/gaphunter Notion
/gaphunter Figma
```

**Multi-competitor** — runs Phase 1 for each product in parallel and merges findings into one report. Source names are prefixed with the competitor name (`"DBeaver/G2"`, `"TablePlus/Reddit"`) so filters distinguish data origins:

```
/gaphunter DBeaver TablePlus
/gaphunter Jira Linear Trello
```

**Sources only** — executes only the research phase and dumps raw findings as a markdown list in chat. No HTML file is written:

```
/gaphunter DBeaver --sources-only
```

## Sources researched

The skill searches these sources in parallel:

- **G2** — structured review pages (cons / dislikes)
- **Capterra** — structured review pages (cons)
- **TrustRadius** — structured review pages (cons / missing features)
- **Reddit** — community threads (problems, wish lists)
- **GitHub Issues** — feature requests and bug reports
- **Hacker News** — web search + `hn.algolia.com` API (always accessible, no 403)

Near-duplicate complaints are clustered semantically before recording — "no dark mode" and "lacks dark theme" become one finding with combined frequency, sources, and quotes.

## Install

```bash
bash install.sh
```

Symlinks `SKILL.md` and `templates/` into `~/.claude/skills/gaphunter/` so Claude Code picks them up globally. Restart Claude Code after installing.

## Uninstall

```bash
bash uninstall.sh
```

## Project structure

```
gaphunter-skill/
├── SKILL.md              # Canonical skill definition
├── templates/
│   └── gaphunter-report-template.html  # Locked HTML report template (v2.0.0)
├── install.sh            # Symlinks SKILL.md and templates/ into ~/.claude/skills/gaphunter/
├── uninstall.sh          # Removes the installed skill
└── examples/
    └── dbeaver-gap-report.html   # Sample output — DBeaver vs Tabularis
```

## Template contract

Generated reports must be created by copying `templates/gaphunter-report-template.html` and replacing only the `__REPORT_DATA_JSON__` placeholder with the JSON data object. The layout, filters, CSS, JavaScript renderer, section order, and print/PDF styling are owned by the template file so every report has identical structure.

**Do not rewrite the HTML shell, CSS, layout, controls, JavaScript renderer, class names, section order, or print styles for individual reports.** If a new visual or interaction is needed, update the template file itself, then regenerate reports.

### Section order (template v2.0.0)

1. `<header class="hero" data-section="overview">`
2. `<aside class="filter-panel" aria-label="Report filters">`
3. `<main class="report-main">`
4. `<section id="executive-summary" data-section="summary">`
5. `<section id="quick-wins" data-section="quickwins">`
6. `<section id="negative-analysis" data-section="analysis">`
7. `<section id="gap-matrix" data-section="matrix">`
8. `<section id="implementation-plan" data-section="plan">`
9. `<section id="sources" data-section="sources">`
10. `<footer class="report-footer">`

## JSON schema reference

The JSON object injected into `__REPORT_DATA_JSON__` must match this shape:

```js
{
  meta: {
    productName: "",          // competitor name(s), e.g. "DBeaver" or "DBeaver, TablePlus"
    projectName: "",          // current project name
    generatedAt: "",          // ISO date string, e.g. "2026-04-25"
    sourceCount: 0,           // total sources consulted
    findingCount: 0,          // total findings
    highPriorityCount: 0,     // count of high-priority findings
    dataQualityNote: "",      // shown as a warning banner if non-empty
    competitiveScore: 0,      // integer 0–100 opportunity score
    quickWinCount: 0          // count of high-priority + small-effort findings
  },
  summary: [
    { id: "", severity: "critical|warning|positive", title: "", text: "" }
  ],
  findings: [
    {
      id: "",                           // unique slug
      theme: "",                        // grouping label
      title: "",
      description: "",
      priority: "high|medium|low",
      status: "missing|partial|present",
      effort: "small|medium|large|none",
      frequency: "many|some|single",
      trend: "persistent|recent|unknown", // defaults to "unknown" if absent
      sources: ["G2"],
      quotes: [{ text: "", cite: "" }],
      implementationSteps: [""],
      filesToTouch: [""]
    }
  ],
  sources: [
    { name: "", type: "", url: "", access: "ok|blocked|snippet", note: "" }
  ]
}
```

**Backward compatibility:** `trend` defaults to `"unknown"` in the renderer if absent. `competitiveScore` and `quickWinCount` are computed on-the-fly from `findings` if missing from `meta`.

## Report sections

| # | Section | Description |
|---|---------|-------------|
| 01 | **Executive Summary** | Top 3–5 insight cards (critical / warning / positive) |
| 02 | **Quick Wins** | High-priority, small-effort findings only — implement these first |
| 03 | **Negative Review Analysis** | All findings grouped by theme, with user quotes and source badges |
| 04 | **Gap Matrix** | Comparison table with status, priority, effort, and trend per finding |
| 05 | **Implementation Plan** | Actionable cards with steps and files to touch (missing/partial only) |
| 06 | **Sources** | All URLs consulted with access status (ok / snippet / blocked) |

## Interactive features

### Filter panel

The sticky sidebar provides:

- **Search** — full-text search over title, description, theme, sources, implementation steps, and files
- **Priority** — All / High / Medium / Low
- **Status** — All / Missing / Partial / Present
- **Effort** — All / Small / Medium / Large
- **Source** — generated from unique source names in the data (including `"DBeaver/G2"` prefixed names in multi-competitor reports)
- **Theme** — generated from unique theme names in the data
- **Trend** — All / Persistent / Recent / Unknown
- **Implementation only** toggle — shows only actionable missing/partial findings

Filtering updates all sections simultaneously: summary cards, Quick Wins, analysis cards, matrix rows, and implementation plan cards.

### Buttons

| Button | Action |
|--------|--------|
| **Reset** | Clears all filters and removes the URL hash |
| **Export PDF** | Calls `window.print()` — browser renders to PDF with optimized light stylesheet |
| **Permalink** | Serializes current filter state to base64 and sets `location.hash`; copies the full URL to clipboard |
| **Export JSON** | Downloads `reportData` as `<productname>-gap-data.json` |

### SVG Priority/Effort quadrant

An inline SVG chart in the hero maps all findings onto a 2×2 grid (Effort x-axis: small→large; Priority y-axis: high at top). Dot colors match priority badges (red = high, amber = medium, green = low). Hover shows a tooltip with the finding title; clicking scrolls to the finding card.

### Trend badges

Findings with `trend === "persistent"` display a `⟳ Persistent` badge (purple pill) in finding cards and gap matrix rows — signaling that this complaint has remained unresolved across multiple review years.

### KPI strip

Six metrics in the hero: Sources, Findings, High Priority, Generated date, Competitive Score, and Quick Wins count.

**Competitive Score** = `round((missing high+medium count / total findings) × 100)` — higher means more opportunity.

## Multi-competitor source attribution

When analyzing two or more products, every source entry is prefixed with the product name:

```
"DBeaver/G2"    "DBeaver/Reddit"
"TablePlus/G2"  "TablePlus/GitHub"
```

This lets the Source filter show data from a single competitor even in a merged report.
