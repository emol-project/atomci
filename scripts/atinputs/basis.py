"""Read a native GTO basis file (format="atomci") -> NSYM/NBF/NOB/MPOB.

Ported from the native reader, `GINPUT` (src/cinewx.f), reached from
AIMAIN's NTYPE=2 (GTO) path:

- The file is a free-token stream, not fixed columns: a shell header
  (angular-momentum letter, primitive count NTERM, scale factor) is
  followed by NTERM exponent tokens and NTERM coefficient tokens, and
  tokens may wrap across physical lines.
- A physical line whose first character is '#' or '"' is a comment: the
  whole line (and every token on it) is dropped, contributing nothing.
- Each header — regardless of NTERM — contributes exactly one basis
  function to NBF of its symmetry (contraction does not multiply NBF).
- The basis list ends at a token starting with ')'.

`read_basis` returns NOB == NBF; `with_orbitals` gives the smaller NOB that
sugar.py derives from orbital.outer (fewer correlating orbitals than the
basis has). An STF file (&AI NTYPE=1) is read by `_read_stf`.

Coverage note: samples/native/f.bas alone exercises only the
'"'-disabled-line and contraction-counting branches (it has no '#'-disabled
lines, malformed headers, or unknown letters). The tests/test_basis.py
synthetic fixtures exist specifically to reach the branches f.bas doesn't:
'#' comments, truncated headers, non-numeric NTERM, an unknown letter (one
genuinely absent from ANGULAR_MOMENTUM_LETTERS, not just an unlikely one —
see the test_unknown_letter_is_error docstring for why that distinction
mattered), a symmetry gap, an empty file, and a missing-terminator file
(tolerated: the reader just stops at end-of-tokens, since no in-tree sample
was found that omits the ')' terminator entirely).
"""

import re
from dataclasses import dataclass

from .constants import ANGULAR_MOMENTUM_LETTERS


class BasisError(Exception):
    pass


@dataclass
class Basis:
    nsym: int
    nbf: list  # NBF per symmetry, indexed 0..nsym-1 (symmetry 1..nsym)
    nob: list  # == nbf (no per-symmetry orbital subset support yet)
    mpob: list  # list of lists, one per symmetry, descending NOB[i]..1


def _tokenize(path):
    tokens = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            if line and line[0] in ('#', '"'):
                continue
            tokens.extend(line.split())
    return tokens


def _from_counts(path, nbf_by_symmetry):
    if not nbf_by_symmetry:
        raise BasisError(f"{path}: no shells found")
    nsym = max(nbf_by_symmetry)
    for k in range(1, nsym + 1):
        if k not in nbf_by_symmetry:
            raise BasisError(f"{path}: symmetry {k} has no shells but a higher one does")
    nbf = [nbf_by_symmetry[k] for k in range(1, nsym + 1)]
    nob = list(nbf)
    mpob = [list(range(n, 0, -1)) for n in nob]
    return Basis(nsym=nsym, nbf=nbf, nob=nob, mpob=mpob)


_STF_TYPE_RE = re.compile(r'^(\d+)([A-Za-z])$')


def _read_stf(path):
    """A native STF basis file (&AI NTYPE=1): pairs of orbital type and
    exponent ('2P 5.509'), free format, ending at a token starting with ')'.
    Ported from the reading loop of AIISTF (src/aiistf.f), which takes the
    principal quantum number and the l letter with READIA, then the
    exponent with READFA; the same comment lines as GINPUT are skipped
    (READIA drops lines starting with '#' or '"'). Each pair is one basis
    function of symmetry l+1."""
    tokens = _tokenize(path)
    nbf_by_symmetry = {}
    i, n = 0, len(tokens)
    while i < n:
        token = tokens[i]
        if token.startswith(')'):
            break
        m = _STF_TYPE_RE.match(token)
        if not m:
            raise BasisError(f"{path}: expected an orbital type like '2P', got '{token}'")
        letter = m.group(2).upper()
        if letter not in ANGULAR_MOMENTUM_LETTERS:
            raise BasisError(f"{path}: unknown angular-momentum letter in '{token}'")
        if i + 1 >= n:
            raise BasisError(f"{path}: orbital type '{token}' has no exponent")
        try:
            float(tokens[i + 1])
        except ValueError:
            raise BasisError(f"{path}: expected an exponent after '{token}', "
                             f"got '{tokens[i + 1]}'")
        symmetry = ANGULAR_MOMENTUM_LETTERS.index(letter) + 1
        nbf_by_symmetry[symmetry] = nbf_by_symmetry.get(symmetry, 0) + 1
        i += 2
    return _from_counts(path, nbf_by_symmetry)


def read_basis(path, ntype=2):
    """ntype: &AI NTYPE -- 1 STF (`_read_stf`), anything else the GTF
    format of GINPUT below."""
    if ntype == 1:
        return _read_stf(path)
    tokens = _tokenize(path)
    nbf_by_symmetry = {}  # 1-based symmetry index (l+1) -> count
    i, n = 0, len(tokens)
    while i < n:
        ang = tokens[i]
        if ang.startswith(')'):
            break
        i += 1
        if i + 1 >= n:
            raise BasisError(f"{path}: truncated shell header at token {i}")
        try:
            nterm = int(tokens[i])
        except ValueError:
            raise BasisError(f"{path}: expected primitive count, got '{tokens[i]}'")
        i += 1
        i += 1  # scale factor, unused for NBF/NOB/MPOB
        letter = ang.upper()
        if letter not in ANGULAR_MOMENTUM_LETTERS:
            raise BasisError(f"{path}: unknown angular-momentum letter '{ang}'")
        symmetry = ANGULAR_MOMENTUM_LETTERS.index(letter) + 1  # l+1, 1-based
        nbf_by_symmetry[symmetry] = nbf_by_symmetry.get(symmetry, 0) + 1
        i += 2 * nterm  # NTERM exponents, then NTERM coefficients

    return _from_counts(path, nbf_by_symmetry)


def with_orbitals(basis, nob):
    """The same basis with NOB orbitals per symmetry (NOB[i] <= NBF[i]) and
    the matching MPOB, descending NOB[i]..1 as for NOB == NBF."""
    return Basis(nsym=basis.nsym, nbf=list(basis.nbf), nob=list(nob),
                 mpob=[list(range(k, 0, -1)) for k in nob])
