#!/usr/bin/env node
// Read feature_list.json without loading the whole file into an agent's context
// (it grows to tens of KB over a few phases). Read-only.
//
//   node feature.mjs <repo> --list [--all]   compact table (unfinished only unless --all)
//   node feature.mjs <repo> <feat-id>...     one entry each, plus its dependencies' status
//   node feature.mjs <repo> <feat-id> --evidence   include the evidence field
//
// <repo>: a key or dir from .claude/orchestra.json (api, backend, …), or a path
// holding feature_list.json (e.g. a worktree, whose entry may be newer than the
// main checkout's).
import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const WS = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const args = process.argv.slice(2);
const flags = new Set(args.filter((a) => a.startsWith("--")));
const [repoArg, ...ids] = args.filter((a) => !a.startsWith("--"));

let alias = {};
try {
  const cfg = JSON.parse(readFileSync(join(WS, ".claude/orchestra.json"), "utf8"));
  alias = Object.fromEntries(
    Object.entries(cfg.repos ?? {}).map(([k, v]) => [k, v.dir]),
  );
} catch {}

const dir = !repoArg
  ? null
  : existsSync(join(repoArg, "feature_list.json"))
    ? repoArg
    : join(WS, alias[repoArg] ?? repoArg);
if (!dir || !existsSync(join(dir, "feature_list.json"))) {
  console.error(
    `Usage: feature.mjs <${Object.keys(alias).join("|") || "repo"}|path> (--list [--all] | <feat-id>... [--evidence])`,
  );
  process.exit(2);
}

const { milestone, features = [] } = JSON.parse(
  readFileSync(join(dir, "feature_list.json"), "utf8"),
);
const byId = new Map(features.map((f) => [f.id, f]));
const deps = (f) =>
  (f.dependencies ?? [])
    .map((d) => `${d}:${byId.get(d)?.status ?? "?"}`)
    .join(" ") || "-";

if (flags.has("--list") || ids.length === 0) {
  const rows = features.filter(
    (f) => flags.has("--all") || f.status !== "pass",
  );
  console.log(
    `${dir.replace(WS + "/", "")} milestone=${milestone} (${rows.length}/${features.length} shown)`,
  );
  for (const f of rows)
    console.log(`${f.id} | ${f.status} | ${f.name} | deps ${deps(f)}`);
  process.exit(0);
}

let missing = 0;
for (const id of ids) {
  const f = byId.get(id);
  if (!f) {
    console.error(`${id}: not found in ${dir}/feature_list.json`);
    missing = 1;
    continue;
  }
  const { evidence, ...rest } = f;
  const out = flags.has("--evidence") ? f : rest;
  console.log(JSON.stringify(out, null, 2));
  console.log(
    `dependencies: ${deps(f)}${evidence && !flags.has("--evidence") ? " | evidence: omitted (--evidence)" : ""}`,
  );
}
process.exit(missing);
