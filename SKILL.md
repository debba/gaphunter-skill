---
name: gaphunter
description: >
  Analyzes negative user reviews of a competing product (from G2, Capterra,
  TrustRadius, Reddit, and community sources), identifies missing or poorly
  implemented features, cross-references them against the current project's
  existing capabilities, and produces a single self-contained HTML report
  with a prioritized implementation plan. Trigger when the user asks to
  analyze competitor reviews, create a gap analysis from user reviews, or
  generate a feature gap report from user complaints. Usage: /gaphunter <ProductName>
---

# G2 Gap Report

You are a product intelligence analyst. Your job is to research what real users hate about a competing product, identify the feature gaps, and map them to a concrete implementation plan for the current project — all delivered as a single polished HTML report.

## Input

The user provides a product name as the argument (e.g., `/gaphunter DBeaver`). If no argument is given, ask the user for the product name before proceeding.

---

## Phase 1 — Research: collect negative reviews

Search across multiple sources in parallel. Use `WebSearch` and `WebFetch` to gather data.

### 1.1 Primary searches (run in parallel)

Run these searches simultaneously:

1. `<ProductName> G2 reviews negative "what do you dislike" missing features`
2. `<ProductName> Capterra reviews cons dislikes 2024 2025 2026`
3. `<ProductName> TrustRadius reviews cons missing features`
4. `<ProductName> site:reddit.com problems missing features wish list`
5. `<ProductName> GitHub issues feature request most requested`

### 1.2 Direct page fetches (run in parallel after searches)

Attempt to fetch these URLs with `WebFetch`. Many review sites return 403 — if a fetch fails, skip it gracefully and rely on search snippets:

- `https://www.g2.com/products/<product-slug>/reviews?qs=pros-and-cons`
- `https://www.capterra.com/p/<...>/<ProductName>/reviews/`
- `https://www.trustradius.com/products/<product-slug>/reviews/all`

### 1.3 What to extract

From every source, extract **only complaints and missing features**. Ignore praise. For each finding record:

- **What** is missing or broken (specific feature or behavior)
- **How often** it is cited (frequency signal: one mention vs. many)
- **Direct quotes** where available (use them verbatim in the report)
- **Source** (G2, Capterra, Reddit, GitHub, etc.)

Discard generic performance complaints ("it's slow") unless they point to a specific missing feature (e.g., "no query cancellation button so I have to kill the process").

---

## Phase 2 — Explore: understand the current project

Explore the current working directory to understand what the project already does. Run these in parallel:

1. Read `package.json` (or `Cargo.toml` / `pyproject.toml`) to identify the tech stack and dependencies.
2. List `src/` directory recursively (2–3 levels deep) to identify components, pages, and features.
3. Read any existing `README.md`, `CLAUDE.md`, or `docs/*.md` that describe the project's purpose and feature set.
4. Grep for keywords related to the most common complaints found in Phase 1 (e.g., if "collaboration" is a top complaint, grep for `collaboration`, `team`, `shared`, `sync`).

Build a concise mental model of: **what the project already does** vs **what it does not yet do**.

---

## Phase 3 — Synthesis: gap analysis

Cross-reference Phase 1 findings against Phase 2 understanding:

| Complaint / Missing Feature | Cited By | Already in Project? | Priority |
|---|---|---|---|
| (list each) | (sources) | ✅ Yes / ❌ No / ⚠️ Partial | High / Medium / Low |

**Priority scoring:**
- **High:** Cited by 3+ sources OR cited by 1 source with multiple upvotes/agreement, AND not in the project
- **Medium:** Cited by 1–2 sources, missing from project, feasible to implement
- **Low:** Rarely cited, already partially present, or extremely complex

---

## Phase 4 — Generate the HTML report

Write a single self-contained HTML file and save it as `docs/<productname>-gap-report.html` (lowercase, hyphenated). If `docs/` does not exist, save to the project root.

You must generate the report from the canonical template file:

`templates/gaphunter-report-template.html`

Use the template as a locked artifact. Copy the file exactly and replace only this placeholder:

`__REPORT_DATA_JSON__`

with a JSON object matching the schema below. Do not rewrite the HTML shell, CSS, layout, controls, JavaScript renderer, class names, section order, or print styles. If you need a new visual or interaction in the future, update the template file itself first; generated reports must not contain one-off layout changes.

Before writing the final report, verify that the template file exists and contains exactly one `__REPORT_DATA_JSON__` placeholder. If the template is unavailable, stop and report the problem instead of recreating the template from memory.

### Strict HTML template contract

The report must use the same rigid template every time. Only the JSON replacing `__REPORT_DATA_JSON__` may change between reports. Do not invent new section layouts, class names, visual systems, or custom one-off blocks for a specific product.

The HTML shell must always contain these top-level regions, in this order:

1. `<header class="hero" data-section="overview">`
2. `<aside class="filter-panel" aria-label="Report filters">`
3. `<main class="report-main">`
4. `<section id="executive-summary" data-section="summary">`
5. `<section id="negative-analysis" data-section="analysis">`
6. `<section id="gap-matrix" data-section="matrix">`
7. `<section id="implementation-plan" data-section="plan">`
8. `<section id="sources" data-section="sources">`
9. `<footer class="report-footer">`

### Required data schema

Build one JSON object with this exact shape and inject it into the template where `__REPORT_DATA_JSON__` appears:

```js
{
  meta: {
    productName: "",
    projectName: "",
    generatedAt: "",
    sourceCount: 0,
    findingCount: 0,
    highPriorityCount: 0,
    dataQualityNote: ""
  },
  summary: [
    { id: "", severity: "critical|warning|positive", title: "", text: "" }
  ],
  findings: [
    {
      id: "",
      theme: "",
      title: "",
      description: "",
      priority: "high|medium|low",
      status: "missing|partial|present",
      effort: "small|medium|large|none",
      frequency: "many|some|single",
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

If a value is unknown, use an empty array or a short explicit string such as `"Not identifiable from this project"`; never omit the key.

Serialize the object as JSON before injecting it. Escape `<` as `\u003c` in the serialized JSON so review text cannot accidentally close the inline `<script>` tag. The final generated HTML must not contain the `__REPORT_DATA_JSON__` placeholder.

### Mandatory filters and interactions

The template must always include a sticky filter panel with:

- Global text search over finding title, description, theme, sources, files, and implementation steps.
- Priority filter: All / High / Medium / Low.
- Status filter: All / Missing / Partial / Present.
- Effort filter: All / Small / Medium / Large.
- Source filter generated from the unique source names in `reportData.findings`.
- Theme filter generated from the unique theme names in `reportData.findings`.
- Toggle: "Implementation only" to show only missing or partial findings that have implementation steps.
- Reset filters button.
- Live result count.
- Export PDF button that calls `window.print()`.

Filtering must update the executive cards, analysis cards, matrix rows, and implementation plan cards consistently. Use inline JavaScript only; do not import libraries.

### HTML style requirements

The HTML must be fully self-contained: inline `<style>` and inline `<script>`, with no external CSS, JS, images, fonts, CDNs, or package dependencies.

Design direction: elegant but technical. The page should feel like a premium product intelligence console, not a plain document. Use a dark background, restrained glass surfaces, sharp typography, subtle grids, clear data density, and strong contrast. Keep cards at `8px` border radius or less.

Use these tokens exactly:

```css
:root {
  --bg: #080b12;
  --panel: #111827;
  --panel-2: #162033;
  --line: #2a3448;
  --text: #e5edf8;
  --muted: #94a3b8;
  --faint: #64748b;
  --accent: #38bdf8;
  --accent-2: #8b5cf6;
  --success: #22c55e;
  --warning: #f59e0b;
  --danger: #ef4444;
}
```

Mandatory visual elements:

- Priority badges: High = red, Medium = amber, Low = green.
- Source badges: compact inline labels.
- Status labels/icons in the gap matrix: present, missing, partial.
- Quote blocks with `border-left: 3px solid var(--accent)`.
- Section headers with an index number and subtle separator line.
- KPI strip in the hero with source count, finding count, high-priority count, and generation date.
- Empty state shown when filters return zero findings.
- Print stylesheet optimized for PDF export: white background, hidden filter panel, visible URL text for sources, preserved page breaks for implementation cards.
- Footer: copyright to `GapHunter`, the repository URL `https://github.com/debba/gaphunter-skill`, and the generation date.

### Rendering rules

- Render all repeated content from `reportData`; do not hard-code findings twice.
- Escape inserted text before writing into `innerHTML`.
- Keep all controls keyboard-accessible and labeled.
- Use semantic tables for the gap matrix.
- Do not fabricate quotes or sources. If a direct quote is unavailable, render the finding without a quote block.
- Keep the template stable even when data is sparse; show data-quality notes and empty arrays rather than changing the layout.

---

## Phase 5 — Report to the user

After saving the HTML file:

1. State the file path where the report was saved.
2. List the top 3 highest-priority features from the implementation plan in a brief markdown summary.
3. Note any sources that were inaccessible (403 errors) so the user knows where the data gaps are.

Do NOT reproduce the full HTML in the chat — it's already in the file. Keep the chat response under 200 words.

---

## Error handling

- If the product has no G2 page or very few reviews, fall back entirely to Reddit, GitHub issues, and community forums.
- If the current project has no `src/` or recognizable structure, skip Phase 2 and omit "Files to touch" from the plan cards.
- If fewer than 5 distinct complaints are found, state this clearly in the Executive Summary and note the limited data quality.
- Never fabricate quotes or invent reviews. If data is sparse, say so.
