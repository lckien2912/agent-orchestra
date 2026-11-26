#!/usr/bin/env bash
# Run a repository's own gates (its init.sh, unchanged) with the full output in
# a log file, and print only what an agent needs: the gate sections, test
# counts, and on failure the tail of the log. Keeps thousands of lines of test
# output out of the agent's context. No gate is added, skipped or weakened.
#
#   bash gate.sh <repo-or-worktree-path> [--integration [--live]] [--tail N]
#
# --integration: RUN_INTEGRATION=1 bash init.sh. In a repository whose
# package.json has a `test:e2e:stack` script (end-to-end specs against a fresh,
# seeded backend on its own ports and database), it runs the baseline init.sh
# and then that script instead, so stale data on a shared dev backend cannot
# fail it. Stack runs are serialised by a lock (one database, one set of
# ports). --live keeps RUN_INTEGRATION=1 init.sh even when the stack exists.
#
# Exit code is init.sh's (or the stack run's). The log path is printed; grep it.
set -uo pipefail

dir="${1:-}"
[[ -n "$dir" && -f "$dir/init.sh" ]] || {
  echo "Usage: gate.sh <path to a repo or worktree with init.sh> [--integration [--live]] [--tail N]" >&2
  exit 2
}
shift
integration=0
live=0
tail_n=60
while [[ $# -gt 0 ]]; do
  case "$1" in
    --integration) integration=1 ;;
    --live | --live-api) live=1 ;;
    --tail) tail_n="${2:-60}"; shift ;;
  esac
  shift
done

dir="$(cd "$dir" && pwd)"
tmp="${TMPDIR:-/tmp}"
log_dir="${tmp%/}/orchestra-gates"
mkdir -p "$log_dir"
log="$log_dir/$(basename "$dir")-$(date +%Y%m%d-%H%M%S).log"

mode=baseline
if [[ $integration -eq 1 ]]; then
  if [[ $live -eq 0 ]] && grep -q '"test:e2e:stack"' "$dir/package.json" 2>/dev/null; then
    mode=stack
  else
    mode=integration
  fi
fi

# One stack run at a time across worktrees; a lock left by a dead run is taken over.
lock="$log_dir/stack.lock"
take_lock() {
  local waited=0
  until mkdir "$lock" 2>/dev/null; do
    local owner
    owner=$(cat "$lock/pid" 2>/dev/null || true)
    if [[ -n "$owner" ]] && ! kill -0 "$owner" 2>/dev/null; then
      rm -rf "${lock:?}"
      continue
    fi
    ((waited == 0)) && echo "gate: waiting for another stack run (pid ${owner:-?}) to finish…"
    sleep 10
    waited=$((waited + 10))
    if ((waited >= 3600)); then
      echo "gate: gave up after 60 min waiting for $lock" >&2
      exit 3
    fi
  done
  echo $$ >"$lock/pid"
  trap 'rm -rf "${lock:?}"' EXIT INT TERM
}

# The package manager the lockfile names, for the stack script.
pm=npm
[[ -f "$dir/pnpm-lock.yaml" ]] && pm=pnpm
[[ -f "$dir/yarn.lock" ]] && pm=yarn
[[ -f "$dir/bun.lock" || -f "$dir/bun.lockb" ]] && pm=bun

start=$(date +%s)
case $mode in
  stack)
    (cd "$dir" && bash init.sh) >"$log" 2>&1
    code=$?
    if [[ $code -eq 0 ]]; then
      take_lock
      echo "=== e2e tests (stack: fresh backend) ===" >>"$log"
      (cd "$dir" && "$pm" run test:e2e:stack) >>"$log" 2>&1
      code=$?
    else
      echo "=== e2e tests (stack) skipped: baseline failed ===" >>"$log"
    fi
    ;;
  integration) (cd "$dir" && RUN_INTEGRATION=1 bash init.sh) >"$log" 2>&1; code=$? ;;
  *) (cd "$dir" && bash init.sh) >"$log" 2>&1; code=$? ;;
esac
secs=$(($(date +%s) - start))

echo "gate: $dir (integration=$integration, $mode) exit=$code in ${secs}s"
echo "log:  $log ($(wc -l <"$log" | tr -d ' ') lines)"
echo "--- sections"
grep -E '^=== ' "$log" | sed 's/^=== \(.*\) ===$/  \1/'
echo "--- results"
# Vitest / Jest / Playwright / pytest / go test / tsc summaries, harness PASS/FAIL lines, skips.
grep -E '^[[:space:]]*(Test Files|Tests)[[:space:]]+[0-9]|[0-9]+ (passed|failed|flaky|skipped)|: (PASS|FAIL)|gate skipped|gates skipped|error TS[0-9]+|ERR_PNPM|✗|FAIL |^(ok|FAIL)[[:space:]]' "$log" |
  sed 's/^[[:space:]]*/  /' | tail -n 40
if [[ $code -ne 0 ]]; then
  echo "--- FAILED: last $tail_n lines"
  tail -n "$tail_n" "$log"
fi
exit $code
