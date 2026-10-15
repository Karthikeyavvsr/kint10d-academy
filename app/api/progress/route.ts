import { getChatGPTUser } from "../../chatgpt-auth";
import { env } from "cloudflare:workers";
export const dynamic = "force-dynamic";
const reply = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
export async function GET() {
  const user = await getChatGPTUser();
  if (!user) return reply({ error: "Sign in to sync progress." }, 401);
  if (!env.DB) return reply({ error: "Progress storage unavailable." }, 503);
  const { results } = await env.DB.prepare(
    "SELECT key,value,revision,updated FROM progress WHERE owner=?",
  )
    .bind(user.userId)
    .all();
  return reply({ records: results });
}
export async function PUT(request: Request) {
  const user = await getChatGPTUser();
  if (!user) return reply({ error: "Sign in to save progress." }, 401);
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin)
    return reply({ error: "Invalid origin." }, 403);
  if (!request.headers.get("content-type")?.startsWith("application/json"))
    return reply({ error: "JSON required." }, 415);
  const raw = await request.text();
  if (raw.length > 24000) return reply({ error: "Record too large." }, 413);
  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    return reply({ error: "Invalid JSON." }, 400);
  }
  const { key, value, revision } = body;
  if (
    typeof key !== "string" ||
    !/^(lesson|paper|resource|note|review|quiz|bookmark|setting|capstone):[a-zA-Z0-9_-]{1,100}$/.test(
      key,
    ) ||
    !Number.isSafeInteger(revision) ||
    revision < 0 ||
    typeof value !== "string" ||
    value.length > 20000
  )
    return reply({ error: "Invalid record." }, 400);
  const kind = key.split(":")[0];
  if (["review", "quiz", "bookmark"].includes(kind)) {
    try {
      const item = JSON.parse(value);
      if (!item || typeof item !== "object" || Array.isArray(item))
        throw Error();
      if (
        kind === "review" &&
        (typeof item.success !== "boolean" ||
          !Number.isFinite(item.due) ||
          !Number.isFinite(item.days))
      )
        throw Error();
      if (
        kind === "bookmark" &&
        (typeof item.lesson !== "string" ||
          !Number.isInteger(item.section) ||
          item.section < 0)
      )
        throw Error();
      if (
        kind === "quiz" &&
        (typeof item.correct !== "boolean" || !Number.isInteger(item.choice))
      )
        throw Error();
    } catch {
      return reply({ error: "Invalid structured progress." }, 400);
    }
  }
  if (kind === "setting" && !/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value))
    return reply({ error: "Invalid time." }, 400);
  if (!env.DB) return reply({ error: "Progress storage unavailable." }, 503);
  const now = new Date().toISOString();
  const result =
    revision === 0
      ? await env.DB.prepare(
          "INSERT OR IGNORE INTO progress(owner,key,value,revision,updated) VALUES(?,?,?,1,?)",
        )
          .bind(user.userId, key, value, now)
          .run()
      : await env.DB.prepare(
          "UPDATE progress SET value=?,revision=revision+1,updated=? WHERE owner=? AND key=? AND revision=?",
        )
          .bind(value, now, user.userId, key, revision)
          .run();
  if (result.meta.changes !== 1)
    return reply(
      {
        error:
          "Changed on another device. Export your unsaved draft, then reload cloud progress before editing.",
      },
      409,
    );
  return reply({ key, value, revision: revision + 1, updated: now });
}
