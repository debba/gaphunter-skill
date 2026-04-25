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

### HTML structure

The report must have these sections:

1. **Header** — product name, date, source count
2. **Executive Summary** — 3–5 bullet points: the most critical gaps
3. **Negative Review Analysis** — full breakdown of complaints grouped by theme, with direct user quotes and source badges
4. **Gap Matrix** — table of all findings with status (missing/partial/present) and priority
5. **Implementation Plan** — prioritized list of features to build, each with:
   - What to implement (specific behavior, not vague)
   - Which files/modules to touch in the current project
   - Estimated effort (Small / Medium / Large)
   - Suggested implementation approach (concrete steps)
6. **Sources** — list of all URLs and sources consulted

### HTML style requirements

The HTML must be **fully self-contained** (no external CSS or JS imports — everything inline). Design it as a dark, professional intelligence report. Use these constraints:

```
Background: #0f1117
Card background: #1a1d27
Accent color: #6366f1 (indigo)
Success: #22c55e
Warning: #f59e0b
Danger: #ef4444
Font stack: system-ui, -apple-system, sans-serif (no external font imports)
```

Use `<style>` in `<head>` for all CSS. No JavaScript required.

**Mandatory visual elements:**
- Priority badges: colored pill labels (High = red, Medium = amber, Low = green)
- Source badges: small inline labels showing "G2", "Capterra", "Reddit", etc.
- Status icons: ✅ ❌ ⚠️ in the gap matrix table
- A thin colored left border on quote blocks (use `border-left: 3px solid #6366f1`)
- Section headers with a subtle top border separator
- A "Generated by Claude Code" footer with the date

**Quote formatting:**
```html
<blockquote class="user-quote">
  "Direct quote from the user review here."
  <cite>— Username, Source (Date)</cite>
</blockquote>
```

**Implementation plan card formatting:**
Each feature gets a card with:
- Feature name as card title
- Priority badge (top right)
- Effort badge (Small / Medium / Large in muted color)
- "Missing from project" or "Partially implemented" label
- Bullet list of implementation steps
- "Files to touch" section (if identifiable from Phase 2)

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
