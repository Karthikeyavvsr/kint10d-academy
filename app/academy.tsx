"use client";
import { useEffect, useRef, useState } from "react";
import Labs from "./labs";
import curriculum from "./curriculum.json";
import papersData from "./papers.json";
import resourcesData from "./resources.json";
type Lesson = {
  id: string;
  track: string;
  title: string;
  level: string;
  minutes: number;
  prerequisites: string[];
  summary: string;
  sections: { title: string; body: string }[];
  exercise: { prompt: string; solution: string };
  interview: { question: string; answer: string };
  quiz: {
    question: string;
    options: string[];
    correct: number;
    explanation: string;
  };
  sources: { title: string; url: string }[];
  lab?: string;
};
type RecordValue = {
  key: string;
  value: string;
  revision: number;
  updated: string;
};
const lessons = curriculum as Lesson[];
const papers = papersData as {
  id: string;
  title: string;
  year: number | string;
  area: string;
  authors: string;
  url: string;
  why: string;
  prerequisites: string;
  readFor: string;
  limits: string;
  exercise: string;
}[];
const resources = resourcesData;
const tracks = [
  "All subjects",
  "Engineering & research",
  "AI & intelligence",
  "Quant & markets",
];
const nav = [
  "Today",
  "Curriculum",
  "Paper library",
  "Visual labs",
  "Interview room",
  "Resources",
  "My notebook",
  "Settings",
];
function download(name: string, body: string, type = "application/json") {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([body], { type }));
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}
export default function Academy({
  user,
}: {
  user: { id: string; name: string } | null;
}) {
  const [view, V] = useState("Today"),
    [selected, Select] = useState<string | null>(null),
    [search, Search] = useState(""),
    [track, Track] = useState("All subjects"),
    [records, Records] = useState<{ [key: string]: RecordValue }>({}),
    [status, Status] = useState("Connecting…"),
    [ready, Ready] = useState(false),
    [busy, Busy] = useState(false),
    [note, Note] = useState(""),
    [dirty, Dirty] = useState(false),
    [show, Show] = useState(false),
    [answer, Answer] = useState<number | null>(null),
    [menu, Menu] = useState(false),
    [time, Time] = useState(""),
    [date, DateStart] = useState(""),
    [interview, I] = useState(0),
    [lab, Lab] = useState("parameters"),
    [drafts, Drafts] = useState<Record<string, string>>({});
  const ref = useRef(records),
    draftRef = useRef(drafts),
    scrollTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const cacheKey = "k10-drafts-v2-" + (user?.id || "guest");
  const active = lessons.find((x) => x.id === selected);
  const get = (key: string, fallback = "") => records[key]?.value ?? fallback;
  const readCount = lessons.filter(
    (l) => get("lesson:" + l.id) === "read",
  ).length;
  const recalled = lessons.filter(
    (l) => get("review:" + l.id) && JSON.parse(get("review:" + l.id)).success,
  ).length;
  async function refresh() {
    try {
      const res = await fetch("/api/progress", { cache: "no-store" });
      const data = (await res.json()) as {
        error?: string;
        records: RecordValue[];
      };
      if (!res.ok) throw Error(data.error);
      const map = Object.fromEntries(
        data.records.map((r: RecordValue) => [r.key, r]),
      );
      ref.current = map;
      Records(map);
      Ready(true);
      Status("Cloud progress loaded");
      Time(map["setting:reminder"]?.value || "");
    } catch (e) {
      Status((e as Error).message);
      Ready(false);
    }
  }
  useEffect(() => {
    if (user) refresh();
    else {
      Status("Sign in to save across devices");
      Ready(false);
    }
    try {
      const d = JSON.parse(localStorage.getItem(cacheKey) || "{}");
      Drafts(d);
      draftRef.current = d;
    } catch {}
    DateStart(new Date().toLocaleDateString("en-CA"));
    if ("serviceWorker" in navigator)
      navigator.serviceWorker.register("/sw.js").catch(() => {});
  }, []);
  function stash(key: string, value: string | null) {
    const d = { ...draftRef.current };
    if (value === null) delete d[key];
    else d[key] = value;
    draftRef.current = d;
    Drafts(d);
    try {
      localStorage.setItem(cacheKey, JSON.stringify(d));
    } catch {}
  }
  async function save(key: string, value: string) {
    if (!ready || busy) {
      Status("Wait for sync, or sign in first.");
      return false;
    }
    Busy(true);
    stash(key, value);
    Status("Saving…");
    try {
      const res = await fetch("/api/progress", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          key,
          value,
          revision: ref.current[key]?.revision ?? 0,
        }),
      });
      const data = (await res.json()) as RecordValue & { error?: string };
      if (!res.ok) throw Error(data.error);
      ref.current = { ...ref.current, [key]: data };
      Records(ref.current);
      if (draftRef.current[key] === value) stash(key, null);
      Status("Saved to your account");
      return true;
    } catch (e) {
      Status((e as Error).message);
      return false;
    } finally {
      Busy(false);
    }
  }
  function change(v: string) {
    if (
      dirty &&
      !confirm(
        "Your note draft is saved on this device but not yet in the cloud. Leave the lesson?",
      )
    )
      return;
    V(v);
    Select(null);
    Menu(false);
    Show(false);
    Search("");
    Dirty(false);
    window.scrollTo(0, 0);
  }
  function open(id: string, bookmark = false) {
    if (dirty && !confirm("Leave with an unsaved note draft on this device?"))
      return;
    const l = lessons.find((x) => x.id === id);
    if (!l) return;
    Select(id);
    V("Curriculum");
    Menu(false);
    Note(
      draftRef.current["note:" + id] ?? ref.current["note:" + id]?.value ?? "",
    );
    Dirty(!!draftRef.current["note:" + id]);
    Answer(null);
    Show(false);
    window.scrollTo(0, 0);
    if (bookmark) {
      const b = ref.current["bookmark:last"]?.value;
      try {
        const item = JSON.parse(b || "{}");
        setTimeout(
          () =>
            document
              .getElementById("section-" + item.section)
              ?.scrollIntoView(),
          150,
        );
      } catch {}
    }
  }
  async function markOpened(kind: string, id: string) {
    if (!get(kind + ":" + id)) await save(kind + ":" + id, "opened");
  }
  function remember(success: boolean) {
    if (!active) return;
    const old = get("review:" + active.id);
    const previous = old ? JSON.parse(old) : {};
    const days = success ? Math.min(30, (previous.days || 1) * 2) : 1;
    save(
      "review:" + active.id,
      JSON.stringify({
        success,
        days,
        due: Date.now() + days * 86400000,
        at: Date.now(),
      }),
    );
  }
  const due = lessons.filter((l) => {
    try {
      return JSON.parse(get("review:" + l.id, "{}")).due <= Date.now();
    } catch {
      return false;
    }
  });
  function calendar() {
    if (!time || !date) return;
    const dt = date.replaceAll("-", "") + "T" + time.replace(":", "") + "00";
    const text = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//KINT10d//Academy//EN",
      "BEGIN:VEVENT",
      "UID:kint10d-study-" + Date.now() + "@academy",
      "DTSTAMP:" +
        new Date()
          .toISOString()
          .replaceAll("-", "")
          .replaceAll(":", "")
          .split(".")[0] +
        "Z",
      "DTSTART:" + dt,
      "DURATION:PT30M",
      "RRULE:FREQ=DAILY",
      "SUMMARY:KINT10d — learn and recall",
      "DESCRIPTION:Open your private Academy. Recall yesterday before reading today.",
      "URL:" + window.location.origin,
      "BEGIN:VALARM",
      "TRIGGER:PT0M",
      "ACTION:DISPLAY",
      "DESCRIPTION:Your study session",
      "END:VALARM",
      "END:VEVENT",
      "END:VCALENDAR",
      "",
    ].join("\r\n");
    download("KINT10d-study-reminder.ics", text, "text/calendar");
  }
  const match = (s: string) => s.toLowerCase().includes(search.toLowerCase());
  const filtered = lessons.filter(
    (l) =>
      (track === "All subjects" || l.track === track) &&
      match(
        l.title +
          " " +
          l.summary +
          " " +
          l.sections.map((s) => s.body).join(" "),
      ),
  );
  const currentInterview = lessons[interview % lessons.length];
  return (
    <div className="shell">
      <a className="skip" href="#main">
        Skip to learning
      </a>
      <aside className={menu ? "sidebar open" : "sidebar"}>
        <a href="/" className="brand">
          <span className="monogram">K10</span>
          <span>
            ACADEMY<small>THE RESEARCHER’S WORKBENCH</small>
          </span>
        </a>
        <p className="eyebrow">YOUR LEARNING SPACE</p>
        <nav>
          {nav.map((n, i) => (
            <button
              key={n}
              className={view === n ? "current" : ""}
              onClick={() => change(n)}
            >
              <span className="nav-icon" aria-hidden="true">
                {["◷", "▤", "▧", "◈", "◇", "↗", "▥", "⚙"][i]}
              </span>
              {n}
            </button>
          ))}
        </nav>
        <div className="side-bottom">
          <div className="mini-progress">
            <span style={{ width: (readCount / lessons.length) * 100 + "%" }} />
          </div>
          <p>
            {readCount} / {lessons.length} lessons read
          </p>
          <small>Understanding grows through practice.</small>
          <a href="/foundation-book.html" target="_blank" rel="noreferrer">
            Open the original field guide ↗
          </a>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <button
            className="mobile-toggle"
            aria-label="Toggle navigation"
            onClick={() => Menu(!menu)}
          >
            ☰
          </button>
          <span>
            LEARN <i>/</i> BUILD <i>/</i> EXPLAIN
          </span>
          <div className="sync" role="status">
            <span className={ready ? "dot" : "dot amber"} />
            {status}
          </div>
        </header>
        <main id="main">
          {!user && (
            <div className="callout">
              Your reading stays private.{" "}
              <a href="/signin-with-chatgpt?return_to=/" target="_top">
                Sign in with ChatGPT
              </a>{" "}
              to save notes and resume across devices.
            </div>
          )}
          {Object.keys(drafts).length > 0 && (
            <div className="draft-alert">
              <strong>
                {Object.keys(drafts).length} device draft(s) not yet synced.
              </strong>
              <p>
                Export drafts before reloading cloud progress if another device
                changed the same record. Notes are also retained locally as you
                type.
              </p>
              <button
                onClick={() =>
                  download(
                    "academy-unsaved-drafts.json",
                    JSON.stringify(drafts, null, 2),
                  )
                }
              >
                Export drafts
              </button>{" "}
              <button disabled={busy} onClick={refresh}>
                Reload cloud progress
              </button>
              <details>
                <summary>Recover individual drafts</summary>
                {Object.entries(drafts).map(([key, value]) => (
                  <div key={key}>
                    <code>{key}</code>{" "}
                    <button
                      disabled={busy || !ready}
                      onClick={() => save(key, value)}
                    >
                      Save this draft over loaded cloud version
                    </button>
                    <button
                      onClick={() => {
                        if (
                          confirm(
                            "Discard this device draft? Cloud data is unchanged.",
                          )
                        )
                          stash(key, null);
                      }}
                    >
                      Discard draft
                    </button>
                  </div>
                ))}
              </details>
            </div>
          )}
          {view === "Today" && (
            <>
              <div className="page-title">
                <div>
                  <p className="eyebrow">A PERSONAL SCHOOL FOR BUILDERS</p>
                  <h1>
                    Build understanding.
                    <br />
                    <em>Then build the system.</em>
                  </h1>
                  <p className="lede">
                    From first principles to defensible decisions.
                    <br />
                    Engineering, intelligence, and markets—connected.
                  </p>
                </div>
                <div className="orbital" aria-hidden="true">
                  <div />
                  <div />
                  <div />
                  <span>
                    KNOW
                    <br />
                    WHY.
                  </span>
                </div>
              </div>
              <section className="continue-card">
                <div>
                  <p className="eyebrow">YOUR NEXT STUDY SESSION</p>
                  <h2>
                    {(() => {
                      try {
                        const b = JSON.parse(get("bookmark:last", "{}"));
                        return (
                          lessons.find((l) => l.id === b.lesson)?.title ||
                          lessons.find((l) => get("lesson:" + l.id) !== "read")
                            ?.title ||
                          "Return to deliberate practice"
                        );
                      } catch {
                        return "Begin with the foundations";
                      }
                    })()}
                  </h2>
                  <p>
                    Read the mechanism. Work the example. Explain it without
                    notes.
                  </p>
                  <button
                    className="primary"
                    onClick={() => {
                      try {
                        const b = JSON.parse(get("bookmark:last", "{}"));
                        open(
                          b.lesson ||
                            lessons.find(
                              (l) => get("lesson:" + l.id) !== "read",
                            )?.id ||
                            lessons[0].id,
                          !!b.lesson,
                        );
                      } catch {
                        open(lessons[0].id);
                      }
                    }}
                  >
                    Continue learning <span>→</span>
                  </button>
                </div>
                <div className="session-plan">
                  <span>
                    01 <b>Recall yesterday</b>
                  </span>
                  <span>
                    02 <b>Study one mechanism</b>
                  </span>
                  <span>
                    03 <b>Solve, explain, review</b>
                  </span>
                </div>
              </section>
              <div className="stats">
                <article>
                  <strong>{lessons.length}</strong>
                  <span>Deep-dive lessons</span>
                </article>
                <article>
                  <strong>{papers.length}</strong>
                  <span>Guided research papers</span>
                </article>
                <article>
                  <strong>{recalled}</strong>
                  <span>Self-reported recall passes</span>
                </article>
                <article>
                  <strong>{due.length}</strong>
                  <span>Reviews due</span>
                </article>
              </div>
              <div className="section-heading">
                <h2>Three disciplines. One practice.</h2>
                <button onClick={() => change("Curriculum")}>
                  Explore the curriculum →
                </button>
              </div>
              <div className="track-grid">
                {tracks.slice(1).map((t, i) => (
                  <button
                    className="track-card"
                    key={t}
                    onClick={() => {
                      change("Curriculum");
                      Track(t);
                    }}
                  >
                    <span className="track-number">0{i + 1}</span>
                    <h3>{t}</h3>
                    <p>
                      {
                        [
                          "Make correct, recoverable software. Understand the data beneath it.",
                          "From gradients and parameters to language models and agent evaluation.",
                          "Reason about uncertainty, market mechanisms and evidence of an edge.",
                        ][i]
                      }
                    </p>
                    <span>
                      {lessons.filter((l) => l.track === t).length} lessons{" "}
                      <b>↗</b>
                    </span>
                  </button>
                ))}
              </div>
              <section className="callout">
                <h3>The standard is evidence, not a completion badge.</h3>
                <p>
                  This is a structured study companion, not an exhaustive degree
                  or a guarantee of interview readiness. Finish the linked
                  courses and projects, reproduce results, and ask another
                  person to challenge your explanations. Clicking a paper is not
                  the same as reading it; passing one quiz is not mastery.
                </p>
              </section>
              <div className="two-col">
                <section className="panel">
                  <h2>Review queue</h2>
                  {due.length ? (
                    due.map((l) => (
                      <button
                        className="list-link"
                        key={l.id}
                        onClick={() => open(l.id)}
                      >
                        {l.title} →
                      </button>
                    ))
                  ) : (
                    <p>
                      After a lesson, rate your recall. Reviews are spaced at 1
                      day after a miss and 2, 4, 8… days after successful
                      recall, capped at 30.
                    </p>
                  )}
                </section>
                <section className="panel">
                  <h2>A practical learning rhythm</h2>
                  <p>
                    Start with 30–60 minutes. Spend about half on reading, the
                    rest on retrieval and implementation. Every fifth session,
                    revisit old problems rather than add new topics.
                  </p>
                  <button onClick={() => change("Settings")}>
                    Choose reminders later—or now →
                  </button>
                </section>
              </div>
            </>
          )}
          {view === "Curriculum" && !active && (
            <>
              <p className="eyebrow">
                FOUNDATIONS → MECHANISMS → PRACTICE → FRONTIER
              </p>
              <h1>The curriculum</h1>
              <p className="lede">
                A layered path. The original field guide remains your broad map;
                these lessons go inside the machinery.
              </p>
              <div className="filters">
                <input
                  aria-label="Search lessons"
                  placeholder="Search concepts, equations, failure modes…"
                  value={search}
                  onChange={(e) => Search(e.target.value)}
                />
                <select
                  aria-label="Choose subject"
                  value={track}
                  onChange={(e) => Track(e.target.value)}
                >
                  {tracks.map((t) => (
                    <option key={t}>{t}</option>
                  ))}
                </select>
              </div>
              <p className="muted">
                {filtered.length} lessons · Time estimates cover reading;
                exercises and linked courses take longer.
              </p>
              <div className="lesson-grid">
                {filtered.map((l, i) => (
                  <button
                    className="lesson-card"
                    key={l.id}
                    onClick={() => open(l.id)}
                  >
                    <div>
                      <span className="tag">{l.level}</span>
                      <span className="muted">{l.minutes} min</span>
                    </div>
                    <small>{l.track}</small>
                    <h2>{l.title}</h2>
                    <p>{l.summary}</p>
                    <footer>
                      <span>
                        {get("lesson:" + l.id) === "read"
                          ? "✓ Read"
                          : "Start lesson"}
                      </span>
                      <span>↗</span>
                    </footer>
                  </button>
                ))}
              </div>
              <Capstones get={get} save={save} disabled={!ready || busy} />
            </>
          )}
          {active && (
            <>
              <button className="back" onClick={() => change("Curriculum")}>
                ← All lessons
              </button>
              <div className="reader-heading">
                <p className="eyebrow">
                  {active.track} / {active.level}
                </p>
                <h1>{active.title}</h1>
                <p className="lede">{active.summary}</p>
                <div className="chips">
                  <span className="tag">{active.minutes} min reading</span>
                  <button
                    disabled={!ready || busy}
                    onClick={() =>
                      save(
                        "lesson:" + active.id,
                        get("lesson:" + active.id) === "read"
                          ? "reading"
                          : "read",
                      )
                    }
                  >
                    {get("lesson:" + active.id) === "read"
                      ? "✓ Marked read"
                      : "Mark as read"}
                  </button>
                  <button onClick={() => window.print()}>Print lesson</button>
                </div>
              </div>
              <div className="reader-layout">
                <aside className="contents">
                  <p className="eyebrow">IN THIS LESSON</p>
                  {active.sections.map((s, i) => (
                    <a href={"#section-" + i} key={i}>
                      {String(i + 1).padStart(2, "0")} {s.title}
                    </a>
                  ))}
                  <a href="#practice">Practice & recall</a>
                  <a href="#notes">Your notes</a>
                </aside>
                <article className="reader">
                  {active.prerequisites?.length > 0 && (
                    <div className="callout">
                      <b>Before you begin</b>
                      <p>
                        {active.prerequisites
                          .map(
                            (id) =>
                              lessons.find((l) => l.id === id)?.title || id,
                          )
                          .join(" · ")}
                      </p>
                    </div>
                  )}
                  {active.sections.map((s, i) => (
                    <section id={"section-" + i} key={i}>
                      <div className="section-heading">
                        <h2>{s.title}</h2>
                        <button
                          className="bookmark"
                          aria-label={"Bookmark " + s.title}
                          disabled={!ready || busy}
                          onClick={() =>
                            save(
                              "bookmark:last",
                              JSON.stringify({ lesson: active.id, section: i }),
                            )
                          }
                        >
                          ⌑ Save place
                        </button>
                      </div>
                      {s.body.split(/\n\s*\n/).map((p, j) => (
                        <p key={j}>{p}</p>
                      ))}
                    </section>
                  ))}
                  {active.lab && (
                    <div className="panel">
                      <p className="eyebrow">TRY THE IDEA</p>
                      <button
                        onClick={() => {
                          Lab(active.lab!);
                          change("Visual labs");
                        }}
                      >
                        Open the {active.lab} visual lab →
                      </button>
                    </div>
                  )}
                  <section id="practice">
                    <p className="eyebrow">DO THE WORK</p>
                    <h2>Apply it before reading the answer</h2>
                    <p>{active.exercise.prompt}</p>
                    <details>
                      <summary>Worked solution / checking rubric</summary>
                      <p>{active.exercise.solution}</p>
                    </details>
                    <h3>Explain it in an interview</h3>
                    <p>{active.interview.question}</p>
                    <details>
                      <summary>Compare with a strong answer</summary>
                      <p>{active.interview.answer}</p>
                    </details>
                    <h3>Check one key idea</h3>
                    <p>{active.quiz.question}</p>
                    <div className="quiz-options">
                      {active.quiz.options.map((o, i) => (
                        <button
                          key={o}
                          className={answer === i ? "selected" : ""}
                          onClick={() => {
                            Answer(i);
                            if (ready && !busy)
                              save(
                                "quiz:" + active.id,
                                JSON.stringify({
                                  correct: i === active.quiz.correct,
                                  choice: i,
                                  at: Date.now(),
                                }),
                              );
                          }}
                        >
                          {String.fromCharCode(65 + i)}. {o}
                        </button>
                      ))}
                    </div>
                    {answer !== null && (
                      <div className="callout">
                        <b>
                          {answer === active.quiz.correct
                            ? "Correct."
                            : "Revisit the reasoning."}
                        </b>
                        <p>{active.quiz.explanation}</p>
                        <small>
                          A single multiple-choice result is a check, not
                          certification.
                        </small>
                      </div>
                    )}
                    <h3>Could you explain this without looking?</h3>
                    <p>
                      Close the answers first. Give a two-minute explanation and
                      solve a fresh example.
                    </p>
                    <div className="chips">
                      <button
                        disabled={!ready || busy}
                        onClick={() => remember(false)}
                      >
                        Not yet · review tomorrow
                      </button>
                      <button
                        disabled={!ready || busy}
                        onClick={() => remember(true)}
                      >
                        Yes · schedule spaced review
                      </button>
                    </div>
                  </section>
                  <section id="notes">
                    <h2>Your working notes</h2>
                    <p className="muted">
                      Write an explanation, a question, or a failure case.
                      Device drafts save while you type; use Save for
                      cross-device sync.
                    </p>
                    <textarea
                      disabled={busy}
                      aria-label="Lesson notes"
                      maxLength={18000}
                      value={note}
                      onChange={(e) => {
                        Note(e.target.value);
                        Dirty(true);
                        stash("note:" + active.id, e.target.value);
                      }}
                      placeholder="What could I explain or implement now?"
                    />
                    <button
                      className="primary"
                      disabled={!ready || busy}
                      onClick={async () => {
                        if (await save("note:" + active.id, note)) Dirty(false);
                      }}
                    >
                      Save notes to account
                    </button>
                  </section>
                  <section>
                    <h2>Go deeper at the source</h2>
                    {active.sources.map((s) => (
                      <a
                        className="source-link"
                        href={s.url}
                        key={s.url}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {s.title} ↗
                      </a>
                    ))}
                    <p className="muted">
                      These are further study references. Lessons are original
                      synthesis; research-paper guides distinguish
                      abstract-level orientation from full reproduction.
                    </p>
                  </section>
                </article>
              </div>
            </>
          )}
          {view === "Visual labs" && (
            <>
              <p className="eyebrow">CHANGE A PARAMETER. PREDICT. OBSERVE.</p>
              <h1>Make the idea visible.</h1>
              <p className="lede">
                Small models of important mechanisms, with their assumptions
                made explicit.
              </p>
              <Labs key={lab} initial={lab} />
              <p className="muted">
                The labs are deterministic teaching examples—not trained trading
                systems or backtests.
              </p>
            </>
          )}
          {view === "Paper library" && (
            <>
              <p className="eyebrow">READ WITH A QUESTION IN MIND</p>
              <h1>The paper shelf</h1>
              <p className="lede">
                Foundational and influential work in AI, intelligence and
                quantitative finance. A guide to investigation—not an
                endorsement of every claim.
              </p>
              <input
                className="wide-search"
                aria-label="Search papers"
                placeholder="Search title, area, or author…"
                value={search}
                onChange={(e) => Search(e.target.value)}
              />
              <div className="paper-list">
                {papers
                  .filter((p) =>
                    match(p.title + " " + p.area + " " + p.authors),
                  )
                  .map((p) => (
                    <article className="paper" key={p.id}>
                      <div className="paper-year">
                        {p.year}
                        <span>{p.area}</span>
                      </div>
                      <div>
                        <h2>
                          <a
                            href={p.url}
                            target="_blank"
                            rel="noreferrer"
                            onClick={() => markOpened("paper", p.id)}
                          >
                            {p.title} ↗
                          </a>
                        </h2>
                        <p className="muted">{p.authors}</p>
                        <p>{p.why}</p>
                        <details>
                          <summary>
                            Reading guide & reproduction question
                          </summary>
                          <p>
                            <b>Prerequisites:</b> {p.prerequisites}
                          </p>
                          <p>
                            <b>Read for:</b> {p.readFor}
                          </p>
                          <p>
                            <b>Limits:</b> {p.limits}
                          </p>
                          <p>
                            <b>Try:</b> {p.exercise}
                          </p>
                        </details>
                        <div className="chips">
                          <span className="tag">
                            {get("paper:" + p.id, "Not opened")}
                          </span>
                          <button
                            disabled={!ready || busy}
                            onClick={() =>
                              save(
                                "paper:" + p.id,
                                get("paper:" + p.id) === "read"
                                  ? "opened"
                                  : "read",
                              )
                            }
                          >
                            {get("paper:" + p.id) === "read"
                              ? "Undo read"
                              : "I finished reading"}
                          </button>
                        </div>
                      </div>
                    </article>
                  ))}
              </div>
            </>
          )}
          {view === "Resources" && (
            <>
              <p className="eyebrow">
                COURSES · VIDEOS · BOOKS · DOCUMENTATION
              </p>
              <h1>Go to the source.</h1>
              <div className="chips">
                <a href="/KINT10d-Deep-Study-Book.html" download>
                  Download offline study book ↓
                </a>
                <a href="/KINT10d-Deep-Study-Book.md" download>
                  Download Markdown ↓
                </a>
              </div>
              <p className="lede">
                The original curated resource collection, now with separate
                opened and read states. Course progress and certificates remain
                with their providers.
              </p>
              <input
                className="wide-search"
                aria-label="Search resources"
                placeholder="Search Python, videos, statistics…"
                value={search}
                onChange={(e) => Search(e.target.value)}
              />
              <div className="lesson-grid">
                {resources
                  .filter((r) =>
                    match(r.title + " " + r.format + " " + r.study_focus),
                  )
                  .map((r) => (
                    <article className="resource-card" key={r.id}>
                      <small>
                        {r.format} · {r.level}
                      </small>
                      <h2>
                        <a
                          href={r.url}
                          target="_blank"
                          rel="noreferrer"
                          onClick={() => markOpened("resource", r.id)}
                        >
                          {r.title} ↗
                        </a>
                      </h2>
                      <p>{r.study_focus}</p>
                      <p className="muted">
                        {r.access} · Link review: {r.verification}, 15 Oct 2026
                      </p>
                      <div className="chips">
                        <span>{get("resource:" + r.id, "Not opened")}</span>
                        <button
                          disabled={!ready || busy}
                          onClick={() =>
                            save(
                              "resource:" + r.id,
                              get("resource:" + r.id) === "read"
                                ? "opened"
                                : "read",
                            )
                          }
                        >
                          {" "}
                          {get("resource:" + r.id) === "read"
                            ? "Undo read"
                            : "Mark read"}
                        </button>
                      </div>
                    </article>
                  ))}
              </div>
            </>
          )}
          {view === "Interview room" && currentInterview && (
            <>
              <p className="eyebrow">RECALL BEFORE RECOGNITION</p>
              <h1>Explain your thinking.</h1>
              <p className="lede">
                Say the answer aloud. State assumptions, derive the mechanism,
                give an example, and name a failure mode.
              </p>
              <div className="interview-card">
                <span className="tag">
                  {currentInterview.track} · {(interview % lessons.length) + 1}{" "}
                  / {lessons.length}
                </span>
                <h2>{currentInterview.interview.question}</h2>
                <button onClick={() => Show(!show)}>
                  {show ? "Hide model answer" : "Reveal a strong answer"}
                </button>
                {show && (
                  <p className="answer">{currentInterview.interview.answer}</p>
                )}
                <div className="chips">
                  <button
                    onClick={() => {
                      I(Math.max(0, interview - 1));
                      Show(false);
                    }}
                  >
                    ← Previous
                  </button>
                  <button
                    onClick={() => {
                      I(interview + 1);
                      Show(false);
                    }}
                  >
                    Next question →
                  </button>
                  <button onClick={() => open(currentInterview.id)}>
                    Study this topic
                  </button>
                </div>
              </div>
              <div className="panel">
                <h3>A self-assessment rubric</h3>
                <p>
                  0: cannot explain. 1: recognizes vocabulary. 2: explains
                  mechanism. 3: derives and implements it. 4: diagnoses a new
                  failure and defends tradeoffs. Ask a reviewer to score an
                  unseen problem; self-ratings are not independent verification.
                </p>
              </div>
            </>
          )}
          {view === "My notebook" && (
            <>
              <p className="eyebrow">YOUR EXPLANATIONS, NOT JUST HIGHLIGHTS</p>
              <h1>A record of understanding.</h1>
              <button
                onClick={() =>
                  download(
                    "kint10d-learning-progress.json",
                    JSON.stringify(
                      { exported: new Date().toISOString(), records, drafts },
                      null,
                      2,
                    ),
                  )
                }
              >
                Export progress & notes
              </button>
              <div className="notebook">
                {lessons
                  .filter((l) => get("note:" + l.id))
                  .map((l) => (
                    <section className="panel" key={l.id}>
                      <h2>
                        <button onClick={() => open(l.id)}>{l.title} →</button>
                      </h2>
                      <p className="note-body">{get("note:" + l.id)}</p>
                    </section>
                  ))}
              </div>
              {!lessons.some((l) => get("note:" + l.id)) && (
                <p className="empty">
                  No cloud-saved notes yet. Open any lesson to write your first
                  explanation.
                </p>
              )}
            </>
          )}
          {view === "Settings" && (
            <>
              <p className="eyebrow">MAKE STUDYING SUSTAINABLE</p>
              <h1>Your learning routine.</h1>
              <div className="two-col">
                <section className="panel">
                  <h2>Daily calendar reminder</h2>
                  <p>
                    Choose a time whenever you are ready. Save the preference,
                    then import a recurring event into your calendar. Calendar
                    alerts can reach your iPhone, iPad and Mac if that calendar
                    syncs across them.
                  </p>
                  <label>
                    Local time
                    <input
                      aria-label="Reminder time"
                      type="time"
                      value={time}
                      onChange={(e) => Time(e.target.value)}
                    />
                  </label>
                  <label>
                    First day
                    <input
                      aria-label="Reminder start date"
                      type="date"
                      value={date}
                      onChange={(e) => DateStart(e.target.value)}
                    />
                  </label>
                  <div className="chips">
                    <button
                      disabled={!time || !ready || busy}
                      onClick={() => save("setting:reminder", time)}
                    >
                      Save preferred time
                    </button>
                    <button disabled={!time || !date} onClick={calendar}>
                      Download calendar reminder
                    </button>
                  </div>
                  <p className="muted">
                    Nothing is scheduled merely by saving the time. Import the
                    file, verify the event timezone and alert on your device.
                    The event follows your calendar’s local-time interpretation.
                    Reimporting can create duplicates; edit or delete the
                    existing calendar event instead.
                  </p>
                  <div className="callout">
                    <b>Background app push: not configured.</b>
                    <p>
                      This release uses calendar alerts. No permission request
                      or push-delivery claim is made. A future push service
                      needs a sender, scheduler, permission and device testing.
                    </p>
                  </div>
                </section>
                <section className="panel">
                  <h2>Use it across devices</h2>
                  <ol>
                    <li>
                      Open the private site URL on each device and sign in with
                      the same account.
                    </li>
                    <li>
                      On iPhone or iPad, use Safari’s Share menu → Add to Home
                      Screen; choose “Open as Web App” if offered.
                    </li>
                    <li>
                      On Mac, bookmark the site or add it to the Dock in a
                      supporting Safari version.
                    </li>
                    <li>
                      Use “Save place” inside a lesson. On another device, load
                      cloud progress and choose Continue learning.
                    </li>
                  </ol>
                  <p>
                    Reading and sync require a connection. This release does not
                    cache private pages for offline reading. Unsaved note drafts
                    remain in this browser; export them before clearing browser
                    data.
                  </p>
                  <button disabled={busy} onClick={refresh}>
                    Load latest cloud progress
                  </button>
                </section>
                <section className="panel">
                  <h2>Privacy and portability</h2>
                  <p>
                    Progress is scoped to your signed-in account. This app has
                    no broker connection, trading keys, order placement, or paid
                    AI calls. This learning app is isolated from trading
                    systems.
                  </p>
                  <button
                    onClick={() =>
                      download(
                        "kint10d-learning-progress.json",
                        JSON.stringify(
                          {
                            exported: new Date().toISOString(),
                            records,
                            drafts,
                          },
                          null,
                          2,
                        ),
                      )
                    }
                  >
                    Export my learning data
                  </button>
                  <p className="muted">
                    Export is a readable backup. Automatic import is not
                    included in this release.
                  </p>
                </section>
                <section className="panel">
                  <h2>How to use the book deeply</h2>
                  <ol>
                    <li>Read foundations without skipping notation.</li>
                    <li>Derive an equation on paper.</li>
                    <li>Implement the smallest example.</li>
                    <li>Break it intentionally and explain the failure.</li>
                    <li>Read the primary source and record discrepancies.</li>
                    <li>Teach it, then revisit after a delay.</li>
                  </ol>
                  <p>
                    No course covers every inch of these fields. The goal is
                    durable foundations and a repeatable way to go deeper.
                  </p>
                </section>
              </div>
            </>
          )}
          <footer className="page-footer">
            KINT10d ACADEMY{" "}
            <span>Evidence before confidence. Practice before claims.</span>
            <small>Curriculum edition · 15 October 2026</small>
          </footer>
        </main>
      </div>
    </div>
  );
}
function Capstones({
  get,
  save,
  disabled,
}: {
  get: (key: string, fallback?: string) => string;
  save: (key: string, value: string) => Promise<boolean>;
  disabled: boolean;
}) {
  const projects = [
    [
      "replay",
      "Build a deterministic market-data replay",
      "Use a frozen dataset and event-time clock. Handle duplicates, late bars, gaps and corporate actions. Acceptance: the same input hash produces the same output; no feature sees future data; interruption and recovery do not duplicate events.",
    ],
    [
      "model",
      "Train and audit a small model",
      "Implement logistic regression before a tiny neural model. Separate train/validation/test chronologically where appropriate. Acceptance: compare against a trivial baseline, report calibration and leakage checks, and reproduce metrics from a clean environment.",
    ],
    [
      "paper",
      "Reproduce one research result",
      "Choose one tractable experiment from the paper shelf. Extract equations, assumptions, data, budget and missing details. Acceptance: independent checking, a discrepancy log and a runnable environment; do not label a result reproduced merely because code runs.",
    ],
    [
      "agent",
      "Build a bounded research agent",
      "Give it read-only tools, explicit budgets, citations and a failure state. Acceptance: adversarial documents cannot change permissions; every empirical claim has evidence; a reviewer can replay tool inputs and outputs.",
    ],
    [
      "edge",
      "Conduct an honest edge investigation",
      "Pre-register a hypothesis, count every trial, model execution costs and reserve untouched confirmation data. Acceptance: reject the idea if evidence fails; show confidence intervals, drawdown, sensitivity and the economic reason the effect might persist.",
    ],
    [
      "operations",
      "Recover the entire system",
      "Simulate expired credentials, provider failures and a process crash. Acceptance: restore a backup, preserve the ledger, surface stale evidence and prevent duplicate financial actions. Use simulation only.",
    ],
  ];
  return (
    <section className="capstones">
      <p className="eyebrow">TURN KNOWLEDGE INTO EVIDENCE</p>
      <h2>Six projects that connect the disciplines</h2>
      <p>
        “Submitted” is your self-report. It does not mean independently reviewed
        or ready for trading.
      </p>
      {projects.map(([id, title, body]) => (
        <article className="panel" key={id}>
          <h3>{title}</h3>
          <p>{body}</p>
          <button
            disabled={disabled}
            onClick={() =>
              save(
                "capstone:" + id,
                get("capstone:" + id) === "submitted"
                  ? "in-progress"
                  : "submitted",
              )
            }
          >
            {get("capstone:" + id) === "submitted"
              ? "✓ Submitted · undo"
              : "Mark my evidence submitted"}
          </button>
        </article>
      ))}
    </section>
  );
}
