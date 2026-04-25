# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code skill that installs as `/gaphunter`. It researches negative user reviews of competing products, identifies feature gaps, and produces a paired HTML+JSON intelligence report. The skill logic lives in `SKILL.md`; the visual + interaction contract lives in `templates/gaphunter-report-template.html`.

**Architecture:** every report is two files in `docs/`:

- `<product>-gap-report.html` — a copy of the viewer template with the JSON **inlined** into a `<script type="application/json" id="report-data">` block, so it renders self-contained on a `file://` double-click without any server.
- `<product>-gap-data.json` — the same data as a sidecar file, kept for re-rendering, diffing, and external consumption.

The HTML's bootstrap reads `#report-data` first. If the placeholder is left unreplaced (no inline data), it falls back to deriving the sibling JSON path from its own filename (`-gap-report.html` → `-gap-data.json`) and `fetch`-ing it over HTTP, then to a drag-drop loader on `file://`. The template also recognises `?data=<path>` as an explicit override.

## Commands

```bash
bash install.sh    # Symlinks SKILL.md and templates/ into ~/.claude/skills/gaphunter/
bash uninstall.sh  # Removes ~/.claude/skills/gaphunter/
```

After `install.sh`, restart Claude Code for the skill to be picked up.

## Architecture

There are two source-of-truth files:

- **`SKILL.md`** — the skill definition (frontmatter + 5-phase execution instructions). This is what Claude reads when `/gaphunter` is invoked.
- **`templates/gaphunter-report-template.html`** — the shared report viewer (v3.0.0). It owns all HTML / CSS / JS, including the bootstrap that loads JSON via `?data=<path>` (HTTP) or via drag-drop / file picker (works on `file://`).

`install.sh` creates symlinks from `~/.claude/skills/gaphunter/` into this repo, so edits here are immediately reflected without reinstalling.

## Template contract (critical)

**Never rewrite the HTML shell.** All CSS, layout, controls, JavaScript renderer, class names, section order, and print styles are owned by `templates/gaphunter-report-template.html`. The only mutation allowed when copying the template per-report is replacing the single `__REPORT_DATA_JSON__` placeholder with the inlined JSON.

When generating a report:
1. Verify the template file exists and contains exactly one `__REPORT_DATA_JSON__` token. If not, stop and report the problem.
2. Build the JSON object matching the schema in `SKILL.md`.
3. Save it as `docs/<productname>-gap-data.json` (lowercase, hyphenated). If `docs/` does not exist, save to the project root.
4. Copy `templates/gaphunter-report-template.html` to `docs/<productname>-gap-report.html`, replacing the single `__REPORT_DATA_JSON__` placeholder with the JSON text. Apply `</` → `<\/` to the substituted JSON so it cannot prematurely close the surrounding `<script>` tag (`JSON.parse` accepts `\/`). Do not modify any other byte of the template.
5. Tell the user it's a single double-clickable HTML — no server needed.

If the placeholder is left unreplaced (e.g., during template debugging), the bootstrap falls back to fetching the sibling JSON over HTTP and then to the drag-drop loader on `file://`, so legacy two-file reports keep rendering.

To add new visuals or interactions, update the template itself, then re-run the skill so the per-report HTML copy is refreshed alongside.

## Skill execution phases

The skill runs five phases when invoked:

1. **Research** — parallel `WebSearch` + `WebFetch` across G2, Capterra, TrustRadius, Reddit, GitHub Issues, Hacker News (`hn.algolia.com` API is always accessible; review sites often 403). Semantically cluster near-duplicate complaints before recording findings.
2. **Explore** — build the project mental model with the **fewest possible file reads**. First check whether codebase-exploration tools are available in the session (GitNexus, RTK, or other MCP servers exposing repo-summary / semantic-search capabilities) and use them as the primary mechanism — one batched call per question (stack, features, complaint-keyword search) instead of walking files. Only fall back to the manual path (read `package.json`/`Cargo.toml`/`pyproject.toml`, list `src/`, read docs, grep for complaint keywords) when no such tool is available or the tool cannot answer a specific question. Record which path was used in `meta.exploration`.
3. **Synthesis** — cross-reference complaints against project capabilities; assign `priority` (high/medium/low), `status` (missing/partial/present), `effort` (small/medium/large/none), `trend` (persistent/recent/unknown), `frequency` (many/some/single). Compute `competitiveScore` and `quickWinCount`.
4. **Generate report** — write `docs/<productname>-gap-data.json` and copy the template verbatim to `docs/<productname>-gap-report.html`.
5. **Report** — state both file paths, explain how to open it (HTTP auto-loads, `file://` requires a drop), list the top 3 high-priority features, note any 403'd sources. Keep chat response under 200 words.

## Flags

| Flag | Behavior |
|------|----------|
| `/gaphunter Product1 Product2` | Multi-competitor: runs Phase 1 in parallel per product, merges findings; prefixes all source names with product name (`"DBeaver/G2"`). Activates the Competitor Comparison tab in the report. |
| `/gaphunter ProductName --sources-only` | Runs Phase 1 only; outputs raw findings as markdown in chat; no files are written |

The report UI is split into tabs: Summary, Quick Wins, Analysis, Comparison, Gap Matrix, Plan, Sources. The Comparison tab auto-detects competitors from source prefixes (split each `finding.sources[i]` on `/`) — keep the prefixing convention in multi-competitor mode or that tab will not populate.

## JSON schema (written as `<product>-gap-data.json`)

```js
{
  meta: {
    productName, projectName, generatedAt,
    sourceCount, findingCount, highPriorityCount,
    dataQualityNote,       // shown as warning banner if non-empty
    competitiveScore,      // 0–100 integer
    quickWinCount
  },
  summary: [{ id, severity: "critical|warning|positive", title, text }],
  findings: [{
    id, theme, title, description,
    priority: "high|medium|low",
    status: "missing|partial|present",
    effort: "small|medium|large|none",
    frequency: "many|some|single",
    trend: "persistent|recent|unknown",  // defaults to "unknown" if absent
    sources: [],
    quotes: [{ text, cite }],
    implementationSteps: [],
    filesToTouch: []
  }],
  sources: [{ name, type, url, access: "ok|blocked|snippet", note }]
}
```

`competitiveScore` = `round((missing high+medium findings / total findings) × 100)`. Quick Wins = findings where `priority === "high"` AND `effort === "small"`.
