# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code skill that installs as `/gaphunter`. It researches negative user reviews of competing products, identifies feature gaps, and produces a paired HTML+JSON intelligence report. The skill logic lives in `SKILL.md`; the visual + interaction contract lives in `templates/gaphunter-report-template.html`.

**Architecture:** every report is two files in `docs/`:

- `<product>-gap-report.html` — a verbatim copy of the viewer template (owns all HTML/CSS/JS).
- `<product>-gap-data.json` — the data only.

The HTML's bootstrap auto-derives the sibling JSON path from its own filename (`-gap-report.html` → `-gap-data.json`) and `fetch`-es it. Over HTTP this is zero-config; on `file://` the user drops the JSON onto the loader screen. The template recognises `?data=<path>` as an explicit override.

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

**Never rewrite the HTML shell, and never modify the per-report HTML copy.** All CSS, layout, controls, JavaScript renderer, class names, section order, and print styles are owned by `templates/gaphunter-report-template.html`.

When generating a report:
1. Verify the template file exists. If not, stop and report the problem.
2. Build the JSON object matching the schema in `SKILL.md`.
3. Save it as `docs/<productname>-gap-data.json` (lowercase, hyphenated). If `docs/` does not exist, save to the project root.
4. Copy `templates/gaphunter-report-template.html` **verbatim** to `docs/<productname>-gap-report.html`. Do not replace `__REPORT_DATA_JSON__` — the template's `typeof` guard treats the literal token as undefined and falls through to the JSON loader.
5. Tell the user how to view it (open the HTML; over HTTP it auto-loads the sibling JSON; on `file://` drop the JSON onto the loader).

The template still recognises a replaced `__REPORT_DATA_JSON__` placeholder via the `typeof` guard, so legacy single-file reports keep rendering — but new reports always use the HTML+JSON pair.

To add new visuals or interactions, update the template itself, then re-run the skill so the per-report HTML copy is refreshed alongside.

## Skill execution phases

The skill runs five phases when invoked:

1. **Research** — parallel `WebSearch` + `WebFetch` across G2, Capterra, TrustRadius, Reddit, GitHub Issues, Hacker News (`hn.algolia.com` API is always accessible; review sites often 403). Semantically cluster near-duplicate complaints before recording findings.
2. **Explore** — read `package.json`/`Cargo.toml`/`pyproject.toml`, list `src/`, read docs, grep for complaint keywords to understand what the current project already does.
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
