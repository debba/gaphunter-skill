---
name: gaphunter
description: >
  Analyzes negative user reviews of competing products (from G2, Capterra,
  TrustRadius, Reddit, Hacker News, and community sources), identifies missing
  or poorly implemented features, cross-references them against the current
  project's existing capabilities, and produces a JSON intelligence report
  rendered by a shared HTML viewer template. Supports single-product and
  multi-competitor analysis, semantic complaint clustering, trend signals,
  Quick Wins identification, and a Competitive Score. Trigger when the user
  asks to analyze competitor reviews, create a gap analysis from user reviews,
  or generate a feature gap report from user complaints.
  Usage: /gaphunter <ProductName> [ProductName2 ...] [--sources-only]
---

# G2 Gap Report

You are a product intelligence analyst. Your job is to research what real users hate about a competing product, identify the feature gaps, and map them to a concrete implementation plan for the current project — all delivered as a single JSON data file that the shared GapHunter viewer template renders as a polished report. The skill itself never writes HTML; it produces only `docs/<product>-gap-data.json`.

## Input

The user provides one or more product names and optional flags as arguments:

- **Single product:** `/gaphunter DBeaver` — standard analysis against one competitor.
- **Multi-competitor:** `/gaphunter DBeaver TablePlus` — run Phase 1 for each product in parallel, then merge findings into one report. Prefix every source name with the competitor product name (e.g., `"DBeaver/G2"`, `"TablePlus/Reddit"`) so source filters distinguish data origins.
- **Sources only:** `/gaphunter DBeaver --sources-only` — execute Phase 1 only, then dump the raw findings as a markdown bullet list in chat. Skip Phases 2, 3, 4, and 5. Do not write any files.

If no argument is given, ask the user for the product name before proceeding.

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
6. `<ProductName> site:news.ycombinator.com complaints missing features`

### 1.2 Direct page fetches (run in parallel after searches)

Attempt to fetch these URLs with `WebFetch`. Many review sites return 403 — if a fetch fails, skip it gracefully and rely on search snippets:

- `https://www.g2.com/products/<product-slug>/reviews?qs=pros-and-cons`
- `https://www.capterra.com/p/<...>/<ProductName>/reviews/`
- `https://www.trustradius.com/products/<product-slug>/reviews/all`
- `https://hn.algolia.com/api/v1/search?query=<ProductName>&tags=comment&numericFilters=points>2` — parse `hits[].comment_text` and `hits[].created_at`; cap at 30 hits. This API is always accessible (no 403).

### 1.3 What to extract

**Semantic clustering:** Before recording findings, group near-duplicate complaints into a single entry. Two complaints are near-duplicates if they describe the same absent capability (e.g., "no dark mode" and "lacks dark theme" → one finding). For merged entries, increment `frequency` and keep all distinct source attributions and quotes.

From every source, extract **only complaints and missing features**. Ignore praise. For each finding record:

- **What** is missing or broken (specific feature or behavior)
- **How often** it is cited (frequency signal: one mention vs. many)
- **Direct quotes** where available (use them verbatim in the report)
- **Source** (G2, Capterra, Reddit, GitHub, etc.)

Discard generic performance complaints ("it's slow") unless they point to a specific missing feature (e.g., "no query cancellation button so I have to kill the process").

---

## Phase 2 — Explore: understand the current project

The goal of Phase 2 is to build a mental model of **what the project already does** vs **what it does not yet do**, while reading as few raw files as possible. Loading whole source trees into context is the most expensive part of the skill, so always prefer aggregated, tool-mediated answers over manual file walking.

### 2.1 Prefer codebase-exploration tools (token-saving fast path)

Before doing any manual file read, check whether codebase-exploration tools are available in the current session — examples:

- **GitNexus** (MCP server): repo-wide summaries, semantic file search, feature mapping, dependency overview.
- **RTK** / repo-toolkit-style MCP or CLI: structured project overview, route/component listing, call-graph queries.
- Any other registered MCP server exposing `summarize_repo`, `search_code`, `list_features`, `describe_module` style tools.

If at least one such tool is available, **use it as the primary exploration mechanism** and skip the equivalent manual steps. The objective is to obtain the same mental model with far fewer tokens than a `Read` + `Grep` walk would consume:

| Manual step (expensive) | Replace with (when tool available) |
|---|---|
| List `src/` recursively, read each file | Tool's repo-overview / file-tree / module-summary call |
| Grep for complaint keywords across the tree | Tool's semantic-search call with the keyword bundle from Phase 1 |
| Read every `README.md` / `docs/*.md` | Tool's project-summary / documentation-summary call |
| Identify tech stack from raw `package.json` | Tool's dependency / stack-overview call |

Issue **one batched query per question** (stack, features, complaint-keyword search) rather than many narrow ones. Only fall back to manual reads (2.2) for gaps the tool cannot answer or when no exploration tool is registered.

Record which path was used in `meta.exploration` (free-form string, e.g., `"gitnexus"`, `"rtk"`, `"manual"`, or `"gitnexus + manual fallback"`) so the report documents how the analysis was conducted.

### 2.2 Manual fallback (only if no exploration tool is available)

Run these in parallel:

1. Read `package.json` (or `Cargo.toml` / `pyproject.toml`) to identify the tech stack and dependencies.
2. List `src/` directory recursively (2–3 levels deep) to identify components, pages, and features.
3. Read any existing `README.md`, `CLAUDE.md`, or `docs/*.md` that describe the project's purpose and feature set.
4. Grep for keywords related to the most common complaints found in Phase 1 (e.g., if "collaboration" is a top complaint, grep for `collaboration`, `team`, `shared`, `sync`).

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

**Trend signal** — After building the findings list, assign `trend` to each finding based on review publication dates:
- `"persistent"`: cited in reviews from at least two different calendar years
- `"recent"`: all citations are dated 2025 or 2026 only
- `"unknown"`: review dates are not available

**Quick Wins** — Count findings where `priority === "high"` AND `effort === "small"`. Record this count as `meta.quickWinCount`.

**Competitive Score** — Compute `Math.round((missingHighMediumCount / totalFindings) * 100)` where `missingHighMediumCount` is the count of findings with `status === "missing"` and `priority` in `["high", "medium"]`, and `totalFindings` is `reportData.findings.length`. Record as `meta.competitiveScore` (integer 0–100). If `totalFindings === 0`, set to `0`.

---

## Phase 4 — Generate the report files

Write **two paired files** into `docs/` (lowercase, hyphenated names). If `docs/` does not exist, save to the project root.

1. `docs/<productname>-gap-data.json` — the JSON data object matching the schema in the next section. Plain JSON, UTF-8, two-space indent. Do not escape `<` — this is a `.json` file, not embedded HTML.
2. `docs/<productname>-gap-report.html` — a copy of `templates/gaphunter-report-template.html` with the JSON **inlined** into the report so the HTML is fully self-contained and works on a `file://` double-click without any server.

### How to inline the JSON into the HTML

The template contains exactly one occurrence of the placeholder token `__REPORT_DATA_JSON__` inside a `<script type="application/json" id="report-data">` block (around the bottom of the file). Do not modify any other part of the template.

Replace that single token with the JSON text, applying these escapes **only to the text being substituted in** (do not modify the `.json` sidecar file):

- Replace every literal `</` with `<\/` so the JSON cannot prematurely close the surrounding `<script>` tag. `JSON.parse` accepts `\/` as an escaped `/`, so this is round-trip safe.
- No other escaping is required: the script block has `type="application/json"`, so the browser does not parse it as JS — only `</script>` (and similar end-tag sequences) can break out, and the `</` → `<\/` rule covers all of them.

The bootstrap reads `#report-data`, calls `JSON.parse` on its text content, and skips the loader entirely when inline data is present. So with the JSON inlined the HTML renders on double-click via `file://`, and the sidecar JSON is still useful for re-rendering or diffing.

If the placeholder is left unreplaced (e.g., during local template debugging), the bootstrap falls back to fetching the sibling JSON over HTTP, then to the drag-drop loader on `file://`.

Before writing, verify that the template file exists and contains exactly one occurrence of `__REPORT_DATA_JSON__`. If either check fails, stop and report the problem; do not recreate the template from memory.

### Strict template contract

The HTML shell, CSS, layout, controls, JavaScript renderer, class names, section order, print styles, and tab structure are owned exclusively by `templates/gaphunter-report-template.html`. Do not invent new section layouts, visual systems, or custom one-off blocks for a specific product, and do not modify the per-report HTML copy. If a new visual or interaction is needed, update the template itself and re-run the skill to refresh the HTML copy alongside.

The HTML shell must always contain these top-level regions, in this order:

1. `<header class="hero" data-section="overview">`
2. `<aside class="filter-panel" aria-label="Report filters">`
3. `<main class="report-main">`
4. `<nav class="tab-bar" id="tab-bar" role="tablist">` — section switcher
5. `<section id="executive-summary" data-section="summary" role="tabpanel">`
6. `<section id="quick-wins" data-section="quickwins" role="tabpanel" hidden>`
7. `<section id="negative-analysis" data-section="analysis" role="tabpanel" hidden>`
8. `<section id="competitor-comparison" data-section="comparison" role="tabpanel" hidden>`
9. `<section id="gap-matrix" data-section="matrix" role="tabpanel" hidden>`
10. `<section id="implementation-plan" data-section="plan" role="tabpanel" hidden>`
11. `<section id="sources" data-section="sources" role="tabpanel" hidden>`
12. `<footer class="report-footer">`

Only the section matching the active tab is visible at a time. The Comparison tab button is hidden by the renderer when fewer than two distinct competitors are detected (single-competitor reports). Print/PDF export reveals every section so the exported document contains the full report.

### Required data schema

Build one JSON object with this exact shape and write it as the entire contents of `docs/<productname>-gap-data.json`. The HTML report copy is independent of the schema — it always uses the template verbatim and reads whatever data the JSON contains.

```js
{
  meta: {
    productName: "",
    projectName: "",
    generatedAt: "",
    sourceCount: 0,
    findingCount: 0,
    highPriorityCount: 0,
    dataQualityNote: "",
    competitiveScore: 0,
    quickWinCount: 0,
    exploration: ""
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
      trend: "persistent|recent|unknown",
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

**Backward compatibility:** `trend` defaults to `"unknown"` in the template renderer if absent from the JSON. `competitiveScore` and `quickWinCount` are computed on-the-fly from `findings` if not present in `meta`. `meta.exploration` is optional and informational; the template ignores unknown meta fields, so adding it does not require template changes.

If a value is unknown, use an empty array or a short explicit string such as `"Not identifiable from this project"`; never omit the key.

Write the file as plain JSON (UTF-8, two-space indent). Do not wrap it in JS, and do not escape `<` — this is a `.json` data file, not embedded HTML.

### Mandatory filters and interactions

The template must always include a sticky filter panel with:

- Global text search over finding title, description, theme, sources, files, and implementation steps.
- Priority filter: All / High / Medium / Low.
- Status filter: All / Missing / Partial / Present.
- Effort filter: All / Small / Medium / Large.
- Source filter generated from the unique source names in `reportData.findings`.
- Theme filter generated from the unique theme names in `reportData.findings`.
- Trend filter: All / Persistent / Recent / Unknown.
- Toggle: "Implementation only" to show only missing or partial findings that have implementation steps.
- Reset filters button (also clears excluded competitors and leaves the active tab unchanged).
- Live result count.
- Export PDF button that un-hides every tabpanel, calls `window.print()`, and restores previous hidden state on `afterprint`.
- Permalink button: serializes current filter state, the active tab name, and the excluded-competitors list to base64 JSON, sets `location.hash`, and copies the full URL to clipboard.
- Export JSON button: downloads `reportData` as `<productname>-gap-data.json` via Blob.

Filtering must update the executive cards, analysis cards, matrix rows, and implementation plan cards consistently. Use inline JavaScript only; do not import libraries.

### HTML style requirements

These are constraints on the viewer template (already implemented there); the skill itself produces only JSON and does not touch styling.

The HTML must be fully self-contained: inline `<style>` and inline `<script>`, with no external CSS, JS, images, fonts, CDNs, or package dependencies. The viewer reads its data from an inline `<script type="application/json" id="report-data">` block. If that block is empty (placeholder unreplaced), it falls back to fetching the sibling JSON via `?data=<path>` or a drag-drop / file-picker loader screen.

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
- KPI strip in the hero with source count, finding count, high-priority count, generation date, Competitive Score (0–100), and Quick Wins count.
- SVG priority/effort quadrant in the hero: inline SVG with Effort on the x-axis (small→large) and Priority on the y-axis (high at top). Each finding is a colored dot; hover shows a tooltip; clicking scrolls to the finding card. Dots in the same cell are spread horizontally (jitter). When filters are active, dots excluded by the current filters are dimmed (opacity 0.22) rather than hidden, so the full distribution remains visible.
- Frequency badge: rendered in finding cards, Quick Win cards, and the Gap Matrix. `many` = cyan, `some` = slate, `single` = faint gray. Use CSS classes `badge freq-many`, `badge freq-some`, `badge freq-single`.
- Effort badges use CSS classes `badge effort-small`, `badge effort-medium`, `badge effort-large` (all slate/neutral) so they are visually distinct from priority badges (which use `badge high/medium/low`).
- Trend badges: `⟳ Persistent` (purple, `var(--accent-2)`) for `trend === "persistent"`; `▲ Recent` (cyan) for `trend === "recent"`. Shown in finding cards, Quick Win cards, and Gap Matrix rows. No badge rendered for `"unknown"`.
- Quick Wins section between Executive Summary and Negative Review Analysis: renders only findings where `priority === "high"` AND `effort === "small"` using a highlighted card grid.
- Tab bar above all sections (`.tab-bar`): seven tabs in this order — Summary, Quick Wins, Analysis, Comparison, Gap Matrix, Plan, Sources. Each tab carries a `data-tab` matching the corresponding section's `data-section`. Clicking a tab toggles `[hidden]` on sibling sections. The active tab uses `aria-selected="true"` and is highlighted with the cyan/violet accent gradient.
- Gap Matrix source toggles (`#matrix-controls`): pill row above the Gap Matrix table with one pill per unique source name in `reportData.findings`. Hidden automatically when the report has 0 or 1 unique sources. Each pill is checked by default; unchecking a pill is a matrix-scoped filter that (a) hides any row whose entire `sources` array consists of unchecked entries, and (b) drops the unchecked source's badges from the visible row's Sources cell. The exclusion set is persisted in the Permalink hash as `matrixExcludedSources` and cleared by Reset.
- Competitor Comparison section (`#competitor-comparison`): renders only when at least two distinct competitor names are detected from `finding.sources` (split each source on `/` and take the prefix; sources without a `/` contribute no competitor). Otherwise the tab button is hidden and the section shows an empty-state hint pointing the user at `/gaphunter Product1 Product2`. When active, it renders:
  - A toggle row with one pill per detected competitor (checkbox); unchecking excludes that competitor from columns and from the row filter.
  - A comparative table with columns: `Feature / Complaint`, `Theme`, `Priority`, one column per active competitor, `Shared`. Each competitor cell shows `✓ <count>` (count of sources from that competitor citing the finding) when the competitor mentions the gap, and `—` otherwise. The `Shared` column shows `N/Total` and renders a `★ All` badge in `var(--warning)` styling when every active competitor cites the gap (universal complaint).
  - Rows are filtered through the same global filter state (priority / status / effort / source / theme / trend / search / implementation-only) and additionally require at least one source from an active competitor. Sorted by descending shared-count so universal gaps surface first.
- Empty state shown when filters return zero findings.
- Print stylesheet optimized for PDF export: white background, hidden filter panel, hidden tab bar, hidden SVG quadrant and permalink/JSON export buttons, visible URL text for sources, preserved page breaks for implementation cards. The Export PDF button must un-hide every `[hidden]` tabpanel before invoking `window.print()` and restore previous hidden state on `afterprint`, so the printed PDF always contains every section.
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

After saving both files:

1. State the absolute paths of the two generated files (`docs/<productname>-gap-report.html` and `docs/<productname>-gap-data.json`).
2. Tell the user the HTML is self-contained: just double-click it (or open it via `file://`) and it renders immediately — no server needed. Mention that the sidecar JSON is kept for re-rendering or external use.
3. List the top 3 highest-priority features from the implementation plan in a brief markdown summary.
4. Note any sources that were inaccessible (403 errors) so the user knows where the data gaps are.

Do NOT reproduce the full JSON or HTML in the chat — they are already in the files. Keep the chat response under 200 words.

---

## Error handling

- If the product has no G2 page or very few reviews, fall back entirely to Reddit, GitHub issues, Hacker News, and community forums.
- If the current project has no `src/` or recognizable structure, skip Phase 2 and omit "Files to touch" from the plan cards.
- If fewer than 5 distinct complaints are found, state this clearly in the Executive Summary and note the limited data quality.
- Never fabricate quotes or invent reviews. If data is sparse, say so.
- If multi-competitor mode is used, prefix every source name with the competitor product name (`"DBeaver/G2"`, `"TablePlus/Reddit"`) so the source filter distinguishes data origins. Use a list of competitor names for `meta.productName` (e.g., `"DBeaver, TablePlus"`).
- If `--sources-only` is passed, terminate after Phase 1 and output a markdown list of raw findings. Do not write a JSON file.
