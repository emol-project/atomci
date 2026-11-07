"""Differential sweep: for each
synthetic case, real atgen (via a generated .atg) and the Python port
(csfgen.generate_csf) must produce byte-identical CSF text.

Coverage recorded explicitly, per this project's "no silent caps" convention:

- Varied: frozen_core shell count (0, 1, 2), active shell count and kind
  mix (S-only, S+P, S+P+D), outer/correlating space size per kind,
  reference occupation (small and large electron counts, a closed P
  subshell as an edge case for MAXOC-at-capacity acceptors), and — because
  they change which (donor, acceptor) parity combinations exist — cases
  spanning S/P/D/F all together (case 'f', already the golden
  case) down to S/P-only (case 'edge_minimal').
- NOT varied, deliberately: atom.z/ang/spin. The .atg format (CARD 1-6,
  see atg.py's docstring) has no spin or nuclear-charge input at all —
  CSF generation depends only on orbital.frozen_core/active/outer and
  reference occupations, so sweeping spin multiplicity would not exercise
  any different code path in refgen.py/excite.py/format.py. That
  dimension is exercised elsewhere (sugar.py's own tests, which cover
  ISPIN/IORB/IPAR derivation).
- Kinds beyond S/P/D/F (G, H, I, K, L, M): settled. Native `atgen` agrees
  with `MOCCN_DEFAULTS`'s G/H/I=2 and K/L/M=50 exactly, including
  above-cap reference occupations (neither native nor the Python port
  validates occupation against capacity at reference-parse time -- see
  `GHI_CASES`' `*_above_cap` entries). **This proves agreement, not
  correctness**: an above-cap occupation is physically meaningless, so a
  byte-identical match there shows the two implementations faithfully
  reproduce the same nonsense, not that the nonsense means anything.
  M additionally surfaced a real, pre-existing limitation: a named active
  M-kind shell's minimum physically-valid label (`"10M"`, n=10) is 3
  characters, exceeding CARD 2's documented `CHARACTER*2` field (see
  `atg.py`'s docstring) -- native silently truncates it to `"10"`,
  dropping the kind letter, which the Python port does not replicate. This
  is the already-documented CARD-2 truncation fragility, newly and
  concretely triggered rather than a new bug; `KLM_CASES`' `m_below_cap`
  works around it by using an aggregate-only (unnamed) M shell instead.
- NOT varied: SGSHL other than the default (-1). See
  constants.ATG_SGSHL_DEFAULT's docstring for why.

Also see the MCONF-uncomputed characterization near the bottom of this
file (renamed from "NORBT-gap"
once the pre-checks showed the gap was never the cause): an
unconditional native defect, kept out of the matching-case sweep entirely
(there is no trustworthy oracle for it -- see that section).
"""

import hashlib
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from ..atg import write_atg
from ..constants import ANGULAR_MOMENTUM_LETTERS, ATG_SGSHL_DEFAULT
from ..csfgen import generate_csf

ATGEN = shutil.which('atgen') or (
    os.path.join(os.environ['ATOMCI_HOME'], 'bin', 'atgen')
    if os.environ.get('ATOMCI_HOME') else None
)
HAVE_ATGEN = bool(ATGEN and os.path.isfile(ATGEN))

# A -fcheck=all -fsanitize=address,undefined build of atgen (atgen.f +
# atlib.f + fdopen.f + fpl90lib.f + clockm.f, gfortran's -fno-automatic
# -ffixed-form -fallow-argument-mismatch plus the sanitizer/bounds-check
# flags -- see scripts/build_san.sh). Not built by
# default CI; only the MCONF-uncomputed characterization test below needs
# it.
ATGEN_SANITIZED = os.environ.get('ATOMCI_SANITIZED_ATGEN')
HAVE_SANITIZED_ATGEN = bool(ATGEN_SANITIZED and os.path.isfile(ATGEN_SANITIZED))

# Staleness guard:
# during the pre-checks, an investigating agent relinked build_san_san0/atgen
# with a temporary MCONF patch and never rebuilt it from clean source. The
# tracked source was clean, so `git status` showed nothing, and the canary
# below silently PASSED (returncode==0) when it should have crashed -- it
# was caught only because a full rerun happened to notice. scripts/build_san.sh
# now writes a sha256 manifest of the exact sources each binary was built
# from (<outdir>/atgen.sha256); re-hash those sources against the working
# tree here and refuse to trust a binary that has drifted. This must FAIL,
# not skip -- a skipped canary is exactly how the original incident slipped
# through.
_REPO_SRC_DIR = Path(__file__).resolve().parents[3] / 'src'


def _sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 16), b''):
            h.update(chunk)
    return h.hexdigest()


def _sanitized_atgen_staleness():
    """None if ATGEN_SANITIZED matches its recorded build manifest, else a
    human-readable reason it doesn't (missing manifest counts as stale --
    a binary built before this guard existed is unverifiable)."""
    if not ATGEN_SANITIZED:
        return None
    manifest = Path(ATGEN_SANITIZED).with_name('atgen.sha256')
    if not manifest.is_file():
        return (
            f'{ATGEN_SANITIZED} has no build manifest ({manifest}) -- '
            'unverifiable, rebuild with scripts/build_san.sh')
    mismatches = []
    for line in manifest.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        expected, _, name = line.partition('  ')
        src_path = _REPO_SRC_DIR / name
        if not src_path.is_file():
            mismatches.append(f'{name}: missing from {_REPO_SRC_DIR}')
            continue
        actual = _sha256_file(src_path)
        if actual != expected:
            mismatches.append(f'{name}: source changed since the sanitizer binary was built')
    if mismatches:
        return (
            f'{ATGEN_SANITIZED} is STALE relative to the working tree -- '
            "rebuild with 'scripts/build_san.sh' before trusting this canary:\n  "
            + '\n  '.join(mismatches))
    return None


ATGEN_SANITIZED_STALE = _sanitized_atgen_staleness()


def shell(label):
    n = int(label[:-1])
    letter = label[-1].upper()
    return {'label': label, 'n': n, 'l': ANGULAR_MOMENTUM_LETTERS.index(letter)}


def shells(labels_csv):
    return [shell(s.strip()) for s in labels_csv.split(',')]


def case(csf, frozen_core, active, outer, refs):
    return {
        'csf': csf,
        'orbital': {
            'frozen_core': shells(frozen_core) if frozen_core else [],
            'active': shells(active),
            'outer': shells(outer),
        },
        'reference': [{'occ': r} for r in refs],
    }


CASES = {
    # F 2P, the golden case: S/P/D/F all present, D/F have no
    # named active shell (aggregate-only).
    'f': case('f.csf', '1S', '2S,2P', '11S,10P,6D,5F', ['2S*2 2P*5']),
    # Carbon-like: smaller occupation, smaller outer space.
    'c_like': case('c.csf', '1S', '2S,2P', '5S,4P,3D', ['2S*2 2P*2']),
    # Closed P subshell: 2P*6 is already at MAXOC(P)=6 capacity -- 2P can
    # donate but nothing can accept into it. Exercises the MAXOC-exhausted
    # acceptor branch.
    'closed_p': case('ne.csf', '1S', '2S,2P', '4S,3P,2D', ['2S*2 2P*6']),
    # Multiple frozen_core shells, D as a genuinely active (occupied) shell
    # rather than aggregate-only, exercising D-kind donors/acceptors with a
    # real named D shell in the table (not just 'ND').
    'd_active': case('sc.csf', '1S,2S', '2P,3D', '6S,5P,4D,3F', ['2P*6 3D*1']),
    # Single active shell, minimal reference and outer space -- smallest
    # WORKING case (no frozen_core at all). NACTE=1 (one active electron,
    # tried first) crashes native atgen -- see
    # test_single_active_electron_crashes_native_atgen below -- so this
    # uses NACTE=2 instead to get real "single active shell" coverage.
    'edge_minimal': case('he.csf', '', '1S', '3S,2P', ['1S*2']),
    # Two active shells of the same kind (2S and 3S both S-type, occupied),
    # to make sure same-kind-multiple-named-shells doesn't confuse the
    # shell table / donor-acceptor loop.
    'same_kind_twice': case('mg.csf', '1S', '2S,3S,2P', '5S,4P,3D', ['2S*2 3S*2 2P*6']),
}


# G/H/I. Built on 'f''s S/P/D/F baseline so only G/H/I are
# new variables. All seven confirmed byte-identical against native atgen
# (gfortran 14.2.0, 2026-08-09) -- including the *_above_cap cases (occ=3
# against the MOCCN=2 cap): neither native's CARD-3 reader nor
# refgen.build_references validates occupation against capacity at parse
# time, so native does not crash or error, it just accepts it, and the
# Python port matches exactly. This settles the "atgen agrees
# with the ported value" question -- the port is correct, and the anomaly
# (G/H/I=2 instead of the 2(2l+1) pattern) is atgen's own unconditional
# hard-coded behaviour (src/atlib.f:156-163, "bug fix by msekiya at
# 2/20/96"), not a Python-side misread.
GHI_CASES = {
    'ghi_at_cap': case('ghi1.csf', '1S', '2S,2P,5G,6H,7I',
                        '11S,10P,6D,5F,3G,3H,3I',
                        ['2S*2 2P*5 5G*2 6H*2 7I*2']),
    'g_below_cap': case('g1.csf', '1S', '2S,2P,5G', '11S,10P,6D,5F,3G',
                         ['2S*2 2P*5 5G*1']),
    'h_below_cap': case('h1.csf', '1S', '2S,2P,6H', '11S,10P,6D,5F,3G,3H',
                         ['2S*2 2P*5 6H*1']),
    'i_below_cap': case('i1.csf', '1S', '2S,2P,7I', '11S,10P,6D,5F,3G,3H,3I',
                         ['2S*2 2P*5 7I*1']),
    # Above the MOCCN=2 cap -- see module docstring: proves agreement, not
    # correctness. Neither implementation validates this at parse time.
    'g_above_cap': case('g3.csf', '1S', '2S,2P,5G', '11S,10P,6D,5F,3G',
                         ['2S*2 2P*5 5G*3']),
    'h_above_cap': case('h3.csf', '1S', '2S,2P,6H', '11S,10P,6D,5F,3G,3H',
                         ['2S*2 2P*5 6H*3']),
    'i_above_cap': case('i3.csf', '1S', '2S,2P,7I', '11S,10P,6D,5F,3G,3H,3I',
                         ['2S*2 2P*5 7I*3']),
}


# K/L/M -- MOCCN=50 departs from 2(2l+1) exactly as G/H/I=2
# does, and is treated as equally suspect until characterized (not just
# the branch that happened to have a source comment). K/L both confirmed
# byte-identical via a genuinely occupied named active shell (n=l+1=8,9,
# single-digit -- fits CARD 2's CHARACTER*2 field). M's minimum valid n is
# 10 (l=9), which makes a named active-M label 3 characters ("10M") and
# hits the pre-existing, already-documented CARD-2 truncation limit (see
# module docstring) -- confirmed empirically here for the first time, but
# it is that known fragility, not a new MOCCN-related bug. m_below_cap
# works around it with an aggregate-only (unnamed) M shell instead, which
# still exercises MOCCN(M)=50 in the shell-table capacity calculation
# (src/atlib.f:710-715, MAXOC = MOCCN * NORBT) without hitting the label
# limit.
KLM_CASES = {
    'k_below_cap': case('k1.csf', '1S', '2S,2P,8K',
                         '11S,10P,6D,5F,3G,3H,3I,3K',
                         ['2S*2 2P*5 8K*4']),
    'l_below_cap': case('l1.csf', '1S', '2S,2P,9L',
                         '11S,10P,6D,5F,3G,3H,3I,3K,3L',
                         ['2S*2 2P*5 9L*4']),
    'm_below_cap': case('m_agg.csf', '1S', '2S,2P',
                         '11S,10P,6D,5F,3G,3H,3I,3K,3L,3M',
                         ['2S*2 2P*6']),
}


# --- 12+ active shells: corrected -- was a misdiagnosis --
#
# This 12-shell case was found to crash native atgen, and it was first
# concluded that 12+ total active shells segfaults
# atgen outright, root cause unknown. It did not: the
# actual cause was `atg.py`'s `write_atg()` CARD 3 writer emitting this
# reference's shell list as a single 73-character line, one character over
# native's CHARACTER*72 CARD-3 buffer (see `atg.py`'s CARD 3 docstring) --
# the exact same class of bug as the CSF-file wrap, just on the INPUT
# side and one character further from the boundary that this case
# happened to land past. Fixed by the same pass that added
# `_wrap_card_tokens` to `write_atg()`; with that fix, this case now runs
# clean (returncode 0) and matches the Python port byte-for-byte -- moved
# here from KNOWN_NATIVE_FAILURES accordingly. A rough, NOT rigorously
# constructed follow-up probe (varying shell count with possibly-invalid
# CARD-1/CARD-2 NORBT-vs-named-shell-count combinations) suggests native
# does have a real, much higher ceiling somewhere around 22-23 shells
# (returncode 152, a graceful "INPUT DATA ARE NOT COMPLETED" abend, not a
# crash) -- NOT characterized or claimed here; a real re-characterization
# needs valid data and is left for a future pass.
#
# "Fixed" above is about write_atg specifically, not ATRGEN: the native
# CARD-3 reader still segfaults on ANY over-72-column line, from any
# source other than write_atg (that native defect is still open; the
# write_atg-side fix is what this comment describes).
MANY_SHELLS_CASES = {
    'many_active_shells': case(
        'many.csf', '',
        '1S,2S,1P,2P,1D,2D,1F,2F,1G,2G,1H,2H',
        '1S,1P,1D,1F,1G,1H',
        ['1S*1 2S*1 1P*1 2P*1 1D*1 2D*1 1F*1 2F*1 1G*1 2G*1 1H*1 2H*1']),
}

# A gapped CARD 1 (S,P,G named -- D omitted). Formerly quarantined as
# MCONF_UNCOMPUTED_CASE / NORBT_GAP_CASE, a sanitizer-confirmed native
# crash: ATDRV (src/atgen.f) called
# ATRGEN with MCONF before MCONF was ever computed -- unconditional,
# present on EVERY atgen invocation, not specific to this gap (the gap
# was just one input among many that reached it; the original "NORBT"
# diagnosis was wrong).
# Fixed (atgen.fpl computes MCONF from MXREF before the
# ATRGEN call). Moved here -- a matching case like any other -- once the
# fix made it one: byte-identical to the Python port, confirmed above.
FIXED_FINDING_CASES = {
    'mconf_uncomputed_gap': case('gap.csf', '1S', '2S,2P,5G', '11S,10P,5F,3G',
                                  ['2S*2 2P*5 5G*2']),
}


# All cases above are confirmed to match byte-for-byte against native
# atgen; combined here so one parametrized test covers all of them.
ALL_MATCHING_CASES = {**CASES, **GHI_CASES, **KLM_CASES, **MANY_SHELLS_CASES,
                       **FIXED_FINDING_CASES}


# --- Gap == explicit-zero equivalence ---------------------------------------
#
# Closed, ruled out: a gapped CARD 1 (a kind skipped mid-range,
# e.g. 'S,P,G' with D omitted) reads NORBT(D) as an implicit zero -- via
# -fno-automatic's guaranteed static/BSS zero-init -- and this is
# byte-for-byte identical to naming the same kind explicitly at zero
# ('S,P,0D,G'). This equivalence is *load-bearing*: it's what makes the
# "not an independent defect" conclusion valid, and it's also the
# reason this project decided against a gap-rejection lint rule --
# gaps are legal, well-defined input, not a defect to
# guard against. Nothing before this pinned that equivalence as a
# permanent regression test; the original investigation used a one-off
# scratch build. Re-verified here directly against the fully-patched
# atgen (the MCONF fix, the CARD validations, the loop
# hardening, all below) -- the original investigation used an MCONF-patched
# scratch build specific to that pre-check, not the final tree.
GAP_CASE = case('gap2.csf', '1S', '2S,2P,5G', '11S,10P,5F,3G', ['2S*2 2P*5 5G*2'])
EXPLICIT_ZERO_CASE = case('exp2.csf', '1S', '2S,2P,5G', '11S,10P,0D,5F,3G',
                           ['2S*2 2P*5 5G*2'])


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_gap_and_explicit_zero_produce_identical_output(tmp_path):
    # Distinct .csf filenames (gap2.csf / exp2.csf), so both can safely
    # share one tmp_path.
    gap_csf = _native_csf(GAP_CASE, tmp_path)
    exp_csf = _native_csf(EXPLICIT_ZERO_CASE, tmp_path)
    assert gap_csf == exp_csf, (
        'a gapped CARD 1 no longer produces byte-identical output to its '
        'explicit-zero-token equivalent -- '
        're-examine before trusting this equivalence, which is what '
        'justifies not having a gap-rejection lint rule')


def _run_native(data, tmp_path, atgen=None):
    """Run native atgen on `data` (any case() dict) via a generated .atg.
    Returns the subprocess.CompletedProcess -- callers decide how to
    interpret returncode/output. Shared by the differential sweep and the
    property-based sweep (test_property_sweep.py)."""
    atg_path = tmp_path / f"{data['csf'].rsplit('.', 1)[0]}.atg"
    atg_path.write_text(write_atg(data))
    with open(atg_path) as f:
        return subprocess.run([atgen or ATGEN], stdin=f, cwd=str(tmp_path),
                               capture_output=True, text=True)


def _native_csf(data, tmp_path):
    """Run native atgen and return the CSF text it wrote, asserting success
    -- for cases known/expected to succeed."""
    result = _run_native(data, tmp_path)
    assert result.returncode == 0, result.stdout
    return (tmp_path / data['csf']).read_text()


# --- CARD 1 strictly-ascending validation (fixed) ---------------------
#
# NKIND (count of distinct symmetries) was
# derived from whichever CARD-1 token ATREAD matched *last*, not a running
# maximum, so out-of-order tokens silently produced a wrong NKIND. Fixed
# by rejecting non-ascending CARD-1 order outright (src/atlib.f, STOP 921).
#
# No new lint.py rule needed to mirror this: atg.py's write_atg() already
# sorts orbital.outer defensively by symmetry (`l`) before ever rendering
# CARD 1 (see its docstring, and the sort at line ~168) -- there is no
# schema an atinputs user can author that reaches native with an
# out-of-order CARD 1. That pre-existing defensive sort *is* the mirror;
# this test instead confirms the native fix directly, by hand-swapping a
# freshly-rendered CARD-1 line's token order (bypassing write_atg's sort,
# which no atinputs-generated .atg could do to itself).
@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_card1_nonascending_order_rejected_by_native(tmp_path):
    data = case('x.csf', '1S', '2S,2P', '11S,10P,6D,5F', ['2S*2 2P*5'])
    atg_text = write_atg(data)
    assert ' 11S 10P 6D 5F )))' in atg_text, (
        'CARD 1 line format changed -- update this test\'s swap below')
    # D(3) before P(2) before S(1): descending, not just out of order.
    bad_atg = atg_text.replace(' 11S 10P 6D 5F )))', ' 6D 10P 11S 5F )))')
    atg_path = tmp_path / 'x.atg'
    atg_path.write_text(bad_atg)
    with open(atg_path) as f:
        result = subprocess.run([ATGEN], stdin=f, cwd=str(tmp_path),
                                 capture_output=True, text=True)
    assert result.returncode != 0, (
        'expected native atgen to reject non-ascending CARD 1 order '
        '(fixed); it did '
        'not -- the fix may have regressed')
    assert 'ASCENDING' in result.stdout.upper()


# --- CARD 3 >72-column validation (fixed) ------------------------------
#
# atg.py's write_atg() already wraps CARD 3 at 72 columns --
# no schema an atinputs user can author reaches native with an unwrapped,
# over-length CARD-3 line, same shape as the CARD-1 ordering case above. To
# exercise the native fix directly, take a case whose reference IS wrapped
# across two physical records by the writer and rejoin them into one --
# reproducing the exact over-length line this defect was about, bypassing
# the wrap the way no legitimate atinputs output could.
@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_card3_over_72_columns_rejected_by_native(tmp_path):
    data = case(
        'many.csf', '',
        '1S,2S,1P,2P,1D,2D,1F,2F,1G,2G,1H,2H',
        '1S,1P,1D,1F,1G,1H',
        ['1S*1 2S*1 1P*1 2P*1 1D*1 2D*1 1F*1 2F*1 1G*1 2G*1 1H*1 2H*1'])
    atg_text = write_atg(data)
    wrapped = (' 1S*1) 2S*1) 1P*1) 2P*1) 1D*1) 2D*1) 1F*1) 2F*1) 1G*1) 2G*1) '
               '1H*1)\n 2H*1))\n')
    assert wrapped in atg_text, (
        "CARD 3 wrap format changed -- update this test's rejoin below")
    rejoined = wrapped.replace('\n', '')  # -> one 73-column physical line
    bad_atg = atg_text.replace(wrapped, rejoined + '\n')
    atg_path = tmp_path / 'many.atg'
    atg_path.write_text(bad_atg)
    with open(atg_path) as f:
        result = subprocess.run([ATGEN], stdin=f, cwd=str(tmp_path),
                                 capture_output=True, text=True)
    assert result.returncode != 0, (
        'expected native atgen to reject a >72-column CARD 3 line '
        '(fixed); it did '
        'not -- the fix may have regressed')
    assert '72 COLUMNS' in result.stdout.upper()


def assert_native_crashes(data, tmp_path):
    """Assert native atgen crashes on `data`, and that the Python port does
    NOT (documenting the divergence, not just the crash). Shared helper for
    the KNOWN_NATIVE_FAILURES registry below -- proves each quarantined
    precondition still fails today, catching the day it silently stops
    crashing (e.g. after an upstream native fix), which would mean the
    quarantine/lint rule mirroring it needs revisiting."""
    result = _run_native(data, tmp_path)
    assert result.returncode != 0, (
        'expected native atgen to crash on this input; it did not '
        '(returncode=0) -- this precondition may no longer apply, '
        'update KNOWN_NATIVE_FAILURES and the lint rule mirroring it')
    generate_csf(data, ATG_SGSHL_DEFAULT)  # ... while the Python port completes


def assert_native_rejects(data, tmp_path, expected_message):
    """Assert native atgen cleanly rejects `data` with `expected_message`
    in its output (a specific, input-validation STOP -- not a raw crash),
    and that the Python port still completes. For findings closed via
    input validation: distinguishes a controlled
    rejection from KNOWN_NATIVE_FAILURES' still-open crashes -- a fixed
    finding's test must assert the specific error, not
    just any nonzero returncode."""
    result = _run_native(data, tmp_path)
    assert result.returncode != 0, (
        'expected native atgen to reject this input; it did not '
        '(returncode=0) -- this precondition may no longer apply, '
        'update KNOWN_NATIVE_REJECTIONS and the lint rule mirroring it')
    assert expected_message in result.stdout, (
        f'expected {expected_message!r} in native atgen output, got:\n'
        f'{result.stdout}')
    # ATPRNT's "SECOND ORDER SPACE" printer was hardened
    # against a runaway loop that findings 3 and 4 both used to reach.
    # Assert -- not just observe once -- that these known triggers are
    # still stopped by input validation and never reach that loop at all;
    # if the guard's own effects (e.g. a clean, silent skip) ever showed
    # up here instead of the specific rejection above, that would mean
    # validation had a hole the hardening was papering over.
    assert 'SECOND ORDER SPACE' not in result.stdout, (
        'this input reached ATPRNT\'s "SECOND ORDER SPACE" printer -- '
        'input validation no longer stops it before the loop, '
        'which the loop hardening alone should not be relied on '
        'to cover')
    generate_csf(data, ATG_SGSHL_DEFAULT)  # ... while the Python port completes


# Preconditions confirmed to crash native atgen. Each is a genuine native
# finding, not a Python-port bug -- the Python port
# completes without error on all of them, which is itself the documented
# gap (mirror these as lint rules so the port rejects them too).
#
# Currently empty -- every entry that was ever here has been fixed (moved
# to KNOWN_NATIVE_REJECTIONS below). This is expected
# and not a bug: test_known_native_failures below correctly reports
# "skipped: got empty parameter set" rather than failing. Left in place
# (not deleted) in case a new native crash is found later -- this is
# where it would go.
KNOWN_NATIVE_FAILURES = {
    # NOTE: 'single_active_electron' (NACTE=1) USED to be here. Fixed: native
    # now cleanly
    # rejects NACTE=1 instead of running ATPRNT's "SECOND ORDER SPACE"
    # loop away -- see KNOWN_NATIVE_REJECTIONS below.

    # NOTE: 'nonconsecutive_same_kind_numbering' (1S,3S -- 2S skipped) USED
    # to be here. Fixed: native now cleanly rejects non-consecutive same-kind CARD-2 numbering
    # instead of crashing (or, for its silent-mismatch sibling, silently
    # producing a wrong result) -- see KNOWN_NATIVE_REJECTIONS below.

    # NOTE: 'many_active_shells' (12+ shells "segfaults") USED to be here.
    # It was a misdiagnosis of the CARD-3 72-column write_atg bug, not a
    # real shell-count limit -- see MANY_SHELLS_CASES above, near
    # ALL_MATCHING_CASES, for the corrected story.
}


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
@pytest.mark.parametrize('name', sorted(ALL_MATCHING_CASES))
def test_matches_native_atgen(name, tmp_path):
    data = ALL_MATCHING_CASES[name]
    native = _native_csf(data, tmp_path)
    mine = generate_csf(data, ATG_SGSHL_DEFAULT)
    assert mine == native


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
@pytest.mark.parametrize('name', sorted(KNOWN_NATIVE_FAILURES))
def test_known_native_failures(name, tmp_path):
    assert_native_crashes(KNOWN_NATIVE_FAILURES[name], tmp_path)


# Preconditions fixed via input validation: native
# cleanly rejects these with a specific error rather than crashing or
# silently mishandling them. Distinct from KNOWN_NATIVE_FAILURES (still
# genuinely open crashes) -- a fixed finding's test must
# assert the specific rejection, not just "still fails somehow."
KNOWN_NATIVE_REJECTIONS = {
    # two named shells of the SAME kind
    # with NON-CONSECUTIVE principal quantum numbers (1S, 3S -- 2S
    # skipped). One formula (src/atlib.f's IA mis-indexing) explained both
    # this crash case AND its silent-mismatch sibling below -- the fix
    # (a consecutive-numbering check where NTOPN is computed, ATRGEN)
    # closes both the same way, confirmed by both hitting the identical
    # STOP 922 / 'NOT CONSECUTIVELY' message.
    'nonconsecutive_same_kind_numbering_crash':
        (case('nc1.csf', '', '1S,3S', '1S', ['1S*1 3S*1']), 'NOT CONSECUTIVELY'),
    'nonconsecutive_same_kind_numbering_mismatch':
        (case('nc2.csf', '', '1S,3S', '1S', ['1S*2 3S*1']), 'NOT CONSECUTIVELY'),

    # a reference with exactly one
    # active/valence electron (NACTE=1) used to run ATPRNT's "SECOND ORDER
    # SPACE" printer into a runaway loop (I.EQ.NDCON exit skipped on first
    # entry when NSCON=NDCON going in -- NACTE=1 leaves no room for a
    # double excitation, so NSCON=NDCON going in). NACTE=2 (case
    # 'edge_minimal' above) works fine, so the boundary is specifically
    # NACTE==1 -- narrow and exact, does NOT generalize to "any single
    # shell at occupation 1" (an early avoidance rule tried that and was
    # wrong -- the real cause of the example that misled it was
    # non-consecutive shell numbering, not row-1 occupation). Fixed by
    # checking NACTE itself, right where it's computed
    # (src/include/ATPRNT's PRESET), not by broadening the precondition.
    'single_active_electron':
        (case('h.csf', '', '1S', '3S,2P', ['1S*1']), 'NACTE=1'),
}


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
@pytest.mark.parametrize('name', sorted(KNOWN_NATIVE_REJECTIONS))
def test_known_native_rejections(name, tmp_path):
    data, expected_message = KNOWN_NATIVE_REJECTIONS[name]
    assert_native_rejects(data, tmp_path, expected_message)


# --- M-kind CARD-2 label truncation: FIXED, reject on both sides --------
#
# A named active M shell's lowest physically-valid label is "10M" (n=10,
# l=9) -- 3 characters, exceeding CARD 2's documented CHARACTER*2 field
# (NAMSL, src/atlib.f). Native used to silently truncate it to "10",
# dropping the kind letter; the Python port did not replicate this
# (a genuine fidelity gap, first concretely triggered by the K/L/M
# characterization sweep). Decision: reject on both sides rather
# than have the port replicate a truncation bug -- this shell simply
# cannot be named on CARD 2 under the native format, on either side of
# the .atg boundary. Native gets the same style of input validation as
# the other CARD checks (a new error stop in src/atlib.f, generalized to
# any CARD-2 label over 2 characters, not just M specifically -- M is
# just the kind for
# which this is unavoidable, since its lowest valid label already needs
# two digits). The port's lint.py gets a matching rule.
M_LABEL_TRUNCATION_CASE = case(
    'm3.csf', '1S', '2S,2P,10M', '11S,10P,6D,5F,3G,3H,3I,3K,3L,3M',
    ['2S*2 2P*5 10M*4'])


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_m_named_shell_label_rejected_by_native(tmp_path):
    result = _run_native(M_LABEL_TRUNCATION_CASE, tmp_path)
    assert result.returncode != 0, (
        'expected native atgen to reject the 3-character "10M" label '
        '(fixed); it did '
        'not -- the fix may have regressed')
    assert '2-CHARACTER FIELD' in result.stdout.upper()


def test_m_named_shell_label_rejected_by_lint():
    from ..lint import _csf_lint
    data = dict(M_LABEL_TRUNCATION_CASE)
    data['ctrl'] = {}
    findings = []
    _csf_lint(data, findings)
    messages = [f.message for f in findings if f.severity == 'error']
    assert any('10M' in m and '2-character' in m for m in messages), (
        f"expected an error flagging '10M' exceeding the 2-character "
        f"CARD-2 field; got: {messages}")


# --- Same-kind non-consecutive numbering: FIXED -------------------------
#
# Found by the property sweep, not the hand-picked cases (every hand-picked
# case already satisfies this by construction, e.g. 'same_kind_twice''s
# 2S,3S). Native ATRGEN's CARD-3 reference-token parser maps a shell label
# to its shell-table row via `IA=NORTS(1,L)+N-L-NTOPN(L)` (src/atlib.f),
# which reduces to `NORTS(1,L) + (N - N_first_named_shell_of_kind_L)` --
# i.e. it assumes a kind's named shells occupy consecutive table rows in
# the same order as their consecutive N values. A gap (e.g. 1S then 3S,
# skipping 2S) breaks that assumption: the second token's computed row
# index lands too far over, mis-indexing into whatever is actually there.
#
# This produced two different symptoms depending on which specific
# occupations ended up written to the wrong row: a segfault when the
# resulting corruption hit an invalid access, or a silent byte-mismatch
# when it didn't -- while the consecutive equivalents (1S,2S) were exact
# and crash-free in both occupation orderings. A first pass at explaining
# the crash case mistakenly generalized this into a "row-1 occupation"
# rule instead (see test_property_sweep.py's deck() for the correction).
#
# Fixed by validating consecutiveness where NTOPN is computed (ATRGEN,
# src/atlib.f) -- both symptoms shared the one root cause, so the one fix
# closes both; see KNOWN_NATIVE_REJECTIONS above for the cases and test.


# --- 72-column line-wrap: fixed ---------------------------------------------
#
# Found by bisecting the SAME property-sweep failure that led to the
# many_active_shells case above (MANY_SHELLS_CASES, near
# ALL_MATCHING_CASES -- its crash turned out to be a different bug, in
# write_atg, not this one). Native's config-line printer (ATPRNT)
# wraps output at exactly 72 columns, splitting a token mid-way (e.g.
# "8I*1" -> "8I" on one line, "     ** 1   ))" continuing on the next,
# Fortran fixed-form card-width convention: IQPUTC/IQPUTI check
# `col + width - 1 > 72` on every write, src/fpl90lib.f:160-166,189-195).
# csfgen/format.py's Card now reproduces this exactly (the same
# IQPUTC/IQLSET/IQXSET/IQCSET line-buffer model it already ported for
# everything else was simply missing this one check) -- see format.py's
# module docstring for the mechanism and the byte-for-byte trace against
# this exact case. Kept as its own dedicated test (not folded into
# ALL_MATCHING_CASES/test_matches_native_atgen above, which is defined --
# and its parametrize list evaluated -- earlier in this file) because it
# additionally pins that a wrap genuinely occurs on both sides, not just
# that the two sides agree.
LINE_WRAP_CASE = case(
    'wrap11.csf', '',
    '1S,2S,1P,2P,1D,2D,1F,2F,1G,2G,1H',
    '1S,1P,1D,1F,1G,1H',
    ['1S*1 2S*1 1P*1 2P*1 1D*1 2D*1 1F*1 2F*1 1G*1 2G*1 1H*1'])


@pytest.mark.skipif(not HAVE_ATGEN, reason='native atgen binary not available')
def test_long_config_line_wraps_and_matches_native(tmp_path):
    native = _native_csf(LINE_WRAP_CASE, tmp_path)
    mine = generate_csf(LINE_WRAP_CASE, ATG_SGSHL_DEFAULT)
    assert any(len(line) == 72 for line in native.splitlines()), (
        'native atgen no longer wraps this 11-shell config at 72 columns -- '
        're-examine the wrap threshold')
    assert any(len(line) == 72 for line in mine.splitlines()), (
        'the Python port no longer emits a 72-column line here -- the '
        '72-column wrap in csfgen/format.py.Card.putc may have regressed')
    assert mine == native


# --- MCONF-uncomputed case: FIXED ----------------------------------------
#
# This used to be a two-test sanitizer canary here (NORBT_GAP_CASE, then
# MCONF_UNCOMPUTED_CASE after a later rename) pinning a crash whose
# root cause turned out to be wrong twice over (an uncomputed MCONF
# passed to ATRGEN before ATDRV ever assigns it, unconditional on every
# atgen invocation, not gap-specific). Now that this has been fixed
# in atgen.fpl, there is nothing left to canary at the crash level: the
# case moved to FIXED_FINDING_CASES above and is covered by
# test_matches_native_atgen like any other matching case (byte-identical
# to the Python port, confirmed directly against the fix). The one thing
# ALL_MATCHING_CASES doesn't reach is the sanitizer build specifically --
# kept below as a standalone regression pin against the exact defect
# recurring under strict bounds-checking, not just "output happens to
# still be correct."
FIXED_FINDING_MCONF_CASE = FIXED_FINDING_CASES['mconf_uncomputed_gap']


@pytest.mark.skipif(not HAVE_SANITIZED_ATGEN,
                     reason='sanitized atgen binary not available (set ATOMCI_SANITIZED_ATGEN)')
def test_mconf_uncomputed_runs_clean_under_sanitizer(tmp_path):
    """Regression pin for the MCONF-uncomputed defect (fixed): this used to
    crash under -fcheck=all -fsanitize=address,undefined
    (NCONF's dimension-2 bound computed to 0); confirms it no longer does."""
    # Staleness guard: fail loudly, don't skip, on a binary
    # that has drifted from the working tree -- see ATGEN_SANITIZED_STALE's
    # definition above for the incident that motivated this.
    if ATGEN_SANITIZED_STALE:
        pytest.fail(ATGEN_SANITIZED_STALE)
    result = _run_native(FIXED_FINDING_MCONF_CASE, tmp_path, atgen=ATGEN_SANITIZED)
    assert result.returncode == 0, result.stderr
