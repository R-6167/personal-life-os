#!/usr/bin/env bash
# Soft audit: list data-layer files that touch activity_events / AtomicWrite.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)/apps/flutter/lib"
echo "== activity_events inserts =="
grep -Rn "activity_events" "$ROOT" --include='*.dart' | head -50 || true
echo
echo "== AtomicWrite call sites =="
grep -Rn "AtomicWrite\." "$ROOT" --include='*.dart' || true
echo
echo "Done. Prefer AtomicWrite.run for state+event pairs."
