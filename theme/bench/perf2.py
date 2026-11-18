#!/usr/bin/env python3
# perf2.py <log> <from-line> : the busiest window's frame pacing, counting only gaps inside continuous
# animation (a gap over 250 ms is the window being idle or hidden, not a stall)
import re, sys
lines = open(sys.argv[1], errors="replace").read().splitlines()[int(sys.argv[2]):]
win = {}
for l in lines:
    m = re.search(r"\[window (0x[0-9a-f]+)\]\[render thread [^\]]+\] syncAndRender: start, elapsed since last call: (\d+) ms", l)
    if m: win.setdefault(m.group(1), []).append(int(m.group(2)))
if not win: print("no frames"); sys.exit()
k, g = max(win.items(), key=lambda kv: len(kv[1]))
inside = [x for x in g if 0 < x < 250]
slow = sorted(x for x in inside if x > 25)
inside.sort()
print(f"{len(g)} frames; median {inside[len(inside)//2]} ms, p95 {inside[int(len(inside)*.95)]} ms; stalls over 25 ms: {slow if slow else 'none'}")
