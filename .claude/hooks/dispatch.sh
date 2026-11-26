#!/usr/bin/env bash
#
# Workspace hook dispatcher for sessions opened at the workspace root (the
# folder that holds the repositories listed in .claude/orchestra.json).
# Claude Code only loads the settings of the folder it was opened in, so the
# repositories' own guard and post-edit hooks would not run from here. This
# forwards each tool call to the hooks of the repository it touches, with
# CLAUDE_PROJECT_DIR set to that repository, so their .harness/ rules apply
# unchanged. No rules live here.
#
#   dispatch.sh pre    PreToolUse  (Bash, Edit, Write, MultiEdit, NotebookEdit)
#   dispatch.sh post   PostToolUse (Edit, Write, MultiEdit)
#
# Which repository:
#   - file tools: the repository that contains the target path (none → allow);
#   - Bash: the repository that contains the command's cwd; from the workspace
#     root, every repository the command names (`cd backend && …`), or all of
#     them when it names none. The strictest answer wins: block > ask > allow.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MODE="${1:-pre}"
PAYLOAD="$(cat)"

REPOS=()
while IFS= read -r r; do
  [[ -n "$r" ]] && REPOS+=("$r")
done < <(node -e '
  try {
    const c = require(process.argv[1]);
    for (const v of Object.values(c.repos || {})) if (v && v.dir) console.log(v.dir);
  } catch {}
' "$ROOT/.claude/orchestra.json" 2>/dev/null)
[[ ${#REPOS[@]} -gt 0 ]] || exit 0

# tool_name, command, file path, cwd — separated by 0x1F, like the repos' lib.sh.
IFS=$'\x1f' read -r TOOL COMMAND FILE_PATH CWD < <(printf '%s' "$PAYLOAD" | node -e '
  let s = "";
  process.stdin.on("data", d => (s += d)).on("end", () => {
    let o = ["", "", "", ""];
    try {
      const j = JSON.parse(s), ti = j.tool_input || {};
      o = [j.tool_name, ti.command, ti.file_path || ti.notebook_path, j.cwd].map(v => String(v || ""));
    } catch {}
    process.stdout.write(o.map(v => v.replace(/[\x1f\r\n]+/g, " ")).join("\x1f") + "\n");
  });
') || exit 0

repo_of() { # repo_of <absolute path> → repository dir, or nothing
  local r
  for r in "${REPOS[@]}"; do
    case "$1/" in "$ROOT/$r/"*) printf '%s' "$r"; return ;; esac
  done
}

targets=()
case "$TOOL" in
  Edit | Write | MultiEdit | NotebookEdit)
    [[ -n "$FILE_PATH" ]] || exit 0
    [[ "$FILE_PATH" == /* ]] || FILE_PATH="${CWD:-$ROOT}/$FILE_PATH"
    r="$(repo_of "$FILE_PATH")"
    [[ -n "$r" ]] && targets=("$r")
    ;;
  Bash)
    [[ "$MODE" == "pre" && -n "$COMMAND" ]] || exit 0
    r="$(repo_of "${CWD:-$ROOT}")"
    if [[ -n "$r" ]]; then
      targets=("$r")
    else
      for r in "${REPOS[@]}"; do
        [[ "$COMMAND" == *"$r"* ]] && targets+=("$r")
      done
      [[ ${#targets[@]} -gt 0 ]] || targets=("${REPOS[@]}")
    fi
    ;;
  *) exit 0 ;;
esac
[[ ${#targets[@]} -gt 0 ]] || exit 0

hook="pretooluse-guard.sh"
[[ "$MODE" == "post" ]] && hook="posttooluse-checks.sh"

ask_json=""
for r in "${targets[@]}"; do
  script="$ROOT/$r/.claude/hooks/$hook"
  [[ -f "$script" ]] || continue
  err="$(mktemp "${TMPDIR:-/tmp}/orchestra-hook.XXXXXX")" || exit 0
  out="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$ROOT/$r" bash "$script" 2>"$err")"
  code=$?
  if [[ $code -eq 2 ]]; then
    { printf '[%s] ' "$r"; cat "$err"; } >&2
    rm -f "$err"
    exit 2
  fi
  rm -f "$err"
  if [[ -z "$ask_json" && "$out" == *'"permissionDecision":"ask"'* ]]; then
    ask_json="${out/GUARDRAIL: /GUARDRAIL [$r]: }"
  fi
done

[[ -n "$ask_json" ]] && printf '%s\n' "$ask_json"
exit 0
