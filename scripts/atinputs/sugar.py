"""Validated dict -> IR.

Multi-pass decks (f.stdin's 3-pass restart structure):
`data['passes']`, when present, is a list of {title, ctrl, raw} -- each
becomes its own `ir.Pass`, built the exact same way a single pass always
was. No inheritance between passes: each pass's
`ctrl` is looked at in complete isolation, nothing carries from the
previous pass's blocks. `atom`/`orbital`/`reference`/`files` stay
calculation-wide, shared across every pass, exactly as before -- only
`title`/`ctrl`/`raw` become per-pass.
"""

import os
import re

from . import constants
from .basis import read_basis, with_orbitals
from .constants import ANGULAR_MOMENTUM_LETTERS, CTRL_STEP_ORDER
from .ir import Block, Deck, IntList, OpenLine, Pass, QuotedStr, RealScalar, StringArray
from .schema import pass_entries as _pass_entries

_OCC_RE = re.compile(r'^(\d+)([A-Za-z])\*(\d+)$')


class SugarError(Exception):
    pass


def _shell_l(label):
    m = re.match(r'^\d+([A-Za-z])$', label)
    if not m:
        raise SugarError(f"cannot parse shell label '{label}'")
    letter = m.group(1).upper()
    if letter not in ANGULAR_MOMENTUM_LETTERS:
        raise SugarError(f"unknown angular-momentum letter in '{label}'")
    return ANGULAR_MOMENTUM_LETTERS.index(letter)


def parse_occ(occ):
    """'2S*2 2P*5' -> [('2S', 2), ('2P', 5)]"""
    shells = []
    for token in occ.split():
        m = _OCC_RE.match(token)
        if not m:
            raise SugarError(f"cannot parse reference occupation token '{token}'")
        n, letter, count = m.group(1), m.group(2).upper(), int(m.group(3))
        shells.append((f'{n}{letter}', count))
    return shells


def core_electrons(frozen_core):
    """Electrons in the closed shells: 2(2l+1) each (2 for 1S, 6 for 2P)."""
    return sum(2 * (2 * shell['l'] + 1) for shell in frozen_core)


def _closed(frozen_core):
    labels = [shell['label'] for shell in frozen_core]
    return ' ' + ' '.join(labels) + ')'


def csfs_reference_line(cfg):
    """One &MC CSFS(i) element for a single reference configuration: each
    shell followed by ')', the last shell gets an extra ')'.
    Verified against the frozen f.deck for a single reference
    configuration; multi-configuration lists are not exercised by either
    sample.

    Exactly one CSFS array element per reference configuration -- there is
    no continuation across elements. Confirmed from the reader
    (`src/mcmcsf.f`'s GET_NEXT, `IC.GE.72`/`IC.EQ.72`->ERR, procedure
    WF_INF's `ID=ID+1` only on a config-ending `))`, never mid-config):
    each `CSFS(i)` is `CHARACTER*72` and MCMCSF's tokenizer treats running
    off the end of one element while still inside a configuration as a
    hard parse error (RTNCD=99), not a continuation signal. Unlike the CSF
    *file* (`csfgen/format.py`'s `Card`), there is nothing to wrap onto --
    a reference configuration whose rendered line exceeds 72 characters
    cannot be represented in this field at all under the native format.
    `lint.py`'s `_csf_lint` rejects that case before it reaches here."""
    shells = parse_occ(cfg['occ'])
    labels = [f'{label}*{count}' for label, count in shells]
    return ' ' + ') '.join(labels) + '))'


def _csfs(reference):
    """`csfs_reference_line` per reference configuration,
    plus a final array element ' )))' terminating the whole list."""
    lines = [csfs_reference_line(cfg) for cfg in reference]
    lines.append(' )))')
    return lines


def mcscf_references(reference):
    """The references of the MCSCF (&MC CSFS): those marked `scf: true`, or
    all of them when none is marked."""
    marked = [cfg for cfg in reference if cfg.get('scf')]
    return marked or list(reference)


def _itnel(frozen_core, reference):
    # Taken from the first reference: every reference has the same electron
    # count (lint checks it). Summing over all references gave twice the
    # count for a two-reference MRSDCI (fixed 2026-11-03).
    # No reference (a general CI written as raw blocks): the core only, as
    # the sum over an empty list gave before.
    closed_electrons = core_electrons(frozen_core)
    open_electrons = sum(count for _label, count in parse_occ(reference[0]['occ'])) \
        if reference else 0
    return closed_electrons + open_electrons


def _ipar(reference):
    # First reference, as in _itnel (lint checks that the parities agree).
    if not reference:
        return 0
    total_l = sum(
        _shell_l(label) * count for label, count in parse_occ(reference[0]['occ']))
    return total_l % 2


def _iorb(ang):
    letter = ang.strip().upper()
    if letter not in ANGULAR_MOMENTUM_LETTERS:
        raise SugarError(f"unknown angular-momentum letter '{ang}' in atom.ang")
    return 2 * ANGULAR_MOMENTUM_LETTERS.index(letter) + 1


def _nrnfg(ctrl):
    return [1 if step in ctrl else 0 for step in CTRL_STEP_ORDER]


def basis_ntype(data):
    """&AI NTYPE of the calculation: the first pass whose ctrl has 'ai'
    (2, GTF, if none has)."""
    for entry in _pass_entries(data):
        if 'ai' in entry['ctrl']:
            return entry['ctrl']['ai']['type']
    return 2


def occupied_counts(data, nsym):
    """Orbitals of each l (0..nsym-1) named in orbital.frozen_core and
    orbital.active."""
    counts = [0] * nsym
    for shell in data['orbital'].get('frozen_core', []) + data['orbital'].get('active', []):
        if shell['l'] < nsym:
            counts[shell['l']] += 1
    return counts


def orbital_nob(data, basis):
    """NOB per symmetry: the occupied orbitals of that l plus the number of
    correlating orbitals that orbital.outer gives for it (0 if it gives
    none). This is the number of orbitals the CSF list of atgen names, so
    NOB < NBF drops the highest vectors of the coefficient set. Without
    orbital.outer (decks whose &WF is a raw payload), NOB is NBF."""
    outer = data['orbital'].get('outer', [])
    if not outer:
        return list(basis.nob)
    counts = occupied_counts(data, basis.nsym)
    for shell in outer:
        if shell['l'] < basis.nsym:
            counts[shell['l']] += shell['n']
    return counts


def read_ci_basis(data, basis_dir):
    """The basis file, with NOB/MPOB for the orbitals of the CI."""
    basis = read_basis(os.path.join(basis_dir, data['files']['basis']), basis_ntype(data))
    return with_orbitals(basis, orbital_nob(data, basis))


def get_ind(tr, nob):
    """&GET IND rows: ctrl.tr.ind as given, or, with ctrl.tr.from_record,
    orbitals 1..NOB of every symmetry from that record."""
    if 'from_record' in tr:
        return [{'record': tr['from_record'], 'l': l, 'first': 1, 'last': k}
                for l, k in enumerate(nob) if k > 0]
    return tr.get('ind', [])


def _ind_flat(rows):
    return [v for row in rows for v in (row['record'], row['l'], row['first'], row['last'])]


def _put(params, name, ctrl_step, key=None, wrap=None):
    """params[name] = ctrl_step[key or name] if the key is present; lists
    become IntList (also used for reals, which emit.py prints as given)."""
    key = key or name
    if key in ctrl_step:
        value = ctrl_step[key]
        params[name] = IntList(value, wrap=wrap) if isinstance(value, list) else value


def _open_lines(data):
    opens = [OpenLine(unit=constants.CFPTBL_UNIT, file=data['files']['cfptable'],
                       format='binary', status='old')]
    for entry in data['files'].get('open', []):
        opens.append(OpenLine(unit=entry['unit'], file=entry['file'],
                               format=entry.get('format', ''),
                               status=entry.get('status', '')))
    # 'basis'/'csf' are absent for a deck whose &AI/&WF are raw blocks with
    # an inline payload instead of a separate file --
    # there is then no such file to OPEN at all.
    if 'basis' in data['files']:
        opens.append(OpenLine(unit=constants.AI_BASIS_UNIT, file=data['files']['basis'],
                               status='old'))
    if 'csf' in data:
        opens.append(OpenLine(unit=constants.WF_CSF_UNIT, file=data['csf'], status='unknown'))
    if 'mcp' in data['files']:
        opens.append(OpenLine(unit=constants.MCP_UNIT, file=data['files']['mcp'],
                               status='unknown'))
    return opens


def _build_pass_blocks(ctrl, ispin, iorb, ipar, itnel, data, basis_dir):
    """One pass's &AI.../&RS blocks (everything but &CNTL itself) from its
    own `ctrl` dict. `ispin`/`iorb`/`ipar`/`itnel` and `data` (for
    `orbital`/`reference`/`files.basis`) are calculation-wide, computed
    once by `build()` and shared across every pass -- only `ctrl` varies
    per call."""
    frozen_core = data['orbital'].get('frozen_core', [])
    reference = data['reference']

    blocks = []

    # Parameter order: the keys that existed before 2026-11-03 keep their
    # place (samples/atinputs/reference/ is a byte-for-byte baseline); the
    # later keys follow.
    if 'ai' in ctrl:
        ai = {
            'z': RealScalar(data['atom']['z']),
            'iunit': constants.AI_BASIS_UNIT,
            'ntype': ctrl['ai']['type'],
        }
        _put(ai, 'idprnt', ctrl['ai'])
        blocks.append(Block('AI', ai))

    if 'mc' in ctrl:
        mc_ctrl = ctrl['mc']
        mc = {
            'ispin': ispin, 'iorb': iorb, 'ipar': ipar, 'itnel': itnel,
            'nset': mc_ctrl.get('nset', constants.MC_NSET),
        }
        _put(mc, 'itmax', mc_ctrl)
        mc['closed'] = QuotedStr(_closed(frozen_core))
        mc['csfs'] = StringArray(_csfs(mcscf_references(reference)))
        for name in ('ethr', 'c2thr', 'nsol', 'nopt'):
            _put(mc, name, mc_ctrl)
        if 'ind' in mc_ctrl:
            mc['nind'] = len(mc_ctrl['ind'])
            mc['ind'] = IntList(_ind_flat(mc_ctrl['ind']), wrap=4)
        blocks.append(Block('MC', mc))

    if 'wf' in ctrl:
        wf = {
            'ispin': ispin, 'iorb': iorb, 'ipar': ipar, 'itnel': itnel,
            'iunit': constants.WF_CSF_UNIT,
            'rule': ctrl['wf']['rule'],
        }
        for name in ('npflg', 'ismax', 'irmax'):
            _put(wf, name, ctrl['wf'])
        blocks.append(Block('WF', wf))

    if 'tr' in ctrl:
        tr = ctrl['tr']
        basis = read_ci_basis(data, basis_dir)
        ind = get_ind(tr, basis.nob)
        blocks.append(Block('TR', {
            'nfaii': tr.get('input_unit', constants.TR_NFAII_DEFAULT),
            'itvci': tr.get('record', constants.TR_ITVCI_DEFAULT),
            'nsym': basis.nsym,
            'nob': IntList(basis.nob),
            'nbf': IntList(basis.nbf),
            'mpob': IntList([v for row in basis.mpob for v in row], wrap=10),
        }))
        get = {
            'nind': len(ind),
            'ivcs': constants.GET_IVCS,
            'ind': IntList(_ind_flat(ind), wrap=4),
        }
        _put(get, 'nbase', tr)
        blocks.append(Block('GET', get))

    if 'pt' in ctrl:
        pt = {}
        for name, key in (('cthr', None), ('ethr', None), ('how', None),
                          ('nsolve', 'nstate'), ('istate', None), ('ips', None),
                          ('pthr', None), ('nrnfg', None)):
            _put(pt, name, ctrl['pt'], key)
        blocks.append(Block('PT', pt))

    if 'ex' in ctrl:
        ex = {}
        if 'retry' in ctrl['ex']:
            ex['retry'] = 1 if ctrl['ex']['retry'] else 0
        for name in ('nfexw', 'nfexe'):
            _put(ex, name, ctrl['ex'])
        blocks.append(Block('EX', ex))

    if 'ci' in ctrl:
        ci_ctrl = ctrl['ci']
        ci = {'nrnfg': IntList(list(constants.CI_NRNFG))}
        for name in ('ips', 'maxit', 'nsdim', 'nstate'):
            _put(ci, name, ci_ctrl)
        ci['ioflg'] = IntList(list(ci_ctrl.get('ioflg', constants.CI_IOFLG)))
        for name in ('nfiv', 'inflg', 'thrcsf', 'xref'):
            _put(ci, name, ci_ctrl)
        blocks.append(Block('CI', ci))

    if 'rs' in ctrl:
        rs = {}
        _put(rs, 'pthr', ctrl['rs'], 'print')
        rs['rule'] = ctrl['rs'].get('rule', constants.RS_RULE)
        _put(rs, 'nrnfg', ctrl['rs'])
        blocks.append(Block('RS', rs))

    return blocks


def _build_pass(title, ctrl, ispin, iorb, ipar, itnel, data, basis_dir):
    blocks = _build_pass_blocks(ctrl, ispin, iorb, ipar, itnel, data, basis_dir)
    cntl = Block('CNTL', {
        'nrnfg': IntList(_nrnfg(ctrl)),
        'title': QuotedStr(title),
    })
    return Pass(title=title, nrnfg=_nrnfg(ctrl), blocks=[cntl] + blocks)


def build(data, basis_dir='.'):
    """data: schema.validate()'s output. basis_dir: directory the basis
    file path in data['files']['basis'] is resolved relative to.

    data['passes'], if present and non-empty, is a list of {title, ctrl,
    raw} -- one ir.Pass per entry, no inheritance between them.
    Absent/empty: a single implicit pass from top-level
    title/ctrl -- raw.py handles top-level `raw` the same way it always has, in
    __main__.py, not here (raw merging was never sugar.py's job)."""
    reference = data['reference']
    frozen_core = data['orbital'].get('frozen_core', [])

    ispin = data['atom']['spin']
    iorb = _iorb(data['atom']['ang'])
    ipar = _ipar(reference)
    itnel = _itnel(frozen_core, reference)

    passes = [_build_pass(p['title'], p['ctrl'], ispin, iorb, ipar, itnel, data, basis_dir)
              for p in _pass_entries(data)]
    return Deck(open=_open_lines(data), passes=passes)
