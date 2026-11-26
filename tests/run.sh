#!/usr/bin/env bash
# Self-test of the orchestra scripts: builds a scratch workspace with two stub
# repositories (backend, frontend) whose hooks and gates are fakes, then checks
# the hook dispatcher, feature.mjs and gate.sh against it.
#
#   bash tests/run.sh      # exits 1 on any failure; needs bash and node
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$(mktemp -d "${TMPDIR:-/tmp}/orchestra-test.XXXXXX")" || exit 1
trap 'rm -rf "${WS:?}"' EXIT
pass=0
fail=0
check() { # check <description> <want> <got>
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); printf '  ok    %s\n' "$1"
  else fail=$((fail + 1)); printf '  FAIL  %s (want %s, got %s)\n' "$1" "$2" "$3"; fi
}

cp -R "$SRC/.claude" "$WS/"
for repo in backend frontend; do
  mkdir -p "$WS/$repo/.claude/hooks"
  # Stub guard: blocks "drop-$repo", asks for "ask-$repo", allows the rest.
  cat >"$WS/$repo/.claude/hooks/pretooluse-guard.sh" <<HOOK
#!/usr/bin/env bash
p="\$(cat)"
[[ "\$CLAUDE_PROJECT_DIR" == */$repo ]] || { echo "wrong project dir \$CLAUDE_PROJECT_DIR" >&2; exit 2; }
case "\$p" in
  *drop-$repo*) echo "GUARDRAIL: blocked in $repo" >&2; exit 2 ;;
  *ask-$repo*) printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"GUARDRAIL: ask in $repo"}}\n' ;;
esac
exit 0
HOOK
  cat >"$WS/$repo/.claude/hooks/posttooluse-checks.sh" <<HOOK
#!/usr/bin/env bash
cat >/dev/null
echo "post $repo" >>"$WS/post.log"
HOOK
  cat >"$WS/$repo/init.sh" <<'INIT'
#!/usr/bin/env bash
echo "=== harness ==="
echo "check-harness: PASS"
[[ -n "${FAIL_GATE:-}" ]] && { echo "boom"; exit 1; }
[[ -n "${RUN_INTEGRATION:-}" ]] && echo "=== integration ===" && echo "3 passed"
exit 0
INIT
done
cat >"$WS/backend/feature_list.json" <<'JSON'
{"milestone":"p1-core","features":[
 {"id":"feat-1","name":"[P1.1] one","status":"pass","dependencies":[],"evidence":"see report"},
 {"id":"feat-2","name":"[P1.2] two","status":"not-started","dependencies":["feat-1"],"evidence":""}]}
JSON

dispatch() { # dispatch <mode> <json> → block | ask | allow
  local out code
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WS" bash "$WS/.claude/hooks/dispatch.sh" "$1" 2>/dev/null)"
  code=$?
  if [[ $code -eq 2 ]]; then echo block
  elif [[ "$out" == *'"permissionDecision":"ask"'* ]]; then echo ask
  else echo allow; fi
}
bash_call() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2"; }
edit_call() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$WS"; }

echo "== dispatch.sh"
check "cwd in backend routes to backend" block "$(dispatch pre "$(bash_call 'drop-backend' "$WS/backend")")"
check "cwd in frontend ignores backend rule" allow "$(dispatch pre "$(bash_call 'drop-backend' "$WS/frontend")")"
check "root, command names frontend" ask "$(dispatch pre "$(bash_call 'cd frontend && ask-frontend' "$WS")")"
check "root, names no repo: all repos checked" block "$(dispatch pre "$(bash_call 'drop-frontend' "$WS")")"
check "root, block beats ask" block "$(dispatch pre "$(bash_call 'ask-backend; drop-frontend' "$WS")")"
check "edit in backend, relative path" allow "$(dispatch pre "$(edit_call 'backend/src/a.ts')")"
check "edit outside the repos" allow "$(dispatch pre "$(edit_call "$WS/slices/x.md")")"
check "malformed payload fails open" allow "$(dispatch pre 'not json')"
dispatch post "$(edit_call "$WS/frontend/src/a.tsx")" >/dev/null
check "post hook runs in the edited repo only" "post frontend" "$(cat "$WS/post.log" 2>/dev/null)"

echo "== feature.mjs"
out="$(node "$WS/.claude/scripts/feature.mjs" api --list)"
check "list by key shows unfinished only" 1 "$(grep -c '^feat-' <<<"$out")"
out="$(node "$WS/.claude/scripts/feature.mjs" backend feat-2)"
check "entry by dir, with dependency status" 1 "$(grep -c 'dependencies: feat-1:pass' <<<"$out")"
node "$WS/.claude/scripts/feature.mjs" api feat-9 >/dev/null 2>&1
check "missing feature exits 1" 1 "$?"
node "$WS/.claude/scripts/feature.mjs" nope >/dev/null 2>&1
check "unknown repo exits 2" 2 "$?"

echo "== gate.sh"
out="$(bash "$WS/.claude/scripts/gate.sh" "$WS/backend")"
check "baseline passes" 1 "$(grep -c 'exit=0' <<<"$out")"
out="$(bash "$WS/.claude/scripts/gate.sh" "$WS/backend" --integration)"
check "integration runs RUN_INTEGRATION=1" 1 "$(grep -c '3 passed' <<<"$out")"
out="$(FAIL_GATE=1 bash "$WS/.claude/scripts/gate.sh" "$WS/backend")"
check "failure prints the log tail" 1 "$(grep -c '^boom' <<<"$out")"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
