"""`.atg` (native `atgen` input) reader and writer.

`atgen` (`src/atgen.f` `PROGRAM ATMAIN`, helpers in `src/atlib.f`) reads a
`.atg` file through the call chain `FDOPEN(5)` [OPEN/END header] ->
`ATDRV` -> `ATREAD` [CARD 1, 2] -> `ATRGEN` [CARD 3] -> `ATSGEN` ->
`ATDGEN` -> `ATCHCK` -> `ATPRNT` [CARD 4, 5, 6, *and* the actual CSF
generation/print]. Every fact below was confirmed by reading that source
directly (line numbers cited); nothing here is inferred from the sample
`.atg` files alone — see the "not required by the grammar" notes for where
`samples/native/f.atg`/`fpt.atg`'s own formatting is cosmetic/hand-typed rather
than something the reader actually requires.

## OPEN/END header

Shared with the main CI driver (`src/fdopen.f`, `SUBROUTINE FDOPEN`), not
atgen-specific. Comment rule: first *non-blank* character (leading blanks
skipped) equal to `"`, `#`, or `/` discards the whole line. The literal
word `OPEN` is decorative — any non-`END`, non-comment line is parsed as an
open-directive by keyword search (`UNIT=`, `FILE=`, ...), so `OPEN` could be
omitted. `END` (left-trimmed, first 3 chars, case-sensitive) ends the
header.

## CARD 1 — correlating (virtual) orbitals, one count per symmetry letter

Read by `ATREAD` (`src/atlib.f:117-145`), `(72A1)` format, columns 1-72.
Comment rule for CARD 1-3: **strict column 1**, `'` or `"` (not `#`).
Tokens are `<digits><letter>` (e.g. `11S`) scanned free-form; the digits are
the literal orbital *count* for that symmetry (`NORBT(letter) = digits`),
not a specific quantum number. Terminated by the literal substring `)))`
anywhere on the line (search via `INDEX`, so it need not be preceded by a
space); if absent, the card continues on the next physical line.

**Fragility, confirmed from source (`src/atlib.f:126-147`)**: `NKIND` (the
count of distinct symmetries) is computed from whichever token was matched
*last*, not a running maximum — so CARD 1's tokens must be listed in
strictly ascending symmetry order (S, P, D, F, ...) or `NKIND` silently
comes out wrong. The writer below sorts defensively; do not rely on the
`.inp`'s `orbital.outer` key order.

## CARD 2 — occupied/active shells

Same `ATREAD` call, `NSTEP.EQ.2` branch (`src/atlib.f:164-198`). Tokens are
literal shell labels (e.g. `2S`), captured verbatim into a `CHARACTER*2`
field — **a label needing 3+ characters truncates silently**. Terminated by
`)))`. For every symmetry present in CARD 1 but *not* named here, `ATREAD`
itself appends a synthetic placeholder shell (`"N"+letter`, e.g. `"ND"`) —
the writer must NOT emit these; they are implicit.

## CARD 3 — reference configuration(s)

Read by `ATRGEN` (`src/atlib.f:725-784`), format `(A)` into a `*72` buffer,
same column-1 `'`/`"` comment rule. Grammar: `<label><letter>*<count>)` per
shell (e.g. `2S*2)`); a *single* `)` separates shells within one reference
configuration, a *double* `))` (the shell's own `)` immediately followed by
another) ends that reference configuration (and starts a new one, unless it
also coincides with the card-terminating `)))`). Spans multiple physical
lines if `)))` isn't found on the current line — genuinely supported, not
just tolerated: each `READ` refills the `*72` buffer and rescans from
column 1, so a new record starting mid-token-stream works fine.

**Each individual line is still hard-capped at 72 columns, and a token must
not straddle two lines.** `TIT72` is `(A)`-read into a fixed `*72` buffer,
so column 73+ of an over-length line is silently dropped before any
tokenizing happens — the loop that hunts for a shell token's closing `)`
(`src/atlib.f:748-751`) stops at `NA` (72, absent an in-line `)))`) without
ever restarting the search on the next record, so a token cut off there is
just lost, not resumed. Confirmed to escalate to a genuine crash, not a
graceful "silently drop one token": a `.atg` with a single 73-character
CARD 3 line segfaults real `atgen` (gfortran 14.2.0, Debian 14.2.0-19),
because the truncation also eats the reference-closing `))`, leaving
`ATRGEN` still "inside" an unterminated reference when it moves on to
CARD 4's data. The writer below wraps CARD 3 at 72 columns,
breaking only between complete tokens, to stay inside the continuation
mechanism this section already relies on rather than the crash path.

This is a defect in `ATRGEN` itself, still
**open** — the wrap below only keeps *this writer* from producing the
73-column line that triggers it (fixed on the writer side). It does not touch
`ATRGEN`, so any other `.atg` producer (hand-written, another tool) can
still segfault native `atgen` with an over-length CARD 3 line today.

## CARD 4 — order of coupling

Read by `ATPRNT`'s "PRESET" step (`src/atgen.f:424-489`) — i.e. only once
generation has otherwise run, continuing the *same* unit-5 stream right
after CARD 3. Comment rule changes here: column 1 `"` only (not `'`).
Tokens are 2-char shell labels, terminated by the *first single* `)` (not
`)))`). If the token count doesn't match the number of valence shells,
the new order is **silently discarded** (no error) and the default
(`CARD 2`'s natural order) is kept — so getting this card wrong doesn't
break anything, it just gets ignored.

## CARD 5 — closed (frozen-core) shells

Same `ATPRNT` step (`src/atgen.f:500-511`). **Not tokenized at all** — the
line is truncated at the first `)` if present (otherwise used whole) and
copied verbatim into the generated CSF text. Free-form text, not a parsed
list.

## CARD 6 — SGSHL option flag

Same `ATPRNT` step (`src/atgen.f:545`, `READ (CARDIN,*)SGSHL` — cited by statement,
not just the line, per this project's anchor-citation convention;
no `.fpl` counterpart to prefer here, unlike most other `src/*.f`
citations in this project — `src/atgen.fpl` is a 268-line fragment covering only
`ATDRV`/`ATCHCK`, with no `ATPRNT` and no `SGSHL` in it at all). The whole line is
parsed as one Fortran integer (`SGSHL`). Not a mere terminator, despite
sometimes being grouped with "frozen core / terminator" cards — it has real
semantics: `SGSHL > 0` names a specific shell index for singlet-coupling
annotation; `SGSHL < -9` gates whether a second-order (double-excitation)
space is generated at all; `SGSHL < -99` additionally skips the
first-order (single-excitation) space. Both worked samples use `-1`
(plain SD-CI: generate both spaces, no singlet annotation) — see
`constants.ATG_SGSHL_DEFAULT`.

## What samples/native/f.atg's formatting is NOT specification

`samples/native/f.atg`/`fpt.atg` pad every line to a fixed ~80-column width — a
hand-typed, card-punch-era styling choice. None of that trailing padding is
required by the grammar above (free tokenization within columns 1-72,
terminator search via `INDEX`, not fixed columns). The writer below does
not reproduce it; the verification target is that the *generated* `.atg`
round-trips through the real `atgen`
binary to the same CSF content, not that it matches the sample
byte-for-byte. The one exception is CARD 5's specific 3-space *leading*
indent, which is reproduced deliberately (see the comment at its
emission site below) because that whitespace is not cosmetic — it is
copied verbatim into the generated CSF text.
"""

import re
from dataclasses import dataclass, field

from . import constants
from .constants import ANGULAR_MOMENTUM_LETTERS
from .csfgen.refgen import card5_closed_shell_text
from .sugar import parse_occ


def _wrap_card_tokens(tokens, max_col=72):
    """Pack space-separated tokens into lines of at most `max_col`
    characters (a leading space on every line, matching CARD 1/2/3's
    existing single-line convention), never splitting a token across two
    lines -- see CARD 3's docstring above for why that specifically must
    be avoided here (unlike the CSF file's ATPRNT wrap, this reader has no
    mid-token continuation mechanism, only a between-record one)."""
    lines = []
    current = []
    current_len = 1  # the leading space every line gets
    for token in tokens:
        grown = current_len + len(token) + (1 if current else 0)
        if current and grown > max_col:
            lines.append(' ' + ' '.join(current))
            current, current_len = [token], 1 + len(token)
        else:
            current.append(token)
            current_len = grown
    if current:
        lines.append(' ' + ' '.join(current))
    return lines


def write_atg(data):
    """data: schema.validate()'s output (same shape sugar.build() takes).
    Returns .atg file text."""
    lines = [
        f"OPEN UNIT={constants.ATG_CSF_UNIT} FILE={data['csf']}",
        'END',
    ]

    outer = sorted(data['orbital'].get('outer', []), key=lambda s: s['l'])
    card1 = ' '.join(f"{s['n']}{ANGULAR_MOMENTUM_LETTERS[s['l']]}" for s in outer)
    lines.append('" INPUT DATA OF ATGEN.  # OF CORRELATING ORBITALS.')
    lines.append(f' {card1} )))')

    active = data['orbital'].get('active', [])
    card2 = ' '.join(s['label'] for s in active)
    lines.append('" SHELL ( OCCUPIED ORBITALS )')
    lines.append(f' {card2} )))')

    lines.append('" REF.')
    ref_tokens = []
    for cfg in data['reference']:
        shells = parse_occ(cfg['occ'])
        for i, (label, count) in enumerate(shells):
            closer = '))' if i == len(shells) - 1 else ')'
            ref_tokens.append(f'{label}*{count}{closer}')
    lines.extend(_wrap_card_tokens(ref_tokens))
    lines.append(' )))')

    card4 = ' '.join(s['label'] for s in active)
    lines.append('" ORDER OF COUPLING')
    lines.append(f' {card4} )))')

    lines.append(card5_closed_shell_text(data['orbital'].get('frozen_core', [])))

    lines.append(f' {constants.ATG_SGSHL_DEFAULT}')

    return '\n'.join(lines) + '\n'


class AtgReadError(Exception):
    pass


@dataclass
class AtgData:
    """Recovered .atg content, for round-trip testing of write_atg().

    Scope note: this reader is intentionally narrower than the native
    ATREAD/ATRGEN/ATPRNT — e.g. it doesn't replicate the CARD 1 "NKIND
    from the last token" fragility, or the exact "grab 2 characters
    ignoring embedded blanks" CARD 4 tokenizer, or the case where a
    reference-closing '))' and the card-terminating ')))' overlap on the
    same characters (write_atg never produces that form — it always puts
    the ')))' terminator on its own line/segment). It is faithful enough
    to parse both write_atg()'s own output and samples/native/f.atg & fpt.atg
    correctly (tested), but is not a full native-parity implementation.
    """

    csf_unit: int
    csf_file: str
    outer: dict = field(default_factory=dict)  # letter -> count
    active: list = field(default_factory=list)  # CARD 2 shell labels, in order
    reference: list = field(default_factory=list)  # [[(label, count), ...], ...]
    coupling_order: list = field(default_factory=list)  # CARD 4 shell labels
    closed_shell_text: str = ''  # CARD 5, verbatim up to the first ')'
    sgshl: int = 0


_OPEN_RE = re.compile(r'UNIT\s*=\s*(\d+)|FILE\s*=\s*([^\s,]+)')
_SHELL_COUNT_RE = re.compile(r'(\d+)([A-Za-z])')
_REF_TOKEN_RE = re.compile(r'(\d+)([A-Za-z])\*(\d+)(\)+)')


def _read_header(lines, i):
    csf_unit, csf_file = None, None
    while i < len(lines):
        raw = lines[i]
        i += 1
        content = raw.lstrip()
        if not content or content[0] in ('"', '#', '/'):
            continue
        if content[:3] == 'END':
            return csf_unit, csf_file, i
        for m in _OPEN_RE.finditer(content):
            if m.group(1):
                csf_unit = int(m.group(1))
            if m.group(2):
                csf_file = m.group(2)
    raise AtgReadError('OPEN/END header: END not found')


def _read_until(lines, i, terminator, comment_chars, card_name):
    """Accumulate lines into one buffer until `terminator` is found in a
    line (comment_chars checked at column 1 each line first)."""
    buf = ''
    while i < len(lines):
        raw = lines[i]
        i += 1
        if raw and raw[0] in comment_chars:
            continue
        idx = raw.find(terminator)
        buf += ' ' + (raw[:idx] if idx >= 0 else raw[:72])
        if idx >= 0:
            return buf, i
    raise AtgReadError(f"{card_name}: '{terminator}' not found")


def _read_card1(lines, i):
    buf, i = _read_until(lines, i, ')))', ("'", '"'), 'CARD 1')
    outer = {m.group(2).upper(): int(m.group(1)) for m in _SHELL_COUNT_RE.finditer(buf)}
    return outer, i


def _read_card2(lines, i):
    buf, i = _read_until(lines, i, ')))', ("'", '"'), 'CARD 2')
    active = [m.group(1) + m.group(2).upper() for m in _SHELL_COUNT_RE.finditer(buf)]
    return active, i


def _read_card3(lines, i):
    buf, i = _read_until(lines, i, ')))', ("'", '"'), 'CARD 3')
    references, current = [], []
    for m in _REF_TOKEN_RE.finditer(buf):
        label, count, parens = m.group(1) + m.group(2).upper(), int(m.group(3)), m.group(4)
        current.append((label, count))
        if len(parens) >= 2:
            references.append(current)
            current = []
    if current:
        references.append(current)
    return references, i


def _read_card4(lines, i):
    buf, i = _read_until(lines, i, ')', ('"',), 'CARD 4')
    return [tok.upper() for tok in buf.split()], i


def _read_card5(lines, i):
    while i < len(lines):
        raw = lines[i]
        i += 1
        if raw and raw[0] == '"':
            continue
        idx = raw.find(')')
        return (raw[:idx] if idx >= 0 else raw), i
    raise AtgReadError('CARD 5: unexpected end of file')


def _read_card6(lines, i):
    while i < len(lines):
        raw = lines[i]
        i += 1
        if raw and raw[0] == '"':
            continue
        return int(raw.strip()), i
    raise AtgReadError('CARD 6: unexpected end of file')


def read_atg(path):
    with open(path, encoding='utf-8') as f:
        lines = f.read().split('\n')
    i = 0
    csf_unit, csf_file, i = _read_header(lines, i)
    outer, i = _read_card1(lines, i)
    active, i = _read_card2(lines, i)
    reference, i = _read_card3(lines, i)
    coupling_order, i = _read_card4(lines, i)
    closed_shell_text, i = _read_card5(lines, i)
    sgshl, i = _read_card6(lines, i)
    return AtgData(csf_unit=csf_unit, csf_file=csf_file, outer=outer, active=active,
                   reference=reference, coupling_order=coupling_order,
                   closed_shell_text=closed_shell_text, sgshl=sgshl)
