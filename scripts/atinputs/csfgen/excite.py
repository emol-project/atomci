"""ATSGEN + ATDGEN — single- and double-excitation generation, ported from
`src/atlib.f:835-1021` (`ATSGEN`) and `src/atlib.f:340-564` (`ATDGEN`).

Loop nesting and insertion order are preserved exactly (reference order,
then donor row ascending, then acceptor row ascending) because `ATPRNT`
prints configs by scanning the table in column order — getting this right
is what makes the output byte-for-byte reproducible, not merely
set-equivalent.

**Deliberate simplification vs. the source**: `ATSGEN`/`ATDGEN`'s
per-reference `(hole, particle)` "path" bookkeeping exists solely so
`ATCHCK` — a diagnostic consistency check — can cross-verify electron-count
deltas. `ATCHCK` never gates or mutates the CSF list (`src/atgen.f:195-315`,
confirmed: no `STOP` reachable, no `NCONF` write), and `ATPRNT`'s formatting
reads only `occ` (and the valence-electron sum derived from it), never the
path metadata. This port therefore tracks occupation vectors only; `ATCHCK`
itself is not ported. Both routines' donor/acceptor loop and duplicate
handling are otherwise ported directly:

- **`ATSGEN`** (singles): base configs are references only; donor/acceptor
  pairs are unfiltered by parity — a "single" can be a genuine excitation
  to a virtual shell, or an intra-valence recoupling (e.g. 2S→2P) that
  changes no valence electron count at all. The latter is never selected
  for printing by `format.py` (it needs exactly 0, not ±1, outer
  electrons) but does become a real table entry — and, critically, a base
  `ATDGEN` can build a genuine "2 electrons outside valence" double on top
  of (the "2P*6"-style cases traced in the ATRGEN/ATPRNT research).
- **`ATDGEN`** (doubles): base configs are the *entire* table after
  `ATSGEN` (references *and* singles) — a parity gate,
  `NPRTY(donor)*NPRTY(acceptor)*base.parity_marker == 1`, is the one real
  filter that doesn't exist in `ATSGEN` at all.

**Print-time parity filter, and why doubles carry marker 0.** `ATPRNT`'s
three print-selection loops (the un-headed "NE0==NACTE" group, "FIRST ORDER
SPACE", "SECOND ORDER SPACE" — `src/atgen.f:723,752,809`) all additionally
skip any config with `NCONF(NACC,I) < 0` (`NACC = MSCHL+1`, the same marker
row `ATSGEN` sets to `NPRTY(donor)*NPRTY(acceptor)`). This directly answers
why e.g. `2S`→virtual-P is absent from the reference F-atom's FIRST ORDER
SPACE even though `ATSGEN` generates it unfiltered: its marker is `-1`
(`S` even · `P` odd), so `ATPRNT` skips printing it — though it still
exists in the table and remains a valid base for `ATDGEN`. Crucially,
`ATDGEN` does *not* store `NPRTY(donor)*NPRTY(acceptor)` for the doubles it
creates the way `ATSGEN` does for singles — it explicitly zeroes the whole
metadata region including the marker row (`DO L=MSCHL+1,MSCH3;
NCONF(L,NCO)=0`, `src/atlib.f:472-473`) for every new double. So every
double's stored marker is `0`, which always passes the `< 0` print filter
regardless of the swap's own parity — parity for doubles is enforced
*only* once, at generation time via `JPT`, not again at print time.
"""

from .refgen import Config, parity_of_kind


def _donor_acceptor_pairs(table):
    n = len(table.shells)
    for j in range(n - 1):  # MSCHL-1: the numerically last row is never a donor
        for k in range(n):
            if k == j:
                continue
            yield j, k


def generate_singles(references, table):
    """references: build_references()'s output. Returns an ordered list:
    the references, followed by every distinct single-excited config, in
    native generation order (insertion-ordered dict = table column order)."""
    seen = {tuple(c.occ): c for c in references}
    for ref in references:
        for j, k in _donor_acceptor_pairs(table):
            ndam = ref.occ[j] - 1
            if ndam < 0:
                continue
            mdam = ref.occ[k] + 1
            if mdam > table.shells[k].capacity:
                continue
            occ = list(ref.occ)
            occ[j], occ[k] = ndam, mdam
            key = tuple(occ)
            if key in seen:
                continue
            marker = parity_of_kind(table.shells[j].kind) * parity_of_kind(table.shells[k].kind)
            seen[key] = Config(occ=occ, parity_marker=marker)
    return list(seen.values())


def generate_doubles(configs, table):
    """configs: generate_singles()'s output (references + singles).
    Returns configs extended with every distinct double-excited config."""
    seen = {tuple(c.occ): c for c in configs}
    base_list = list(configs)  # ATDGEN's base range (1..NSCON) is fixed before it starts
    for base in base_list:
        for j, k in _donor_acceptor_pairs(table):
            ndam = base.occ[j] - 1
            if ndam < 0:
                continue
            mdam = base.occ[k] + 1
            if mdam > table.shells[k].capacity:
                continue
            jpt = (parity_of_kind(table.shells[j].kind)
                   * parity_of_kind(table.shells[k].kind)
                   * base.parity_marker)
            if jpt != 1:
                continue
            occ = list(base.occ)
            occ[j], occ[k] = ndam, mdam
            key = tuple(occ)
            if key in seen:
                continue
            # ATDGEN zeroes the marker row for new doubles (src/atlib.f:472-473),
            # unlike ATSGEN -- parity was already enforced by the JPT gate above.
            seen[key] = Config(occ=occ, parity_marker=0)
    return list(seen.values())
