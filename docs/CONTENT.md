# Content editing

Author lessons in content-engineering.json, content-ai.json and content-quant.json. Paper guides live in the corresponding content-*-papers.json files.

Preserve stable lesson IDs because progress depends on them. Each lesson includes prerequisites, summary, sections, worked exercise, interview answer, four-option quiz and primary references.

Regenerate bundled JSON after edits:

~~~bash
node scripts/bundle-content.mjs
npm run test:content
~~~

Offline HTML/Markdown books are edition snapshots, not rebuilt by this command. Update them separately for a new edition.

Use original explanations, explicit assumptions and reproducible examples. Link papers instead of copying full copyrighted works. Disclose paywalls, abstract-only review and unverified claims. Verify changing market rules against authoritative sources.
