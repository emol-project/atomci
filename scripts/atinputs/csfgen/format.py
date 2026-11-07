"""CSF card-punch output — ported from `ATPRNT` (`src/atgen.f:316-968`).

`ATPRNT` builds output through a tiny "card image" buffering API
(`IQPUTC`/`IQPUTI`/`IQXSET`/`IQCSET`/`IQLSET`, `src/fpl90lib.f`) rather than
direct `WRITE`s; `Card` below reproduces that API's semantics directly
(1-indexed column cursor, `IQXSET`=relative skip, `IQCSET`=absolute jump,
`IQLSET(n)`=flush n times, where flushing an already-empty buffer emits a
genuine blank line — this is the actual mechanism behind every blank line
in the output, confirmed at `src/fpl90lib.f:219-315`).

**72-column wrap** (`IQPUTC`/`IQPUTI`, `src/fpl90lib.f:160-166,189-195`):
every write checks `col + len(text) - 1 > 72` *before* writing, on the
write's own width — `IQXSET`/`IQCSET` bypass the check entirely, since they
touch only the column cursor, never the buffer (confirmed: `src/fpl90lib.f`
has no such guard in `IQXSET`/`IQCSET`), so a gap can legally push the
cursor past column 72 with no wrap until the *next* `putc`/`puti`. On
overflow the buffer flushes (same rstrip-to-min-one-space rule as `IQLSET`)
and the new line opens with columns 1-5 blank, `'*'` at column 6 (the
Fortran fixed-form continuation flag — this is unit 2, the CSF file, the
only channel `IQPUTC` special-cases this way), and the write resumes at
column 7. Because the check runs per-write rather than per-token, a
multi-write token (e.g. shell label + `'*'` + count) can split mid-token —
confirmed byte-for-byte against native on the 11-active-shell case
: `...1D* 1   )` ends one line at column 67 (a
`KSHL>5` regroup, not a width wrap), then `...2G` runs out of room at
column 72 mid-way through `1H`'s label, continuing as `     ** 1   ))` —
column 6's `*` (the flag) immediately followed by column 7's `*` (the
literal separator `putc('*', 1)` that didn't fit on the prior line).

**The print-time parity filter.** All three selection loops below (the
un-headed `NE0==NACTE` group, `FIRST ORDER SPACE`, `SECOND ORDER SPACE` —
`src/atgen.f:723,752,809`) skip any config whose stored marker
(`NCONF(MSCHL+1,·)`, called `NACC` in the source) is negative. See
`excite.py`'s docstring for why singles can fail this (unfiltered at
generation time) while doubles never do (their marker is unconditionally
zeroed by `ATDGEN`).

**Header** (`src/atgen.f:655-674`): for each kind with `NORBT>0`, prints
virtual-orbital numbers descending from `NORBT+10` to `11` (a hardcoded
constant start, not derived from anything else), 5 columns/item
(`IQPUTI(id,3)` + 1-char letter + 1 space), wrapping after any `id` ending
in `1`. `LPAD = 9 - (NORBT-1) % 10` blank 5-column placeholders precede the
loop so every line — first (partial) group included — normalizes to
exactly 50 columns, right-justified.

**Valence line + closed shells** (`src/atgen.f:675-692`): the coupling-order
line uses a *different* grid (`IQXSET(2)` then repeating `label(2 cols) +
IQXSET(3)` = 5 cols/item, offset +2 from the header's grid). `CLOSHL` (the
free-text CARD 5 content) is printed **twice**, identically, followed by a
separate `' ))'` line — all three confirmed as literal, unconditional
source lines, not something a loop or flag varies.

**Excitation labels** use a third grid: `CARDX`/`CARDY`, fixed 62-character
templates (`(2X,20A3)` — 2 spaces + 20 three-column fields) built once per
kind from its correlating-orbital count, right-justified so the lowest
orbital number always lands in the same trailing column position. This is
*not* the same grid as the header block (5 cols/item, 50-col-normalized) —
implemented here as separate functions per `ATPRNT`'s own research notes.

**`INNER_PRINT`** (`src/atgen.f:609-652`): the "remaining valence
occupation" line. 10-column initial indent, 12 columns/shell (`label(2) +
'*' + count(2, right-justified) + 4-char suffix`), zero-occupancy valence
shells skipped, wraps every 5 printed shells. Always ends with one extra
`') '` (the record's own closing paren) then `IQLSET(2)` — i.e. every
printed CSF record is followed by exactly one blank line, no exceptions.
The optional `SGSHL>0` singlet-coupling suffix (`' 1S)'` in place of the
default `'   )'`) is not implemented — this generator fixes `SGSHL=-1`
throughout (`constants.ATG_SGSHL_DEFAULT`), so that branch is never
exercised.

**SECOND ORDER SPACE's dual representation** (`src/atgen.f:890-945`,
dispatch table `src/atgen.f:962`): when both outer electrons occupy the
*same* virtual shell (`NCONF(J,I)==2`), that ONE table entry is printed
**twice** — once as `"...* 2  )"` with its own remaining-occupation line,
and again as `"...* 1  )"` `"...* 1  )"` (two singly-occupied
representations of the identical shell) with a second, independent
remaining-occupation line. Traced directly from the computed-`GOTO`
dispatch, not inferred from the sample output.
"""

from .refgen import parity_of_kind

# CARDX/CARDY orbital-number labels: CHARX(1)='11' .. CHARX(40)='50'
# (src/atgen.f, DATA-initialized). Index 1-based, matching the source.
_CHARX = [str(n) for n in range(11, 51)]

# IQLMAX(2) (src/fpl90lib.f:24) -- the CSF file's fixed-form card width.
# Card is only ever used for this one channel, so this is a module
# constant rather than a per-instance parameter (unlike IQLMAX, which is
# an array over all five IQ channels).
_MAX_COL = 72


class Card:
    """Reproduces the IQPUTC/IQPUTI/IQXSET/IQCSET/IQLSET line-buffer API."""

    def __init__(self):
        self.lines = []
        self._chars = []
        self.col = 1  # 1-indexed, next write position

    def putc(self, text, width=None):
        if width is not None:
            text = text[:width].ljust(width)
        if text and self.col + len(text) - 1 > _MAX_COL:
            self._flush()
            self._chars = [' ', ' ', ' ', ' ', ' ', '*']
            self.col = 7
        start = self.col - 1
        end = start + len(text)
        if len(self._chars) < end:
            self._chars.extend([' '] * (end - len(self._chars)))
        self._chars[start:end] = list(text)
        self.col = end + 1

    def puti(self, value, width):
        self.putc(str(value).rjust(width))

    def xset(self, n):
        self.col += n

    def cset(self, n):
        self.col = n

    def lset(self, n=1):
        for _ in range(n):
            self._flush()

    def _flush(self):
        # IQEMIT trims trailing blanks but "the search stops at column 2"
        # (src/fpl90lib.f) -- it never trims below 1 character, so an
        # untouched/all-blank buffer emits a single space, not an empty
        # line. Confirmed byte-for-byte against reference/f.atgen.csf.
        text = ''.join(self._chars).rstrip()
        self.lines.append(text if text else ' ')
        self._chars = []
        self.col = 1

    def text(self):
        return '\n'.join(self.lines) + '\n'


def _card_templates(table):
    """CARDX(kind): 62-char, right-justified virtual-orbital label strip
    for that kind (src/atgen.f:377-395). CARDY: the fixed 20-slot
    continuation template (labels 30..11), shared by every kind that needs
    it (NORBT>20 -- not exercised by this generator's current test cases; ported
    from source but with lower confidence than the rest of this module)."""
    cardx = {}
    for kind in table.kind_order:
        nx0 = table.norbt.get(kind, 0)
        if nx0 > 20:
            nb0 = 40 - nx0
            fields = ([''] * nb0) + [_CHARX[i - 1] for i in range(nx0, 20, -1)]
        else:
            nb0 = 20 - nx0
            fields = ([''] * nb0) + [_CHARX[i - 1] for i in range(nx0, 0, -1)]
        cardx[kind] = '  ' + ''.join(f.rjust(3) for f in fields)
    cardy = '  ' + ''.join(_CHARX[i - 1].rjust(3) for i in range(20, 0, -1))
    return cardx, cardy


def _format_header(table, card):
    for kind in table.kind_order:
        nouter = table.norbt.get(kind, 0)
        if nouter <= 0:
            continue
        lpad = 9 - (nouter - 1) % 10
        for _ in range(lpad):
            card.putc('     ', 5)
        for ident in range(nouter + 10, 10, -1):
            card.puti(ident, 3)
            card.putc(kind, 1)
            card.putc(' ', 1)
            if ident % 10 == 1:
                card.lset(1)


def _format_valence_and_closed(table, closed_shell_text, card):
    card.xset(2)
    for shell in table.shells:
        if shell.is_virtual:
            continue
        card.putc(shell.label, 2)
        card.xset(3)
    card.lset(1)
    card.putc(closed_shell_text, 60)
    card.putc(')', 1)
    card.lset(1)
    card.putc(closed_shell_text, 60)
    card.putc(')', 1)
    card.lset(1)
    card.putc(' )) ', 4)
    card.lset(1)


def _valence_indices(table):
    return [i for i, s in enumerate(table.shells) if not s.is_virtual]


def _ne0(config, valence_idx):
    return sum(config.occ[i] for i in valence_idx)


def _inner_print(config, table, valence_idx, card):
    """The remaining-occupation line + its trailing blank line."""
    card.xset(7)
    kshl = 0
    for i in valence_idx:
        nel = config.occ[i]
        if nel == 0:
            continue
        kshl += 1
        if kshl > 5:
            card.lset(1)
            card.xset(7)
            kshl = 0
        card.xset(3)
        card.putc(table.shells[i].label, 2)
        card.putc('*', 1)
        card.puti(nel, 2)
        card.putc('   )', 4)
    card.putc(') ', 2)
    card.lset(2)


def _print_virtual_label(card, cardx, table, shell_index, star_count):
    shell = table.shells[shell_index]
    card.putc(cardx[shell.kind], 62)
    card.putc(shell.kind, 1)
    card.putc(f'* {star_count}', 3)
    card.cset(68)
    card.putc(' )', 2)
    card.lset(1)


def _first_order_space(configs, table, cardx, valence_idx, nacte, sgshl, card):
    card.putc('" FIRST ORDER SPACE   ', 22)
    card.lset(1)
    for cfg in configs:
        if cfg.parity_marker < 0:
            continue
        if _ne0(cfg, valence_idx) != nacte - 1:
            continue
        outer_idx = next(i for i, s in enumerate(table.shells)
                          if s.is_virtual and cfg.occ[i] == 1)
        _print_virtual_label(card, cardx, table, outer_idx, 1)
        _inner_print(cfg, table, valence_idx, card)


def _second_order_space(configs, table, cardx, valence_idx, nacte, sgshl, card):
    # src/atgen.f label 1176: an extra IQLSET(1) precedes this heading only
    # (FIRST ORDER SPACE's heading has no such extra flush) -- on top of
    # the last FIRST-ORDER record's own blank line, this produces two
    # consecutive blank lines before "SECOND ORDER SPACE", confirmed
    # against the frozen reference CSF.
    card.lset(1)
    card.putc('" SECOND ORDER SPACE  ', 22)
    card.lset(1)
    virtual_idx = [i for i, s in enumerate(table.shells) if s.is_virtual]
    for cfg in configs:
        if cfg.parity_marker < 0:
            continue
        if _ne0(cfg, valence_idx) != nacte - 2:
            continue
        singles = [i for i in virtual_idx if cfg.occ[i] == 1]
        doubles = [i for i in virtual_idx if cfg.occ[i] == 2]
        if doubles:
            (i,) = doubles
            _print_virtual_label(card, cardx, table, i, 2)
            _inner_print(cfg, table, valence_idx, card)
            _print_virtual_label(card, cardx, table, i, 1)
            _print_virtual_label(card, cardx, table, i, 1)
            _inner_print(cfg, table, valence_idx, card)
        else:
            for i in singles:
                _print_virtual_label(card, cardx, table, i, 1)
            _inner_print(cfg, table, valence_idx, card)


def generate_csf_text(table, closed_shell_text, references, singles_table, all_configs,
                       sgshl):
    """table: refgen.build_shell_table()'s output.
    closed_shell_text: CARD 5's raw text (as sugar.py would build ' '.join
    of frozen_core labels, or whatever free text was supplied).
    references: refgen.build_references()'s output.
    singles_table: excite.generate_singles()'s output (references + singles).
    all_configs: excite.generate_doubles()'s output (+ doubles).
    sgshl: constants.ATG_SGSHL_DEFAULT normally.
    Returns the full CSF file text."""
    card = Card()
    cardx, _cardy = _card_templates(table)
    valence_idx = _valence_indices(table)
    nrefn = len(references)
    nscon = len(singles_table)
    nacte = _ne0(references[0], valence_idx) if references else 0

    _format_header(table, card)
    _format_valence_and_closed(table, closed_shell_text, card)
    card.lset(1)  # blank line after the header block, before references

    for ref in references:
        _inner_print(ref, table, valence_idx, card)

    if sgshl < 0:
        card.putc(' ) ', 3)
    card.lset(1)
    card.putc('" SINGLE AND DOUBLE EXCITATION  WITHIN GROUP 1  ', 48)
    card.lset(1)

    # un-headed "GROUP 1" section: NE0==NACTE, same marker filter
    for cfg in all_configs[nrefn:]:
        if cfg.parity_marker < 0:
            continue
        if _ne0(cfg, valence_idx) == nacte:
            _inner_print(cfg, table, valence_idx, card)

    if sgshl < -99:
        return _terminator(card)

    _first_order_space(all_configs[nrefn:], table, cardx, valence_idx, nacte, sgshl, card)

    if sgshl < -9:
        return _terminator(card)

    _second_order_space(all_configs[nscon:], table, cardx, valence_idx, nacte, sgshl, card)

    return _terminator(card)


def _terminator(card):
    # src/atgen.f:952-954 (label 1134): reached from all three exit paths
    # (SGSHL<-99, SGSHL<-9, or falling through SECOND ORDER SPACE). An
    # extra IQLSET(1) on top of whatever the last record's own trailing
    # blank line left -- confirmed against the frozen reference CSF (two
    # blank lines precede the terminator in the normal, full-generation case).
    card.lset(1)
    card.putc('   )))) ', 8)
    card.lset(1)
    return card.text()
