#!/bin/zsh
# N4.0, the measure: reads a calls.log (one JSON line per model call, `Phew/Brain/CallLog.swift`) and prints numbers
# only: the time between calls, the share of pauses over 5 and over 60 minutes, calls per job, looks per guide, and
# the cost per agent. calls.log holds no words of the user, and nothing here prints any field but numbers and the
# agents' and tiers' fixed names.
# Usage: Tools/measure-calls.sh <path to calls.log>
# How runs are told apart, since a line carries no job or guide number: every request starts with one conductor call;
# a job is a run of doer calls with no other agent's call between them; a guide's looks are the follower calls after
# a guide call, up to the next conductor or guide call. An explanation is a guide call too, so "guides" counts only
# guide calls followed by at least one look.
set -euo pipefail
(( $# == 1 )) || { echo "Usage: Tools/measure-calls.sh <calls.log>" >&2; exit 2; }
[[ -r "$1" ]] || { echo "measure-calls: cannot read $1" >&2; exit 2; }
exec /usr/bin/python3 -I -c '
import json, sys
from datetime import datetime

calls = []
for raw in open(sys.argv[1], encoding="utf-8"):
    try:
        line = json.loads(raw)
        ts = datetime.fromisoformat(line["ts"].replace("Z", "+00:00")).timestamp()
        calls.append((ts, str(line["agent"]), str(line["tier"]), float(line.get("usd", 0))))
    except (ValueError, KeyError, TypeError):
        continue
calls.sort(key=lambda c: c[0])
print(f"calls: {len(calls)}")
if not calls:
    sys.exit(0)

def quantile(values, q):
    values = sorted(values)
    i = (len(values) - 1) * q
    lo = int(i)
    hi = min(lo + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (i - lo)

def gaps(name, times):
    g = [(b - a) / 60 for a, b in zip(times, times[1:])]
    if not g:
        return print(f"{name}: no gaps")
    over5 = sum(1 for x in g if x > 5) / len(g) * 100
    over60 = sum(1 for x in g if x > 60) / len(g) * 100
    print(f"{name}: {len(g)} gaps, median {quantile(g, .5):.2f} min, middle half {quantile(g, .25):.2f} to {quantile(g, .75):.2f} min, "
          f"over 5 min {over5:.1f}%, over 60 min {over60:.1f}%")

gaps("between all calls", [c[0] for c in calls])
gaps("between main-model calls", [c[0] for c in calls if c[2] == "main"])
gaps("between requests (conductor calls)", [c[0] for c in calls if c[1] == "conductor"])

def runs(counts, name, unit):
    if not counts:
        return print(f"{name}: none")
    print(f"{name}: {len(counts)}, {unit} median {quantile(counts, .5):.1f}, mean {sum(counts) / len(counts):.2f}, most {max(counts)}")

jobs, run = [], 0
for c in calls:
    if c[1] == "doer":
        run += 1
    elif run:
        jobs.append(run); run = 0
if run:
    jobs.append(run)
runs(jobs, "jobs", "calls per job")

looks, open_guide = [], None
for c in calls:
    if c[1] == "follower" and open_guide is not None:
        open_guide += 1
    elif c[1] in ("guide", "conductor"):
        if open_guide:
            looks.append(open_guide)
        open_guide = 0 if c[1] == "guide" else None
if open_guide:
    looks.append(open_guide)
runs(looks, "guides with looks", "looks per guide")

agents = {}
for c in calls:
    n, usd = agents.get(c[1], (0, 0.0))
    agents[c[1]] = (n + 1, usd + c[3])
total = sum(usd for _, usd in agents.values())
print(f"cost: total ${total:.4f}")
for name in sorted(agents):
    n, usd = agents[name]
    print(f"  {name}: {n} calls, ${usd:.4f} in all, ${usd / n:.5f} a call, {usd / total * 100 if total else 0:.1f}% of the cost")
' "$1"
