# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code skill that installs as `/gaphunter`. It researches negative user reviews of competing products, identifies feature gaps, and produces a self-contained HTML intelligence report. The skill logic lives in `SKILL.md`; the visual contract lives in `templates/gaphunter-report-template.html`.

## Commands

```bash
bash install.sh    # Symlinks SKILL.md and templates/ into ~/.claude/skills/gaphunter/
bash uninstall.sh  # Removes ~/.claude/skills/gaphunter/
```

After `install.sh`, restart Claude Code for the skill to be picked up.

## Architecture

There are two source-of-truth files:

- **`SKILL.md`** — the skill definition (frontmatter + 5-phase execution instructions). This is what Claude reads when `/gaphunter` is invoked.
- **`templates/gaphunter-report-template.html`** — the locked HTML report template (v2.0.0). Generated reports are produced by copying this file and replacing only the `__REPORT_DATA_JSON__` placeholder with a JSON object.

`install.sh` creates symlinks from `~/.claude/skills/gaphunter/` into this repo, so edits here are immediately reflected without reinstalling.

## Template contract (critical)

**Never rewrite the HTML shell.** The template's CSS, layout, controls, JavaScript renderer, class names, section order, and print styles are owned by `templates/gaphunter-report-template.html`. Generated reports may only differ in the injected JSON data.

When generating a report:
1. Verify the template file exists and contains exactly one `__REPORT_DATA_JSON__` placeholder.
2. Copy the template exactly.
3. Replace `__REPORT_DATA_JSON__` with the serialized JSON object.
4. Escape `<` as `<` in the JSON to prevent inline `<script>` tag injection.
5. Save as `docs/<productname>-gap-report.html` (lowercase, hyphenated). If `docs/` does not exist, save to the project root.

To add new visuals or interactions, update the template itself — never add one-off layout changes to a generated report.

## Skill execution phases

The skill runs five phases when invoked:

1. **Research** — parallel `WebSearch` + `WebFetch` across G2, Capterra, TrustRadius, Reddit, GitHub Issues, Hacker News (`hn.algolia.com` API is always accessible; review sites often 403). Semantically cluster near-duplicate complaints before recording findings.
2. **Explore** — read `package.json`/`Cargo.toml`/`pyproject.toml`, list `src/`, read docs, grep for complaint keywords to understand what the current project already does.
3. **Synthesis** — cross-reference complaints against project capabilities; assign `priority` (high/medium/low), `status` (missing/partial/present), `effort` (small/medium/large/none), `trend` (persistent/recent/unknown), `frequency` (many/some/single). Compute `competitiveScore` and `quickWinCount`.
4. **Generate report** — inject JSON into the template, write the HTML file.
5. **Report** — state the file path, list the top 3 high-priority features, note any 403'd sources. Keep chat response under 200 words.

## Flags

| Flag | Behavior |
|------|----------|
| `/gaphunter Product1 Product2` | Multi-competitor: runs Phase 1 in parallel per product, merges findings; prefixes all source names with product name (`"DBeaver/G2"`) |
| `/gaphunter ProductName --sources-only` | Runs Phase 1 only; outputs raw findings as markdown in chat; no HTML file written |

## JSON schema (injected into template)

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
