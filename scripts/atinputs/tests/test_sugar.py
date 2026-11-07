from ..parser import parse_file
from ..schema import validate
from ..sugar import SugarError, build, core_electrons, parse_occ
import pytest


def _load(atinputs_dir, name):
    path = str(atinputs_dir / f'{name}.inp')
    return validate(parse_file(path), path)


def _load_text(text, samples_dir):
    from ..parser import parse
    data = validate(parse(text, 'x.inp'), 'x.inp')
    return build(data, basis_dir=str(samples_dir))


_MINIMAL_RS = """
title: x
deck: x.deck
csf: x.csf
atom:
  z: 9
  ang: P
  spin: 2
files:
  cfptable: ./CFPTBL
  basis: f.bas
  format: atomci
orbital:
  frozen_core: 1S
  active: 2S, 2P
  outer: 11S, 10P, 6D, 5F
reference:
  - occ: 2S*2 2P*5
ctrl:
  rs: print: -0.001{extra}
"""


def test_parse_occ():
    assert parse_occ('2S*2 2P*5') == [('2S', 2), ('2P', 5)]


def test_parse_occ_bad_token():
    with pytest.raises(SugarError):
        parse_occ('2S-2')


def test_core_electrons_counts_2_2l_plus_1_per_shell():
    core = [{'label': '1S', 'n': 1, 'l': 0}, {'label': '2S', 'n': 2, 'l': 0},
            {'label': '2P', 'n': 2, 'l': 1}, {'label': '3D', 'n': 3, 'l': 2}]
    assert core_electrons(core) == 2 + 2 + 6 + 10


def test_f_itnel_ispin_iorb_ipar(atinputs_dir, samples_dir):
    data = _load(atinputs_dir, 'f')
    deck = build(data, basis_dir=str(samples_dir))
    mc = next(b for b in deck.passes[0].blocks if b.group == 'MC')
    assert mc.params['itnel'] == 9
    assert mc.params['ispin'] == 2
    assert mc.params['iorb'] == 3
    assert mc.params['ipar'] == 1  # F: 2S*2 2P*5 -> sum l = 0*2 + 1*5 = 5, odd


def test_f_closed_and_csfs(atinputs_dir, samples_dir):
    data = _load(atinputs_dir, 'f')
    deck = build(data, basis_dir=str(samples_dir))
    mc = next(b for b in deck.passes[0].blocks if b.group == 'MC')
    assert mc.params['closed'].value == ' 1S)'
    assert mc.params['csfs'].values == [' 2S*2) 2P*5))', ' )))']


def test_f_nrnfg(atinputs_dir, samples_dir):
    data = _load(atinputs_dir, 'f')
    deck = build(data, basis_dir=str(samples_dir))
    cntl = deck.passes[0].blocks[0]
    assert cntl.group == 'CNTL'
    assert cntl.params['nrnfg'].values == [1, 1, 1, 1, 0, 0, 1, 1]


def test_fpt_nrnfg_no_mc(atinputs_dir, samples_dir):
    data = _load(atinputs_dir, 'fpt')
    deck = build(data, basis_dir=str(samples_dir))
    cntl = deck.passes[0].blocks[0]
    assert cntl.params['nrnfg'].values == [1, 0, 1, 1, 1, 1, 1, 1]
    groups = [b.group for b in deck.passes[0].blocks]
    assert 'MC' not in groups


def test_rs_without_nrnfg_is_unchanged(samples_dir):
    # Strictly additive: omitting ctrl.rs.nrnfg must produce
    # the exact same &RS params as before it existed -- no 'nrnfg' key at
    # all, not merely a default value for it. This is what keeps every
    # existing .inp file (f.inp, fpt.inp, and any user's) byte-identical.
    deck = _load_text(_MINIMAL_RS.format(extra=''), samples_dir)
    rs = next(b for b in deck.passes[0].blocks if b.group == 'RS')
    assert rs.params == {'pthr': -0.001, 'rule': 2}


def test_rs_nrnfg_is_exposed_when_present(samples_dir):
    # fpt.stdin (the hand-written native deck) uses &RS NRNFG=1 for the
    # rejected-CSF energy-correction estimate -- the jar could never emit
    # it; this closes that fidelity gap.
    deck = _load_text(_MINIMAL_RS.format(extra=', nrnfg: 1'), samples_dir)
    rs = next(b for b in deck.passes[0].blocks if b.group == 'RS')
    assert rs.params == {'pthr': -0.001, 'rule': 2, 'nrnfg': 1}


def test_tr_and_get_derived_from_basis(atinputs_dir, samples_dir):
    data = _load(atinputs_dir, 'f')
    deck = build(data, basis_dir=str(samples_dir))
    tr = next(b for b in deck.passes[0].blocks if b.group == 'TR')
    assert tr.params['nsym'] == 4
    assert tr.params['nob'].values == [13, 11, 6, 5]
    assert tr.params['itvci'] == 1  # default, even though f.inp's tr has no 'record'
    get = next(b for b in deck.passes[0].blocks if b.group == 'GET')
    assert get.params['nind'] == 4
    assert get.params['ind'].values[:4] == [1, 0, 1, 13]
