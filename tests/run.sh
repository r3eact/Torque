#!/usr/bin/env bash
# Runs Torque's logic tests outside Roblox using the official Luau CLI.
#   1. syntax-checks every .luau file with luau-compile
#   2. bundles the module sources into one file and runs tests/TestRunner.luau,
#      which executes the REAL shared modules + server services against a small
#      mock of the Roblox API.
# Usage: LUAU_BIN=/path/to/luau-binaries tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="${LUAU_BIN:-$(dirname "$(command -v luau)")}"
OUT="${TMPDIR:-/tmp}/torque-tests"
mkdir -p "$OUT"

echo "== Syntax check"
fail=0
while IFS= read -r f; do
  if ! "$BIN/luau-compile" "$f" > /dev/null; then echo "  FAIL $f"; fail=1; fi
done < <(find src -name '*.luau')
[ "$fail" = 0 ] && echo "  all files compile"

echo "== Quest events tracked by the server"
grep -rhoE 'Track\([a-zA-Z]+, "[A-Za-z]+"' src/server | grep -oE '"[A-Za-z]+"' | sort -u | tr '\n' ' '; echo

BUNDLE="$OUT/bundle.luau"
{
  echo "local SOURCES = {}"
  while IFS= read -r f; do
    key="${f#src/}"; key="${key%.luau}"
    if grep -q ']=====]' "$f"; then echo "bad delimiter in $f" >&2; exit 1; fi
    printf 'SOURCES["%s"] = [=====[\n%s\n]=====]\n' "$key" "$(cat "$f")"
  done < <(find src/shared src/server/Services -name '*.luau')
  cat tests/TestRunner.luau
} > "$BUNDLE"
echo "== Logic tests"
"$BIN/luau" "$BUNDLE"
