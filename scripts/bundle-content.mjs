import fs from "node:fs";
const read = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
fs.writeFileSync(
  "app/curriculum.json",
  JSON.stringify(
    ["engineering", "ai", "quant"].flatMap((n) =>
      read("content-" + n + ".json"),
    ),
    null,
    2,
  ) + "\n",
);
fs.writeFileSync(
  "app/papers.json",
  JSON.stringify(
    ["ai", "quant"].flatMap((n) => read("content-" + n + "-papers.json")),
    null,
    2,
  ) + "\n",
);
