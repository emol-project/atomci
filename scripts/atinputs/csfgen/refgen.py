"""Shell table + reference-configuration setup — ported from `ATRGEN`
(`src/atlib.f:628-834`) and the shell-table bootstrap it performs from data
`ATREAD` already parsed (`NORTS`/`MAXOC`, `src/atlib.f:699-715`).

**Shell table.** One row per *named* (occupied/active) shell, plus exactly
one aggregate "virtual"/correlating row per symmetry kind — appended for
*every* kind present in CARD 1 (`orbital.outer`), even a kind that also has
named shells (confirmed: the F-atom sample's shell table is
`[2S, NS, 2P, NP, ND, NF]`, `MSCHL=6` — S and P each keep their own named
shell *and* get an aggregate row). The aggregate row's capacity is the
*combined* Pauli capacity of every correlating orbital of that kind at once
(`MOCCN(kind) * NORBT(kind)`, `src/atlib.f:710-715`), not a per-orbital cap —
this is the structural fact behind the "one compact NCONF row = many
individual virtual orbitals" printed notation (see `format.py`).

**`MOCCN`** (max occupation per shell of a kind) is ported verbatim from
`ATREAD`'s defaults, *including* what looks like an oversight for G/H/I
(`2` instead of the `2(2l+1)` pattern S/P/D/F follow) — this is what the
source actually does, not what the physics "should" say.

**Reference configurations** (CARD 3) map each `label*count` token onto its
shell-table row by exact label match. `NCONF(MSCHL+1, i)` — the parity
marker consumed by `excite.py`'s double-excitation gate — is hardcoded to
`1` for every reference (`src/atlib.f:786-787`): a construction baseline,
not a check against any physical/absolute parity value.
"""

from dataclasses import dataclass, field

from ..constants import ANGULAR_MOMENTUM_LETTERS
from ..sugar import parse_occ

# Ported verbatim from ATREAD's defaults (src/atlib.f): kinds 1-7 get
# 2,6,10,14,2,2,2; kinds 8-10 (K,L,M) keep the generic default of 50. Not
# "corrected" to 2(2l+1) for G/H/I -- faithfully reproducing the source,
# not the physics it presumably meant to express.
MOCCN_DEFAULTS = {
    'S': 2, 'P': 6, 'D': 10, 'F': 14, 'G': 2, 'H': 2, 'I': 2,
    'K': 50, 'L': 50, 'M': 50,
}

# NPRTY(kind) = (-1)^l -- S=+1, P=-1, D=+1, F=-1, ... matches ATREAD's
# "alternates +1,-1 per kind index" (kind index is assigned in ascending-l
# order by construction, see CARD 1's fragility note in atg.py).
def parity_of_kind(kind):
    return 1 if ANGULAR_MOMENTUM_LETTERS.index(kind) % 2 == 0 else -1


class RefGenError(Exception):
    pass


@dataclass
class Shell:
    label: str  # e.g. "2S", or "NS" for the aggregate virtual/correlating row
    kind: str  # letter, e.g. "S"
    is_virtual: bool  # True for the aggregate virtual/correlating row
    capacity: int  # MAXOC for this row


@dataclass
class ShellTable:
    shells: list = field(default_factory=list)  # MSCHL rows
    kind_order: list = field(default_factory=list)  # letters, ascending l
    norbt: dict = field(default_factory=dict)  # kind letter -> correlating-orbital count

    def index(self, label):
        for i, s in enumerate(self.shells):
            if s.label == label:
                return i
        raise RefGenError(f"shell '{label}' not in table")

    def virtual_index(self, kind):
        for i, s in enumerate(self.shells):
            if s.kind == kind and s.is_virtual:
                return i
        raise RefGenError(f"no virtual row for kind '{kind}'")


@dataclass
class Config:
    occ: list  # length MSCHL, occupation per shell row
    parity_marker: int = 1  # NCONF(MSCHL+1, i)
    # ref_index -> [(hole_row, particle_row), ...] -- one entry per swap
    # that reaches this config from that reference (1 for singles, 2 for
    # doubles); populated by excite.py, not here.
    paths: dict = field(default_factory=dict)


def build_shell_table(data):
    outer = data['orbital'].get('outer', [])
    active = data['orbital'].get('active', [])
    if not outer:
        raise RefGenError("orbital.outer is empty -- no correlating orbitals to build a shell table from")
    kinds = sorted({ANGULAR_MOMENTUM_LETTERS[s['l']] for s in outer},
                   key=ANGULAR_MOMENTUM_LETTERS.index)
    norbt = {ANGULAR_MOMENTUM_LETTERS[s['l']]: s['n'] for s in outer}

    table = ShellTable(kind_order=kinds, norbt=norbt)
    for kind in kinds:
        moccn = MOCCN_DEFAULTS.get(kind)
        if moccn is None:
            raise RefGenError(f"no MOCCN default for kind '{kind}'")
        for shell in active:
            if shell['label'][-1].upper() == kind:
                table.shells.append(Shell(shell['label'], kind, False, moccn))
        table.shells.append(Shell(f'N{kind}', kind, True, moccn * norbt[kind]))
    return table


def card5_closed_shell_text(frozen_core):
    """CARD 5's raw text: copied verbatim into the
    generated CSF's closed-shell lines by ATPRNT, so the leading whitespace
    here is not cosmetic. The 3-space indent matches samples/native/f.atg/fpt.atg
    and was confirmed to round-trip byte-identically through real atgen
    (see atg.py's write_atg docstring)."""
    return '   ' + ' '.join(s['label'] for s in frozen_core)


def build_references(data, table):
    references = []
    for cfg in data['reference']:
        occ = [0] * len(table.shells)
        for label, count in parse_occ(cfg['occ']):
            occ[table.index(label)] = count
        references.append(Config(occ=occ, parity_marker=1))
    return references
