"""Property-based differential sweep: generates valid random shell configurations
and diffs Python csfgen against native atgen on each, extending the
hand-picked cases in test_differential_sweep.py.

Generator ranges (stated honestly, per this project's "no silent caps"
convention):

- Kinds: an ascending-ordered subset of S,P,D,F,G,H,I, possibly with gaps
  (K/L/M excluded -- same MOCCN=50 behavior as each other and already
  characterized by test_differential_sweep.py's KLM_CASES; can be added
  later without changing this strategy's shape). Order must still be
  strictly ascending -- that's a real, still-enforced native
  constraint (src/atlib.f rejects any violation with
  STOP 921) -- but the subset no longer has to be *contiguous*. It used
  to: a gap was believed to be a distinct native
  defect (the original, wrong diagnosis of a defect now understood
  differently) and was
  kept structurally unreachable by this generator on purpose. That
  diagnosis was corrected: a gap reads
  as an implicit zero and is byte-identical to naming the same kind
  explicitly at zero -- legal, well-defined input, not a defect. Nothing
  about gaps needs avoiding anymore, so the generator was widened
  to actually exercise them, rather than leaving that
  coverage to the two hand-picked cases in test_differential_sweep.py.
- For each present kind: a CARD-1 correlating-orbital count (NORBT, 1-6),
  and 0-2 distinctly-numbered named/occupied shells (covers "multiple
  active shells of the same kind"), each occupied 1..MOCCN_DEFAULTS[kind]
  (hypothesis's boundary-biased integers() exercises the at-capacity/
  MAXOC-exhausted acceptor branch often, without forcing it).
- 0-2 already-drawn shells may be promoted to frozen_core (before the
  crash-avoidance check below, since closed shells don't participate in
  the active donor/acceptor table).
- The known NACTE=1 native segfault (test_differential_sweep.py's
  KNOWN_NATIVE_FAILURES['single_active_electron'])
  is avoided BY CONSTRUCTION: only possible when exactly one shell was
  drawn total, at occupation 1 -- that occupation is bumped to 2 rather
  than the example being discarded. (An earlier version of this
  avoidance over-generalized the rule based on one crashing example this
  sweep found; controlled follow-up showed the real cause was the
  non-consecutive-numbering defect below, not NACTE=1's scope. See the
  correction noted at the check itself.)
- Named shells of the same kind must be CONSECUTIVELY numbered (see
  `_named_shells`'s docstring) -- a real native input constraint this
  sweep found (§7.6), not merely a convention.
- Named-shell n is kept single-digit (<=9) -- the already-documented
  CARD-2 label-truncation limit (§7.4), reachable from any high-l kind,
  not just M.
- Total active (named/occupied) shells across ALL kinds capped at 11 (see
  `deck`'s TOTAL_SHELL_BUDGET) -- chosen to deterministically exercise the
  CSF-file's 72-column wrap, not an arbitrary tidiness limit. Native's
  config-line printer wraps at exactly 72 columns starting at 11 shells --
  previously a genuine gap in the Python port's formatter, now fixed
  (`csfgen/format.py`'s `Card.putc` reproduces the same
  `col + width - 1 > 72` check as native's `IQPUTC`) and specifically
  regression-tested at
  `test_differential_sweep.test_long_config_line_wraps_and_matches_native`.
  11 is deliberately the threshold itself, not a margin below it, so this
  sweep exercises the wrap path (11-shell decks trigger it
  deterministically: every shell field is a fixed 12-column write
  regardless of label/occupation value, so any deck reaching the budget
  wraps) rather than avoiding it.

  A second sweep-bisected failure at 12 shells was originally attributed
  to native atgen segfaulting outright at 12+ total shells
  (`test_differential_sweep.KNOWN_NATIVE_FAILURES['many_active_shells']`)
  -- that diagnosis was WRONG. The actual cause was a different bug,
  found and fixed in the same pass: `atg.py`'s `write_atg()`
  wrote CARD 3's reference-configuration tokens as one unwrapped line,
  which happened to land at 73 columns for that specific 12-shell case --
  one over native's `CHARACTER*72` CARD-3 buffer -- and crashed for that
  reason, not because of the shell count. With `write_atg` now wrapping
  CARD 3 too (`_wrap_card_tokens`), that exact case runs clean and matches
  the Python port byte-for-byte (moved to
  `test_differential_sweep.MANY_SHELLS_CASES`). This budget was NOT raised
  past 11 to reflect that correction, since 11 is independently the right
  number for exercising the (still real, still fixed-here) CSF-file wrap
  above -- there was never a need to go higher, the old "12 is the
  ceiling" belief just happened to also constrain it from above. A rough
  follow-up probe suggests native's real ceiling is much higher (around
  22-23 shells), but that was not rigorously characterized (the probe's
  CARD-1/CARD-2 data may itself be invalid at that shell count) and is not
  relied on here. "Fixed" above is write_atg-specific: native ATRGEN
  itself still segfaults on any over-72-column CARD-3 line regardless of
  what produced it (still open) -- write_atg
  just no longer generates one.
- Parity and total-electron-count range are emergent from the draws, not
  forced.

**Agreement, not correctness**: a passing sweep
proves the two implementations agree on every generated input, not that
every generated input is physically meaningful -- occupations up to a
kind's MOCCN cap are drawn without regard to whether the resulting
configuration is a sensible atomic state.

Run modes: default ('ci' profile, see conftest.py) is 25 examples,
derandomized for reproducibility without depending on a persisted
.hypothesis/ example database. `ATINPUTS_HYPOTHESIS_PROFILE=extended
pytest ...` runs 2000 randomized examples for a deliberate longer local
sweep; any new failure hypothesis finds there gets shrunk to a minimal
case and saved to the local database for replay.
"""

import pytest
from hypothesis import assume, given
from hypothesis import strategies as st

from ..constants import ANGULAR_MOMENTUM_LETTERS, ATG_SGSHL_DEFAULT
from ..csfgen import generate_csf
from ..csfgen.refgen import MOCCN_DEFAULTS
from .test_differential_sweep import HAVE_ATGEN, _run_native

# S..I: the standard 2(2l+1) pattern (S/P/D/F) plus the MOCCN=2 anomaly
# (G/H/I). K/L/M excluded -- see module docstring.
KINDS = "SPDFGHI"


def _kind_l(letter):
    return ANGULAR_MOMENTUM_LETTERS.index(letter)


@st.composite
def _named_shells(draw, kind, max_count=2, n_span=4):
    """0..max_count named/occupied shells of one kind, CONSECUTIVELY
    numbered starting from a drawn n0 (n0, n0+1, ..., n0+count-1) --
    e.g. 1S,2S is valid, 1S,3S is not.

    This is required, not just tidy: found by this sweep (shrunk from a
    real divergence -- see test_property_matches_native_atgen's history). Native ATRGEN's CARD-3 reference-token parser
    maps a shell label to its shell-table row via
    `IA=NORTS(1,L)+N-L-NTOPN(L)` (src/atlib.f), which reduces to
    `NORTS(1,L) + (N - N_first_named_shell_of_kind_L)` -- i.e. it assumes
    a kind's named shells occupy CONSECUTIVE table rows in the same order
    as their consecutive N values. A gap (e.g. 1S then 3S, skipping 2S)
    breaks that assumption: the second token's computed row index lands
    two rows over instead of one, mis-indexing into whatever is actually
    there (the kind's aggregate row, or beyond) -- confirmed to produce
    both a silent byte-mismatch (occupations 1S*2,3S*1) and a segfault
    (1S*1,3S*1), while the consecutive equivalents (1S*2,2S*1 /
    1S*1,2S*1) are exact and crash-free. This is a real, undocumented
    native input constraint, not merely a convention -- every existing
    hand-picked case already satisfies it by construction (e.g.
    'same_kind_twice''s 2S,3S), which is exactly why this sweep is what
    found the gap, not the hand-picked cases.

    n is also kept single-digit (<=9): the FIRST run of this sweep also
    hit test_differential_sweep.py's already-documented CARD-2
    CHARACTER*2 label-truncation limit (originally found for M's minimum
    n=10, see test_m_named_shell_label_truncates_on_
    native) via unrelated high-l kinds (e.g. "10I", "11I") -- not a new
    finding, just the same known, out-of-scope-to-fix limitation reached
    from a different direction. Kept out of the random search the same
    way: by construction, not by filtering it out after the fact.
    """
    l = _kind_l(kind)
    count = draw(st.integers(0, max_count))
    if count == 0:
        return []
    n0 = draw(st.integers(l + 1, min(l + 1 + n_span, 9 - (count - 1))))
    return [{'label': f'{n}{kind}', 'n': n, 'l': l}
            for n in range(n0, n0 + count)]


@st.composite
def deck(draw):
    # Ascending-ordered subset of KINDS, possibly with gaps
    # -- see module docstring for why a gap
    # is safe to generate now (it wasn't excluded for correctness, it was
    # excluded because this sweep couldn't produce one). Order must still
    # be strictly ascending -- that's a real, still-enforced
    # constraint (src/atlib.f, §3.3a) -- so sort by KINDS' index rather
    # than relying on draw order.
    chosen = draw(st.lists(st.sampled_from(KINDS), min_size=1,
                            max_size=len(KINDS), unique=True))
    present = sorted(chosen, key=KINDS.index)

    outer, active, ref_tokens = [], [], []
    # Total active (named/occupied) shells across ALL kinds capped at 11 --
    # chosen to land exactly on the CSF-file's 72-column wrap threshold
    # (not an arbitrary tidiness limit), not because native crashes above
    # it -- see the module docstring's "12+ shells segfault" correction:
    # that belief was wrong. The real bug was write_atg emitting an
    # unwrapped CARD-3 line (fixed on the writer side); the
    # underlying native reader defect that made that dangerous is separate
    # and still OPEN -- native's real shell-count ceiling is
    # much higher and unrelated to this budget either way.
    # Native's config-line printer wraps at exactly 72 columns starting at
    # 11 shells -- previously a Python-port gap, fixed
    # (csfgen/format.py's Card.putc) -- so this budget's ceiling makes an
    # 11-shell deck exercise that fix rather than avoid it. 11 was
    # verified safe (native does not crash) with worst-case
    # (highest-capacity-kind, widest-token) occupations.
    TOTAL_SHELL_BUDGET = 11
    remaining = TOTAL_SHELL_BUDGET
    for kind in present:
        l = _kind_l(kind)
        norbt = draw(st.integers(1, 6))
        outer.append({'label': f'{norbt}{kind}', 'n': norbt, 'l': l})

        cap = MOCCN_DEFAULTS[kind]
        for shell in draw(_named_shells(kind, max_count=min(2, remaining))):
            occ = draw(st.integers(1, cap))
            active.append(shell)
            ref_tokens.append([shell['label'], occ])
            remaining -= 1

    assume(ref_tokens)  # need >=1 occupied shell

    # Promote 0-2 already-drawn shells to frozen_core BEFORE the crash
    # check below -- closed shells don't participate in the active
    # donor/acceptor table, so they must not count as "occupied" for it.
    # Drop them from active/reference so they aren't double-counted as
    # both closed and separately excited.
    frozen_core = []
    if active:
        frozen_core = draw(st.lists(st.sampled_from(active), max_size=2,
                                     unique_by=lambda s: s['label']))
    frozen_labels = {s['label'] for s in frozen_core}
    active = [s for s in active if s['label'] not in frozen_labels]
    ref_tokens = [t for t in ref_tokens if t[0] not in frozen_labels]
    assume(ref_tokens)

    # NACTE=1 (test_differential_sweep.KNOWN_NATIVE_FAILURES
    # ['single_active_electron']) avoided by
    # construction: only possible when exactly one shell was drawn total,
    # at occupation 1. Bumped to 2 (always within cap -- every
    # MOCCN_DEFAULTS value is >=2) rather than discarding the example.
    #
    # NOTE, corrected after a first pass got this wrong: an earlier
    # version of this check tried to generalize the rule to "the first
    # occupied kind's row-1 shell has occupation 1" (motivated by a
    # crashing example this sweep found, {1S:1, 3S:1}). That
    # generalization was WRONG -- controlled follow-up tests
    # ({1S:1, 2S:1}, consecutively numbered, does NOT crash) showed the
    # real cause of that example was the non-consecutive numbering
    # defect below, not row-1 occupation. Reverted to the narrow,
    # originally-correct rule.
    if len(ref_tokens) == 1 and ref_tokens[0][1] == 1:
        ref_tokens[0][1] = 2

    return {
        'csf': 'sweep.csf',
        'orbital': {'frozen_core': frozen_core, 'active': active, 'outer': outer},
        'reference': [{'occ': ' '.join(f'{label}*{occ}' for label, occ in ref_tokens)}],
    }


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
@given(data=deck())
def test_property_matches_native_atgen(data, tmp_path_factory):
    # NOT the plain tmp_path fixture -- it's function-scoped and would be
    # reused/cleared across @given's multiple examples within one test
    # invocation; hypothesis's own health check
    # (HealthCheck.function_scoped_fixture) flags this. A fresh directory
    # per example instead:
    tmp_path = tmp_path_factory.mktemp('sweep')
    result = _run_native(data, tmp_path)
    if result.returncode != 0:
        pytest.fail(
            f"native atgen failed (unquarantined) on a generated deck:\n"
            f"{data}\nstdout: {result.stdout}\nstderr: {result.stderr}")
    native = (tmp_path / data['csf']).read_text()
    mine = generate_csf(data, ATG_SGSHL_DEFAULT)
    assert mine == native
