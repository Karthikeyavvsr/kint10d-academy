import fs from "node:fs";
import assert from "node:assert/strict";
const read = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const lessons = read("app/curriculum.json"),
  papers = read("app/papers.json"),
  resources = read("app/resources.json");
const ids = new Set(lessons.map((x) => x.id));
assert.equal(ids.size, lessons.length);
assert.equal(new Set(papers.map((x) => x.id)).size, papers.length);
for (const l of lessons) {
  assert(l.sections.length >= 3, l.id);
  assert(
    l.sections.every((s) => s.title && s.body),
    l.id,
  );
  assert(
    l.exercise.prompt &&
      l.exercise.solution &&
      l.interview.question &&
      l.interview.answer,
    l.id,
  );
  assert.equal(l.quiz.options.length, 4);
  assert(
    Number.isInteger(l.quiz.correct) &&
      l.quiz.correct >= 0 &&
      l.quiz.correct < 4,
  );
  for (const id of l.prerequisites) assert(ids.has(id), id);
  for (const s of l.sources) assert.equal(new URL(s.url).protocol, "https:");
}
for (const p of papers) {
  assert.equal(new URL(p.url).protocol, "https:");
  assert(p.limits && p.exercise && p.readFor, p.id);
}
for (const r of resources) assert.equal(new URL(r.url).protocol, "https:");
assert.deepEqual(
  lessons,
  ["engineering", "ai", "quant"].flatMap((n) => read("content-" + n + ".json")),
);
assert.deepEqual(
  papers,
  ["ai", "quant"].flatMap((n) => read("content-" + n + "-papers.json")),
);
assert(
  !read(".openai/hosting.json").project_id,
  "Public source contains a personal deployment identity.",
);
console.log(
  JSON.stringify({
    lessons: lessons.length,
    papers: papers.length,
    resources: resources.length,
    valid: true,
  }),
);
