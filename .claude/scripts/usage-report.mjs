#!/usr/bin/env node
// Measured token usage of every subagent delegated from sessions opened in this
// workspace, read from Claude Code's own transcripts (no estimates). Read-only.
//
//   node usage-report.mjs [--since YYYY-MM-DD] [--session <id-prefix>] [--rows N]
//
// Per delegation: date, agent, description (routing tag), requested and actual
// model, API calls, peak context, uncached input (+cache writes), cache reads,
// output, and the "Routing:" line of the brief. Then totals per model and agent.
// Tokens only: prices change, so convert with the current price list yourself.
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname, resolve, basename } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const WS = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const cfg = process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), ".claude");
const projDir = join(cfg, "projects", WS.replace(/[^A-Za-z0-9]/g, "-"));
const arg = (k) => {
  const i = process.argv.indexOf(k);
  return i > 0 ? process.argv[i + 1] : undefined;
};
const since = arg("--since");
const sessionPrefix = arg("--session");
const maxRows = Number(arg("--rows") ?? 40);

if (!existsSync(projDir)) {
  console.error(`No transcripts at ${projDir}`);
  process.exit(1);
}

const seen = new Set();
const rows = [];
const subDirs = readdirSync(projDir)
  .map((s) => [s, join(projDir, s, "subagents")])
  .filter(([, d]) => existsSync(d) && statSync(d).isDirectory());
// A forked or resumed session copies its subagents' transcripts but not always
// their meta files: collect meta from every session first.
const metas = new Map();
for (const [, sub] of subDirs)
  for (const f of readdirSync(sub))
    if (f.endsWith(".meta.json") && !metas.has(f.slice(0, -10)))
      metas.set(
        f.slice(0, -10),
        JSON.parse(readFileSync(join(sub, f), "utf8")),
      );

for (const [session, sub] of subDirs) {
  if (sessionPrefix && !session.startsWith(sessionPrefix)) continue;
  for (const f of readdirSync(sub)) {
    if (!f.endsWith(".jsonl")) continue;
    const id = basename(f, ".jsonl");
    if (seen.has(id)) continue; // forked sessions copy their subagents' transcripts
    seen.add(id);
    const meta = metas.get(id) ?? {};
    const r = {
      id: id.replace(/^agent-/, "").slice(0, 8),
      agent: meta.agentType ?? "?",
      desc: meta.description ?? "",
      req: meta.model ?? "-",
      models: {},
      calls: 0,
      peak: 0,
      input: 0,
      cacheRead: 0,
      output: 0,
      routing: "",
      date: "",
    };
    const msgIds = new Set();
    for (const line of readFileSync(join(sub, f), "utf8").split("\n")) {
      if (!line) continue;
      let e;
      try {
        e = JSON.parse(line);
      } catch {
        continue;
      }
      if (!r.date && e.timestamp) r.date = e.timestamp.slice(0, 10);
      const m = e.message ?? {};
      if (!r.routing && e.type === "user") {
        const text =
          typeof m.content === "string"
            ? m.content
            : (m.content ?? []).map((c) => c.text ?? "").join("\n");
        const hit = text.match(/^Routing:.*$/m);
        if (hit) r.routing = hit[0].slice(9, 140).trim();
      }
      if (
        e.type !== "assistant" ||
        !m.id ||
        msgIds.has(m.id) ||
        m.model === "<synthetic>"
      )
        continue;
      msgIds.add(m.id);
      const u = m.usage ?? {};
      const inp = (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
      const cr = u.cache_read_input_tokens ?? 0;
      r.calls++;
      r.models[m.model] = (r.models[m.model] ?? 0) + 1;
      r.input += inp;
      r.cacheRead += cr;
      r.output += u.output_tokens ?? 0;
      r.peak = Math.max(r.peak, inp + cr);
    }
    if (since && r.date < since) continue;
    if (r.calls) rows.push(r);
  }
}

const k = (n) =>
  n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : `${Math.round(n / 1e3)}k`;
const model = (r) =>
  Object.entries(r.models)
    .sort((a, b) => b[1] - a[1])[0][0]
    .replace(/^claude-/, "");
rows.sort((a, b) => a.date.localeCompare(b.date));

console.log(
  `Subagent usage from ${projDir}${since ? ` since ${since}` : ""}: ${rows.length} delegations\n`,
);
console.log(
  "date       agent            req     model          calls  peak  input  cacheRd  out   description / routing",
);
for (const r of rows.slice(-maxRows)) {
  console.log(
    `${r.date} ${r.agent.padEnd(16).slice(0, 16)} ${r.req.padEnd(7)} ${model(r).padEnd(14)} ${String(r.calls).padStart(5)} ${k(r.peak).padStart(5)} ${k(r.input).padStart(6)} ${k(r.cacheRead).padStart(8)} ${k(r.output).padStart(5)}   ${r.desc.slice(0, 50)}${r.routing ? `\n${" ".repeat(76)}↳ ${r.routing}` : ""}`,
  );
}

const group = (key) => {
  const g = {};
  for (const r of rows) {
    const x = (g[key(r)] ??= {
      n: 0,
      calls: 0,
      input: 0,
      cacheRead: 0,
      output: 0,
    });
    x.n++;
    x.calls += r.calls;
    x.input += r.input;
    x.cacheRead += r.cacheRead;
    x.output += r.output;
  }
  return Object.entries(g).sort((a, b) => b[1].cacheRead - a[1].cacheRead);
};
for (const [title, key] of [
  ["model", model],
  ["agent", (r) => r.agent],
]) {
  console.log(`\nBy ${title}:`);
  for (const [name, x] of group(key))
    console.log(
      `  ${name.padEnd(18)} n=${String(x.n).padStart(3)}  calls=${String(x.calls).padStart(5)}  avg calls=${String(Math.round(x.calls / x.n)).padStart(3)}  input=${k(x.input).padStart(6)}  cacheRead=${k(x.cacheRead).padStart(7)}  output=${k(x.output).padStart(6)}`,
    );
}
