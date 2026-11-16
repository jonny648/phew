#!/bin/zsh
# Reads a test result bundle and fails unless: no test failed, at least <least> tests ran, and exactly <skipped> were
# skipped. A skipped test counts as a pass for xcodebuild, so a run where the live tests all skipped looks green (R37).
# Usage: Tools/check-tests.sh <result bundle> <least> <skipped>
# Normal run: 6 skipped (5 practice-window tests, 1 spoken measure). With PHEW_LIVE=1: 1. With PHEW_HEAR=1 too: 0.
set -euo pipefail
(( $# == 3 )) || { echo "Usage: Tools/check-tests.sh <result bundle> <least> <skipped>" >&2; exit 2; }
summary=$(xcrun xcresulttool get test-results summary --path "$1")
read -r total failed skipped <<<"$(print -r -- "$summary" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["totalTestCount"], d["failedTests"], d["skippedTests"])')"
echo "tests: $total ran, $failed failed, $skipped skipped"
(( failed == 0 )) || { echo "check-tests: $failed failed" >&2; exit 1; }
(( total >= $2 )) || { echo "check-tests: only $total tests ran, expected at least $2" >&2; exit 1; }
(( skipped == $3 )) || { echo "check-tests: $skipped skipped, expected $3" >&2; exit 1; }
