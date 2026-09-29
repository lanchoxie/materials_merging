#!/usr/bin/env bash
# Run every headless test (tests/test_*.gd) and summarise pass/fail.
# Usage: dev/run_tests.sh [name-filter] [out-dir]
# Benchmarks are excluded; a test "fails" on non-zero exit OR any SCRIPT ERROR in its log.
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
export APPDATA="$ROOT/.runtime/AppData" LOCALAPPDATA="$ROOT/.runtime/LocalAppData" TEMP="$ROOT/.runtime/Temp" TMP="$ROOT/.runtime/Temp"
GD="${GODOT:-$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
FILTER="${1:-}"
OUT="${2:-artifacts/test-run}"
mkdir -p "$OUT"
: > "$OUT/summary.txt"
pass=0; fail=0
for t in tests/test_*.gd; do
	n=$(basename "$t" .gd)
	[[ -n "$FILTER" && "$n" != *"$FILTER"* ]] && continue
	# Screenshot tests without a headless guard await frame_post_draw, which never fires headless.
	mode=(--headless)
	if grep -q "frame_post_draw" "$t" && ! grep -q "headless" "$t"; then mode=(--rendering-driver opengl3 --windowed); fi
	timeout 240 "$GD" "${mode[@]}" --path . --script "res://$t" -- --release-ui-test > "$OUT/$n.log" 2>&1
	code=$?
	if [[ $code -eq 0 ]] && ! grep -q "SCRIPT ERROR" "$OUT/$n.log"; then
		pass=$((pass+1)); echo "PASS $n" | tee -a "$OUT/summary.txt"
	else
		fail=$((fail+1)); echo "FAIL($code) $n :: $(grep -m1 -E 'FAILED|SCRIPT ERROR|ERROR' "$OUT/$n.log")" | tee -a "$OUT/summary.txt"
	fi
done
echo "== $pass passed, $fail failed ==" | tee -a "$OUT/summary.txt"
