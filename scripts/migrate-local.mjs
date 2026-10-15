import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
let config;
try {
  config = JSON.parse(readFileSync("dist/server/wrangler.json", "utf8"));
} catch {
  throw new Error("Run npm run build first to generate local configuration.");
}
config.main = resolve("dist/server", config.main);
if (config.assets)
  config.assets.directory = resolve("dist/server", config.assets.directory);
config.d1_databases = config.d1_databases.map((d) => ({
  ...d,
  migrations_dir: resolve("drizzle"),
}));
mkdirSync(".sites-runtime", { recursive: true });
writeFileSync(
  ".sites-runtime/local-migrations.json",
  JSON.stringify(config, null, 2),
);
const result = spawnSync(
  process.execPath,
  [
    "--import",
    "./scripts/sites-env.mjs",
    "./node_modules/wrangler/bin/wrangler.js",
    "d1",
    "migrations",
    "apply",
    "DB",
    "--local",
    "--config",
    ".sites-runtime/local-migrations.json",
    "--persist-to",
    ".wrangler/state",
  ],
  { stdio: "inherit" },
);
if (result.error) throw result.error;
process.exit(result.status ?? 1);
