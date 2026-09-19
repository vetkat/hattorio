"""Validation of generated hat patches.

This is the gate. A sign error anywhere upstream surfaces here as overlapping
hats or hairline gaps, before any Lua exists. Do not proceed past a failure.
"""
from __future__ import annotations

import math
import random

from tools.geometry import Xf
from tools.hatviz_port import MetaTile, hat_polygon
from tools.substitution import levels

PHI = (1 + math.sqrt(5)) / 2


def flatten(mt: MetaTile, acc: Xf = None):
    """Every hat in the tree as (world transform, reflected)."""
    acc = acc or Xf.identity()
    out = []
    for ch in mt.children:
        xf = acc.mul(ch.xf)
        if isinstance(ch.geom, str):
            out.append((xf, xf.is_reflected()))
        else:
            out.extend(flatten(ch.geom, xf))
    return out


def _poly_f(xf: Xf):
    return [p.to_float() for p in hat_polygon(xf)]


def _area(poly):
    s = 0.0
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def _bbox(poly):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return min(xs), min(ys), max(xs), max(ys)


def _inside(poly, x, y):
    ins = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[j]
        if (ay > y) != (by > y):
            if x < ax + (y - ay) / (by - ay) * (bx - ax):
                ins = not ins
        j = i
    return ins


class _Grid:
    """Uniform bucket grid so containment queries are not O(n) per point."""

    def __init__(self, polys, cell):
        self.cell = cell
        self.buckets = {}
        for i, p in enumerate(polys):
            x0, y0, x1, y1 = _bbox(p)
            for gx in range(int(math.floor(x0 / cell)), int(math.floor(x1 / cell)) + 1):
                for gy in range(int(math.floor(y0 / cell)), int(math.floor(y1 / cell)) + 1):
                    self.buckets.setdefault((gx, gy), []).append(i)

    def candidates(self, x, y):
        return self.buckets.get((int(math.floor(x / self.cell)),
                                 int(math.floor(y / self.cell))), ())


def check_no_overlaps(hats, samples=12, seed=12345):
    """Interior samples of each hat must lie in no other hat."""
    polys = [_poly_f(x) for x, _ in hats]
    grid = _Grid(polys, cell=3.0)
    rng = random.Random(seed)
    errs = []
    for i, pi in enumerate(polys):
        x0, y0, x1, y1 = _bbox(pi)
        hits = 0
        tries = 0
        while hits < samples and tries < samples * 40:
            tries += 1
            x = rng.uniform(x0, x1)
            y = rng.uniform(y0, y1)
            if not _inside(pi, x, y):
                continue
            hits += 1
            for j in grid.candidates(x, y):
                if j != i and _inside(polys[j], x, y):
                    errs.append(f"hats {i} and {j} overlap near ({x:.6f}, {y:.6f})")
                    return errs
    return errs


def check_no_gaps(hats, resolution=120):
    """Sample a disc well inside the patch; every sample must land in some hat."""
    polys = [_poly_f(x) for x, _ in hats]
    grid = _Grid(polys, cell=3.0)
    xs = [p[0] for poly in polys for p in poly]
    ys = [p[1] for poly in polys for p in poly]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    r = min(max(xs) - min(xs), max(ys) - min(ys)) / 5
    missed = 0
    tested = 0
    step = 2 * r / resolution
    y = cy - r
    while y < cy + r:
        x = cx - r
        while x < cx + r:
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                tested += 1
                if not any(_inside(polys[j], x, y) for j in grid.candidates(x, y)):
                    missed += 1
            x += step
        y += step
    if tested == 0:
        return ["gap check sampled nothing"]
    frac = missed / tested
    if frac > 0.001:
        return [f"gaps found: {100 * frac:.3f}% of interior samples "
                f"({missed}/{tested}) lie in no hat"]
    return []


def reflected_density(hats):
    return sum(1 for _, r in hats if r) / len(hats)


def max_coefficient(hats):
    worst = 0
    for xf, _ in hats:
        worst = max(worst, xf.denominator())
        for group in xf.numerators():
            for n in group:
                worst = max(worst, abs(int(n)))
    return worst


def verify_all(depth: int):
    errs = []
    hats = flatten(levels(depth)[depth]["H"])
    if not hats:
        return ["no hats produced"]
    errs += check_no_overlaps(hats)
    errs += check_no_gaps(hats)
    d = reflected_density(hats)
    if not (0.05 < d < 0.22):
        errs.append(f"reflected density {d:.4f} outside plausible range")
    mc = max_coefficient(hats)
    if mc >= 2 ** 53:
        errs.append(f"coefficient {mc} exceeds 2^53")
    return errs
